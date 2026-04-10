"""
Sensor Input Simulator for ENERGIA

Purpose
- Simulate realistic sensor payloads (similar to sensor_data table values)
- Exercise end-to-end app use cases: normal usage, anomalies, escalation, recovery
- Support fast validation of role-based notifications and anomaly alert progression

Examples
1) Quick smoke test (posts a few normal + anomaly payloads):
   python simulate_sensor_usecases.py --scenario smoke

2) Mixed stream for 3 minutes:
   python simulate_sensor_usecases.py --scenario mixed --duration-sec 180 --interval-sec 4

3) Force escalation windows quickly (5/10/15 min stages accelerated):
   python simulate_sensor_usecases.py --scenario escalation --accelerate-stages

4) Target specific rooms:
   python simulate_sensor_usecases.py --scenario mixed --rooms Floor-2-Class-201,Floor-2-Class-202

5) Dry-run only (no HTTP writes):
   python simulate_sensor_usecases.py --scenario mixed --dry-run
"""

from __future__ import annotations

import argparse
import random
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

import requests
from sqlalchemy import create_engine, text

import config


@dataclass
class RoomProfile:
    room_id: str
    avg_power: float
    avg_current: float
    avg_voltage: float
    avg_pf: float
    avg_freq: float
    latest_energy: float


def _safe_float(value, default: float) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except Exception:
        return default


def _db_engine():
    return create_engine(config.get_db_url(), pool_pre_ping=True)


def discover_rooms(limit: int = 8) -> List[str]:
    """Prefer mapped rooms (class-rep flow visible), then fallback to recent sensor rooms."""
    engine = _db_engine()
    with engine.connect() as conn:
        mapped = conn.execute(
            text(
                """
                SELECT room_id
                FROM class_rep_room_mapping
                WHERE is_active = TRUE
                ORDER BY room_id
                """
            )
        ).fetchall()
        mapped_rooms = [r[0] for r in mapped if r and r[0]]
        if mapped_rooms:
            return mapped_rooms[:limit]

        rows = conn.execute(
            text(
                """
                SELECT device_id
                FROM sensor_data
                WHERE power IS NOT NULL
                GROUP BY device_id
                ORDER BY COUNT(*) DESC
                LIMIT :lim
                """
            ),
            {"lim": limit},
        ).fetchall()
        return [r[0] for r in rows if r and r[0]]


def load_profiles(room_ids: List[str]) -> Dict[str, RoomProfile]:
    """Load realistic baseline profile per room from existing sensor_data."""
    engine = _db_engine()
    profiles: Dict[str, RoomProfile] = {}

    with engine.connect() as conn:
        for rid in room_ids:
            stats = conn.execute(
                text(
                    """
                    SELECT
                        AVG(power) AS avg_power,
                        AVG(current) AS avg_current,
                        AVG(voltage) AS avg_voltage,
                        AVG(power_factor) AS avg_pf,
                        AVG(frequency) AS avg_freq
                    FROM sensor_data
                    WHERE UPPER(device_id) = UPPER(:rid)
                      AND power IS NOT NULL
                    """
                ),
                {"rid": rid},
            ).fetchone()

            latest_energy_row = conn.execute(
                text(
                    """
                    SELECT energy
                    FROM sensor_data
                    WHERE UPPER(device_id) = UPPER(:rid)
                      AND energy IS NOT NULL
                    ORDER BY ds DESC
                    LIMIT 1
                    """
                ),
                {"rid": rid},
            ).fetchone()

            avg_power = _safe_float(stats[0] if stats else None, 900.0)
            avg_current = _safe_float(stats[1] if stats else None, max(0.1, avg_power / 230.0))
            avg_voltage = _safe_float(stats[2] if stats else None, 230.0)
            avg_pf = _safe_float(stats[3] if stats else None, 0.92)
            avg_freq = _safe_float(stats[4] if stats else None, 50.0)
            latest_energy = _safe_float(latest_energy_row[0] if latest_energy_row else None, 10.0)

            profiles[rid] = RoomProfile(
                room_id=rid,
                avg_power=avg_power,
                avg_current=avg_current,
                avg_voltage=avg_voltage,
                avg_pf=avg_pf,
                avg_freq=avg_freq,
                latest_energy=latest_energy,
            )

    return profiles


