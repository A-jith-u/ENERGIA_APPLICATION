#!/usr/bin/env python3
"""Check available sensor data tables and their structure."""
import os, sys, importlib
from sqlalchemy import create_engine, inspect, text

def _load_cfg():
    if __package__:
        from . import config
        return config
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        return importlib.import_module("config")

cfg = _load_cfg()
DB_URL = cfg.get_db_url()

engine = create_engine(DB_URL)
inspector = inspect(engine)

print(f"[DB] Using: {DB_URL}")
print("\n[TABLES]")
for table in sorted(inspector.get_table_names()):
    cols = inspector.get_columns(table)
    count = engine.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
    print(f"  {table}: {len(cols)} cols, {count} rows")

print("\n[SENSOR_DATA]")
try:
    with engine.connect() as conn:
        result = conn.execute(text("SELECT * FROM sensor_data ORDER BY ds DESC LIMIT 3"))
        for row in result:
            print(f"  Record: {dict(row._mapping)}")
except Exception as e:
    print(f"  [ERROR] {e}")
