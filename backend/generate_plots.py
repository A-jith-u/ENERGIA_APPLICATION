"""
Generate accuracy plots for:
  1. Ensemble model (energy_ensemble_90_mixed)
  2. Isolation Forest anomaly detector
"""
import joblib
import warnings
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sqlalchemy import create_engine, text
from pathlib import Path

warnings.filterwarnings('ignore')

DB_URL = 'postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia'
engine = create_engine(DB_URL)

Path('metrics').mkdir(parents=True, exist_ok=True)

FIG_BG    = '#ffffff'
PANEL_BG  = '#ffffff'
TEXT      = '#111111'
SUBTEXT   = '#333333'
BORDER    = '#c7c7c7'
BLUE      = '#1f77b4'
GREEN     = '#2ca02c'
PURPLE    = '#7f3c8d'
YELLOW    = '#b8860b'
RED       = '#d62728'


def style_ax(ax):
    ax.set_facecolor(PANEL_BG)
    ax.tick_params(colors=SUBTEXT)
    ax.xaxis.label.set_color(SUBTEXT)
    ax.yaxis.label.set_color(SUBTEXT)
    ax.title.set_color(TEXT)
    for spine in ax.spines.values():
        spine.set_edgecolor(BORDER)


# ─────────────────────────────────────────────────────────────────────────────
# PLOT 1: ENSEMBLE MODEL
# ─────────────────────────────────────────────────────────────────────────────
print('Generating ensemble model accuracy plot...')

with open('metrics/ensemble90_mixed_metrics.json') as f:
    m = json.load(f)

pred_df = pd.read_csv('metrics/ensemble90_mixed_predictions.csv')
y_test = pred_df['actual'].values
y_pred = pred_df['predicted'].values

mo = m['metrics_overall']
mg30 = m['metrics_gt30']
mg50 = m['metrics_gt50']
mg100 = m['metrics_gt100']

fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.patch.set_facecolor(FIG_BG)
for ax in axes.flat:
    style_ax(ax)

# 1) Actual vs Predicted (tail 250)
ax = axes[0, 0]
n = min(250, len(y_test))
ax.plot(y_test[-n:], label='Actual', color=BLUE, linewidth=1.5)
ax.plot(y_pred[-n:], label='Predicted', color=GREEN, linewidth=1.5, linestyle='--')
ax.set_title('Actual vs Predicted (Test Tail)', fontsize=11, fontweight='bold')
ax.set_xlabel('Sample Index')
ax.set_ylabel('Energy Value (W)')
ax.legend(facecolor='#ffffff', edgecolor=BORDER, labelcolor=SUBTEXT)
ax.grid(True, alpha=0.15, color=BORDER)

# 2) Scatter
ax = axes[0, 1]
ax.scatter(y_test, y_pred, s=8, alpha=0.4, color=BLUE)
lo = min(float(y_test.min()), float(y_pred.min()))
hi = max(float(y_test.max()), float(y_pred.max()))
ax.plot([lo, hi], [lo, hi], 'r--', linewidth=1.2, label='Perfect fit')
ax.set_title('Predicted vs Actual (Scatter)', fontsize=11, fontweight='bold')
ax.set_xlabel('Actual')
ax.set_ylabel('Predicted')
ax.legend(facecolor='#ffffff', edgecolor=BORDER, labelcolor=SUBTEXT)
ax.grid(True, alpha=0.15, color=BORDER)

# 3) Relative error histogram
ax = axes[1, 0]
denom = np.where(np.abs(y_test) < 1e-9, 1.0, np.abs(y_test))
rel_err = np.abs(y_test - y_pred) / denom * 100.0
ax.hist(rel_err, bins=50, color=PURPLE, alpha=0.85, edgecolor='#6e40c9')
ax.axvline(15, color=GREEN,  linestyle='--', linewidth=1.2,
           label='15%% — %.1f%% inside' % mo['acc15_all'])
ax.axvline(20, color=RED, linestyle='--', linewidth=1.2,
           label='20%% — %.1f%% inside' % mo['acc20_all'])
ax.set_title('Relative Error Distribution (%)', fontsize=11, fontweight='bold')
ax.set_xlabel('Absolute Percent Error')
ax.set_ylabel('Count')
ax.legend(facecolor='#ffffff', edgecolor=BORDER, labelcolor=SUBTEXT, fontsize=9)
ax.grid(True, alpha=0.15, color=BORDER)

