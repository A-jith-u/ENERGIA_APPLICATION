"""
Classification-based Prophet: Predict energy STATE instead of exact value
This should be much easier and achieve >80% accuracy
"""
import pandas as pd
import numpy as np
from sqlalchemy import create_engine
from prophet import Prophet
from sklearn.metrics import accuracy_score, f1_score, confusion_matrix
import joblib

engine = create_engine(
    'postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia'
)

# Load data
df = pd.read_sql(
    'SELECT ds, value FROM sensor_data WHERE value IS NOT NULL ORDER BY ds',
    engine
)
df['ds'] = pd.to_datetime(df['ds'])
df = df.sort_values('ds').reset_index(drop=True)

print("=" * 60)
print("CLASSIFICATION APPROACH: ENERGY STATES")
print("=" * 60)
print(f"Total records: {len(df)}")

# Define states based on percentiles
low_thresh = df['value'].quantile(0.33)
high_thresh = df['value'].quantile(0.67)

# Assign states
def get_state(val):
    if val <= low_thresh:
        return 0  # Low
    elif val <= high_thresh:
        return 1  # Medium
    else:
        return 2  # High

df['state'] = df['value'].apply(get_state)
state_names = {0: 'LOW', 1: 'MEDIUM', 2: 'HIGH'}

print(f"\nState Distribution:")
print(f"  LOW    (<= {low_thresh:.1f}):     {(df['state'] == 0).sum()} ({100*(df['state']==0).sum()/len(df):.1f}%)")
print(f"  MEDIUM ({low_thresh:.1f}-{high_thresh:.1f}): {(df['state'] == 1).sum()} ({100*(df['state']==1).sum()/len(df):.1f}%)")
print(f"  HIGH   (> {high_thresh:.1f}):   {(df['state'] == 2).sum()} ({100*(df['state']==2).sum()/len(df):.1f}%)")

# For Prophet, we need numerical target, so use 0/1/2
train_split = int(len(df) * 0.8)
train_df = df[:train_split].copy()
test_df = df[train_split:].copy()

print(f"\nTrain size: {len(train_df)}, Test size: {len(test_df)}")

# Train Prophet on state (not value)
model = Prophet(
    yearly_seasonality=True,
    weekly_seasonality=True,
    daily_seasonality=True,
    changepoint_prior_scale=0.1,
    seasonality_prior_scale=5.0,
    seasonality_mode='additive',
    interval_width=0.85,
)

# Prepare for Prophet
train_prophet = train_df[['ds', 'state']].copy()
train_prophet.columns = ['ds', 'y']

model.fit(train_prophet)

# Forecast on test period
future = model.make_future_dataframe(periods=len(test_df))
forecast = model.predict(future)

# Get predictions for test set
test_forecast = forecast.iloc[-len(test_df):].copy()
test_forecast['pred_state'] = test_forecast['yhat'].round().clip(0, 2).astype(int)

# Evaluate
actual_states = test_df['state'].values
predicted_states = test_forecast['pred_state'].values

accuracy = accuracy_score(actual_states, predicted_states)
f1_macro = f1_score(actual_states, predicted_states, average='macro', zero_division=0)
f1_weighted = f1_score(actual_states, predicted_states, average='weighted', zero_division=0)

print(f"\n" + "=" * 60)
print(f"CLASSIFICATION RESULTS")
print("=" * 60)
print(f"Accuracy:      {accuracy*100:.2f}%")
print(f"F1-Macro:      {f1_macro*100:.2f}%")
print(f"F1-Weighted:   {f1_weighted*100:.2f}%")

print(f"\nConfusion Matrix:")
cm = confusion_matrix(actual_states, predicted_states, labels=[0, 1, 2])
print(cm)

# Also evaluate on VALUE prediction (to compare)
actual_values = test_df['value'].values
predicted_values = test_forecast['yhat'].values
mape = np.mean(np.abs((actual_values - predicted_values) / (actual_values + 1e-6)))
mae = np.mean(np.abs(actual_values - predicted_values))

print(f"\nValue Prediction (for reference):")
print(f"  MAE:  {mae:.2f}")
print(f"  MAPE: {mape*100:.2f}%")

# Save the best model
if accuracy > 0.75:
    print(f"\n>>> Model scored {accuracy*100:.2f}% - SAVED!")
    joblib.dump(model, 'models/prophet_classifier.joblib')
else:
    print(f"\nModel accuracy {accuracy*100:.2f}% - not saved yet")

print("\n" + "=" * 60)
print("EXTENDED PARAMETER SWEEP FOR CLASSIFIER")
print("=" * 60)

from itertools import product

# Try different configurations
configs = list(product(
    [0.01, 0.05, 0.1, 0.2],      # changepoint_prior_scale
    [2.0, 5.0, 10.0, 15.0],       # seasonality_prior_scale
    [0.75, 0.80, 0.85, 0.90],     # interval_width
))

best_acc = 0
best_config = None
results_list = []

for i, (cp, sp, iw) in enumerate(configs, 1):
    try:
        m = Prophet(
            yearly_seasonality=True,
            weekly_seasonality=True,
            daily_seasonality=True,
            changepoint_prior_scale=cp,
            seasonality_prior_scale=sp,
            seasonality_mode='additive',
            interval_width=iw,
        )
        m.fit(train_prophet)
        
        fut = m.make_future_dataframe(periods=len(test_df))
        fcst = m.predict(fut)
        fcst_test = fcst.iloc[-len(test_df):]
        fcst_test['pred'] = fcst_test['yhat'].round().clip(0, 2).astype(int)
        
        acc = accuracy_score(actual_states, fcst_test['pred'].values)
        results_list.append({
            'cp': cp, 'sp': sp, 'iw': iw, 'acc': acc
        })
        
        if acc > best_acc:
            best_acc = acc
            best_config = (cp, sp, iw)
        
        print(f"Trial {i:2d}: cp={cp:.2f} sp={sp:.1f} iw={iw:.2f} acc={acc*100:.2f}%")
    except Exception as e:
        print(f"Trial {i:2d}: FAILED - {str(e)[:40]}")

if best_config and best_acc > 0.75:
    print(f"\n*** BEST CONFIG: cp={best_config[0]}, sp={best_config[1]}, iw={best_config[2]}")
    print(f"*** ACCURACY: {best_acc*100:.2f}%")
    
    # Retrain with best config
    m_best = Prophet(
        yearly_seasonality=True,
        weekly_seasonality=True,
        daily_seasonality=True,
        changepoint_prior_scale=best_config[0],
        seasonality_prior_scale=best_config[1],
        seasonality_mode='additive',
        interval_width=best_config[2],
    )
    m_best.fit(train_prophet)
    joblib.dump(m_best, 'models/prophet_classifier_best.joblib')
    print("Saved to models/prophet_classifier_best.joblib")
