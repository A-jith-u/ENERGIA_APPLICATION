"""
Train a Prophet model from sensor time-series in a Postgres/TimescaleDB table or CSV.
Saves a joblib model file `models/prophet_model.joblib`.

Usage:
  # with DB
  export DB_URL=postgresql://user:pass@db:5432/energia
  python train_prophet.py

  # or point to CSV
  python train_prophet.py --csv data/sample_sensor.csv

The input data must have two columns: `ds` (timestamp ISO) and `y` (value to predict).
"""

import os
import argparse
from pathlib import Path
import pandas as pd
from prophet import Prophet
import joblib
from sqlalchemy import create_engine

MODEL_DIR = Path("models")
MODEL_DIR.mkdir(parents=True, exist_ok=True)


def load_from_db(db_url, table_name="sensor_data", ts_col="ts", value_col="value", limit=None):
    engine = create_engine(db_url)
    query = f"SELECT {ts_col} as ds, {value_col} as y FROM {table_name} ORDER BY {ts_col}"
    if limit:
        query += f" LIMIT {limit}"
    df = pd.read_sql(query, engine)
    df["ds"] = pd.to_datetime(df["ds"])
    return df


def load_from_csv(path):
    df = pd.read_csv(path)
    df["ds"] = pd.to_datetime(df["ds"])
    return df


def train(df, freq=None):
    # Prophet works with ds/y
    df = df[["ds", "y"]].dropna().sort_values("ds")
    # Simple example: no extra regressors
    m = Prophet()
    m.fit(df)
    return m


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", help="Path to CSV with ds,y columns")
    parser.add_argument("--db-url", help="Database URL (overrides env DB_URL)")
    parser.add_argument("--out", default=str(MODEL_DIR / "prophet_model.joblib"))
    parser.add_argument("--limit", type=int, help="Limit rows for training (for dev)")
    args = parser.parse_args()

    if args.csv:
        df = load_from_csv(args.csv)
    else:
        db_url = args.db_url or os.environ.get("DB_URL")
        if not db_url:
            raise RuntimeError("No DB_URL set and no CSV provided. Export DB_URL or pass --csv.")
        df = load_from_db(db_url, limit=args.limit)

    print(f"Training on {len(df)} rows")
    model = train(df)
    joblib.dump(model, args.out)
    print(f"Saved model to {args.out}")
