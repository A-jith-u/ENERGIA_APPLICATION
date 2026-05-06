from __future__ import annotations

import argparse
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Optional

import requests
from sqlalchemy import text

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from simulation_data.common import (
    AuthConfig,
    accelerate_tracking_row,
    clamp,
    current_utc,
    fetch_notification_counts,
    get_latest_tracking_row,
    login_and_get_headers,
    make_engine,
    post_sensor_reading,
    print_notification_summary,
    print_tracking_summary,
)

DEFAULT_BASE_URL = "http://127.0.0.1:5000"
DEFAULT_DEVICE_ID = "ESP32-CS-C201"
DEFAULT_ROOM_ID = "CS-C201"


def build_high_usage_payload(device_id: str, power_watts: float, occupancy: int = 0) -> Dict[str, float | int | str]:
    voltage = clamp(230.0, 226.0, 234.0)
    power_factor = 0.95
    current = max(0.0, power_watts / max(voltage * power_factor, 1.0))
    return {
        "device_id": device_id,
        "power": round(power_watts, 2),
        "current": round(current, 3),
        "voltage": round(voltage, 2),
        "energy": 0.0,
        "frequency": 50.0,
        "power_factor": round(power_factor, 2),
        "human_present": int(occupancy),
        "relay_state": "ON",
    }


def latest_anomaly_log_id(device_id: str) -> Optional[int]:
    engine = make_engine()
    with engine.connect() as conn:
        row = conn.execute(
            text(
                """
                SELECT id
                FROM anomaly_logs
                WHERE UPPER(device_id) = UPPER(:device_id)
                ORDER BY ds DESC
                LIMIT 1
                """
            ),
            {"device_id": device_id},
        ).fetchone()
        return int(row[0]) if row else None


def trigger_alert_creation(base_url: str, room_id: str, anomaly_log_id: int) -> requests.Response:
    return requests.post(
        f"{base_url.rstrip('/')}/anomaly-alerts/create-alert",
        json={"room_id": room_id, "anomaly_log_id": anomaly_log_id},
        timeout=15,
    )


def wait_for_scheduler(seconds: float) -> None:
    print(f"[ESC] Waiting {seconds:.0f}s for the backend scheduler... ")
    time.sleep(seconds)


def ensure_tracking_key(device_id: str, room_id: str) -> str:
    if get_latest_tracking_row(room_id):
        return room_id
    if get_latest_tracking_row(device_id):
        return device_id
    return room_id


def main() -> None:
    parser = argparse.ArgumentParser(description="Test staged alert escalation and auto-cutoff.")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--device-id", default=DEFAULT_DEVICE_ID)
    parser.add_argument("--room-id", default=DEFAULT_ROOM_ID)
    parser.add_argument("--username", default=None)
    parser.add_argument("--password", default=None)
    parser.add_argument("--department", default=None)
    parser.add_argument("--token", default=None)
    parser.add_argument("--power-watts", type=float, default=165.0)
    parser.add_argument("--scheduler-wait-sec", type=float, default=35.0)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    print("[ESC] Starting staged alert test.")
    print(f"[ESC] device_id={args.device_id} room_id={args.room_id} power={args.power_watts}W")
    print("[ESC] Order under test: class rep -> coordinator -> sergeant -> auto-cutoff")

    if args.dry_run:
        payload = build_high_usage_payload(args.device_id, args.power_watts, occupancy=0)
        print(f"[ESC][DRY] {current_utc().isoformat()} {payload}")
        return

    headers = login_and_get_headers(
        AuthConfig(
            base_url=args.base_url,
            username=args.username,
            password=args.password,
            department=args.department,
            token=args.token,
        )
    )

    payload = build_high_usage_payload(args.device_id, args.power_watts, occupancy=0)
    resp = post_sensor_reading(args.base_url, headers, payload)
    print(f"[ESC] Initial sensor post status={resp.status_code} body={resp.text[:180]}")

    anomaly_log_id = latest_anomaly_log_id(args.device_id)
    if anomaly_log_id is None:
        raise SystemExit(
            f"No anomaly_logs row found for {args.device_id}. Check that the backend created an anomaly from the sample payload."
        )

    create_resp = trigger_alert_creation(args.base_url, args.room_id, anomaly_log_id)
    print(f"[ESC] create-alert status={create_resp.status_code} body={create_resp.text[:180]}")

    tracking_key = ensure_tracking_key(args.device_id, args.room_id)
    print_tracking_summary(tracking_key)
    print_notification_summary(tracking_key)

    stages = [
        ("coordinator", 1, 6),
        ("sergeant", 2, 11),
        ("cutoff", 3, 16),
    ]

    for stage_name, alert_count, minutes_ago in stages:
        ok = accelerate_tracking_row(tracking_key, alert_count=alert_count, minutes_ago=minutes_ago)
        if not ok:
            raise SystemExit(f"Unable to locate active alert for {tracking_key} to accelerate stage={stage_name}.")

        print(f"[ESC] Accelerated to stage={stage_name} (alert_count={alert_count}, age={minutes_ago}m).")
        wait_for_scheduler(args.scheduler_wait_sec)

        print_tracking_summary(tracking_key)
        print_notification_summary(tracking_key)

    print("[ESC] Final check complete.")
    print("[ESC] If SMTP is configured in the backend, mail notifications should have been sent for each stage.")


if __name__ == "__main__":
    main()
