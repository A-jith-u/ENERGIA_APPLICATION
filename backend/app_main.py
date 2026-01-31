import importlib
import os
import sys
import joblib
import pandas as pd
import numpy as np
from fastapi import FastAPI, Request, HTTPException
from datetime import datetime, timezone
from sqlalchemy import text, create_engine

# --- DATABASE SETUP ---
# Update with your actual credentials
DATABASE_URL = "postgresql://postgres:aswathy2004@localhost:5432/energia"
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
# Import your auth_api module here as you did before
def _load(name: str):
    sys.path.append(os.path.dirname(__file__))
    return importlib.import_module(name)

auth_api = _load("auth_api")
app.mount("/auth", auth_api.app)
# REMOVED: app.mount("/api", auth_api.app) - app_main now handles /api