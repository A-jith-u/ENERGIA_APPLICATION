"""Prophet training pipeline for minute-level PZEM data.

Workflow
1) Load raw measurements (1-min aggregates) from Postgres (DB_URL) or CSV
2) Preprocess: sort, de-duplicate, resample to 1-minute, interpolate, clip outliers
3) Persist the preprocessed dataset to a table for traceability
4) Train Prophet on `ds`/`y`
5) Generate a 15-minute forecast and persist it to a predictions table
6) Save the trained model to `models/prophet_model.joblib`

Notes
- Default raw table columns are suited for PZEM payloads: ts, voltage, current,
  power, power_factor, active_power, energy, frequency
- Target column defaults to `energy`; adjust with --target-col if needed
- DB_URL must be PostgreSQL (enforced elsewhere in config)
"""

import argparse
import os
from pathlib import Path
from typing import Optional

import joblib
import numpy as np
import pandas as pd
from prophet import Prophet
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError
import matplotlib.pyplot as plt

MODEL_DIR = Path("models")
MODEL_DIR.mkdir(parents=True, exist_ok=True)

DEFAULT_CSV = Path(r"..\sensor_data_export_fixed.csv")
PLOT_DIR = Path("metrics")
PLOT_DIR.mkdir(parents=True, exist_ok=True)


def load_from_db(
    db_url: str,
    table_name: str,
    ts_col: str,
    limit: int | None = None,
    lookback_days: Optional[int] = None,
) -> pd.DataFrame:
    engine = create_engine(db_url)
    where_clause = ""
    if lookback_days is not None and lookback_days > 0:
        where_clause = f" WHERE {ts_col} >= NOW() - INTERVAL '{int(lookback_days)} days'"
    query = f"SELECT * FROM {table_name}{where_clause} ORDER BY {ts_col}"
    if limit:
        query += f" LIMIT {limit}"
    return pd.read_sql(query, engine)


def preprocess_sensor_table(
    df: pd.DataFrame,
    ts_col: str = "ds",
    target_col: str = "value",
    resample_rule: str = "1min",
) -> pd.DataFrame:
    """
    Preprocess full sensor_data table with robust cleaning rules:
    - remove fully-missing rows
    - for single missing column, fill using nearest/median
    - constrain voltage to 236-240V
    - constrain other columns to frequent range (quantile clipping)
    - output Prophet-ready ds/y after resampling
    """
    if ts_col not in df.columns:
        raise ValueError(f"Timestamp column '{ts_col}' not found. Available: {list(df.columns)}")

    working = df.copy()

    # Derived robust target from real-world table sparsity
    if target_col.lower() == "power_or_value":
        if "power" not in working.columns or "value" not in working.columns:
            raise ValueError("power_or_value requires both 'power' and 'value' columns in sensor_data")
        working["power_or_value"] = pd.to_numeric(working["power"], errors="coerce").fillna(
            pd.to_numeric(working["value"], errors="coerce")
        )
        target_col = "power_or_value"

    if target_col not in working.columns:
        raise ValueError(f"Target column '{target_col}' not found. Available: {list(working.columns)}")

    numeric_candidates = [
        "value",
        "voltage",
        "current",
        "power",
        "energy",
        "frequency",
        "power_factor",
    ]
    numeric_cols = [column for column in numeric_candidates if column in df.columns]

    working[ts_col] = pd.to_datetime(working[ts_col], errors="coerce")
    working = working.dropna(subset=[ts_col])

    for column in numeric_cols:
        working[column] = pd.to_numeric(working[column], errors="coerce")

    if numeric_cols:
        missing_count = working[numeric_cols].isna().sum(axis=1)

        # Remove rows where all numeric columns are missing
        working = working.loc[missing_count < len(numeric_cols)].copy()

        # Fill rows with only one missing value using nearest neighbors first
        single_missing_mask = working[numeric_cols].isna().sum(axis=1) == 1
        nearest_filled = working[numeric_cols].ffill().bfill()
        working.loc[single_missing_mask, numeric_cols] = working.loc[single_missing_mask, numeric_cols].fillna(
            nearest_filled.loc[single_missing_mask, numeric_cols]
        )

        # Fill remaining gaps by interpolation, then median fallback
        working[numeric_cols] = working[numeric_cols].interpolate(method="linear", limit_direction="both")
        for column in numeric_cols:
            working[column] = working[column].fillna(working[column].median())

        # Voltage hard constraint
        if "voltage" in working.columns:
            working["voltage"] = working["voltage"].clip(lower=236.0, upper=240.0)

        # Other numeric columns constrained to frequently occurring range (10th-90th percentile)
        # Keep target_col untouched here to avoid flattening the training signal.
        for column in numeric_cols:
            if column == "voltage" or column.lower() == target_col.lower():
                continue
            q10, q90 = working[column].quantile([0.10, 0.90])
            if pd.notna(q10) and pd.notna(q90) and q90 > q10:
                working[column] = working[column].clip(lower=q10, upper=q90)

    prophet_df = working[[ts_col, target_col]].rename(columns={ts_col: "ds", target_col: "y"})
    prophet_df = prophet_df.dropna(subset=["ds", "y"]).sort_values("ds").drop_duplicates(subset=["ds"], keep="last")
    prophet_df = prophet_df.set_index("ds").resample(resample_rule).mean()
    prophet_df["y"] = prophet_df["y"].interpolate(method="time", limit=5, limit_direction="both")
    prophet_df = prophet_df.reset_index().dropna(subset=["y"])
    prophet_df["y"] = prophet_df["y"].clip(lower=0)

    q_low, q_high = prophet_df["y"].quantile([0.01, 0.99])
    prophet_df["y"] = prophet_df["y"].clip(lower=q_low, upper=q_high)
    prophet_df = prophet_df.dropna(subset=["y"])

    return prophet_df[["ds", "y"]]


