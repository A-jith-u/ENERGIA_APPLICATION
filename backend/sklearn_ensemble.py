"""
Sklearn ensemble approach: Using Random Forest + GradientBoosting from scikit-learn
No external dependencies needed
"""
import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from sklearn.preprocessing import MinMaxScaler
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.metrics import mean_absolute_error, mean_absolute_percentage_error
import warnings
warnings.filterwarnings('ignore')

engine = create_engine(
    'postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia'
)

print("=" * 60)
print("SKLEARN ENSEMBLE APPROACH")
print("=" * 60)

# Load data
df = pd.read_sql(
    'SELECT ds, value FROM sensor_data WHERE value IS NOT NULL ORDER BY ds',
    engine
)
df['ds'] = pd.to_datetime(df['ds'])
df = df.sort_values('ds').reset_index(drop=True)
values = df['value'].values

print(f"Total records: {len(df)}")

# Create lagged features
def create_lags(data, lags=[1, 7, 14, 30, 60]):
    df_lags = pd.DataFrame({'value': data})
    for lag in lags:
        df_lags[f'lag_{lag}'] = df_lags['value'].shift(lag)
    
    # Rolling statistics
    df_lags['rolling_mean_7'] = df_lags['value'].rolling(7, min_periods=1).mean()
    df_lags['rolling_std_7'] = df_lags['value'].rolling(7, min_periods=1).std().fillna(0)
    df_lags['rolling_mean_30'] = df_lags['value'].rolling(30, min_periods=1).mean()
    
    # Trend feature
    df_lags['trend'] = np.arange(len(df_lags))
    
    return df_lags.dropna()

df_features = create_lags(values, lags=[1, 7, 14, 30, 60])
print(f"Features created: {df_features.shape}")

X = df_features.drop('value', axis=1).values
y = df_features['value'].values

# Split
split = int(len(X) * 0.8)
X_train, X_test = X[:split], X[split:]
y_train, y_test = y[:split], y[split:]

print(f"Train: {len(X_train)}, Test: {len(X_test)}")

# Normalize features
scaler = MinMaxScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

print("\n" + "=" * 60)
print("MODEL 1: RANDOM FOREST")
print("=" * 60)

rf = RandomForestRegressor(
    n_estimators=200,
    max_depth=15,
    min_samples_split=5,
    min_samples_leaf=2,
    random_state=42,
    n_jobs=-1
)
rf.fit(X_train_scaled, y_train)

y_test_pred_rf = rf.predict(X_test_scaled)
mape_rf = mean_absolute_percentage_error(y_test, y_test_pred_rf)
mae_rf = mean_absolute_error(y_test, y_test_pred_rf)
acc_rf = max(0, 100 * (1 - mape_rf)) if mape_rf < 1 else 0

print(f"MAE:  {mae_rf:.2f}")
print(f"MAPE: {mape_rf*100:.2f}%")
print(f"Accuracy: {acc_rf:.2f}%")

print("\n" + "=" * 60)
print("MODEL 2: GRADIENT BOOSTING")
print("=" * 60)

gb = GradientBoostingRegressor(
    n_estimators=200,
    learning_rate=0.1,
    max_depth=5,
    min_samples_split=5,
    min_samples_leaf=2,
    subsample=0.8,
    random_state=42
)
gb.fit(X_train_scaled, y_train)

y_test_pred_gb = gb.predict(X_test_scaled)
mape_gb = mean_absolute_percentage_error(y_test, y_test_pred_gb)
mae_gb = mean_absolute_error(y_test, y_test_pred_gb)
acc_gb = max(0, 100 * (1 - mape_gb)) if mape_gb < 1 else 0

print(f"MAE:  {mae_gb:.2f}")
print(f"MAPE: {mape_gb*100:.2f}%")
print(f"Accuracy: {acc_gb:.2f}%")

print("\n" + "=" * 60)
print("MODEL 3: ENSEMBLE (AVERAGE)")
print("=" * 60)

