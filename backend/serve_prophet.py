from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import os
import sys
import importlib
import pandas as pd
from datetime import datetime, timezone

app = FastAPI(title="Prophet Model Service")
MODEL_PATH = os.environ.get("MODEL_PATH", "models/prophet_model.joblib")
# Make MODEL_PATH absolute relative to this script's directory
if not os.path.isabs(MODEL_PATH):
    MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", MODEL_PATH)


# Import AI recommendation engine for prediction-based recommendations
def _load_ai_engine():
    if __package__:
        try:
            from . import ai_recommendation_engine
            return ai_recommendation_engine
        except ImportError:
            return None
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        try:
            return importlib.import_module("ai_recommendation_engine")
        except ImportError:
            return None

ai_engine_module = _load_ai_engine()


class PredictNowRequest(BaseModel):
    horizon_minutes: int = 15  # default 15-minute forecast
    freq: str = "1min"         # pandas offset alias


class Predict15MinRequest(BaseModel):
    """Request for 15-minute interval predictions for the next 15 minutes."""
    pass  # No parameters needed - always predicts next 15 min in 15-min intervals


def load_model():
    """Load the model into app state. Called on startup and when mounted."""
    if not os.path.exists(MODEL_PATH):
        app.state.model = None
        print(f"WARNING: Model not found at {MODEL_PATH}")
    else:
        try:
            app.state.model = joblib.load(MODEL_PATH)
            print(f"Model loaded successfully from {MODEL_PATH}")
        except Exception as e:
            app.state.model = None
            print(f"ERROR loading model: {e}")


@app.on_event("startup")
def startup_event():
    load_model()


# Load model immediately when module is imported (for mounted apps)
load_model()


@app.post("/predict_next")
def predict_next(req: PredictNowRequest):
    if app.state.model is None:
        raise HTTPException(status_code=500, detail="Model not found. Train the model first and place at MODEL_PATH")

    if req.horizon_minutes <= 0 or req.horizon_minutes > 240:
        raise HTTPException(status_code=400, detail="horizon_minutes must be between 1 and 240")

    model = app.state.model

    freq_map = {
        "min": "min",
        "1min": "min",
        "m": "min",
        "h": "h",
        "hour": "h",
        "d": "d",
        "day": "d",
    }
    freq = freq_map.get(req.freq.lower(), req.freq)

    try:
        future = model.make_future_dataframe(periods=req.horizon_minutes, freq=freq)
        forecast = model.predict(future.tail(req.horizon_minutes))
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    result = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].to_dict(orient="records")
    return {"predictions": result}


@app.post("/predict_15min")
def predict_15min(req: Predict15MinRequest = None):
    """Predict energy usage for the next 15 minutes at 15-minute intervals.
    
    Returns a single prediction point 15 minutes from now WITH AI-generated recommendations.
    This is designed for class rep dashboards to show immediate upcoming usage.
    """
    if app.state.model is None:
        raise HTTPException(status_code=500, detail="Model not found. Train the model first and place at MODEL_PATH")

    model = app.state.model

    try:
        # Generate prediction for next 15 minutes using 15-minute frequency
        future = model.make_future_dataframe(periods=1, freq="15min")  # min = minute in pandas (updated from deprecated T)
        forecast = model.predict(future.tail(1))
        
        # Extract the prediction
        pred = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].iloc[0]
        
        result = {
            "timestamp": pred["ds"].isoformat() if hasattr(pred["ds"], "isoformat") else str(pred["ds"]),
            "predicted_energy": float(pred["yhat"]),
            "lower_bound": float(pred["yhat_lower"]),
            "upper_bound": float(pred["yhat_upper"]),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "horizon_minutes": 15,
        }
        
        # Generate AI recommendations based on this prediction
        recommendations = _generate_prediction_recommendations(result)
        result["recommendations"] = recommendations
        result["recommendation_count"] = len(recommendations)
        
        return result
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc


def _generate_prediction_recommendations(prediction: dict) -> list:
    """Generate actionable recommendations based on prediction."""
    recommendations = []
    pred_val = prediction.get("predicted_energy", 0)
    upper = prediction.get("upper_bound", 0)
    lower = prediction.get("lower_bound", 0)
    
    # High usage prediction
    if pred_val > 5.0:  # kWh threshold
        recommendations.append({
            "title": "High Energy Usage Predicted",
            "message": f"Predicted: {pred_val:.1f} kWh in next 15 minutes. Consider reducing non-essential loads.",
            "priority": "high",
            "action": "Reduce load before peak",
            "icon": "warning",
            "impact_kwh": round(max(0, pred_val - 4.0), 2),
            "impact_cost": round(max(0, pred_val - 4.0) * 8.5, 2),
        })
    
    # Large uncertainty
    uncertainty = upper - lower
    if uncertainty > pred_val * 0.5:
        recommendations.append({
            "title": "High Uncertainty in Prediction",
            "message": f"Usage could vary significantly ({lower:.1f} - {upper:.1f} kWh). Monitor closely.",
            "priority": "medium",
            "action": "Monitor usage",
            "icon": "info",
        })
    
    # Rising trend
    if pred_val > 4.5:
        recommendations.append({
            "title": "Rising Energy Trend",
            "message": "Energy consumption is trending upward. Implement efficiency measures now.",
            "priority": "medium",
            "action": "Check AC and lighting",
            "icon": "trending_up",
        })
    
    # Low usage (off-hours detection)
    if pred_val < 1.0:
        recommendations.append({
            "title": "Low Usage Period Ahead",
            "message": "Good time to shut down non-essential equipment and save energy.",
            "priority": "info",
            "action": "Power down devices",
            "icon": "power_settings_new",
        })
    
    # Normal range
    if 2.0 <= pred_val <= 4.5:
        recommendations.append({
            "title": "Normal Usage Expected",
            "message": f"Predicted usage ({pred_val:.1f} kWh) is within normal range. Maintain current efficiency practices.",
            "priority": "info",
            "action": "Continue monitoring",
            "icon": "check_circle",
        })
    
    return recommendations


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": app.state.model is not None}
