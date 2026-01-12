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
import pandas as pd
import numpy as np
from prophet import Prophet
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError

MODEL_DIR = Path("models")
MODEL_DIR.mkdir(parents=True, exist_ok=True)


def load_from_db(db_url: str, table_name: str, ts_col: str, limit: int | None = None) -> pd.DataFrame:
    engine = create_engine(db_url)
    query = f"SELECT * FROM {table_name} ORDER BY {ts_col}"
    if limit:
        query += f" LIMIT {limit}"
    df = pd.read_sql(query, engine)
    return df


def load_from_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    return df


def preprocess_raw(df: pd.DataFrame, ts_col: str, target_col: str, resample_rule: str = "1min") -> pd.DataFrame:
    if ts_col not in df.columns:
        raise RuntimeError(f"Timestamp column '{ts_col}' not found in dataset")
    if target_col not in df.columns:
        raise RuntimeError(f"Target column '{target_col}' not found in dataset")

    working = df.copy()
    working[ts_col] = pd.to_datetime(working[ts_col], utc=True, errors="coerce")
    working = working.dropna(subset=[ts_col]).sort_values(ts_col)
    # Prophet expects naive timestamps; strip tz after aligning to UTC
    working[ts_col] = working[ts_col].dt.tz_convert("UTC").dt.tz_localize(None)
    working = working[~working[ts_col].duplicated(keep="last")]

    numeric_cols = [c for c in working.columns if pd.api.types.is_numeric_dtype(working[c])]
    if not numeric_cols:
        raise RuntimeError("No numeric columns available for preprocessing")

    # Resample to uniform cadence
    resampled = working.set_index(ts_col).resample(resample_rule).mean()
    # Interpolate and back/forward fill to handle small gaps
    resampled[numeric_cols] = resampled[numeric_cols].interpolate(limit_direction="both").ffill().bfill()

    # Clip extreme outliers on the target to avoid blowing up the fit
    y_series = resampled[target_col]
    if y_series.empty:
        raise RuntimeError("No rows left after preprocessing; cannot train")
    q1, q3 = y_series.quantile([0.25, 0.75])
    iqr = q3 - q1
    if pd.notna(iqr) and iqr > 0:
        lower = q1 - 3 * iqr
        upper = q3 + 3 * iqr
        resampled[target_col] = y_series.clip(lower=lower, upper=upper)

    processed = resampled.reset_index().rename(columns={ts_col: "ds", target_col: "y"})
    ordered_cols = ["ds", "y"] + [c for c in processed.columns if c not in {"ds", "y"}]
    return processed[ordered_cols]


def train_model(df: pd.DataFrame) -> Prophet:
    clean = df[["ds", "y"]].dropna().sort_values("ds")
    if len(clean) < 10:
        raise RuntimeError(f"Not enough rows to train Prophet (got {len(clean)}, need >=10)")
    model = Prophet()
    model.fit(clean)
    return model


def evaluate_forecast(test_df: pd.DataFrame, forecast_tail: pd.DataFrame) -> dict[str, float]:
    actual = test_df["y"].to_numpy()
    pred = forecast_tail["yhat"].to_numpy()
    lower = forecast_tail["yhat_lower"].to_numpy()
    upper = forecast_tail["yhat_upper"].to_numpy()

    abs_err = np.abs(actual - pred)
    mae = float(np.mean(abs_err))
    rmse = float(np.sqrt(np.mean(np.square(abs_err))))
    denom = np.clip(np.abs(actual), 1e-6, None)
    mape = float(np.mean(abs_err / denom) * 100.0)
    coverage = float(np.mean((actual >= lower) & (actual <= upper)))
    accuracy = float(max(0.0, 1.0 - mape / 100.0))

    return {
        "mae": mae,
        "rmse": rmse,
        "mape_percent": mape,
        "coverage": coverage,
        "accuracy": accuracy,
    }


def save_df_to_db(df: pd.DataFrame, db_url: str, table_name: str, if_exists: str = "replace") -> None:
    engine = create_engine(db_url)
    try:
        df.to_sql(table_name, engine, if_exists=if_exists, index=False)
    except SQLAlchemyError as exc:  # noqa: BLE001
        raise RuntimeError(f"Failed to write to table '{table_name}': {exc}") from exc