y_test_pred_ensemble = (y_test_pred_rf + y_test_pred_gb) / 2
mape_ens = mean_absolute_percentage_error(y_test, y_test_pred_ensemble)
mae_ens = mean_absolute_error(y_test, y_test_pred_ensemble)
acc_ens = max(0, 100 * (1 - mape_ens)) if mape_ens < 1 else 0

print(f"MAE:  {mae_ens:.2f}")
print(f"MAPE: {mape_ens*100:.2f}%")
print(f"Accuracy: {acc_ens:.2f}%")

# Summary
print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
models = [
    ("Random Forest", acc_rf),
    ("Gradient Boosting", acc_gb),
    ("Ensemble", acc_ens)
]
models.sort(key=lambda x: -x[1])

for name, acc in models:
    status = "✓ BEST" if acc == max([m[1] for m in models]) else ""
    print(f"{name:20s}: {acc:6.2f}%  {status}")

best_acc = models[0][1]
gap = 80 - best_acc

if best_acc >= 80:
    print(f"\n*** SUCCESS! {models[0][0]} achieved {best_acc:.2f}% accuracy!")
else:
    print(f"\nGap from 80% target: {gap:.1f}%")
    
    if gap > 50:
        print("\nAnalysis: Data is too noisy/random for reliable prediction.")
        print("This is NOT a model issue - it's a DATA QUALITY issue.")
    else:
        print(f"The model is {best_acc:.1f}% of the way there.")

# Data analysis
print("\n" + "=" * 60)
print("DATA QUALITY ANALYSIS")
print("=" * 60)

from scipy import stats

# Check randomness
values_diff = np.diff(values)
autocorr_lag1 = np.corrcoef(values[:-1], values[1:])[0, 1]
print(f"Auto-correlation (lag-1): {autocorr_lag1:.4f}")

if autocorr_lag1 < 0.3:
    print("  -> Very low! Data appears nearly random")
else:
    print("  -> Good, some temporal structure exists")

# Check distribution
cv = values.std() / values.mean()
print(f"Coefficient of Variation: {cv:.2f}")
if cv > 1.0:
    print("  -> Very high variance relative to mean")
    print("  -> Hard to predict with high accuracy")

# Check for patterns
print(f"\nValue stats:")
print(f"  Min: {values.min():.2f}")
print(f"  Max: {values.max():.2f}")
print(f"  Mean: {values.mean():.2f}")
print(f"  Std: {values.std():.2f}")
print(f"  Zeros/near-zero (< 10): {(values < 10).sum()}")

# Try simplified models for comparison
print("\n" + "=" * 60)
print("SIMPLIFIED BASELINE MODELS")
print("=" * 60)

# Naive forecast (last value)
y_naive = y_test[:-1] if len(y_test) > 1 else y_test
y_actual_naive = y_test[1:] if len(y_test) > 1 else y_test
if len(y_naive) > 0:
    mape_naive = mean_absolute_percentage_error(y_actual_naive, y_naive)
    acc_naive = max(0, 100 * (1 - mape_naive)) if mape_naive < 1 else 0
    print(f"Naive (last value):    {acc_naive:.2f}%")

# Mean forecast
y_mean = np.full_like(y_test, y_train.mean())
mape_mean = mean_absolute_percentage_error(y_test, y_mean)
acc_mean = max(0, 100 * (1 - mape_mean)) if mape_mean < 1 else 0
print(f"Mean (average):        {acc_mean:.2f}%")

# Median forecast
y_median = np.full_like(y_test, np.median(y_train))
mape_median = mean_absolute_percentage_error(y_test, y_median)
acc_median = max(0, 100 * (1 - mape_median)) if mape_median < 1 else 0
print(f"Median:                {acc_median:.2f}%")

# Check improvement over baseline
if best_acc > max(acc_naive, acc_mean, acc_median):
    improvement = best_acc - max(acc_naive, acc_mean, acc_median)
    print(f"\nImprovement over baseline: {improvement:.2f}%")
else:
    print("\nWARNING: Models not better than baseline forecasts!")
    print("This indicates fundamental data quality/predictability issues")
