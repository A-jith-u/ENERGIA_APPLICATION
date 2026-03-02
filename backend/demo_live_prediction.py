#!/usr/bin/env python3
"""
Demo script showing live data predictions in action
Fetches latest sensor data and generates a prediction for 5 minutes ahead
"""

import os
import sys
import json
from datetime import datetime, timedelta
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent))

from sqlalchemy import create_engine, text
import pandas as pd
from prophet import Prophet
import joblib


def demo_live_prediction():
    """Demonstrate the live data prediction pipeline"""
    
    print("\n" + "="*70)
    print("🎬 LIVE DATA PREDICTION DEMO")
    print("="*70 + "\n")
    
    DB_URL = os.environ.get("DB_URL", "sqlite:///energia.db")
    MODEL_PATH = "models/prophet_model.joblib"
    
    print(f"⚙️  Configuration:")
    print(f"   Database: {DB_URL}")
    print(f"   Model: {MODEL_PATH}")
    print()
    
    # Step 1: Load Prophet model
    print("Step 1️⃣ : Loading Prophet model...")
    try:
        model = joblib.load(MODEL_PATH)
        print(f"   ✅ Model loaded successfully")
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return
    
    # Step 2: Fetch live sensor data
    print("\nStep 2️⃣ : Fetching live sensor data...")
    try:
        engine = create_engine(DB_URL)
        
        # Try sensor_data first, then prophet_preprocessed
        query = """
            SELECT ds, y FROM prophet_preprocessed
            WHERE ds IS NOT NULL
            ORDER BY ds DESC
            LIMIT 500
        """
        
        df = pd.read_sql(query, engine)
        
        if df.empty:
            print(f"   ❌ No sensor data found")
            return
        
        # Prepare data
        df['ds'] = pd.to_datetime(df['ds'], errors='coerce')
        df['y'] = pd.to_numeric(df['y'], errors='coerce')
        df = df.dropna(subset=['ds', 'y'])
        df = df.sort_values('ds').reset_index(drop=True)
        
        print(f"   ✅ Loaded {len(df)} readings")
        
        latest_time = df['ds'].max()
        latest_value = df['y'].iloc[-1]
        oldest_time = df['ds'].min()
        
        print(f"   Latest: {latest_time} = {latest_value:.2f}W")
        print(f"   Range:  {oldest_time} to {latest_time}")
        print(f"   Duration: {(latest_time - oldest_time).total_seconds()/3600:.1f} hours")
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return
    
    # Step 3: Create future dataframe from latest timestamp
    print("\nStep 3️⃣ : Creating prediction horizon...")
    try:
        # Next 5 minutes from latest data
        prediction_start = latest_time
        prediction_end = prediction_start + timedelta(minutes=5)
        
        future_df = pd.DataFrame({
            'ds': pd.date_range(
                start=prediction_start + timedelta(minutes=1),
                end=prediction_end,
                freq='1min'
            )
        })
        
        print(f"   ✅ Prediction period: {prediction_start} to {prediction_end}")
        print(f"   Periods: {len(future_df)} (1 per minute)")
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return
    
    # Step 4: Generate forecast
    print("\nStep 4️⃣ : Generating forecast...")
    try:
        forecast = model.predict(future_df)
        
        # Get the last forecast point (5 minutes ahead)
        pred_row = forecast.iloc[-1]
        
        pred_time = pd.Timestamp(pred_row['ds']).to_pydatetime()
        pred_yhat = float(pred_row['yhat'])
        pred_lower = float(pred_row['yhat_lower'])
        pred_upper = float(pred_row['yhat_upper'])
        
        print(f"   ✅ Forecast generated for {len(forecast)} periods")
        print()
        
        # Print results
        print("="*70)
        print("📊 LIVE DATA PREDICTION RESULTS")
        print("="*70)
        print()
        print(f"🔵 Current Situation (Latest Live Data):")
        print(f"   Time: {latest_time}")
        print(f"   Power: {latest_value:.2f} W")
        print()
        print(f"🟢 Prediction for 5 Minutes Ahead:")
        print(f"   Time: {pred_time}")
        print(f"   Power: {pred_yhat:.2f} W")
        print(f"   Confidence Interval: {pred_lower:.2f}W - {pred_upper:.2f}W")
        print(f"   Range: ±{(pred_upper - pred_lower)/2:.2f}W")
        print()
        
        # Calculate change
        change = pred_yhat - latest_value
        pct_change = (change / latest_value * 100) if latest_value != 0 else 0
        
        print(f"📈 Predicted Change:")
        if change > 0:
            print(f"   📊 +{change:.2f}W ({pct_change:+.1f}%) - Usage INCREASING")
        elif change < 0:
            print(f"   📊 {change:.2f}W ({pct_change:+.1f}%) - Usage DECREASING")
        else:
            print(f"   📊 No change ({pct_change:+.1f}%) - Usage STABLE")
        print()
        
        # Show as JSON (like API response)
        print("="*70)
        print("📋 API RESPONSE FORMAT")
        print("="*70)
        response = {
            "timestamp": pred_time.isoformat(),
            "yhat": pred_yhat,
            "yhat_lower": pred_lower,
            "yhat_upper": pred_upper,
            "generated_at": datetime.now().isoformat(),
            "horizon_minutes": 5,
            "based_on_live_data": True,
            "last_reading": {
                "timestamp": str(latest_time),
                "value": latest_value
            }
        }
        print(json.dumps(response, indent=2))
        print()
        
        # Show forecast graph info
        print("="*70)
        print("📈 FORECAST TRAJECTORY (Next 5 minutes)")
        print("="*70)
        print()
        for idx, row in forecast.iterrows():
            t = pd.Timestamp(row['ds']).to_pydatetime()
            y = float(row['yhat'])
            offset = (idx + 1)
            bar_length = int(y / 20)
            bar = "█" * bar_length
            print(f"{t.strftime('%H:%M')} : {y:7.2f}W │{bar}")
        print()
        
    except Exception as e:
        print(f"   ❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return
    
    print("="*70)
    print("✅ DEMO COMPLETE")
    print("="*70)
    print()
    print("This is what happens when you click 'Fetch Prediction' in the app:")
    print("  1. Latest sensor data fetched (from latest_time)")
    print("  2. Model creates future dates (next 5 minutes)")
    print("  3. Prophet generates forecast")
    print("  4. Result shown with 'based_on_live_data: true' ✅")
    print()


if __name__ == "__main__":
    demo_live_prediction()