def build_payload(profile: RoomProfile, power: float, occupancy: int, energy_step: float = 0.015) -> dict:
    """Build sensor payload matching backend /sensor-data schema."""
    voltage = max(180.0, min(260.0, profile.avg_voltage + random.uniform(-2.5, 2.5)))
    pf = max(0.65, min(1.0, profile.avg_pf + random.uniform(-0.03, 0.03)))
    frequency = max(49.6, min(50.4, profile.avg_freq + random.uniform(-0.1, 0.1)))
    current = max(0.0, power / max(voltage * max(pf, 0.7), 1.0))

    profile.latest_energy += max(0.0, energy_step)

    return {
        "device_id": profile.room_id,
        "power": round(power, 2),
        "current": round(current, 3),
        "voltage": round(voltage, 2),
        "energy": round(profile.latest_energy, 4),
        "power_factor": round(pf, 3),
        "frequency": round(frequency, 2),
        "human_present": int(occupancy),
    }


def post_sensor(base_url: str, payload: dict, timeout_sec: int = 8) -> requests.Response:
    return requests.post(f"{base_url.rstrip('/')}/sensor-data", json=payload, timeout=timeout_sec)


def scenario_point(profile: RoomProfile, scenario: str, tick: int) -> dict:
    """Generate one payload point by scenario."""
    ap = profile.avg_power

    if scenario == "normal":
        # Occupied + low/stable usage below anomaly threshold (>100 when occupied)
        power = random.uniform(45.0, 95.0)
        occ = 1
    elif scenario == "idle":
        # Empty room + near-zero power (should not alert)
        power = random.uniform(3.0, 15.0)
        occ = 0
    elif scenario == "anomaly_empty_high":
        # Empty room + high power (alerts/escalation candidate)
        power = max(120.0, ap * random.uniform(1.1, 1.6))
        occ = 0
    elif scenario == "anomaly_occupied_high":
        # Occupied + unusually high power
        power = max(140.0, ap * random.uniform(1.2, 1.8))
        occ = 1
    elif scenario == "recovery":
        # Recovery pattern: first high-empty, then occupied-normal
        if tick % 2 == 0:
            power = max(120.0, ap * random.uniform(1.05, 1.4))
            occ = 0
        else:
            # Recovery side should drop below occupied anomaly threshold.
            power = random.uniform(45.0, 95.0)
            occ = 1
    else:
        # mixed
        r = random.random()
        if r < 0.45:
            # Non-anomalous occupied traffic
            power = random.uniform(45.0, 95.0)
            occ = 1
        elif r < 0.65:
            power = random.uniform(3.0, 18.0)
            occ = 0
        elif r < 0.85:
            power = max(110.0, ap * random.uniform(1.05, 1.5))
            occ = 0
        else:
            power = max(130.0, ap * random.uniform(1.2, 1.8))
            occ = 1

    return build_payload(profile, power=power, occupancy=occ)


def simulate_stream(
    base_url: str,
    profiles: Dict[str, RoomProfile],
    scenario: str,
    duration_sec: int,
    interval_sec: float,
    dry_run: bool,
) -> None:
    if not profiles:
        print("[SIM] No room profiles available. Aborting.")
        return

    room_ids = list(profiles.keys())
    end_time = time.time() + duration_sec
    tick = 0
    sent = 0
    anomalies_pred = 0

    print(f"[SIM] Scenario={scenario} rooms={room_ids} duration={duration_sec}s interval={interval_sec}s")

    while time.time() < end_time:
        for rid in room_ids:
            payload = scenario_point(profiles[rid], scenario, tick)
            is_likely_anomaly = (
                (payload["human_present"] == 0 and payload["power"] >= 20.0)
                or (payload["human_present"] == 1 and payload["power"] > 100.0)
            )
            if is_likely_anomaly:
                anomalies_pred += 1

            if dry_run:
                print(f"[DRY] {rid}: {payload}")
            else:
                try:
                    resp = post_sensor(base_url, payload)
                    ok = resp.status_code == 200
                    body = resp.json() if ok else {"status": "error", "http": resp.status_code, "body": resp.text[:200]}
                    print(f"[POST] {rid} status={resp.status_code} -> {body}")
                except Exception as e:
                    print(f"[POST][ERR] {rid}: {e}")

            sent += 1

        tick += 1
        time.sleep(max(0.1, interval_sec))

    print(f"[SIM] Done. payloads_sent={sent}, likely_anomaly_payloads={anomalies_pred}")


