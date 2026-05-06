from __future__ import annotations

"""Averaging PZEM004T simulator.

Generates rapid PZEM-like samples, computes averaged electrical readings
over a window, then POSTs the averaged payload to the backend `/sensor-data`
endpoint. Optionally emits occupancy-only updates (separate POSTs) to test
the backend's merge behavior.

Usage example:
  .venv/Scripts/python.exe simulation_data/pzem004t_averaging_simulator.py \
    --username CCS002 --password J0q!8p --department CSE --count 10
"""

import argparse
import random
import time
import sys
from statistics import mean
from typing import Dict, List
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


def generate_sample(baseline_power: float, spike_chance: float, spike_min: float, spike_max: float):
    power = random.uniform(max(0.0, baseline_power * 0.25), baseline_power * 1.5)
    if random.random() < spike_chance:
        power = random.uniform(spike_min, spike_max)
    voltage = clamp(random.gauss(230.0, 1.5), 224.0, 236.0)
    power_factor = clamp(random.gauss(0.94, 0.02), 0.75, 0.99)
    current = approx_current_from_power(power, voltage, power_factor)
    frequency = round(clamp(random.gauss(50.0, 0.05), 49.8, 50.2), 2)
    return {
        "power": round(power, 2),
        "voltage": round(voltage, 2),
        "power_factor": round(power_factor, 3),
        "current": round(current, 3),
        "frequency": frequency,
    }


def build_averaged_payload(device_id: str, samples: List[Dict], energy_kwh: float) -> Dict[str, float | str]:
    avg_power = mean([s["power"] for s in samples])
    avg_voltage = mean([s["voltage"] for s in samples])
    avg_pf = mean([s["power_factor"] for s in samples])
    # Prefer computing current from the averaged power/voltage/pf for consistency
    avg_current = approx_current_from_power(avg_power, avg_voltage, avg_pf)
    avg_frequency = mean([s["frequency"] for s in samples])

    return {
        "device_id": device_id,
        "power": round(avg_power, 2),
        "current": round(avg_current, 3),
        "voltage": round(avg_voltage, 2),
        "energy": round(energy_kwh, 4),
        "frequency": round(avg_frequency, 2),
        "power_factor": round(avg_pf, 3),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="PZEM averaging simulator")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--device-id", default=DEFAULT_DEVICE_ID)
    parser.add_argument("--username", default=None)
    parser.add_argument("--password", default=None)
    parser.add_argument("--department", default=None)
    parser.add_argument("--token", default=None)
    parser.add_argument("--sample-interval", type=float, default=6.0, help="Interval between raw samples (s)")
    parser.add_argument("--samples-per-window", type=int, default=10, help="Number of raw samples to average per 60-second window")
    parser.add_argument("--baseline-power", type=float, default=62.0)
    parser.add_argument("--spike-chance", type=float, default=0.18)
    parser.add_argument("--spike-min-watts", type=float, default=120.0)
    parser.add_argument("--spike-max-watts", type=float, default=280.0)
    parser.add_argument("--emit-occupancy", action="store_true", help="Emit a separate occupancy-only POST before each averaged electrical payload")
    parser.add_argument("--occupancy-prob", type=float, default=0.2, help="Probability that occupancy is 1 when emitting occupancy updates")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--count", type=int, default=0, help="Number of averaged 60-second windows to send (0=infinite)")
    args = parser.parse_args()

    if args.samples_per_window <= 0:
        raise SystemExit("--samples-per-window must be greater than 0")
    if args.sample_interval <= 0:
        raise SystemExit("--sample-interval must be greater than 0")

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
    window_seconds = args.samples_per_window * args.sample_interval
    sent = 0
    try:
        while True:
            samples = []
            for _ in range(args.samples_per_window):
                samples.append(generate_sample(args.baseline_power, args.spike_chance, args.spike_min_watts, args.spike_max_watts))
                time.sleep(args.sample_interval)

            # compute averaged payload over one minute of raw readings
            avg_power = mean([s["power"] for s in samples])
            # accumulate energy using average power over the full window
            energy_kwh += max(0.0, avg_power) * (window_seconds / 3600.0) / 1000.0

            payload = build_averaged_payload(args.device_id, samples, energy_kwh)

            # optionally emit occupancy-only POST first to test merge behavior
            if args.emit_occupancy:
                occ = 1 if random.random() < args.occupancy_prob else 0
                occ_payload = {"device_id": args.device_id, "human_present": occ}
                if args.dry_run:
                    print(f"[OCC][DRY] {current_utc().isoformat()} {occ_payload} window_seconds={window_seconds}")
                else:
                    r = post_sensor_reading(args.base_url, headers or {}, occ_payload)
                    print(f"[OCC] {current_utc().isoformat()} status={r.status_code} occ={occ}")

            # send averaged electrical payload
            if args.dry_run:
                print(f"[AVG][DRY] {current_utc().isoformat()} {payload} samples={len(samples)} window_seconds={window_seconds}")
            else:
                resp = post_sensor_reading(args.base_url, headers or {}, payload)
                print(f"[AVG] {current_utc().isoformat()} status={resp.status_code} power={payload['power']}W voltage={payload['voltage']}V energy={payload['energy']}kWh samples={len(samples)} window_seconds={window_seconds}")

            sent += 1
            if args.count > 0 and sent >= args.count:
                break

    except KeyboardInterrupt:
        print("[AVG] Stopped by user.")


if __name__ == "__main__":
    main()
