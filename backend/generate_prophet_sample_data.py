"""Generate synthetic minute-level energy data for Prophet training.

Outputs:
- backend/sample_data/prophet_training_sample.csv (created/overwritten)
- (optional) writes to a Postgres table if DB_URL is set and --write-db is passed

The synthetic signal combines a daily sinusoid, a mild trend, and noise to mimic
PZEM readings (voltage, current, active power, energy, power factor).
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.exc import SQLAlchemyError

SAMPLE_DIR = Path("backend/sample_data")
SAMPLE_DIR.mkdir(parents=True, exist_ok=True)
CSV_PATH = SAMPLE_DIR / "prophet_training_sample.csv"


def generate_sample(rows: int = 24 * 60 * 2) -> pd.DataFrame:
    rng = pd.date_range("2024-01-01", periods=rows, freq="1min", tz="UTC")
    minutes = np.arange(rows)

    # Base signals
    daily_cycle = 0.4 + 0.3 * np.sin(2 * np.pi * (minutes % 1440) / 1440)
    trend = 0.0001 * minutes
    noise = np.random.normal(0, 0.05, size=rows)

    current = 2 + daily_cycle + noise
    voltage = 230 + 5 * np.sin(2 * np.pi * (minutes % 720) / 720) + np.random.normal(0, 0.8, size=rows)
    power_factor = 0.92 + 0.03 * np.sin(2 * np.pi * (minutes % 180) / 180)
    active_power = voltage * current * power_factor / 1000  # kW
    energy = np.cumsum(active_power / 60.0)  # kWh accumulated per minute

    df = pd.DataFrame(
        {
            "ts": rng,
            "voltage": voltage,
            "current": current,
            "power": active_power,  # alias for active_power
            "power_factor": power_factor,
            "active_power": active_power,
            "energy": energy,
            "frequency": 50 + np.random.normal(0, 0.02, size=rows),
        }
    )
    return df


def write_to_db(df: pd.DataFrame, db_url: str, table: str) -> None:
    engine = create_engine(db_url)
    try:
        df.to_sql(table, engine, if_exists="replace", index=False)
    except SQLAlchemyError as exc:  # noqa: BLE001
        raise RuntimeError(f"Failed to write sample data to {table}: {exc}") from exc


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate synthetic PZEM dataset for Prophet training")
    parser.add_argument("--rows", type=int, default=24 * 60 * 2, help="Number of 1-min rows to generate (default: 2 days)")
    parser.add_argument("--table", default="pzem_readings", help="Optional table name to write into Postgres")
    parser.add_argument("--write-db", action="store_true", help="Write generated data to DB_URL table as well")
    args = parser.parse_args()

    df = generate_sample(rows=args.rows)
    CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(CSV_PATH, index=False)
    print(f"Wrote synthetic CSV to {CSV_PATH} with {len(df)} rows")

    db_url = os.environ.get("DB_URL")
    if args.write_db:
        if not db_url:
            raise RuntimeError("DB_URL is not set; cannot write to database")
        write_to_db(df, db_url, args.table)
        print(f"Wrote sample data to table '{args.table}'")


if __name__ == "__main__":
    main()
