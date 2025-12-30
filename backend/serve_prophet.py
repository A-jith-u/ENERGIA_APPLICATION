from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import os
import pandas as pd
from datetime import datetime, timezone

app = FastAPI(title="Prophet Model Service")
MODEL_PATH = os.environ.get("MODEL_PATH", "models/prophet_model.joblib")


class PredictNowRequest(BaseModel):
    horizon_minutes: int = 15  # default 15-minute forecast
    freq: str = "1min"         # pandas offset alias


class Predict15MinRequest(BaseModel):
    """Request for 15-minute interval predictions for the next 15 minutes."""
    pass  # No parameters needed - always predicts next 15 min in 15-min intervals


@app.on_event("startup")
def load_model():
    global model
    if not os.path.exists(MODEL_PATH):
        model = None
        app.state.model = None
        app.logger = lambda *args, **kwargs: None
    else:
        model = joblib.load(MODEL_PATH)
        app.state.model = model


@app.post("/predict_next")
def predict_next(req: PredictNowRequest):
    if app.state.model is None:
        raise HTTPException(status_code=500, detail="Model not found. Train the model first and place at MODEL_PATH")

    if req.horizon_minutes <= 0 or req.horizon_minutes > 240:
        raise HTTPException(status_code=400, detail="horizon_minutes must be between 1 and 240")

    model = app.state.model

    freq_map = {
        "min": "T",
        "1min": "T",
        "m": "T",
        "h": "H",
        "hour": "H",
        "d": "D",
        "day": "D",
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
    
    Returns a single prediction point 15 minutes from now.
    This is designed for class rep dashboards to show immediate upcoming usage.
    """
    if app.state.model is None:
        raise HTTPException(status_code=500, detail="Model not found. Train the model first and place at MODEL_PATH")

    model = app.state.model

    try:
        # Generate prediction for next 15 minutes using 15-minute frequency
        future = model.make_future_dataframe(periods=1, freq="15T")  # T = minute in pandas
        forecast = model.predict(future.tail(1))
        
        # Extract the prediction
        pred = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].iloc[0]
        
        return {
            "timestamp": pred["ds"].isoformat() if hasattr(pred["ds"], "isoformat") else str(pred["ds"]),
            "predicted_energy": float(pred["yhat"]),
            "lower_bound": float(pred["yhat_lower"]),
            "upper_bound": float(pred["yhat_upper"]),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "horizon_minutes": 15
        }
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": app.state.model is not None}
