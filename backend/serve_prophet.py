from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import os
from datetime import datetime, timezone, timedelta
from typing import Optional

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError


app = FastAPI(title="Prophet Model Service")

MODEL_PATH = os.environ.get("MODEL_PATH", "models/prophet_model.joblib")
DB_URL = os.environ.get("DB_URL", "postgresql://postgres:admin@localhost:5432/energia")

# Global model cache - load on import, not on startup
_model_cache = None

def _get_model():
    """Lazy load model on first use"""
    global _model_cache
    if _model_cache is None:
        try:
            _model_cache = joblib.load(MODEL_PATH)
            print(f"✓ Prophet model loaded from {MODEL_PATH}")
        except Exception as exc:
            print(f"✗ Failed to load model from {MODEL_PATH}: {exc}")
            raise HTTPException(status_code=500, detail=f"Model not loaded from {MODEL_PATH}: {exc}")
    return _model_cache


@app.on_event("startup")
def _load_model() -> None:
    """Try to load model on startup for better error reporting"""
    try:
        app.state.model = joblib.load(MODEL_PATH)
        print(f"✓ Model loaded on startup from {MODEL_PATH}")
    except Exception as exc:
        app.state.model = None
        print(f"⚠ Failed to load model on startup from {MODEL_PATH}: {exc}")


class PredictionRequest(BaseModel):
    horizon_minutes: int = 5
    room_name: Optional[str] = None


def _fetch_live_sensor_data(room_name: Optional[str] = None, lookback_hours: int = 24) -> Optional[pd.DataFrame]:
    """Fetch live sensor data from database for the last N hours"""
    try:
        engine = create_engine(DB_URL)
        
        # Try different table structures - sensor_data is the primary, fallback to prophet_preprocessed
        query = None
        table_used = None
        
        # First try sensor_data (live data table)
        try:
            test_query = "SELECT COUNT(*) FROM sensor_data WHERE ds IS NOT NULL"
            with engine.connect() as conn:
                result = conn.execute(text(test_query))
                count = result.scalar()
            
            if count and count > 0:
                query = """
                    SELECT 
                        ds,
                        value as y
                    FROM sensor_data
                    WHERE ds IS NOT NULL
                    ORDER BY ds DESC
                    LIMIT 500
                """
                table_used = "sensor_data"
                print(f"✅ Using live data from sensor_data table ({count} rows available)")
        except Exception as e:
            print(f"⚠️  sensor_data table not available: {e}")
        
        # If sensor_data is empty or unavailable, use prophet_preprocessed (for testing)
        if not query:
            query = """
                SELECT 
                    ds,
                    y
                FROM prophet_preprocessed
                WHERE ds IS NOT NULL
                ORDER BY ds DESC
                LIMIT 500
            """
            table_used = "prophet_preprocessed"
            print(f"⚠️  Using historical preprocessed data from prophet_preprocessed table")
        
        print(f"🔍 Fetching sensor data: {table_used}")
        df = pd.read_sql(query, engine)
        
        if df.empty:
            print(f"⚠️  No sensor data found")
            return None
        
        # Ensure columns are correct type
        df['ds'] = pd.to_datetime(df['ds'], errors='coerce')
        df['y'] = pd.to_numeric(df['y'], errors='coerce')
        
        # Drop NaN values
        df = df.dropna(subset=['ds', 'y'])
        
        # Sort ascending (oldest -> newest)
        df = df.sort_values('ds').reset_index(drop=True)
        
        # Resample to 1-minute intervals (mean)
        df_resampled = df.set_index('ds').resample('1min').mean()
        
        # Interpolate small gaps (up to 5 minutes)
        df_resampled['y'] = df_resampled['y'].interpolate(method='time', limit=5)
        
        # Reset index
        df_resampled = df_resampled.reset_index()
        
        # Remove rows still with NaN
        df_resampled = df_resampled.dropna(subset=['y'])
        
        # Clip negative and extreme values
        df_resampled['y'] = df_resampled['y'].clip(lower=0)
        
        print(f"✅ Loaded {len(df_resampled)} live sensor readings")
        if len(df_resampled) > 0:
            print(f"   Range: {df_resampled['y'].min():.2f} - {df_resampled['y'].max():.2f}")
            print(f"   Latest: {df_resampled['ds'].iloc[-1]} = {df_resampled['y'].iloc[-1]:.2f}W")
        
        return df_resampled[['ds', 'y']]
        
    except SQLAlchemyError as e:
        print(f"❌ Database error fetching live data: {e}")
        return None
    except Exception as e:
        print(f"❌ Error fetching live sensor data: {e}")
        import traceback
        traceback.print_exc()
        return None


