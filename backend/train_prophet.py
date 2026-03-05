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


def load_from_db(db_url: str, table_name: str, ts_col: str, limit: int | None = None) -> pd.DataFrame:
    engine = create_engine(db_url)
    query = f"SELECT * FROM {table_name} ORDER BY {ts_col}"
    if limit:
        query += f" LIMIT {limit}"
    return pd.read_sql(query, engine)


def load_from_csv(path: str) -> pd.DataFrame:
    return pd.read_csv(path)


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
    parser.add_argument("--csv", default=str(DEFAULT_CSV), help="Path to CSV with raw data")
    parser.add_argument("--db-url", help="Database URL (overrides env DB_URL)")
    parser.add_argument("--raw-table", default="pzem_readings", help="Raw input table name")
    parser.add_argument("--processed-table", default="prophet_preprocessed", help="Table to store preprocessed data")
    parser.add_argument("--predictions-table", default="prophet_predictions", help="Table to store forecast output")
    parser.add_argument("--ts-col", default="ds", help="Timestamp column in raw data")
    parser.add_argument("--target-col", default="energy", help="Target column to forecast")
    parser.add_argument("--resample", default="1min", help="Pandas offset alias for resampling")
    parser.add_argument("--horizon-minutes", type=int, default=15, help="Forecast horizon in minutes")
    parser.add_argument("--out", default=str(MODEL_DIR / "prophet_model.joblib"), help="Path to save model")
    parser.add_argument("--limit", type=int, help="Limit rows from raw source")
    parser.add_argument("--no-db-write", action="store_true", help="Skip writing to DB")
    parser.add_argument("--no-save-predictions", action="store_true", help="Skip writing predictions")
    parser.add_argument("--eval-split", type=float, default=0.15, help="Evaluation split ratio")
    parser.add_argument("--changepoint-prior", type=float, default=0.5, help="changepoint_prior_scale")
    parser.add_argument("--seasonality-prior", type=float, default=10.0, help="seasonality_prior_scale")
    parser.add_argument("--energy-to-power", action="store_true",
                        help="If target is energy (cumulative), convert to power W before training")
    parser.add_argument("--no-save-plot", action="store_true", help="Do not save accuracy plot")
    parser.add_argument("--no-show-plot", action="store_true", help="Do not show accuracy plot")
    args = parser.parse_args()

    db_url = args.db_url or os.environ.get("DB_URL")

    # Always use CSV (sensor_data_export_fixed.csv) unless explicitly changed via --csv
    raw_df = load_from_csv(args.csv) if args.csv else load_from_db(
        db_url, table_name=args.raw_table, ts_col=args.ts_col, limit=args.limit
    )

    print(f"Loaded {len(raw_df)} raw rows from {args.csv}")

    processed_df = preprocess_raw(
        raw_df,
        ts_col=args.ts_col,
        target_col=args.target_col,
        resample_rule=args.resample,
        energy_to_power=args.energy_to_power
    )

    if db_url and not args.no_db_write:
        save_df_to_db(processed_df, db_url, args.processed_table, if_exists="replace")

    split_idx = max(10, int(len(processed_df) * (1 - args.eval_split)))
    if split_idx >= len(processed_df):
        raise RuntimeError("Not enough data to create eval split; reduce --eval-split")

    train_df = processed_df.iloc[:split_idx]
    test_df = processed_df.iloc[split_idx:]

    eval_model = train_model(train_df, args.changepoint_prior, args.seasonality_prior)
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

    final_model = train_model(processed_df, args.changepoint_prior, args.seasonality_prior)
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