# 4) Accuracy bar chart by subset
ax = axes[1, 1]
labels = ['All', '>30 W', '>50 W', '>100 W']
acc20_vals = [mo['acc20_all'], mg30['acc20'], mg50['acc20'], mg100['acc20']]
acc15_vals = [mo['acc15_all'], mg30['acc15'], mg50['acc15'], mg100['acc15']]
x = np.arange(len(labels))
w = 0.38
b1 = ax.bar(x - w/2, acc20_vals, width=w, label='Within ±20%',
            color=GREEN, edgecolor=BORDER, zorder=3)
b2 = ax.bar(x + w/2, acc15_vals, width=w, label='Within ±15%',
            color=BLUE, edgecolor=BORDER, zorder=3)
ax.set_ylim(0, 115)
ax.axhline(90, color=YELLOW, linestyle='--', linewidth=1.0, alpha=0.7, label='90% target')
ax.set_xticks(x)
ax.set_xticklabels(labels)
ax.set_title('Accuracy by Subset & Tolerance', fontsize=11, fontweight='bold')
ax.set_ylabel('Accuracy (%)')
ax.legend(facecolor='#ffffff', edgecolor=BORDER, labelcolor=SUBTEXT, fontsize=9)
ax.grid(True, axis='y', alpha=0.15, color=BORDER, zorder=0)
for b, v in zip(list(b1) + list(b2), acc20_vals + acc15_vals):
    ax.text(b.get_x() + b.get_width()/2, v + 1.2, '%.1f%%' % v,
            ha='center', va='bottom', fontsize=8, color=TEXT, fontweight='bold')

fig.suptitle(
    'Ensemble Model\n'
    'MAE=%.3f  RMSE=%.3f  R²=%.4f  Accuracy ±20%%=%.2f%%' % (
        mo['mae'], mo['rmse'], mo['r2'], mo['acc20_all']
    ),
    fontsize=13, fontweight='bold', color=TEXT, y=1.02
)
fig.tight_layout()
out1 = 'metrics/ensemble_model_accuracy_plot.png'
fig.savefig(out1, dpi=150, bbox_inches='tight', facecolor=fig.get_facecolor())
plt.close(fig)
print('  Saved:', out1)


# ─────────────────────────────────────────────────────────────────────────────
# PLOT 2: ISOLATION FOREST
# ─────────────────────────────────────────────────────────────────────────────
print('Generating Isolation Forest accuracy plot...')

clf = joblib.load('models/isolation_forest_model.pkl')

with engine.connect() as conn:
    df = pd.read_sql(
        text('''SELECT power, occupancy, is_anomaly, anomaly_score
                FROM anomaly_logs
                WHERE power IS NOT NULL
                ORDER BY ds DESC
                LIMIT 5000'''),
        conn
    )

# Score distribution (from DB — decision_function values stored as anomaly_score)
scores = df['anomaly_score'].dropna().values
flags  = df['is_anomaly'].values
power  = df['power'].values

total   = len(df)
flagged = int((flags == 1).sum())
normal  = int((flags == 0).sum())
legacy  = int((flags == -1).sum())

neg_scores = int((scores < 0).sum())
anomaly_pct = 100.0 * flagged / total if total else 0

fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.patch.set_facecolor(FIG_BG)
for ax in axes.flat:
    style_ax(ax)

# 1) Decision score distribution
ax = axes[0, 0]
ax.hist(scores, bins=60, color=PURPLE, alpha=0.85, edgecolor='#6e40c9', zorder=3)
ax.axvline(0, color=RED, linestyle='--', linewidth=1.5, label='Decision boundary (0)')
ax.axvline(clf.offset_, color=YELLOW, linestyle=':', linewidth=1.5,
           label='Offset (%.4f)' % clf.offset_)
ax.set_title('Anomaly Score Distribution\n(decision_function output)', fontsize=11, fontweight='bold')
ax.set_xlabel('Score  (negative = anomalous)')
ax.set_ylabel('Count')
ax.legend(facecolor='#ffffff', edgecolor=BORDER, labelcolor=SUBTEXT, fontsize=9)
ax.grid(True, alpha=0.15, color=BORDER, zorder=0)
neg_lbl = '%.1f%% anomalous (score < 0)' % (100.0 * neg_scores / len(scores) if len(scores) else 0)
ax.text(0.97, 0.95, neg_lbl, transform=ax.transAxes,
        ha='right', va='top', color=RED, fontsize=9,
        bbox=dict(facecolor='#ffffff', edgecolor=BORDER, boxstyle='round,pad=0.3'))