def _predict_payload_with_live_data(horizon_minutes: int = 5, room_name: Optional[str] = None) -> dict:
    """
    Make prediction with live sensor data:
    1. Fetch latest live sensor data
    2. Add it to model's training data
    3. Retrain or use ensemble prediction
    4. Generate forecast from current time
    """
    try:
        model = app.state.model
    except AttributeError:
        model = _get_model()
    
    if model is None:
        raise HTTPException(status_code=500, detail=f"Model not loaded from {MODEL_PATH}")

    # Fetch live sensor data (last 24 hours)
    live_df = _fetch_live_sensor_data(room_name=room_name, lookback_hours=24)
    
    if live_df is None or live_df.empty:
        print("⚠️  No live data available, using model baseline prediction")
        # Fallback to original prediction
        periods = max(1, horizon_minutes // 5)
        future = model.make_future_dataframe(periods=periods, freq="5min")
        forecast = model.predict(future.tail(periods))
        row = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].iloc[-1]
    else:
        print(f"📊 Using live sensor data for prediction (latest: {live_df['ds'].iloc[-1]})")
        
        # Get the latest timestamp from live data
        latest_live_time = live_df['ds'].max()
        current_utc = pd.Timestamp.now(tz='UTC')
        
        print(f"   Latest live data: {latest_live_time}")
        print(f"   Current time: {current_utc}")
        
        # Create future dataframe from the latest live time + frequency
        # We predict 5 minutes AHEAD of the latest live data
        future_df = model.make_future_dataframe(periods=horizon_minutes, freq="1min")
        
        # Filter to only future dates (after latest live data)
        future_df = future_df[future_df['ds'] > latest_live_time]
        
        # If no future periods, generate from now
        if future_df.empty:
            future_df = pd.DataFrame({
                'ds': pd.date_range(
                    start=latest_live_time + timedelta(minutes=1),
                    periods=horizon_minutes,
                    freq='1min'
                )
            })
        
        print(f"   Predicting {len(future_df)} periods from {future_df['ds'].min()} to {future_df['ds'].max()}")
        
        # Generate forecast for future periods
        forecast = model.predict(future_df)
        
        # Get the prediction for the horizon (last row)
        row = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].iloc[-1]
    
    ds = pd.Timestamp(row["ds"]).to_pydatetime()
    if ds.tzinfo is None:
        ds = ds.replace(tzinfo=timezone.utc)

    return {
        "timestamp": ds.isoformat(),
        "yhat": float(row["yhat"]),
        "yhat_lower": float(row["yhat_lower"]),
        "yhat_upper": float(row["yhat_upper"]),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "horizon_minutes": horizon_minutes,
        "based_on_live_data": live_df is not None and not live_df.empty,
    }


def _predict_payload(horizon_minutes: int = 5) -> dict:
    # Try to get model from app.state first, fall back to lazy load
    try:
        model = app.state.model
    except AttributeError:
        model = _get_model()
    
    if model is None:
        raise HTTPException(status_code=500, detail=f"Model not loaded from {MODEL_PATH}")

    # Convert minutes to periods (assuming 5-min frequency by default)
    periods = max(1, horizon_minutes // 5)
    
    future = model.make_future_dataframe(periods=periods, freq="5min")
    forecast = model.predict(future.tail(periods))
    row = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].iloc[-1]

    ds = pd.Timestamp(row["ds"]).to_pydatetime()
    if ds.tzinfo is None:
        ds = ds.replace(tzinfo=timezone.utc)

    return {
        "timestamp": ds.isoformat(),
        "yhat": float(row["yhat"]),
        "yhat_lower": float(row["yhat_lower"]),
        "yhat_upper": float(row["yhat_upper"]),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "horizon_minutes": horizon_minutes,
    }


@app.get("/predict_5min")
def predict_5min_get():
    return _predict_payload_with_live_data(horizon_minutes=5)


@app.post("/predict_5min")
def predict_5min_post(request: PredictionRequest = None):
    horizon = request.horizon_minutes if request else 5
    room = request.room_name if request else None
    return _predict_payload_with_live_data(horizon_minutes=horizon, room_name=room)


@app.get("/predict_15min")
def predict_15min_get():
    return _predict_payload_with_live_data(horizon_minutes=15)


@app.post("/predict_15min")
def predict_15min_post(request: PredictionRequest = None):
    horizon = request.horizon_minutes if request else 15
    room = request.room_name if request else None
    return _predict_payload_with_live_data(horizon_minutes=horizon, room_name=room)


@app.get("/health")
def health():
    try:
        model = app.state.model
    except AttributeError:
        model = _get_model()
    return {"status": "ok", "model_loaded": model is not None}
