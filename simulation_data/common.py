from __future__ import annotations

import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Optional

import requests
from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.config import get_db_url  # noqa: E402


@dataclass
class AuthConfig:
    base_url: str
    username: Optional[str] = None
    password: Optional[str] = None
    department: Optional[str] = None
    token: Optional[str] = None


def make_engine():
    return create_engine(get_db_url(), pool_pre_ping=True)


def login_and_get_headers(config: AuthConfig) -> Dict[str, str]:
    if config.token:
        return {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {config.token}",
        }

    if not config.username or not config.password:
        raise SystemExit(
            "Provide either --token or --username/--password (and --department for coordinator login)."
        )

    payload: Dict[str, Any] = {
        "username": config.username,
        "password": config.password,
    }
    if config.department:
        payload["department"] = config.department

    resp = requests.post(
        f"{config.base_url.rstrip('/')}/login",
        json=payload,
        timeout=15,
    )
    if resp.status_code != 200:
        raise SystemExit(f"Login failed: {resp.status_code} {resp.text}")

    token = resp.json()["access_token"]
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }


def post_sensor_reading(base_url: str, headers: Dict[str, str], payload: Dict[str, Any]) -> requests.Response:
    return requests.post(
        f"{base_url.rstrip('/')}/sensor-data",
        json=payload,
        headers=headers,
        timeout=15,
    )


def current_utc() -> datetime:
    return datetime.now(timezone.utc)


def approx_current_from_power(power_watts: float, voltage: float, power_factor: float) -> float:
    denominator = max(voltage * max(power_factor, 0.7), 1.0)
    return max(0.0, power_watts / denominator)


def clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(upper, value))


def get_latest_tracking_row(room_id: str):
    engine = make_engine()
    with engine.connect() as conn:
        return conn.execute(
            text(
                """
                SELECT id, room_id, first_detected_at, alert_count, current_interval_minutes, anomaly_type, status
                FROM anomaly_alert_tracking
                WHERE UPPER(room_id) = UPPER(:room_id)
                ORDER BY first_detected_at DESC
                LIMIT 1
                """
            ),
            {"room_id": room_id},
        ).fetchone()


def print_tracking_summary(room_id: str) -> None:
    row = get_latest_tracking_row(room_id)
    if not row:
        print(f"[TRACK] No anomaly tracking row found for {room_id}")
        return
    print(
        f"[TRACK] id={row[0]} room={row[1]} status={row[6]} type={row[5]} "
        f"alert_count={row[3]} interval={row[4]} first_detected={row[2]}"
    )


def accelerate_tracking_row(room_id: str, alert_count: int, minutes_ago: int, anomaly_type: str = "usage_without_occupancy") -> bool:
    engine = make_engine()
    first_detected_at = current_utc() - timedelta(minutes=minutes_ago)
    with engine.begin() as conn:
        row = conn.execute(
            text(
                """
                SELECT id
                FROM anomaly_alert_tracking
                WHERE UPPER(room_id) = UPPER(:room_id)
                ORDER BY first_detected_at DESC
                LIMIT 1
                """
            ),
            {"room_id": room_id},
        ).fetchone()

        if not row:
            return False

        conn.execute(
            text(
                """
                UPDATE anomaly_alert_tracking
                SET first_detected_at = :first_detected_at,
                    alert_count = :alert_count,
                    anomaly_type = :anomaly_type,
                    status = 'active'
                WHERE id = :id
                """
            ),
            {
                "first_detected_at": first_detected_at,
                "alert_count": alert_count,
                "anomaly_type": anomaly_type,
                "id": row[0],
            },
        )
    return True


def fetch_notification_counts(room_id: str):
    engine = make_engine()
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT recipient_type, COUNT(*)
                FROM notifications
                WHERE UPPER(room_id) = UPPER(:room_id)
                  AND created_at >= NOW() - INTERVAL '90 minutes'
                GROUP BY recipient_type
                ORDER BY recipient_type
                """
            ),
            {"room_id": room_id},
        ).fetchall()
        return [(r[0], r[1]) for r in rows]


def print_notification_summary(room_id: str) -> None:
    counts = fetch_notification_counts(room_id)
    if not counts:
        print(f"[NOTIFY] No notifications recorded for {room_id}")
        return
    print(f"[NOTIFY] {room_id}: {counts}")
