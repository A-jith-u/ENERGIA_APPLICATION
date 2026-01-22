"""
Application entrypoint that mounts auth and model APIs into a single FastAPI app.
This allows the Docker image to expose a single HTTP service for auth, model, and health checks.
"""
import importlib
import os
import sys
import joblib
import pandas as pd
from fastapi import FastAPI
from datetime import datetime

# ==========================================================
# 1. AI MODEL LOADING LOGIC
# ==========================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) 
# Path logic: Go up one level (..) to Energia_Application, then into /models
MODEL_PATH = os.path.join(BASE_DIR, "..", "models", "isolation_forest_model.pkl")
FEATURES_PATH = os.path.join(BASE_DIR, "..", "models", "model_features.pkl")

# Global variables for the model
model = None
model_features = None
# ==========================================================
# 2.5 AUTO-PREPROCESSING LOGIC
# ==========================================================
try:
    # Assuming your preprocessing script is in the same directory and named preprocess_data.py
    # If it has a different name, change 'preprocess_data' below
    from ml_scripts import preprocess 
    print("🔄 Running automated data preprocessing...")
    preprocess.run_preprocessing()
    print("✅ Preprocessed CSV is now up-to-date.")
except Exception as e:
    print(f"⚠️ Preprocessing skipped or failed: {e}")
try:
    if os.path.exists(MODEL_PATH):
        model = joblib.load(MODEL_PATH)
        model_features = joblib.load(FEATURES_PATH)
        print("✅ Anomaly Detection Model Loaded Successfully")
    else:
        print(f"⚠️ Warning: Model file not found at {MODEL_PATH}")
except Exception as e:
    print(f"❌ Error loading AI model: {e}")

# ==========================================================
# 2. MODULE LOADING UTILITY
# ==========================================================
def _load(name: str):
    """Import backend modules whether run as package or as a bare module."""
    if __package__:
        return importlib.import_module(f".{name}", __package__)
    sys.path.append(os.path.dirname(__file__))
    return importlib.import_module(name)

# Import existing API modules
auth_api = _load("auth_api")
notify_api = _load("notify_api")
recommendation_api = _load("recommendation_api")
activity_log_api = _load("activity_log_api")
monthly_report_api = _load("monthly_report_api")

try:
    serve_prophet = _load("serve_prophet")
    _model_app = serve_prophet.app
except Exception as _err:
    _model_app = None

# ==========================================================
# 3. APP INITIALIZATION & NEW ROUTES
# ==========================================================
app = FastAPI(title="ENERGIA Backend")

@app.get("/health")
async def health_check():
    return {"status": "healthy", "ai_model_loaded": model is not None}


# --- NEW: Real-time Anomaly Detection Route ---
@app.post("/api/detect-anomaly")
async def detect_anomaly(payload: dict):
    """
    Receives PZEM data and returns anomaly status.
    Expected: power, current, power_factor, occupancy, device_id
    """
    if model is None or model_features is None:
        return {"error": "AI Model not initialized on server"}

    try:
        # 1. Prepare Features (Order must match model_features.pkl)
        # Using current timestamp for holiday check
        is_holiday = 1 if datetime.now().weekday() >= 5 else 0
        
        # Simplified context for real-time (In prod, fetch last 4 readings for rolling stats)
        input_data = {
            'power': payload.get('power', 0),
            'current': payload.get('current', 0),
            'power_factor': payload.get('power_factor', 0),
            'power_change_rate': 0, # Placeholder for single reading
            'rolling_avg_power': payload.get('power', 0), 
            'rolling_std_power': 0,
            'is_holiday': is_holiday,
            'occupancy': payload.get('occupancy', 0)
        }
        
        input_df = pd.DataFrame([input_data])[model_features]

        # 2. Predict
        prediction = model.predict(input_df)[0] # 1 = Normal, -1 = Anomaly
        score = model.decision_function(input_df)[0]

        return {
            "is_anomaly": bool(prediction == -1),
            "anomaly_score": round(score, 4),
            "status": "Anomaly Detected" if prediction == -1 else "Normal"
        }
    except Exception as e:
        return {"error": str(e)}


# ==========================================================
# 4. MOUNTING SUB-APPS
# ==========================================================
app.mount("/auth", auth_api.app)
app.mount("/api/auth", auth_api.app)
app.mount("/api", auth_api.app) # This makes /api/sensor-data work
app.mount("/auth", auth_api.app) # This keeps your login/register working
app.mount("/notify", notify_api.app)
app.mount("/recommendations", recommendation_api.app)
app.mount("/activity", activity_log_api.app)
app.mount("/report", monthly_report_api.app)

if _model_app:
    app.mount("/model", _model_app)