def _accelerate_escalation_windows(room_id: str, stage: str) -> None:
    """
    Fast-forward alert age so background service triggers stage quickly.

    stage=coordinator -> first_detected_at = now-6m, alert_count=1
    stage=sergeant    -> first_detected_at = now-11m, alert_count=2
    stage=cutoff      -> first_detected_at = now-16m, alert_count=3, anomaly_type usage_without_occupancy
    """
    now = datetime.now(timezone.utc)
    if stage == "coordinator":
        first_detected_at = now - timedelta(minutes=6)
        alert_count = 1
        anomaly_type = "usage_without_occupancy"
    elif stage == "sergeant":
        first_detected_at = now - timedelta(minutes=11)
        alert_count = 2
        anomaly_type = "usage_without_occupancy"
    else:
        first_detected_at = now - timedelta(minutes=16)
        alert_count = 3
        anomaly_type = "usage_without_occupancy"

    engine = _db_engine()
    with engine.begin() as conn:
        row = conn.execute(
            text(
                """
                SELECT id
                FROM anomaly_alert_tracking
                WHERE UPPER(room_id)=UPPER(:rid)
                  AND status='active'
                ORDER BY first_detected_at DESC
                LIMIT 1
                """
            ),
            {"rid": room_id},
        ).fetchone()

        if not row:
            print(f"[ESC] No active alert found for room {room_id}. Run anomaly scenario first.")
            return

        conn.execute(
            text(
                """
                UPDATE anomaly_alert_tracking
                SET first_detected_at = :fd,
                    alert_count = :ac,
                    anomaly_type = COALESCE(:atype, anomaly_type),
                    status = 'active'
                WHERE id = :id
                """
            ),
            {
                "fd": first_detected_at,
                "ac": alert_count,
                "atype": anomaly_type,
                "id": row[0],
            },
        )

    print(f"[ESC] Accelerated room={room_id} to stage={stage}. Wait ~35s for scheduler tick.")


def send_escalation_anchor_payload(base_url: str, profile: RoomProfile) -> None:
    """Post one deterministic empty-room/high-power reading so latest anomaly type stays stable."""
    power = max(140.0, profile.avg_power * 1.25)
    payload = build_payload(profile, power=power, occupancy=0)
    try:
        resp = post_sensor(base_url, payload)
        print(f"[ESC][ANCHOR] {profile.room_id} status={resp.status_code} body={resp.text[:120]}")
    except Exception as e:
        print(f"[ESC][ANCHOR][ERR] {profile.room_id}: {e}")


def ensure_active_alert(base_url: str, room_id: str) -> None:
    """Create an alert explicitly from latest anomaly log when needed."""
    engine = _db_engine()
    with engine.connect() as conn:
        row = conn.execute(
            text(
                """
                SELECT id
                FROM anomaly_logs
                WHERE UPPER(device_id)=UPPER(:rid)
                  AND is_anomaly = 1
                ORDER BY ds DESC
                LIMIT 1
                """
            ),
            {"rid": room_id},
        ).fetchone()

    if not row:
        print(f"[ESC][CREATE] No anomaly_log found for room {room_id}")
        return

    payload = {"room_id": room_id, "anomaly_log_id": int(row[0])}
    try:
        resp = requests.post(f"{base_url.rstrip('/')}/anomaly-alerts/create-alert", json=payload, timeout=8)
        print(f"[ESC][CREATE] room={room_id} status={resp.status_code} body={resp.text[:140]}")
    except Exception as e:
        print(f"[ESC][CREATE][ERR] room={room_id}: {e}")