def make_predictions(model: Prophet, horizon_minutes: int, freq: str) -> pd.DataFrame:
    future = model.make_future_dataframe(periods=horizon_minutes, freq=freq)
    forecast = model.predict(future.tail(horizon_minutes))
    preds = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].copy()
    preds["generated_at"] = pd.Timestamp.utcnow()
    return preds


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train Prophet on minute-level energy data")
    parser.add_argument("--csv", help="Path to CSV with raw data (will be preprocessed)")
    parser.add_argument("--db-url", help="Database URL (overrides env DB_URL)")
    parser.add_argument("--raw-table", default="pzem_readings", help="Raw input table name")
    parser.add_argument("--processed-table", default="prophet_preprocessed", help="Table to store preprocessed data")
    parser.add_argument("--predictions-table", default="prophet_predictions", help="Table to store forecast output")
    parser.add_argument("--ts-col", default="ts", help="Timestamp column in raw data")
    parser.add_argument("--target-col", default="energy", help="Target column to forecast")
    parser.add_argument("--resample", default="1min", help="Pandas offset alias for resampling (e.g., 1min, 5min)")
    parser.add_argument("--horizon-minutes", type=int, default=15, help="Forecast horizon in minutes")
    parser.add_argument("--out", default=str(MODEL_DIR / "prophet_model.joblib"), help="Path to save the trained model")
    parser.add_argument("--limit", type=int, help="Limit rows from raw source (dev only)")
    parser.add_argument("--no-db-write", action="store_true", help="Skip writing preprocessed/prediction tables to DB")
    parser.add_argument("--no-save-predictions", action="store_true", help="Skip writing predictions table")
    parser.add_argument("--eval-split", type=float, default=0.15, help="Fraction of tail data to hold out for evaluation (0-1)")
    args = parser.parse_args()

    db_url = args.db_url or os.environ.get("DB_URL")

    if args.csv:
        raw_df = load_from_csv(args.csv)
    else:
        if not db_url:
            raise RuntimeError("No DB_URL set and no CSV provided. Export DB_URL or pass --csv.")
        raw_df = load_from_db(db_url, table_name=args.raw_table, ts_col=args.ts_col, limit=args.limit)

    print(f"Loaded {len(raw_df)} raw rows")
    processed_df = preprocess_raw(raw_df, ts_col=args.ts_col, target_col=args.target_col, resample_rule=args.resample)
    print(f"Preprocessed rows: {len(processed_df)} (columns: {list(processed_df.columns)})")

    if db_url and not args.no_db_write:
        save_df_to_db(processed_df, db_url, args.processed_table, if_exists="replace")
        print(f"Saved preprocessed data to table '{args.processed_table}'")

    if not (0 < args.eval_split < 1):
        raise RuntimeError("--eval-split must be between 0 and 1")

    split_idx = max(10, int(len(processed_df) * (1 - args.eval_split)))
    if split_idx >= len(processed_df):
        raise RuntimeError("Not enough data to create an evaluation split; reduce --eval-split")

    train_df = processed_df.iloc[:split_idx]
    test_df = processed_df.iloc[split_idx:]
    print(f"Train rows: {len(train_df)} | Eval rows: {len(test_df)}")

    eval_model = train_model(train_df)
    future_eval = eval_model.make_future_dataframe(periods=len(test_df), freq=args.resample)
    forecast_eval = eval_model.predict(future_eval.tail(len(test_df)))
    metrics = evaluate_forecast(test_df, forecast_eval)
    print("Evaluation metrics:")
    print(f"  MAPE: {metrics['mape_percent']:.2f}%")
    print(f"  Accuracy (1 - MAPE): {metrics['accuracy']*100:.2f}%")
    print(f"  MAE: {metrics['mae']:.4f}")
    print(f"  RMSE: {metrics['rmse']:.4f}")
    print(f"  PI coverage: {metrics['coverage']*100:.1f}%")

    # Train final model on full data for saving and forecasting
    final_model = train_model(processed_df)
    joblib.dump(final_model, args.out)
    print(f"Saved model to {args.out}")

    if db_url and not args.no_db_write and not args.no_save_predictions:
        preds_df = make_predictions(final_model, horizon_minutes=args.horizon_minutes, freq=args.resample)
        save_df_to_db(preds_df, db_url, args.predictions_table, if_exists="replace")
        print(f"Saved {len(preds_df)} forecast rows to table '{args.predictions_table}'")

    print("Done.")
