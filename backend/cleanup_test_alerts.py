import os
import sys

from sqlalchemy import text

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

from backend.auth_api import engine


def main() -> None:
    with engine.begin() as conn:
        mark_sql = text(
            """
            UPDATE anomaly_alert_tracking
            SET status = 'ignored_test_data',
                resolved_at = COALESCE(resolved_at, NOW())
            WHERE (UPPER(room_id) LIKE '%TEST%'
                OR UPPER(room_id) LIKE '%DEMO%'
                OR UPPER(room_id) LIKE '%MOCK%')
              AND status IN ('active', 'power_cut', 'acknowledged', 'auto_resolved', 'type_switched', 'expired')
            """
        )
        marked = conn.execute(mark_sql).rowcount or 0

        print(f"marked_test_alerts={marked}")

        left_sql = text(
            """
            SELECT id, room_id, status, first_detected_at
            FROM anomaly_alert_tracking
            WHERE UPPER(room_id) LIKE '%TEST%'
               OR UPPER(room_id) LIKE '%DEMO%'
               OR UPPER(room_id) LIKE '%MOCK%'
            ORDER BY first_detected_at DESC
            """
        )
        rows = conn.execute(left_sql).fetchall()
        print(f"remaining_test_rows={len(rows)}")
        for r in rows:
            print(f"{r[0]}|{r[1]}|{r[2]}|{r[3]}")


if __name__ == "__main__":
    main()
