from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import os
import pandas as pd
from datetime import timedelta

app = FastAPI(title="Prophet Model Service")
MODEL_PATH = os.environ.get("MODEL_PATH", "models/prophet_model.joblib")

class PredictNowRequest(BaseModel):
    lookback_minutes: int = 60
    freq: str = "min"   # 'min' for minute-level, 'H' for hourly


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


@app.post("/predict_next_hour")
def predict_next_hour(req: PredictNowRequest):
    # This endpoint expects a trained Prophet model at MODEL_PATH.
    # For demo: we create a future dataframe using last timestamp frequency and request 60 minutes ahead.
    if app.state.model is None:
        raise HTTPException(status_code=500, detail="Model not found. Train the model first and place at MODEL_PATH")

    model = app.state.model

    # Create future dataframe for 60 steps depending on freq
    # freq map
    freq_map = {"min": "T", "H": "H"}
    period = 60 if req.freq == "min" else 1
    try:
        future = model.make_future_dataframe(periods=period, freq=freq_map.get(req.freq, "T"))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    forecast = model.predict(future.tail(period))
    # return the last period predictions
    result = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].to_dict(orient="records")
    return {"predictions": result}


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": app.state.model is not None}