# 2) Detection breakdown (pie)
ax = axes[0, 1]
labels_pie = ['Anomaly (1)', 'Normal (0)']
sizes_pie  = [flagged, normal + legacy]
colors_pie = [RED, GREEN]
explode    = (0.06, 0)
wedges, texts, autotexts = ax.pie(
    sizes_pie, labels=labels_pie, colors=colors_pie,
    explode=explode, autopct='%1.1f%%', startangle=90,
    textprops={'color': SUBTEXT},
    wedgeprops={'edgecolor': BORDER, 'linewidth': 1.2}
)
for at in autotexts:
    at.set_color(TEXT)
    at.set_fontweight('bold')
ax.set_title('Detection Class Distribution\n(%d total records)' % total,
             fontsize=11, fontweight='bold')

# 3) Power vs anomaly score scatter
ax = axes[1, 0]
mask_anom   = flags == 1
mask_normal = flags != 1
s_anom   = df.loc[df['is_anomaly'] == 1,  'anomaly_score'].fillna(0).values
s_normal = df.loc[df['is_anomaly'] != 1, 'anomaly_score'].fillna(0).values
p_anom   = df.loc[df['is_anomaly'] == 1,  'power'].values
p_normal = df.loc[df['is_anomaly'] != 1, 'power'].values
ax.scatter(p_normal, s_normal, s=8, alpha=0.4, color=GREEN, label='Normal',   zorder=2)
ax.scatter(p_anom,   s_anom,   s=8, alpha=0.5, color=RED,   label='Anomaly',  zorder=3)
ax.axhline(0, color=YELLOW, linestyle='--', linewidth=1.0, label='boundary=0', alpha=0.7)
ax.set_title('Power (W) vs Anomaly Score', fontsize=11, fontweight='bold')
ax.set_xlabel('Power (W)')
ax.set_ylabel('Anomaly Score')
ax.legend(facecolor='#ffffff', edgecolor=BORDER, labelcolor=SUBTEXT, fontsize=9)
ax.grid(True, alpha=0.15, color=BORDER)

# 4) Score stats bar
ax = axes[1, 1]
stat_labels = ['Min', 'Max', 'Mean', 'Std', 'Offset']
stat_vals   = [
    float(scores.min()) if len(scores) else 0,
    float(scores.max()) if len(scores) else 0,
    float(scores.mean()) if len(scores) else 0,
    float(scores.std())  if len(scores) else 0,
    float(clf.offset_),
]
bar_colors = [RED if v < 0 else BLUE for v in stat_vals]
bars = ax.bar(stat_labels, stat_vals, color=bar_colors, edgecolor=BORDER, zorder=3)
ax.axhline(0, color=YELLOW, linestyle='--', linewidth=1.0, alpha=0.7, label='Zero threshold')
ax.set_title('Decision Function Statistics', fontsize=11, fontweight='bold')
ax.set_ylabel('Score Value')
ax.legend(facecolor='#ffffff', edgecolor=BORDER, labelcolor=SUBTEXT)
ax.grid(True, axis='y', alpha=0.15, color=BORDER, zorder=0)
for b, v in zip(bars, stat_vals):
    ax.text(b.get_x() + b.get_width()/2,
            v + (0.005 if v >= 0 else -0.012),
            '%.4f' % v, ha='center', va='bottom', fontsize=9, color=TEXT)

fig.suptitle(
    'Isolation Forest — Anomaly Detection\n'
    'n_estimators=100  contamination=0.02  offset=%.4f  |  '
    'Flagged: %d/%d (%.1f%%)' % (clf.offset_, flagged, total, anomaly_pct),
    fontsize=13, fontweight='bold', color=TEXT, y=1.02
)
fig.tight_layout()
out2 = 'metrics/isolation_forest_accuracy_plot.png'
fig.savefig(out2, dpi=150, bbox_inches='tight', facecolor=fig.get_facecolor())
plt.close(fig)
print('  Saved:', out2)

print('\nDone. Both plots generated.')
