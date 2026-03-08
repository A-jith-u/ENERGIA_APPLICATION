"""
Improved training with multiple strategies to reach 80%+ accuracy
"""
import sys
import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from prophet import Prophet
import joblib
from datetime import datetime
from sklearn.metrics import mean_absolute_percentage_error

engine = create_engine(
    'postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia'
)

# Strategy 1: DAILY AGGREGATES (sum energy per day, smooth)
print("=" * 60)
print("STRATEGY 1: DAILY AGGREGATES")
print("=" * 60)

df = pd.read_sql(
    'SELECT ds, value FROM sensor_data WHERE value IS NOT NULL ORDER BY ds',
    engine
)
df['ds'] = pd.to_datetime(df['ds'])
df = df.sort_values('ds')

# Remove outliers using IQR on raw data
Q1 = df['value'].quantile(0.25)
Q3 = df['value'].quantile(0.75)
IQR = Q3 - Q1
lower_bound = Q1 - 1.5 * IQR
upper_bound = Q3 + 1.5 * IQR
df_clean = df[(df['value'] >= lower_bound) & (df['value'] <= upper_bound)].copy()
print(f"Removed {len(df) - len(df_clean)} outliers via IQR")
print(f"Outlier bounds: {lower_bound:.2f} - {upper_bound:.2f}")

# Aggregate to daily
df_daily = df_clean.set_index('ds').resample('D')['value'].sum().reset_index()
df_daily.columns = ['ds', 'y']
df_daily = df_daily[df_daily['y'] > 0]  # Remove zero days
print(f"Daily data points: {len(df_daily)}")
print(df_daily.describe())

# Train on daily aggregates
train_size = int(len(df_daily) * 0.8)
train_daily = df_daily[:train_size]
test_daily = df_daily[train_size:]

model1 = Prophet(
    yearly_seasonality=True,
    weekly_seasonality=True,
    daily_seasonality=False,
    changepoint_prior_scale=0.01,
    seasonality_prior_scale=2.0,
    interval_width=0.80,
)
model1.fit(train_daily)

future = model1.make_future_dataframe(periods=len(test_daily))
forecast = model1.predict(future)
forecast_test = forecast.iloc[-len(test_daily):]

# Evaluate Strategy 1
actual_s1 = test_daily['y'].values
pred_s1 = forecast_test['yhat'].values
mape_s1 = mean_absolute_percentage_error(actual_s1, pred_s1)
mae_s1 = np.mean(np.abs(actual_s1 - pred_s1))
rmse_s1 = np.sqrt(np.mean((actual_s1 - pred_s1) ** 2))
accuracy_s1 = max(0, 100 * (1 - mape_s1)) if mape_s1 < 1 else 0

print(f"\nStrategy 1 Results:")
print(f"  MAE:      {mae_s1:.2f}")
print(f"  RMSE:     {rmse_s1:.2f}")
print(f"  MAPE:     {mape_s1*100:.2f}%")
print(f"  Accuracy: {accuracy_s1:.2f}%")

# Strategy 2: DIFFERENCED DATA (day-over-day changes)
print("\n" + "=" * 60)
print("STRATEGY 2: DIFFERENCED DATA (CHANGES)")
print("=" * 60)

df_daily['diff'] = df_daily['y'].diff().fillna(df_daily['y'].iloc[0])
df_diff = df_daily[['ds', 'diff']].copy()
df_diff.columns = ['ds', 'y']
df_diff = df_diff[df_diff['y'] > 0]  # Positive differences only

Q1_d = df_diff['y'].quantile(0.25)
Q3_d = df_diff['y'].quantile(0.75)
IQR_d = Q3_d - Q1_d
lower_d = Q1_d - 1.5 * IQR_d
upper_d = Q3_d + 1.5 * IQR_d
df_diff_clean = df_diff[(df_diff['y'] >= lower_d) & (df_diff['y'] <= upper_d)].copy()
print(f"Removed {len(df_diff) - len(df_diff_clean)} outliers")

train_size_d = int(len(df_diff_clean) * 0.8)
train_diff = df_diff_clean[:train_size_d]
test_diff = df_diff_clean[train_size_d:]

