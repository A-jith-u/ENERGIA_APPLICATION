import importlib
import os
import sys
import joblib
import pandas as pd
import numpy as np
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timezone
from sqlalchemy import text, create_engine
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv(override=False)

def _load_sibling_module(name: str):
    """
    Load a sibling module by filename, working in both contexts:
      - Package:  backend.app_main  (uvicorn backend.app_main:app)
      - Script:   python app_main.py
    Always does a direct file import so __init__.py is never involved.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    filepath = os.path.join(here, name + ".py")
    spec = importlib.util.spec_from_file_location(name, filepath)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod          # register so relative imports inside the module work
    spec.loader.exec_module(mod)
    return mod


# --- DATABASE SETUP ---
def _load_cfg():
    """Load config module handling both package and script execution."""
    if __package__:
        from . import config
        return config
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        return importlib.import_module("config")

cfg = _load_cfg()
DATABASE_URL = cfg.get_db_url()
engine = create_engine(DATABASE_URL)

# --- 1. AI MODEL LOADING ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__)) 
MODEL_PATH = os.path.join(BASE_DIR, "models", "isolation_forest_model.pkl")
FEATURES_PATH = os.path.join(BASE_DIR, "models", "model_features.pkl")

model = None
model_features = None

try:
    if os.path.exists(MODEL_PATH):
        model = joblib.load(MODEL_PATH)
        model_features = joblib.load(FEATURES_PATH)
        print("✅ Anomaly Detection Model Loaded Successfully")
except Exception as e:
    print(f"❌ Error loading AI model: {e}")

# --- 2. AUTO-PREPROCESSING ---
try:
    from ml_scripts import preprocess 
    preprocess.run_preprocessing()
    print("✅ Preprocessed CSV updated on startup.")
except Exception as e:
    print(f"⚠️ Preprocessing skipped: {e}")

app = FastAPI(title="ENERGIA Backend")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- 4. MOUNT REMAINING APPS ---
# Import auth_api module handling both package and script execution
def _load_auth_api():
    if __package__:
        from . import auth_api
        return auth_api
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("auth_api")

auth_api_module = _load_auth_api()
# Include routes without prefix (for Flutter app - /dashboard/overview, /login, etc.)
app.include_router(auth_api_module.app.router)
# Also include sensor-data routes with /api prefix (for ESP32 - /api/sensor-data)
app.include_router(auth_api_module.app.router, prefix="/api", tags=["ESP32 API"])

# Import activity_log_api module
def _load_activity_log_api():
    if __package__:
        from . import activity_log_api
        return activity_log_api
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("activity_log_api")

activity_log_api_module = _load_activity_log_api()
app.include_router(activity_log_api_module.app.router, prefix="/activity", tags=["Activity Logs"])

# Import recommendation_api module
def _load_recommendation_api():
    if __package__:
        from . import recommendation_api
        return recommendation_api
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("recommendation_api")

recommendation_api_module = _load_recommendation_api()
app.include_router(recommendation_api_module.app.router, prefix="/recommendations", tags=["Recommendations"])

# Import monthly_report_api module
def _load_monthly_report_api():
    if __package__:
        from . import monthly_report_api
        return monthly_report_api
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("monthly_report_api")

monthly_report_api_module = _load_monthly_report_api()
app.include_router(monthly_report_api_module.app.router, prefix="/reports", tags=["Reports"])

# Import notify_api module
try:
    notify_api_module = _load_sibling_module("notify_api")
    app.include_router(notify_api_module.app.router, prefix="/notify", tags=["Notifications"])
    print("[app_main] notify_api mounted at /notify ✅")
except Exception as _e:
    notify_api_module = None
    print(f"[app_main] notify_api not available: {_e}")
# Import sergeant_api module
def _load_sergeant_api():
    if __package__:
        from . import sergeant_api
        return sergeant_api
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("sergeant_api")

sergeant_api_module = _load_sergeant_api()
app.include_router(sergeant_api_module.app.router, prefix="/sergeant", tags=["Sergeant Management"])

# Import relay_control_api module
def _load_relay_control_api():
    if __package__:
        from . import relay_control_api
        return relay_control_api
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("relay_control_api")

relay_control_api_module = _load_relay_control_api()
app.include_router(relay_control_api_module.app.router, prefix="/relay", tags=["Relay Control"])
# Also include relay control routes with /api prefix (for ESP32 polling)
app.include_router(relay_control_api_module.app.router, prefix="/api/relay", tags=["ESP32 Relay Control"])

# Import anomaly_alert_service module
try:
    anomaly_alert_service_module = _load_sibling_module("anomaly_alert_service")
    app.include_router(anomaly_alert_service_module.app.router, prefix="/anomaly-alerts", tags=["Anomaly Alerts"])
    print("[app_main] anomaly_alert_service mounted at /anomaly-alerts ✅")
except Exception as _e:
    anomaly_alert_service_module = None
    print(f"[app_main] anomaly_alert_service not available: {_e}")


# Import mixed ensemble model service first; fall back to Prophet if unavailable.
def _load_serve_ensemble_90_mixed():
    if __package__:
        from . import serve_ensemble_90_mixed
        return serve_ensemble_90_mixed
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("serve_ensemble_90_mixed")


def _load_serve_prophet():
    if __package__:
        from . import serve_prophet
        return serve_prophet
    else:
        sys.path.append(os.path.dirname(__file__))
        return importlib.import_module("serve_prophet")


try:
    serve_mixed_module = _load_serve_ensemble_90_mixed()
    app.include_router(serve_mixed_module.app.router, prefix="/model", tags=["Predictions"])
    print("Mixed ensemble model serving API mounted at /model")
except Exception as mixed_error:
    print(f"Warning: Could not load mixed ensemble model serving API: {mixed_error}")
    try:
        serve_prophet_module = _load_serve_prophet()
        app.include_router(serve_prophet_module.app.router, prefix="/model", tags=["Predictions"])
        print("Prophet model serving API mounted at /model (fallback)")
    except Exception as prophet_error:
        print(f"Warning: Could not load Prophet model serving API fallback: {prophet_error}")

# --- START SERVER ---
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)