import os
import sys

from sqlalchemy import text

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from backend.auth_api import engine


def main() -> None:
    with engine.begin() as conn:
        print("=== RECENT SENSOR_DATA (LIVE) ===")
        rows = conn.execute(
            text(
                """
                SELECT id, ds, device_id, power, occupancy
                FROM sensor_data
                ORDER BY ds DESC
                LIMIT 20
                """
            )
        ).fetchall()
        for r in rows:
            print(f"{r[0]}|{r[1]}|{r[2]}|power={r[3]}|occ={r[4]}")

        print("\n=== ACTIVE/POWER_CUT ALERT THREADS ===")
        rows = conn.execute(
            text(
                """
                SELECT id, room_id, status, anomaly_type, first_detected_at,
                       alert_count, current_interval_minutes, power_cut_at
                FROM anomaly_alert_tracking
                WHERE status IN ('active', 'power_cut')
                ORDER BY first_detected_at DESC
                """
            )
        ).fetchall()
        for r in rows:
            print(
                f"{r[0]}|{r[1]}|{r[2]}|type={r[3]}|first={r[4]}|"
                f"count={r[5]}|interval={r[6]}|cut={r[7]}"
            )

        print("\n=== TEST/DEMO ALERT THREADS ===")
        rows = conn.execute(
            text(
                """
                SELECT id, room_id, status, first_detected_at
                FROM anomaly_alert_tracking
                WHERE UPPER(room_id) LIKE '%TEST%'
                   OR UPPER(room_id) LIKE '%DEMO%'
                   OR UPPER(room_id) LIKE '%MOCK%'
                ORDER BY first_detected_at DESC
                """
            )
        ).fetchall()
        print(f"test_alert_count={len(rows)}")
        for r in rows:
            print(f"{r[0]}|{r[1]}|{r[2]}|{r[3]}")

        print("\n=== TEST/DEMO ANOMALY LOGS ===")
        rows = conn.execute(
            text(
                """
                SELECT id, ds, device_id, power, occupancy, is_anomaly
                FROM anomaly_logs
                WHERE UPPER(device_id) LIKE '%TEST%'
                   OR UPPER(device_id) LIKE '%DEMO%'
                   OR UPPER(device_id) LIKE '%MOCK%'
                ORDER BY ds DESC
                LIMIT 40
                """
            )
        ).fetchall()
        print(f"test_anomaly_log_count={len(rows)}")
        for r in rows:
            print(
                f"{r[0]}|{r[1]}|{r[2]}|power={r[3]}|occ={r[4]}|is_anomaly={r[5]}"
            )


if __name__ == "__main__":
    main()
