import pandas as pd
import holidays
import sys
from sqlalchemy import create_engine
from sklearn.ensemble import IsolationForest

# 1. SETTINGS
DB_URL = 'postgresql://postgres:aswathy2004@localhost:5432/energia'
country_holidays = holidays.India()

def detect_anomalies(user_threshold=None):
    try:
        engine = create_engine(DB_URL)
        df = pd.read_sql('SELECT * FROM sensor', engine)
        df['ds'] = pd.to_datetime(df['ds'])

        # FIX: Correctly indented block
        if user_threshold:
            high_usage_threshold = float(user_threshold)
        else:
            high_usage_threshold = df['power'].quantile(0.90)

        # 2. FEATURE ENGINEERING
        df['occupancy'] = (df['current'] > 0.1).astype(int)
        df['is_holiday'] = df['ds'].apply(lambda x: 1 if (x in country_holidays or x.weekday() >= 5) else 0)

        # 3. DEFINE ANOMALY RULES
        df['rule_anomaly'] = 0
        df.loc[(df['power'] > high_usage_threshold) & (df['occupancy'] == 0), 'rule_anomaly'] = 1
        df.loc[(df['power'] > high_usage_threshold) & (df['is_holiday'] == 1), 'rule_anomaly'] = 1

        # 4. ISOLATION FOREST (ML)
        features = ['power', 'voltage', 'current']
        model = IsolationForest(contamination=0.05, random_state=42)
        df['ml_anomaly_score'] = model.fit_predict(df[features])
        df['is_anomaly'] = (df['ml_anomaly_score'] == -1).astype(int)

        # 5. UPLOAD UPDATED TABLE
        df.to_sql('sensor', engine, if_exists='replace', index=False)
        print(f"Success: Analysis complete using threshold {high_usage_threshold}W")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    # This allows your dashboard to send a value like: python detect_anomalies.py 500
    threshold_input = sys.argv[1] if len(sys.argv) > 1 else None
    detect_anomalies(threshold_input)