import importlib
import os
import sys
import joblib
import pandas as pd
import numpy as np
from fastapi import FastAPI, Request, HTTPException
from datetime import datetime, timezone
from sqlalchemy import text, create_engine
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv(override=False)

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

# --- START SERVER ---
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5000)