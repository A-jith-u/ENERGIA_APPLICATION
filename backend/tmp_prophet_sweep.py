import itertools
import re
import subprocess
import sys

py = r"e:/Flutter/flutter_application_1/.venv/Scripts/python.exe"
base = [
    py, "train_prophet.py",
    "--source", "db",
    "--db-url", "postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia",
    "--raw-table", "sensor_data",
    "--ts-col", "ds",
    "--target-col", "power_or_value",
    "--resample", "1min",
    "--no-show-plot",
]

lookbacks = [14, 30, 60, 120]
synthetic = [600, 1200, 3000, 6000]
eval_splits = [0.1, 0.15, 0.2]
cp = [0.05, 0.1, 0.2, 0.3]
sp = [3.0, 5.0, 8.0, 12.0]

pat = {
    'mae': re.compile(r"MAE:\s+([0-9.]+)"),
    'rmse': re.compile(r"RMSE:\s+([0-9.]+)"),
    'mape': re.compile(r"MAPE:\s+([0-9.]+)%"),
    'acc': re.compile(r"Accuracy:\s+([0-9.]+)%"),
}

results = []
# keep runtime manageable
for i, (lb, syn, ev, c, s) in enumerate(itertools.product(lookbacks, synthetic, eval_splits, cp, sp), start=1):
    if i > 60:
        break
    cmd = base + [
        "--lookback-days", str(lb),
        "--synthetic-target-rows", str(syn),
        "--eval-split", str(ev),
        "--changepoint-prior", str(c),
        "--seasonality-prior", str(s),
        "--no-save-plot",
        "--export-training-csv", "metrics/prophet_training_combined_tmp.csv",
    ]
    p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    t = (p.stdout or "") + "\n" + (p.stderr or "")
    rec = {'lookback': lb, 'synthetic': syn, 'eval_split': ev, 'cp': c, 'sp': s, 'ok': True}
    for k, rgx in pat.items():
        m = rgx.search(t)
        rec[k] = float(m.group(1)) if m else None
    if rec['acc'] is None:
        rec['ok'] = False
    results.append(rec)
    print(f"trial {i:02d}: lb={lb} syn={syn} ev={ev} cp={c} sp={s} acc={rec['acc']} mape={rec['mape']}")

valid = [r for r in results if r['ok']]
if not valid:
    print("NO_VALID_RESULTS")
    sys.exit(0)

best = sorted(valid, key=lambda r: (-(r['acc'] or -1), r['mape'] or 1e9, r['rmse'] or 1e9))[0]
print("BEST_RESULT", best)