def add_synthetic_samples(df: pd.DataFrame, target_rows: int = 3000, resample_rule: str = "1min") -> pd.DataFrame:
    """Augment with historical synthetic rows using minute-of-day profile and robust spread.

    Synthetic rows are generated BEFORE the earliest real timestamp to avoid leakage
    into evaluation windows.
    """
    clean = df[["ds", "y"]].dropna().sort_values("ds").copy()
    clean["source"] = "real"
    if len(clean) == 0 or len(clean) >= target_rows:
        return clean

    needed = target_rows - len(clean)
    rule_delta = pd.to_timedelta(resample_rule)

    # Build robust per-minute profile from real data
    clean["minute_of_day"] = clean["ds"].dt.hour * 60 + clean["ds"].dt.minute
    minute_median = clean.groupby("minute_of_day")["y"].median()
    minute_q25 = clean.groupby("minute_of_day")["y"].quantile(0.25)
    minute_q75 = clean.groupby("minute_of_day")["y"].quantile(0.75)

    global_median = float(clean["y"].median())
    global_iqr = float((clean["y"].quantile(0.75) - clean["y"].quantile(0.25)))
    base_noise = max(global_iqr * 0.08, 0.5)

    # Generate timestamps before real data to avoid leakage
    end = clean["ds"].min() - rule_delta
    synthetic_ds = pd.date_range(end=end, periods=needed, freq=resample_rule)
    synthetic_df = pd.DataFrame({"ds": synthetic_ds})
    synthetic_df["minute_of_day"] = synthetic_df["ds"].dt.hour * 60 + synthetic_df["ds"].dt.minute

    synthetic_df["y_base"] = synthetic_df["minute_of_day"].map(minute_median).fillna(global_median)
    spread = (minute_q75 - minute_q25).reindex(synthetic_df["minute_of_day"]).fillna(global_iqr)
    noise = np.random.normal(0.0, 1.0, len(synthetic_df)) * np.maximum(spread.to_numpy() * 0.20, base_noise)
    synthetic_df["y"] = (synthetic_df["y_base"] + noise).clip(lower=0)

    # Final winsorization to keep synthetic values in realistic operating range
    lo, hi = clean["y"].quantile([0.01, 0.99])
    synthetic_df["y"] = synthetic_df["y"].clip(lower=lo, upper=hi)

    synthetic_df = synthetic_df[["ds", "y"]]
    synthetic_df["source"] = "synthetic"
    augmented = pd.concat([synthetic_df, clean[["ds", "y", "source"]]], ignore_index=True).sort_values("ds")
    return augmented


