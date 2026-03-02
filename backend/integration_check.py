#!/usr/bin/env python3
"""
Complete integration check for live data prediction
Verifies all components are working correctly
"""

import os
import sys
import requests
import json
from pathlib import Path
from datetime import datetime

def check_backend_files():
    """Check if all required backend files exist"""
    print("\n📁 Checking Backend Files...")
    print("=" * 60)
    
    backend_dir = Path(".")
    required_files = [
        "serve_prophet.py",
        "train_prophet.py",
        "config.py",
        "models/prophet_model.joblib",
    ]
    
    all_exist = True
    for file in required_files:
        file_path = backend_dir / file
        if file_path.exists():
            size_mb = file_path.stat().st_size / (1024*1024)
            print(f"✅ {file} ({size_mb:.2f} MB)")
        else:
            print(f"❌ {file} - MISSING")
            all_exist = False
    
    return all_exist


def check_model_loadable():
    """Check if Prophet model can be loaded"""
    print("\n🧠 Checking Prophet Model...")
    print("=" * 60)
    
    try:
        import joblib
        model = joblib.load("models/prophet_model.joblib")
        print(f"✅ Model loaded successfully")
        print(f"   Type: {type(model)}")
        print(f"   Model details: {model}")
        return True
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return False


def check_database():
    """Check database connection and sensor data"""
    print("\n🗄️  Checking Database...")
    print("=" * 60)
    
    try:
        from sqlalchemy import create_engine, text
        import os
        
        db_url = os.environ.get("DB_URL", "postgresql://postgres:admin@localhost:5432/energia")
        engine = create_engine(db_url)
        
        with engine.connect() as conn:
            # Check if we can connect
            result = conn.execute(text("SELECT 1"))
            print(f"✅ Database connected")
            
            # Check for sensor_data table
            try:
                result = conn.execute(text("SELECT COUNT(*) FROM sensor_data"))
                count = result.scalar()
                print(f"✅ sensor_data table: {count} rows")
            except:
                print(f"⚠️  sensor_data table not available")
            
            # Check for preprocessed data
            try:
                result = conn.execute(text("SELECT COUNT(*) FROM prophet_preprocessed"))
                count = result.scalar()
                print(f"✅ prophet_preprocessed table: {count} rows")
            except:
                print(f"⚠️  prophet_preprocessed table not available")
            
            return True
    except Exception as e:
        print(f"❌ Database error: {e}")
        return False


def check_backend_service():
    """Check if backend service is running"""
    print("\n🚀 Checking Backend Service...")
    print("=" * 60)
    
    endpoints = [
        ("http://localhost:5000/health", "Health check"),
        ("http://localhost:5000/predict_5min", "Prediction endpoint"),
    ]
    
    for url, desc in endpoints:
        try:
            resp = requests.get(url, timeout=3)
            if resp.status_code == 200:
                print(f"✅ {desc}: {resp.status_code}")
                if url.endswith("/health"):
                    print(f"   {resp.json()}")
                elif url.endswith("/predict_5min"):
                    data = resp.json()
                    print(f"   Prediction for: {data.get('timestamp')}")
                    print(f"   Based on live data: {data.get('based_on_live_data', 'unknown')}")
            else:
                print(f"⚠️  {desc}: {resp.status_code}")
        except requests.exceptions.ConnectionError:
            print(f"❌ {desc}: Connection refused (backend not running)")
        except Exception as e:
            print(f"❌ {desc}: {e}")


def check_flutter_app():
    """Check if Flutter app files are updated"""
    print("\n📱 Checking Flutter App...")
    print("=" * 60)
    
    lib_dir = Path("../lib")
    target_file = lib_dir / "prediction_comparison_page.dart"
    
    if target_file.exists():
        content = target_file.read_text()
        
        checks = [
            ("_isLiveDataBased", "Live data flag"),
            ("room_name", "Room name support"),
            ("based_on_live_data", "Response parsing"),
            ("Live Data", "UI indicator"),
        ]
        
        for keyword, desc in checks:
            if keyword in content:
                print(f"✅ {desc}: Found '{keyword}'")
            else:
                print(f"❌ {desc}: Missing '{keyword}'")
    else:
        print(f"❌ prediction_comparison_page.dart not found")


def print_summary():
    """Print a helpful summary"""
    print("\n" + "=" * 60)
    print("📊 LIVE DATA PREDICTION INTEGRATION CHECK")
    print("=" * 60)
    print("""
The prediction system has been updated to use LIVE SENSOR DATA:

✨ Key Changes:
  • Predictions now use the latest 24-hour sensor data
  • Predicts 5 minutes ahead from the CURRENT timestamp
  • Visual indicator shows if prediction uses live data (green) or history (blue)
  • Room name support for future multi-room predictions

🔧 To Use:
  1. Ensure backend is running: uvicorn serve_prophet:app --port 5000 --reload
  2. Start sensor data collection
  3. Open Flutter app and navigate to "Prediction Comparison"
  4. Click "Fetch Prediction"
  5. Look for green "📡 Live Data" indicator = SUCCESS ✅

📚 Documentation:
  • Backend changes: /backend/serve_prophet.py
  • Frontend changes: /lib/prediction_comparison_page.dart
  • Test script: /backend/test_live_prediction.py
  • Full guide: /LIVE_DATA_PREDICTION_FIX.md

❓ Issues?
  • Run: python check_live_sensor_tables.py (check DB structure)
  • Run: python test_live_prediction.py (test endpoint)
  • Check backend logs for "live data" messages
  • Ensure sensor data has recent timestamps
""")


if __name__ == "__main__":
    
    print("\n🔍 LIVE DATA PREDICTION - INTEGRATION CHECK")
    print("=" * 60)
    print(f"Time: {datetime.now().isoformat()}")
    
    checks = [
        ("Backend Files", check_backend_files),
        ("Prophet Model", check_model_loadable),
        ("Database", check_database),
        ("Backend Service", check_backend_service),
        ("Flutter App", check_flutter_app),
    ]
    
    results = {}
    for name, check_func in checks:
        try:
            results[name] = check_func()
        except Exception as e:
            print(f"❌ {name}: {e}")
            results[name] = False
    
    print_summary()
    
    # Overall status
    print("\n📋 OVERALL STATUS:")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    print(f"   {passed}/{total} checks passed")
    
    if passed == total:
        print("\n✅ ALL SYSTEMS GO! Your live data prediction is ready.")
    else:
        print("\n⚠️  Some checks failed. See above for details.")
