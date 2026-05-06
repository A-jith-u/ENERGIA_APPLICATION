"""Background demo data generator for ENERGIA.

The service feeds the backend with realistic per-minute sensor payloads so the
existing prediction, anomaly detection, notification, and mail pipelines can be
demonstrated without live hardware.
"""

from __future__ import annotations

import importlib
import os
import random
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Iterable, Optional

import requests
from sqlalchemy import create_engine, text

from simulation_data.common import approx_current_from_power, accelerate_tracking_row


def _load_cfg():
    if __package__:
        from . import config

        return config

    return importlib.import_module("config")


cfg = _load_cfg()
DB_URL = cfg.get_db_url()


@dataclass
class DemoRoomProfile:
    room_id: str
    room_name: str
    department: str
    mode: str
    seed: int
    energy_kwh: float


def _infer_department(room_id: str, fallback: str = "CSE") -> str:
    token = (room_id or "").strip().upper()
    if token.startswith("IT"):
        return "IT"
    if token.startswith("ME"):
        return "ME"
    if token.startswith("EE") or token.startswith("EC"):
        return "EEE"
    if token.startswith("CS"):
        return "CSE"
    return fallback


def _safe_room_name(room_id: str, room_name: Optional[str]) -> str:
    if room_name and str(room_name).strip():
        return str(room_name).strip()
    return room_id


