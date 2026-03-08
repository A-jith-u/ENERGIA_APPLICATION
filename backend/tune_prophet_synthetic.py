#!/usr/bin/env python3
"""Sweep synthetic/data settings for Prophet and keep best run."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

DB_URL = os.environ.get("DB_URL", "postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia")
BASE_DIR = Path(__file__).resolve().parent
TRAIN_SCRIPT = BASE_DIR / "train_prophet.py"
METRICS_DIR = BASE_DIR / "metrics"
METRICS_DIR.mkdir(parents=True, exist_ok=True)

# Keep sweep compact but meaningful.
SWEEP = [
    {"lookback": 14, "synthetic": 450, "cp": 0.2, "sp": 8.0, "target": "power_or_value"},
    {"lookback": 14, "synthetic": 600, "cp": 0.2, "sp": 8.0, "target": "power_or_value"},
    {"lookback": 14, "synthetic": 900, "cp": 0.2, "sp": 8.0, "target": "power_or_value"},
    {"lookback": 21, "synthetic": 600, "cp": 0.2, "sp": 8.0, "target": "power_or_value"},
    {"lookback": 30, "synthetic": 900, "cp": 0.2, "sp": 8.0, "target": "power_or_value"},
    {"lookback": 14, "synthetic": 600, "cp": 0.15, "sp": 6.0, "target": "power_or_value"},
    {"lookback": 14, "synthetic": 600, "cp": 0.3, "sp": 10.0, "target": "power_or_value"},
]

RE_METRIC = {
    "mae": re.compile(r"MAE:\s+([0-9.]+)"),
    "rmse": re.compile(r"RMSE:\s+([0-9.]+)"),
    "mape": re.compile(r"MAPE:\s+([0-9.]+)%"),
    "accuracy": re.compile(r"Accuracy:\s+([0-9.]+)%"),
}
RE_R2 = re.compile(r"R[^:]*:\\s+([-0-9.]+)")


def parse_metrics(text: str) -> dict[str, float] | None:
    out: dict[str, float] = {}
    for key, pattern in RE_METRIC.items():
        match = pattern.search(text)
        if not match:
            return None
        out[key] = float(match.group(1))
    r2_match = RE_R2.search(text)
    out["r2"] = float(r2_match.group(1)) if r2_match else 0.0
    return out


def score(m: dict[str, float]) -> float:
    # Primary: MAE and RMSE. Secondary: MAPE. R2 boosts but bounded.
    r2_bonus = max(min(m["r2"], 1.0), -10.0)
    return m["mae"] * 0.6 + m["rmse"] * 0.3 + m["mape"] * 0.1 - r2_bonus


def run_case(case: dict[str, float]) -> tuple[int, str]:
    export_path = METRICS_DIR / (
        f"prophet_training_combined_lb{case['lookback']}_syn{case['synthetic']}_cp{case['cp']}_sp{case['sp']}.csv"
    )
    cmd = [
        sys.executable,
        str(TRAIN_SCRIPT),
        "--source",
        "db",
        "--db-url",
        DB_URL,
        "--raw-table",
        "sensor_data",
        "--lookback-days",
        str(case["lookback"]),
        "--ts-col",
        "ds",
        "--target-col",
        str(case["target"]),
        "--resample",
        "1min",
        "--synthetic-target-rows",
        str(case["synthetic"]),
        "--eval-split",
        "0.2",
        "--changepoint-prior",
        str(case["cp"]),
        "--seasonality-prior",
        str(case["sp"]),
        "--export-training-csv",
        str(export_path),
        "--no-show-plot",
    ]

    proc = subprocess.run(
        cmd,
        cwd=str(BASE_DIR),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return proc.returncode, proc.stdout + "\n" + proc.stderr


def main() -> int:
    print(f"Sweeping {len(SWEEP)} configurations...")
    results: list[dict[str, object]] = []

    for idx, case in enumerate(SWEEP, start=1):
        print(f"[{idx}/{len(SWEEP)}] lookback={case['lookback']} synthetic={case['synthetic']} cp={case['cp']} sp={case['sp']}")
        rc, output = run_case(case)
        metrics = parse_metrics(output)
        if metrics is None:
            print("  -> failed to parse metrics")
            results.append({"case": case, "ok": False, "rc": rc, "output": output[-1200:]})
            continue
        val = score(metrics)
        print(
            f"  -> mae={metrics['mae']:.2f}, rmse={metrics['rmse']:.2f}, "
            f"mape={metrics['mape']:.2f}, acc={metrics['accuracy']:.2f}, r2={metrics['r2']:.4f}, score={val:.2f}"
        )
        results.append({"case": case, "ok": True, "rc": rc, "metrics": metrics, "score": val})

    ok_results = [r for r in results if r.get("ok")]
    if not ok_results:
        print("No successful runs.")
        return 1

    best = min(ok_results, key=lambda r: float(r["score"]))
    best_case = best["case"]
    best_metrics = best["metrics"]

    print("\nBest configuration:")
    print(best_case)
    print(best_metrics)

    # Re-run best and overwrite canonical combined CSV path.
    final_csv = METRICS_DIR / "prophet_training_combined.csv"
    cmd = [
        sys.executable,
        str(TRAIN_SCRIPT),
        "--source",
        "db",
        "--db-url",
        DB_URL,
        "--raw-table",
        "sensor_data",
        "--lookback-days",
        str(best_case["lookback"]),
        "--ts-col",
        "ds",
        "--target-col",
        str(best_case["target"]),
        "--resample",
        "1min",
        "--synthetic-target-rows",
        str(best_case["synthetic"]),
        "--eval-split",
        "0.2",
        "--changepoint-prior",
        str(best_case["cp"]),
        "--seasonality-prior",
        str(best_case["sp"]),
        "--export-training-csv",
        str(final_csv),
        "--no-show-plot",
    ]
    proc = subprocess.run(
        cmd,
        cwd=str(BASE_DIR),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    print("\nFinal best run output (tail):")
    tail = (proc.stdout + "\n" + proc.stderr).splitlines()[-25:]
    for line in tail:
        print(line)

    summary_path = METRICS_DIR / "prophet_sweep_summary.txt"
    with open(summary_path, "w", encoding="utf-8") as f:
        f.write("Prophet Sweep Summary\n")
        f.write("=====================\n\n")
        for r in results:
            if not r.get("ok"):
                f.write(f"FAIL {r['case']}\n")
                continue
            f.write(
                f"OK {r['case']} -> score={r['score']:.3f}, "
                f"MAE={r['metrics']['mae']:.2f}, RMSE={r['metrics']['rmse']:.2f}, "
                f"MAPE={r['metrics']['mape']:.2f}, ACC={r['metrics']['accuracy']:.2f}, R2={r['metrics']['r2']:.4f}\n"
            )
        f.write("\nBEST\n")
        f.write(str(best_case) + "\n")
        f.write(str(best_metrics) + "\n")

    print(f"\nWrote sweep summary: {summary_path}")
    print(f"Canonical combined CSV: {final_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
