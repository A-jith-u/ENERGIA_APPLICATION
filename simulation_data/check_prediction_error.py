from datetime import datetime, timedelta
import os
import sys

import requests
from sqlalchemy import create_engine, text

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKEND_DIR = os.path.join(ROOT, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from config import get_db_url

DB_URL = get_db_url()
BASE_URL = "http://127.0.0.1:5000"
ROOM_NAME = "CS-201"
DEVICE_ID = "ESP32-CS-C201"

pred = requests.post(
    f"{BASE_URL}/model/predict_15min",
    json={"horizon_minutes": 15, "room_name": ROOM_NAME},
    timeout=20,
)
pred.raise_for_status()
payload = pred.json()

print("PREDICTION_PAYLOAD", payload)

pred_ts = datetime.fromisoformat(payload["timestamp"].replace("Z", "+00:00"))
generated_ts = datetime.fromisoformat(payload["generated_at"].replace("Z", "+00:00"))
yhat = float(payload["yhat"])

engine = create_engine(DB_URL)
query = text(
    """
    SELECT ds, power
    FROM sensor_data
    WHERE UPPER(device_id) = UPPER(:device_id)
      AND ds BETWEEN :t_start AND :t_end
      AND power IS NOT NULL
    ORDER BY ABS(EXTRACT(EPOCH FROM (ds - :target_ts))) ASC
    LIMIT 1
    """
)

query_generated = text(
        """
        SELECT ds, power
        FROM sensor_data
        WHERE UPPER(device_id) = UPPER(:device_id)
            AND ds BETWEEN :t_start AND :t_end
            AND power IS NOT NULL
        ORDER BY ABS(EXTRACT(EPOCH FROM (ds - :target_ts))) ASC
        LIMIT 1
        """
)

query_closest_any = text(
        """
        SELECT ds, power,
                     ABS(EXTRACT(EPOCH FROM (ds - :target_ts))) AS diff_seconds
        FROM sensor_data
        WHERE UPPER(device_id) = UPPER(:device_id)
            AND power IS NOT NULL
        ORDER BY ABS(EXTRACT(EPOCH FROM (ds - :target_ts))) ASC
        LIMIT 1
        """
)

with engine.connect() as conn:
    row = conn.execute(
        query,
        {
            "device_id": DEVICE_ID,
            "target_ts": pred_ts,
            "t_start": pred_ts - timedelta(minutes=10),
            "t_end": pred_ts + timedelta(minutes=10),
        },
    ).fetchone()

if not row:
    print("NO_ACTUAL_READING_NEAR_TARGET", pred_ts.isoformat())
else:
    actual_ts = row[0]
    actual = float(row[1])
    abs_err = abs(yhat - actual)
    pct_err = (abs_err / actual * 100.0) if actual else None

    print("TARGET_TS", pred_ts.isoformat())
    print("ACTUAL_TS", actual_ts.isoformat() if hasattr(actual_ts, "isoformat") else str(actual_ts))
    print("PREDICTED_POWER", round(yhat, 4))
    print("ACTUAL_POWER", round(actual, 4))
    print("ABS_ERROR", round(abs_err, 4))
    print("PCT_ERROR", None if pct_err is None else round(pct_err, 2))

with engine.connect() as conn:
    row_any = conn.execute(
        query_closest_any,
        {
            "device_id": DEVICE_ID,
            "target_ts": pred_ts,
        },
    ).fetchone()

if row_any:
    actual_ts_any = row_any[0]
    actual_any = float(row_any[1])
    diff_seconds = float(row_any[2] or 0.0)
    abs_err_any = abs(yhat - actual_any)
    pct_err_any = (abs_err_any / actual_any * 100.0) if actual_any else None
    print("\nCLOSEST_ACTUAL_ANYTIME")
    print("TARGET_TS", pred_ts.isoformat())
    print("ACTUAL_TS_CLOSEST", actual_ts_any.isoformat() if hasattr(actual_ts_any, "isoformat") else str(actual_ts_any))
    print("TIME_GAP_MINUTES", round(diff_seconds / 60.0, 2))
    print("PREDICTED_POWER", round(yhat, 4))
    print("ACTUAL_POWER_CLOSEST", round(actual_any, 4))
    print("ABS_ERROR_CLOSEST", round(abs_err_any, 4))
    print("PCT_ERROR_CLOSEST", None if pct_err_any is None else round(pct_err_any, 2))

with engine.connect() as conn:
    row_now = conn.execute(
        query_generated,
        {
            "device_id": DEVICE_ID,
            "target_ts": generated_ts,
            "t_start": generated_ts - timedelta(minutes=10),
            "t_end": generated_ts + timedelta(minutes=10),
        },
    ).fetchone()

if not row_now:
    print("NO_ACTUAL_READING_NEAR_GENERATED", generated_ts.isoformat())
else:
    actual_ts_now = row_now[0]
    actual_now = float(row_now[1])
    abs_err_now = abs(yhat - actual_now)
    pct_err_now = (abs_err_now / actual_now * 100.0) if actual_now else None
    print("\nPROXY_CHECK_AT_GENERATED_TIME")
    print("GENERATED_TS", generated_ts.isoformat())
    print("ACTUAL_TS_NEAR_GENERATED", actual_ts_now.isoformat() if hasattr(actual_ts_now, "isoformat") else str(actual_ts_now))
    print("PREDICTED_POWER", round(yhat, 4))
    print("ACTUAL_POWER_NEAR_GENERATED", round(actual_now, 4))
    print("ABS_ERROR_GENERATED", round(abs_err_now, 4))
    print("PCT_ERROR_GENERATED", None if pct_err_now is None else round(pct_err_now, 2))