def load_from_csv(path: str) -> pd.DataFrame:
    for encoding in ['utf-16', 'utf-8-sig', 'utf-8', 'latin-1', 'cp1252']:
        try:
            return pd.read_csv(path, encoding=encoding)
        except (UnicodeDecodeError, UnicodeError):
            continue
    # If nothing worked, try with errors='ignore'
    return pd.read_csv(path, encoding='utf-8', errors='ignore')


def preprocess_raw(
    df: pd.DataFrame,
    ts_col: str,
    target_col: str,
    resample_rule: str = "1min",
    energy_to_power: bool = True,
) -> pd.DataFrame:
    """
    Keep ONLY ds + y for Prophet. Clean, sort, de-dup, resample, interpolate, clip outliers.
    If target_col == 'energy' and energy_to_power is True, convert to power (W).
    """
    if ts_col not in df.columns:
        raise ValueError(f"Timestamp column '{ts_col}' not found. Available: {list(df.columns)}")
    if target_col not in df.columns:
        raise ValueError(f"Target column '{target_col}' not found. Available: {list(df.columns)}")

    working = df[[ts_col, target_col]].copy()

    # Parse timestamps and target
    working[ts_col] = pd.to_datetime(working[ts_col], errors="coerce")
    working[target_col] = pd.to_numeric(working[target_col], errors="coerce")

    # Drop bad rows
    working = working.dropna(subset=[ts_col, target_col])

    # Sort and de-duplicate by timestamp
    working = working.sort_values(ts_col).drop_duplicates(subset=[ts_col], keep="last")

    # Rename for Prophet
    working = working.rename(columns={ts_col: "ds", target_col: "y"}).set_index("ds")

    # Resample to uniform interval
    resampled = working.resample(resample_rule).mean()

    # Interpolate small gaps only
    resampled = resampled.interpolate(method="time", limit=2)

    # Reset index
    resampled = resampled.reset_index()

    # If energy is cumulative, convert to power (W) for modeling
    if target_col.lower() == "energy" and energy_to_power:
        try:
            interval_hours = pd.to_timedelta(resample_rule).total_seconds() / 3600.0
            if interval_hours <= 0:
                raise ValueError
            # energy assumed in kWh -> power W
            resampled["y"] = (resampled["y"].diff() / interval_hours) * 1000.0
        except Exception:
            # Fallback: use actual time deltas
            dt_hours = resampled["ds"].diff().dt.total_seconds() / 3600.0
            resampled["y"] = (resampled["y"].diff() / dt_hours) * 1000.0

        # Drop first row and negatives (energy resets/noise)
        resampled = resampled.dropna(subset=["y"])
        resampled["y"] = resampled["y"].clip(lower=0)

    # Clip negatives
    resampled["y"] = resampled["y"].clip(lower=0)

    # Clip extreme outliers (less aggressive)
    q_low, q_high = resampled["y"].quantile([0.005, 0.995])
    resampled["y"] = resampled["y"].clip(lower=q_low, upper=q_high)

    # Final check
    resampled = resampled.dropna(subset=["y"])
    if list(resampled.columns) != ["ds", "y"]:
        raise ValueError(f"Expected columns ['ds','y'], got {list(resampled.columns)}")

    print(f"Preprocessed rows: {len(resampled)}")
    print(f"Range: {resampled['y'].min():.4f} - {resampled['y'].max():.4f}")
    print(f"Mean: {resampled['y'].mean():.4f}, Std: {resampled['y'].std():.4f}")

    return resampled