def print_validation_summary(room_ids: List[str], last_minutes: int = 60) -> None:
    """Print DB-level verification summary for anomalies, alerts, and notifications."""
    engine = _db_engine()
    with engine.connect() as conn:
        print("\n=== VALIDATION SUMMARY ===")
        for rid in room_ids:
            print(f"\nRoom: {rid}")

            alog = conn.execute(
                text(
                    """
                    SELECT COUNT(*),
                           COALESCE(SUM(CASE WHEN is_anomaly=1 THEN 1 ELSE 0 END), 0)
                    FROM anomaly_logs
                    WHERE UPPER(device_id)=UPPER(:rid)
                      AND ds >= NOW() - (:mins * INTERVAL '1 minute')
                    """
                ),
                {"rid": rid, "mins": last_minutes},
            ).fetchone()

            atrack = conn.execute(
                text(
                    """
                    SELECT status, alert_count, anomaly_type, first_detected_at, last_alert_sent_at
                    FROM anomaly_alert_tracking
                    WHERE UPPER(room_id)=UPPER(:rid)
                    ORDER BY first_detected_at DESC
                    LIMIT 1
                    """
                ),
                {"rid": rid},
            ).fetchone()

            noti = conn.execute(
                text(
                    """
                    SELECT recipient_type, COUNT(*)
                    FROM notifications
                    WHERE UPPER(room_id)=UPPER(:rid)
                      AND created_at >= NOW() - (:mins * INTERVAL '1 minute')
                    GROUP BY recipient_type
                    ORDER BY recipient_type
                    """
                ),
                {"rid": rid, "mins": last_minutes},
            ).fetchall()

            print(f"  anomaly_logs(last {last_minutes}m): total={alog[0] if alog else 0}, flagged={alog[1] if alog else 0}")
            if atrack:
                print(
                    "  tracking:" 
                    f" status={atrack[0]}, alert_count={atrack[1]}, type={atrack[2]},"
                    f" first={atrack[3]}, last_sent={atrack[4]}"
                )
            else:
                print("  tracking: none")

            if noti:
                print(f"  notifications(last {last_minutes}m): {[(r[0], r[1]) for r in noti]}")
            else:
                print("  notifications(last window): none")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="ENERGIA sensor input simulator")
    parser.add_argument("--base-url", default="http://127.0.0.1:5000", help="Backend base URL")
    parser.add_argument(
        "--scenario",
        default="smoke",
        choices=["smoke", "normal", "idle", "anomaly_empty_high", "anomaly_occupied_high", "recovery", "mixed", "escalation"],
    )
    parser.add_argument("--rooms", default="", help="Comma-separated room IDs. Empty = auto-discover")
    parser.add_argument("--duration-sec", type=int, default=120, help="Simulation run duration in seconds")
    parser.add_argument("--interval-sec", type=float, default=4.0, help="Delay between ticks")
    parser.add_argument("--dry-run", action="store_true", help="Print payloads only")
    parser.add_argument("--accelerate-stages", action="store_true", help="Fast-forward escalation windows")
    parser.add_argument(
        "--escalation-target",
        default="coordinator",
        choices=["coordinator", "sergeant", "cutoff"],
        help="Stage target when --accelerate-stages is used",
    )
    parser.add_argument("--summary-window-min", type=int, default=90, help="Validation summary time window")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    # Basic health check
    try:
        r = requests.get(f"{args.base_url.rstrip('/')}/health", timeout=5)
        print(f"[HEALTH] {args.base_url} -> {r.status_code} {r.text[:120]}")
    except Exception as e:
        print(f"[HEALTH][WARN] Could not reach backend health endpoint: {e}")

    if args.rooms.strip():
        room_ids = [r.strip() for r in args.rooms.split(",") if r.strip()]
    else:
        room_ids = discover_rooms(limit=4)

    if not room_ids:
        print("[SIM] No rooms found. Provide --rooms explicitly.")
        return

    profiles = load_profiles(room_ids)
    print("[SIM] Loaded room profiles:")
    for rid, p in profiles.items():
        print(
            f"  - {rid}: avg_power={p.avg_power:.2f}W, avg_voltage={p.avg_voltage:.2f}V,"
            f" avg_pf={p.avg_pf:.3f}, avg_freq={p.avg_freq:.2f}Hz"
        )

    scenario = args.scenario
    if scenario == "smoke":
        # Short sequence touching normal + both anomaly types + recovery
        for step in ["normal", "anomaly_empty_high", "anomaly_occupied_high", "recovery"]:
            simulate_stream(
                base_url=args.base_url,
                profiles=profiles,
                scenario=step,
                duration_sec=18,
                interval_sec=max(1.5, args.interval_sec),
                dry_run=args.dry_run,
            )
    elif scenario == "escalation":
        simulate_stream(
            base_url=args.base_url,
            profiles=profiles,
            scenario="anomaly_empty_high",
            duration_sec=max(20, args.duration_sec),
            interval_sec=args.interval_sec,
            dry_run=args.dry_run,
        )
        if args.accelerate_stages and not args.dry_run:
            for rid in room_ids:
                ensure_active_alert(args.base_url, rid)
                _accelerate_escalation_windows(rid, args.escalation_target)
                send_escalation_anchor_payload(args.base_url, profiles[rid])
            print("[ESC] Waiting 35 seconds for scheduler to process escalated stage...")
            time.sleep(35)
    else:
        simulate_stream(
            base_url=args.base_url,
            profiles=profiles,
            scenario=scenario,
            duration_sec=args.duration_sec,
            interval_sec=args.interval_sec,
            dry_run=args.dry_run,
        )

    if not args.dry_run:
        print_validation_summary(room_ids, last_minutes=args.summary_window_min)


if __name__ == "__main__":
    main()
