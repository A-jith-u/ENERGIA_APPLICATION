import pandas as pd
import numpy as np
import joblib
import os
from sklearn.ensemble import IsolationForest

# ==========================================================
# 1. CONFIGURATION & PATHS
# ==========================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Preprocessed data is kept in a dedicated training dataset folder.
BACKEND_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
DATA_PATH = os.path.join(BACKEND_DIR, "datasets", "preprocessed_energy_data.csv")
LEGACY_DATA_PATH = os.path.join(BACKEND_DIR, "preprocessed_energy_data.csv")
# Models folder
SAVE_DIR = os.path.join(SCRIPT_DIR, "..", "models")

def run_anomaly_pipeline():
    # ==========================================================
    # 2. LOAD PREPROCESSED DATA
    # ==========================================================
    data_path = DATA_PATH if os.path.exists(DATA_PATH) else LEGACY_DATA_PATH
    print(f"Loading preprocessed data from: {data_path}")
    if not os.path.exists(data_path):
        print("❌ Error: Preprocessed CSV not found. Run preprocess_data.py first.")
        return
        
    df = pd.read_csv(data_path)
    
    if len(df) < 10:
        print("⚠️ Warning: Not enough data points to train a reliable model.")
        return

    # ==========================================================
    # 3. SELECT FEATURES
    # ==========================================================
    # Since preprocessing already created these, we just define the list
    features = [
        'power', 'current', 'power_factor', 'power_change_rate', 
        'rolling_avg_power', 'rolling_std_power', 'is_holiday', 'occupancy'
    ]
    
    # Ensure no missing values interfere with training
    df_train = df.dropna(subset=features).copy()

    # ==========================================================
    # 4. TRAIN MODEL (Isolation Forest)
    # ==========================================================
    print(f"Training on {len(df_train)} records...")
    # contamination=0.02 means we expect roughly 2% of data to be anomalies
    model = IsolationForest(n_estimators=100, contamination=0.02, random_state=42)
    
    # Fit the model
    model.fit(df_train[features])
    
    # Optional: Test a prediction
    df_train['is_anomaly'] = model.predict(df_train[features]) # 1 normal, -1 anomaly

    # ==========================================================
    # 5. SAVE MODEL & FEATURE LIST
    # ==========================================================
    os.makedirs(SAVE_DIR, exist_ok=True)
    joblib.dump(model, os.path.join(SAVE_DIR, 'isolation_forest_model.pkl'))
    joblib.dump(features, os.path.join(SAVE_DIR, 'model_features.pkl'))
    
    print(f"✅ Success! AI Model saved in: {os.path.abspath(SAVE_DIR)}")
    print(f"Features used for training: {features}")

if __name__ == "__main__":
    run_anomaly_pipeline()