def _inverse_transform(arr: np.ndarray, log_transform: bool) -> np.ndarray:
    if not log_transform:
        return arr
    return np.expm1(arr)


def train_model(df: pd.DataFrame, changepoint_prior_scale: float = 0.5,
                seasonality_prior_scale: float = 10.0) -> Prophet:
    clean = df[["ds", "y"]].dropna().sort_values("ds")
    if len(clean) < 10:
        raise RuntimeError(f"Not enough rows to train Prophet (got {len(clean)})")

    model = Prophet(
        changepoint_prior_scale=changepoint_prior_scale,
        seasonality_prior_scale=seasonality_prior_scale,
        seasonality_mode="multiplicative",
        daily_seasonality=True,
        weekly_seasonality=False,
        yearly_seasonality=False,
        interval_width=0.80,
        changepoint_range=0.85,
    )

    model.fit(clean)
    return model


def evaluate_forecast(
    test_df: pd.DataFrame,
    forecast_tail: pd.DataFrame,
) -> dict[str, float]:
    actual = test_df["y"].to_numpy()
    pred = forecast_tail["yhat"].to_numpy()
    lower = forecast_tail["yhat_lower"].to_numpy()
    upper = forecast_tail["yhat_upper"].to_numpy()

    # Clamp to non-negative
    actual = np.clip(actual, 0, None)
    pred = np.clip(pred, 0, None)
    lower = np.clip(lower, 0, None)
    upper = np.clip(upper, 0, None)

    abs_err = np.abs(actual - pred)
    mae = float(np.mean(abs_err))
    rmse = float(np.sqrt(np.mean(np.square(abs_err))))

    denom = np.maximum(np.abs(actual), 10.0)
    mape = float(np.mean(abs_err / denom) * 100.0)
    smape = float(np.mean(2 * abs_err / (np.abs(actual) + np.abs(pred) + 1e-6)) * 100.0)

    coverage = float(np.mean((actual >= lower) & (actual <= upper)))
    r2 = float(1 - (np.sum((actual - pred) ** 2) / (np.sum((actual - np.mean(actual)) ** 2) + 1e-6)))
    accuracy = float(max(0.0, 100.0 - mape))

    return {
        "mae": mae,
        "rmse": rmse,
        "mape_percent": mape,
        "smape_percent": smape,
        "coverage": coverage,
        "accuracy": accuracy,
        "r2_score": r2,
    }


def save_df_to_db(df: pd.DataFrame, db_url: str, table_name: str, if_exists: str = "replace") -> None:
    engine = create_engine(db_url)
    try:
        df.to_sql(table_name, engine, if_exists=if_exists, index=False)
    except SQLAlchemyError as exc:
        raise RuntimeError(f"Failed to write to table '{table_name}': {exc}") from exc


def make_predictions(model: Prophet, horizon_minutes: int, freq: str) -> pd.DataFrame:
    future = model.make_future_dataframe(periods=horizon_minutes, freq=freq)
    forecast = model.predict(future.tail(horizon_minutes))
    preds = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].copy()

    preds["yhat"] = preds["yhat"].clip(lower=0)
    preds["yhat_lower"] = preds["yhat_lower"].clip(lower=0)
    preds["yhat_upper"] = preds["yhat_upper"].clip(lower=0)
    preds["generated_at"] = pd.Timestamp.utcnow()
    return preds


