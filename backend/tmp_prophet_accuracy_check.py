import os
import json
import numpy as np
import pandas as pd
import joblib
from sqlalchemy import create_engine, text

MODEL_PATH = os.environ.get('MODEL_PATH', 'backend/models/prophet_model.joblib')
DB_URL = os.environ.get('DB_URL', 'postgresql://postgres:admin@localhost:5432/energia')

model = joblib.load(MODEL_PATH)

source = None
df = None

# 1) DB source used by serving backend
try:
    engine = create_engine(DB_URL)
    q = text('''
        SELECT ds, value AS y
        FROM sensor_data
        WHERE ds IS NOT NULL
        ORDER BY ds DESC
        LIMIT 2000
    ''')
    with engine.connect() as conn:
        temp = pd.read_sql(q, conn)
    if temp is not None and not temp.empty:
        df = temp
        source = 'sensor_data'
except Exception:
    pass

# 2) Fallback local preprocessed file
if df is None or df.empty:
    path = 'backend/preprocessed_energy_data.csv'
    if os.path.exists(path):
        temp = pd.read_csv(path)
        if 'ds' in temp.columns:
            if 'y' in temp.columns:
                df = temp[['ds','y']].copy()
                source = 'preprocessed_energy_data.csv:y'
            elif 'value' in temp.columns:
                df = temp[['ds','value']].rename(columns={'value':'y'})
                source = 'preprocessed_energy_data.csv:value'
            elif 'power' in temp.columns:
                df = temp[['ds','power']].rename(columns={'power':'y'})
                source = 'preprocessed_energy_data.csv:power'

if df is None or df.empty:
    print(json.dumps({'status':'failed','error':'No usable data source found'}))
    raise SystemExit(1)

# Clean like serving pipeline

df['ds'] = pd.to_datetime(df['ds'], errors='coerce')
df['y'] = pd.to_numeric(df['y'], errors='coerce')
df = df.dropna(subset=['ds','y']).sort_values('ds').reset_index(drop=True)

df = df.set_index('ds').resample('1min').mean()
df['y'] = df['y'].interpolate(method='time', limit=5)
df = df.reset_index().dropna(subset=['y'])
df['y'] = df['y'].clip(lower=0)

if len(df) < 30:
    print(json.dumps({'status':'failed','error':f'Not enough rows after cleaning: {len(df)}','source':source}))
    raise SystemExit(1)

window = min(180, max(30, len(df)//5))
test_df = df.tail(window).copy()

pred_df = model.predict(test_df[['ds']])[['yhat','yhat_lower','yhat_upper']]
actual = test_df['y'].to_numpy()
pred = np.clip(pred_df['yhat'].to_numpy(), 0, None)
lower = np.clip(pred_df['yhat_lower'].to_numpy(), 0, None)
upper = np.clip(pred_df['yhat_upper'].to_numpy(), 0, None)

abs_err = np.abs(actual - pred)
mae = float(np.mean(abs_err))
rmse = float(np.sqrt(np.mean(np.square(abs_err))))
denom = np.maximum(np.abs(actual), 10.0)
mape = float(np.mean(abs_err / denom) * 100.0)
smape = float(np.mean(2 * abs_err / (np.abs(actual) + np.abs(pred) + 1e-6)) * 100.0)
r2 = float(1 - (np.sum((actual - pred) ** 2) / (np.sum((actual - np.mean(actual)) ** 2) + 1e-6)))
coverage = float(np.mean((actual >= lower) & (actual <= upper)))
accuracy = float(max(0.0, 100.0 - mape))

print(json.dumps({
    'status': 'ok',
    'source': source,
    'points': int(len(test_df)),
    'window_start': str(test_df['ds'].iloc[0]),
    'window_end': str(test_df['ds'].iloc[-1]),
    'accuracy_percent': round(accuracy, 2),
    'mape_percent': round(mape, 2),
    'mae': round(mae, 4),
    'rmse': round(rmse, 4),
    'smape_percent': round(smape, 2),
    'r2_score': round(r2, 4),
    'coverage_80_interval': round(coverage, 4)
}, indent=2))
