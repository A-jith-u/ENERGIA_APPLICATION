import os
import sys
from sqlalchemy import create_engine, text

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKEND_DIR = os.path.join(ROOT, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from config import get_db_url

engine = create_engine(get_db_url())

queries = [
    ("latest_any", "SELECT device_id, ds, power, value FROM sensor_data ORDER BY ds DESC LIMIT 10", {}),
    (
        "latest_cs_c201",
        "SELECT device_id, ds, power, value FROM sensor_data WHERE UPPER(device_id)=UPPER(:d) ORDER BY ds DESC LIMIT 10",
        {"d": "ESP32-CS-C201"},
    ),
]

with engine.connect() as conn:
    for name, sql, params in queries:
        print(f"\n== {name} ==")
        rows = conn.execute(text(sql), params).fetchall()
        for r in rows:
            print(r)
        if not rows:
            print("<no rows>")