def save_accuracy_plot(test_df: pd.DataFrame, forecast_df: pd.DataFrame, metrics: dict,
                       show_plot: bool = True, save_plot: bool = True) -> None:
    # Align lengths safely
    n = min(len(test_df), len(forecast_df))
    ds = test_df["ds"].to_numpy()[:n]
    actual = test_df["y"].to_numpy()[:n]
    pred = forecast_df["yhat"].to_numpy()[:n]
    abs_err = np.abs(actual - pred)

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 7), sharex=True)
    ax1.plot(ds, actual, label="Actual", linewidth=1.5)
    ax1.plot(ds, pred, label="Predicted", linewidth=1.2)
    ax1.set_title("Model Accuracy (Actual vs Predicted)")
    ax1.set_ylabel("Value")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    ax2.plot(ds, abs_err, color="tomato", linewidth=1.2)
    ax2.set_title("Absolute Error")
    ax2.set_ylabel("Error")
    ax2.set_xlabel("Time")
    ax2.grid(True, alpha=0.3)

    # Add metrics text
    fig.suptitle(
        f"MAE={metrics['mae']:.2f}, RMSE={metrics['rmse']:.2f}, "
        f"MAPE={metrics['mape_percent']:.2f}%, R²={metrics['r2_score']:.3f}",
        fontsize=10
    )
    fig.tight_layout()

    if save_plot:
        out_path = PLOT_DIR / "accuracy_plot.png"
        fig.savefig(out_path, dpi=150)
        print(f"Saved accuracy plot to {out_path.resolve()}")

    if show_plot:
        try:
            plt.show()
        except Exception as exc:  # noqa: BLE001
            print(f"Plot display failed: {exc}")

    plt.close(fig)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train Prophet on minute-level energy data")
    parser.add_argument("--csv", default=None, help="Path to CSV with raw data")
    parser.add_argument("--source", choices=["db", "csv"], default="db", help="Training source")
    parser.add_argument("--db-url", help="Database URL (overrides env DB_URL)")
    parser.add_argument("--raw-table", default="sensor_data", help="Raw input table name")
    parser.add_argument("--processed-table", default="prophet_preprocessed", help="Table to store preprocessed data")
    parser.add_argument("--predictions-table", default="prophet_predictions", help="Table to store forecast output")
    parser.add_argument("--ts-col", default="ds", help="Timestamp column in raw data")
    parser.add_argument("--target-col", default="power_or_value", help="Target column to forecast")
    parser.add_argument("--resample", default="1min", help="Pandas offset alias for resampling")
    parser.add_argument("--horizon-minutes", type=int, default=15, help="Forecast horizon in minutes")
    parser.add_argument("--out", default=str(MODEL_DIR / "prophet_model.joblib"), help="Path to save model")
    parser.add_argument("--limit", type=int, help="Limit rows from raw source")
    parser.add_argument("--lookback-days", type=int, default=14,
                        help="Use only the latest N days from DB source")
    parser.add_argument("--no-db-write", action="store_true", help="Skip writing to DB")
    parser.add_argument("--no-save-predictions", action="store_true", help="Skip writing predictions")
    parser.add_argument("--eval-split", type=float, default=0.2, help="Evaluation split ratio")
    parser.add_argument("--changepoint-prior", type=float, default=0.2, help="changepoint_prior_scale")
    parser.add_argument("--seasonality-prior", type=float, default=8.0, help="seasonality_prior_scale")
    parser.add_argument("--energy-to-power", action="store_true",
                        help="If target is energy (cumulative), convert to power W before training")
    parser.add_argument("--synthetic-target-rows", type=int, default=600,
                        help="Minimum rows after synthetic augmentation")
    parser.add_argument(
        "--export-training-csv",
        default=str(PLOT_DIR / "prophet_training_combined.csv"),
        help="Path to export combined real+synthetic training dataset CSV",
    )
    parser.add_argument("--no-save-plot", action="store_true", help="Do not save accuracy plot")
    parser.add_argument("--no-show-plot", action="store_true", help="Do not show accuracy plot")
    args = parser.parse_args()

    print(
        "Training profile: "
        f"source={args.source}, table={args.raw_table}, target={args.target_col}, "
        f"lookback_days={args.lookback_days}, synthetic_target_rows={args.synthetic_target_rows}, "
        f"eval_split={args.eval_split}, changepoint_prior={args.changepoint_prior}, "
        f"seasonality_prior={args.seasonality_prior}"
    )

    db_url = args.db_url or os.environ.get("DB_URL")

    if args.source == "db":
        if not db_url:
            raise RuntimeError("DB_URL is required when --source db")
        raw_df = load_from_db(
            db_url,
            table_name=args.raw_table,
            ts_col=args.ts_col,
            limit=args.limit,
            lookback_days=args.lookback_days,
        )
        print(
            f"Loaded {len(raw_df)} raw rows from table '{args.raw_table}' "
            f"(lookback_days={args.lookback_days})"
        )
        processed_df = preprocess_sensor_table(
            raw_df,
            ts_col=args.ts_col,
            target_col=args.target_col,
            resample_rule=args.resample,
        )
    else:
        csv_path = args.csv or str(DEFAULT_CSV)
        raw_df = load_from_csv(csv_path)
        print(f"Loaded {len(raw_df)} raw rows from {csv_path}")
        processed_df = preprocess_raw(
            raw_df,
            ts_col=args.ts_col,
            target_col=args.target_col,
            resample_rule=args.resample,
            energy_to_power=args.energy_to_power,
        )

    if db_url and not args.no_db_write:
        save_df_to_db(processed_df, db_url, args.processed_table, if_exists="replace")

    split_idx = max(10, int(len(processed_df) * (1 - args.eval_split)))
    if split_idx >= len(processed_df):
        raise RuntimeError("Not enough data to create eval split; reduce --eval-split")

    train_df = processed_df.iloc[:split_idx]
    test_df = processed_df.iloc[split_idx:]

    train_df_aug = add_synthetic_samples(
        train_df,
        target_rows=args.synthetic_target_rows,
        resample_rule=args.resample,
    )
    print(f"Real rows: {len(processed_df)} | Train rows after augmentation: {len(train_df_aug)}")

    eval_model = train_model(train_df_aug, args.changepoint_prior, args.seasonality_prior)
    future_eval = eval_model.make_future_dataframe(periods=len(test_df), freq=args.resample)
    forecast_eval = eval_model.predict(future_eval.tail(len(test_df)))

    metrics = evaluate_forecast(test_df, forecast_eval)
    print("\nEVALUATION METRICS")
    print(f"  MAE:      {metrics['mae']:.2f}")
    print(f"  RMSE:     {metrics['rmse']:.2f}")
    print(f"  MAPE:     {metrics['mape_percent']:.2f}%")
    print(f"  sMAPE:    {metrics['smape_percent']:.2f}%")
    print(f"  Accuracy: {metrics['accuracy']:.2f}%")
    print(f"  R²:       {metrics['r2_score']:.4f}")
    print(f"  Coverage: {metrics['coverage']*100:.1f}%\n")

    full_train_aug = add_synthetic_samples(
        processed_df,
        target_rows=max(args.synthetic_target_rows, len(processed_df)),
        resample_rule=args.resample,
    )
    export_cols = ["ds", "y"] + (["source"] if "source" in full_train_aug.columns else [])
    full_train_aug[export_cols].to_csv(args.export_training_csv, index=False)
    print(f"Exported combined training dataset to {args.export_training_csv} ({len(full_train_aug)} rows)")

    final_model = train_model(full_train_aug, args.changepoint_prior, args.seasonality_prior)
    joblib.dump(final_model, args.out)
    print(f"Saved model to {args.out}")

    if db_url and not args.no_db_write and not args.no_save_predictions:
        preds_df = make_predictions(final_model, args.horizon_minutes, args.resample)
        save_df_to_db(preds_df, db_url, args.predictions_table, if_exists="replace")
        print(f"Saved {len(preds_df)} predictions to '{args.predictions_table}'")

    save_accuracy_plot(
        test_df,
        forecast_eval,
        metrics,
        show_plot=not args.no_show_plot,
        save_plot=not args.no_save_plot
    )