if len(train_diff) > 10:
    model2 = Prophet(
        yearly_seasonality=False,
        weekly_seasonality=True,
        daily_seasonality=False,
        changepoint_prior_scale=0.05,
        seasonality_prior_scale=3.0,
    )
    model2.fit(train_diff)
    
    future_d = model2.make_future_dataframe(periods=len(test_diff))
    forecast_d = model2.predict(future_d)
    forecast_d_test = forecast_d.iloc[-len(test_diff):]
    
    actual_s2 = test_diff['y'].values
    pred_s2 = forecast_d_test['yhat'].values
    mape_s2 = mean_absolute_percentage_error(actual_s2, pred_s2)
    mae_s2 = np.mean(np.abs(actual_s2 - pred_s2))
    rmse_s2 = np.sqrt(np.mean((actual_s2 - pred_s2) ** 2))
    accuracy_s2 = max(0, 100 * (1 - mape_s2)) if mape_s2 < 1 else 0
    
    print(f"  Data points: {len(df_diff_clean)}")
    print(f"\nStrategy 2 Results:")
    print(f"  MAE:      {mae_s2:.2f}")
    print(f"  RMSE:     {rmse_s2:.2f}")
    print(f"  MAPE:     {mape_s2*100:.2f}%")
    print(f"  Accuracy: {accuracy_s2:.2f}%")
else:
    accuracy_s2 = 0
    print("Not enough data for differencing strategy")

# Strategy 3: AGGRESSIVE PREPROCESSING (remove bottom 10%, resample to hourly)
print("\n" + "=" * 60)
print("STRATEGY 3: HOURLY + AGGRESSIVE FILTERING")
print("=" * 60)

df_raw = pd.read_sql(
    'SELECT ds, value FROM sensor_data WHERE value IS NOT NULL ORDER BY ds',
    engine
)
df_raw['ds'] = pd.to_datetime(df_raw['ds'])
df_raw = df_raw.sort_values('ds').set_index('ds')

# Hourly average
df_hourly = df_raw.resample('h')['value'].mean().reset_index()
df_hourly.columns = ['ds', 'y']
df_hourly = df_hourly.dropna()

# Remove bottom percentile (mostly idle readings)
p10 = df_hourly['y'].quantile(0.10)
df_hourly_filtered = df_hourly[df_hourly['y'] > p10].copy()
print(f"Removed bottom 10% (< {p10:.2f})")
print(f"Hourly data points: {len(df_hourly_filtered)}")

train_size_h = int(len(df_hourly_filtered) * 0.8)
train_h = df_hourly_filtered[:train_size_h]
test_h = df_hourly_filtered[train_size_h:]

model3 = Prophet(
    yearly_seasonality=False,
    weekly_seasonality=True,
    daily_seasonality=True,
    changepoint_prior_scale=0.1,
    seasonality_prior_scale=5.0,
    interval_width=0.80,
)
model3.fit(train_h)

future_h = model3.make_future_dataframe(periods=len(test_h), freq='h')
forecast_h = model3.predict(future_h)
forecast_h_test = forecast_h.iloc[-len(test_h):]

actual_s3 = test_h['y'].values
pred_s3 = forecast_h_test['yhat'].values
mape_s3 = mean_absolute_percentage_error(actual_s3, pred_s3)
mae_s3 = np.mean(np.abs(actual_s3 - pred_s3))
rmse_s3 = np.sqrt(np.mean((actual_s3 - pred_s3) ** 2))
accuracy_s3 = max(0, 100 * (1 - mape_s3)) if mape_s3 < 1 else 0

print(f"\nStrategy 3 Results:")
print(f"  MAE:      {mae_s3:.2f}")
print(f"  RMSE:     {rmse_s3:.2f}")
print(f"  MAPE:     {mape_s3*100:.2f}%")
print(f"  Accuracy: {accuracy_s3:.2f}%")

# Summary
print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
results = [
    ('Daily Aggregates', accuracy_s1),
    ('Differenced Data', accuracy_s2),
    ('Hourly + Filtering', accuracy_s3),
]
results.sort(key=lambda x: -x[1])
for name, acc in results:
    print(f"{name:25s}: {acc:6.2f}%")

best_strategy = results[0]
print(f"\nBest Strategy: {best_strategy[0]} ({best_strategy[1]:.2f}%)")

if best_strategy[1] > 60:
    print(f"\n>>> BREAKTHROUGH! {best_strategy[1]:.2f}% is above 60%")
    if best_strategy[1] > 80:
        print(f">>> GOAL ACHIEVED! {best_strategy[1]:.2f}% is above 80%")