class DemoModeService:
    """Continuously posts simulated readings for demo purposes."""

    def __init__(self) -> None:
        self.base_url = os.environ.get(
            "DEMO_BASE_URL",
            f"http://127.0.0.1:{os.environ.get('PORT', '5000')}",
        ).rstrip("/")
        self.history_minutes = int(os.environ.get("DEMO_HISTORY_MINUTES", "90"))
        self.interval_seconds = int(os.environ.get("DEMO_INTERVAL_SECONDS", "60"))
        self.room_limit = int(os.environ.get("DEMO_ROOM_LIMIT", "6"))
        self._engine = create_engine(DB_URL, pool_pre_ping=True)
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._room_profiles: list[DemoRoomProfile] = []
        self._accelerated_rooms: set[str] = set()

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._thread = threading.Thread(target=self._run, name="energia-demo-mode", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=5)

    def _wait_for_backend(self, timeout_seconds: int = 60) -> bool:
        deadline = time.time() + timeout_seconds
        health_url = f"{self.base_url}/health"
        while time.time() < deadline and not self._stop_event.is_set():
            try:
                response = requests.get(health_url, timeout=5)
                if response.status_code == 200:
                    return True
            except Exception:
                pass
            time.sleep(2)
        return False

    def _load_room_profiles(self) -> list[DemoRoomProfile]:
        rooms: list[tuple[str, Optional[str], Optional[str]]] = []
        with self._engine.connect() as conn:
            rows = conn.execute(
                text(
                    """
                    SELECT room_id, room_name, department
                    FROM rooms
                    ORDER BY room_id
                    LIMIT :limit
                    """
                ),
                {"limit": self.room_limit},
            ).fetchall()

            for row in rows:
                if row and row[0]:
                    rooms.append((str(row[0]), row[1], row[2]))

        if not rooms:
            rooms = [
                ("CS-201", "CS-201", "CSE"),
                ("CS-202", "CS-202", "CSE"),
                ("IT-101", "IT-101", "IT"),
                ("ME-101", "ME-101", "ME"),
                ("EE-101", "EE-101", "EEE"),
            ]

        profiles: list[DemoRoomProfile] = []
        for index, (room_id, room_name, department) in enumerate(rooms):
            if index % 3 == 0:
                mode = "normal"
            elif index % 3 == 1:
                mode = "usage_without_occupancy"
            else:
                mode = "occupied_high"

            seed = sum(ord(ch) for ch in room_id) % 10_000
            profiles.append(
                DemoRoomProfile(
                    room_id=room_id,
                    room_name=_safe_room_name(room_id, room_name),
                    department=(department or _infer_department(room_id)).strip() or _infer_department(room_id),
                    mode=mode,
                    seed=seed,
                    energy_kwh=round(6.0 + (index * 0.75), 3),
                )
            )

        return profiles

    def _ensure_demo_mappings(self, profiles: Iterable[DemoRoomProfile]) -> None:
        with self._engine.begin() as conn:
            reps = conn.execute(
                text(
                    """
                    SELECT email, department
                    FROM class_representatives
                    WHERE COALESCE(email, '') <> ''
                    ORDER BY created_at DESC
                    """
                )
            ).fetchall()

            for profile in profiles:
                conn.execute(
                    text(
                        """
                        UPDATE rooms
                        SET department = COALESCE(NULLIF(TRIM(department), ''), :department)
                        WHERE UPPER(room_id) = UPPER(:room_id)
                        """
                    ),
                    {"room_id": profile.room_id, "department": profile.department},
                )

                existing = conn.execute(
                    text(
                        """
                        SELECT 1
                        FROM class_rep_room_mapping
                        WHERE UPPER(room_id) = UPPER(:room_id)
                          AND is_active = TRUE
                        LIMIT 1
                        """
                    ),
                    {"room_id": profile.room_id},
                ).fetchone()
                if existing or not reps:
                    continue

                preferred = None
                for rep_email, rep_department in reps:
                    if (rep_department or "").strip().upper() == profile.department.strip().upper():
                        preferred = rep_email
                        break
                if preferred is None:
                    preferred = reps[0][0]

                conn.execute(
                    text(
                        """
                        INSERT INTO class_rep_room_mapping (room_id, class_rep_email, is_active)
                        VALUES (:room_id, :email, TRUE)
                        ON CONFLICT (room_id, class_rep_email)
                        DO UPDATE SET is_active = TRUE, created_at = NOW()
                        """
                    ),
                    {"room_id": profile.room_id, "email": preferred},
                )

                conn.execute(
                    text(
                        """
                        UPDATE class_representatives
                        SET assigned_room_id = :room_id
                        WHERE UPPER(email) = UPPER(:email)
                        """
                    ),
                    {"room_id": profile.room_id, "email": preferred},
                )


    def _reading_for(self, profile: DemoRoomProfile, tick: int, timestamp: datetime) -> dict:
        rng = random.Random(profile.seed + tick)

        if profile.mode == "normal":
            occupancy = 1
            power = rng.uniform(48.0, 92.0)
        elif profile.mode == "occupied_high":
            occupancy = 1
            power = rng.uniform(155.0, 310.0)
        else:  # usage_without_occupancy
            occupancy = 0
            power = rng.uniform(180.0, 420.0)

        voltage = rng.uniform(226.0, 241.0)
        power_factor = rng.uniform(0.84, 0.98)
        current = approx_current_from_power(power, voltage, power_factor)
        frequency = rng.uniform(49.7, 50.3)

        profile.energy_kwh += max(0.0, power / 1000.0 / 60.0)

        return {
            "device_id": profile.room_id,
            "timestamp": timestamp.isoformat(),
            "demo_mode": True,
            "source": "demo",
            "power": round(power, 2),
            "current": round(current, 3),
            "voltage": round(voltage, 2),
            "energy": round(profile.energy_kwh, 4),
            "power_factor": round(power_factor, 3),
            "frequency": round(frequency, 2),
            "human_present": int(occupancy),
            "relay_state": "ON",
        }

    def _post_reading(self, payload: dict) -> None:
        try:
            response = requests.post(f"{self.base_url}/sensor-data", json=payload, timeout=15)
            if response.status_code >= 400:
                print(f"[DEMO] sensor-data rejected for {payload.get('device_id')}: {response.status_code} {response.text}")
        except Exception as exc:
            print(f"[DEMO] Failed to post demo reading for {payload.get('device_id')}: {exc}")

    def _bootstrap_history(self) -> None:
        if not self._room_profiles:
            return

        now = datetime.now(timezone.utc)
        start = now - timedelta(minutes=self.history_minutes)
        print(f"[DEMO] Bootstrapping {self.history_minutes} minutes of history for {len(self._room_profiles)} rooms")

        for minute in range(self.history_minutes):
            timestamp = start + timedelta(minutes=minute)
            for profile in self._room_profiles:
                self._post_reading(self._reading_for(profile, minute, timestamp))

    def _accelerate_active_alerts(self) -> None:
        for profile in self._room_profiles:
            if profile.mode == "normal" or profile.room_id in self._accelerated_rooms:
                continue

            try:
                for _ in range(15):
                    if self._stop_event.is_set():
                        return
                    if accelerate_tracking_row(profile.room_id, alert_count=0, minutes_ago=16):
                        self._accelerated_rooms.add(profile.room_id)
                        print(f"[DEMO] Accelerated alert tracking for {profile.room_id}")
                        break
                    time.sleep(1)
            except Exception as exc:
                print(f"[DEMO] Unable to accelerate alerts for {profile.room_id}: {exc}")

    def _run(self) -> None:
        if not self._wait_for_backend():
            print("[DEMO] Backend health check timed out; demo mode not started")
            return

        self._room_profiles = self._load_room_profiles()
        self._ensure_demo_mappings(self._room_profiles)

        self._bootstrap_history()

        # Post one fresh reading immediately so the dashboards have current data.
        current_tick = self.history_minutes
        current_ts = datetime.now(timezone.utc)
        for profile in self._room_profiles:
            self._post_reading(self._reading_for(profile, current_tick, current_ts))

        # Pull the first anomaly tracking rows forward so the alert pipeline
        # can demonstrate class rep -> coordinator -> sergeant escalation quickly.
        self._accelerate_active_alerts()

        tick = current_tick + 1
        while not self._stop_event.wait(self.interval_seconds):
            current_ts = datetime.now(timezone.utc)
            for profile in self._room_profiles:
                self._post_reading(self._reading_for(profile, tick, current_ts))
            tick += 1
