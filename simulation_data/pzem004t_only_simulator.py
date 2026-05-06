from __future__ import annotations

import argparse
import random
import time
import sys
from typing import Dict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from simulation_data.common import (
    AuthConfig,
    approx_current_from_power,
    clamp,
    current_utc,
    login_and_get_headers,
    post_sensor_reading,
)

DEFAULT_DEVICE_ID = "ESP32-CS-C201"
DEFAULT_BASE_URL = "http://127.0.0.1:5000"


def build_pzem_payload(
    device_id: str,
    energy_kwh: float,
    power_watts: float,
) -> Dict[str, float | str]:
    voltage = clamp(random.gauss(230.0, 1.5), 224.0, 236.0)
    power_factor = clamp(random.gauss(0.94, 0.02), 0.75, 0.99)
    current = approx_current_from_power(power_watts, voltage, power_factor)

    return {
        "device_id": device_id,
        "power": round(power_watts, 2),
        "current": round(current, 3),
        "voltage": round(voltage, 2),
        "energy": round(energy_kwh, 4),
        "frequency": round(clamp(random.gauss(50.0, 0.05), 49.8, 50.2), 2),
        "power_factor": round(power_factor, 3),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Simulate only the PZEM004T electrical readings.")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--device-id", default=DEFAULT_DEVICE_ID)
    parser.add_argument("--username", default=None, help="Backend login username")
    parser.add_argument("--password", default=None, help="Backend login password")
    parser.add_argument("--department", default=None, help="Department for coordinator login")
    parser.add_argument("--token", default=None, help="Use an existing JWT instead of logging in")
    parser.add_argument("--interval-sec", type=float, default=5.0)
    parser.add_argument("--baseline-power", type=float, default=62.0)
    parser.add_argument("--spike-chance", type=float, default=0.18)
    parser.add_argument("--spike-min-watts", type=float, default=120.0)
    parser.add_argument("--spike-max-watts", type=float, default=280.0)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--count", type=int, default=0, help="Run a finite number of samples instead of looping forever")
    args = parser.parse_args()

    headers = None
    if not args.dry_run:
        headers = login_and_get_headers(
            AuthConfig(
                base_url=args.base_url,
                username=args.username,
                password=args.password,
                department=args.department,
                token=args.token,
            )
        )

    energy_kwh = 0.0
    if args.count > 0:
        print(f"[PZEM] Starting PZEM004T-only simulation for {args.count} samples.")
    else:
        print("[PZEM] Starting infinite PZEM004T-only simulation. Press Ctrl+C to stop.")
    print(f"[PZEM] device_id={args.device_id} base_url={args.base_url} spike_chance={args.spike_chance}")

    samples_sent = 0
    try:
        while True:
            power = random.uniform(18.0, 95.0)
            if random.random() < args.spike_chance:
                power = random.uniform(args.spike_min_watts, args.spike_max_watts)

            energy_kwh += max(0.0, power) * (args.interval_sec / 3600.0) / 1000.0
            payload = build_pzem_payload(
                device_id=args.device_id,
                energy_kwh=energy_kwh,
                power_watts=power,
            )

            if args.dry_run:
                print(f"[PZEM][DRY] {current_utc().isoformat()} {payload}")
            else:
                resp = post_sensor_reading(args.base_url, headers or {}, payload)
                print(f"[PZEM] {current_utc().isoformat()} status={resp.status_code} power={payload['power']}W voltage={payload['voltage']}V energy={payload['energy']}kWh")

            samples_sent += 1
            if args.count > 0 and samples_sent >= args.count:
                break

            time.sleep(max(0.2, args.interval_sec))
    except KeyboardInterrupt:
        print("[PZEM] Stopped by user.")


if __name__ == "__main__":
    main()
