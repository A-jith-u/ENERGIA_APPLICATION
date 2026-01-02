"""
Test the prediction API endpoints.
Run this after injecting test data and starting the server.
"""
import requests
import json

BASE_URL = "http://localhost:8000"


def test_health():
    """Test the health endpoint."""
    print("🔍 Testing health endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/model/health")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.json().get("model_loaded", False)
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def test_predict_15min():
    """Test the 15-minute prediction endpoint."""
    print("\n🔍 Testing 15-minute prediction...")
    try:
        response = requests.post(f"{BASE_URL}/model/predict_15min", json={})
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Prediction successful!")
            print(json.dumps(data, indent=2))
            print(f"\n📊 Summary:")
            print(f"   Predicted Energy: {data['predicted_energy']:.2f} kWh")
            print(f"   Range: {data['lower_bound']:.2f} - {data['upper_bound']:.2f} kWh")
            print(f"   Timestamp: {data['timestamp']}")
        else:
            print(f"❌ Error: {response.text}")
    except Exception as e:
        print(f"❌ Error: {e}")


def test_predict_next(horizon_minutes=60):
    """Test the next N minutes prediction endpoint."""
    print(f"\n🔍 Testing {horizon_minutes}-minute prediction...")
    try:
        response = requests.post(
            f"{BASE_URL}/model/predict_next",
            json={"horizon_minutes": horizon_minutes, "freq": "15min"}
        )
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            predictions = data["predictions"]
            print(f"✅ Got {len(predictions)} predictions")
            
            print("\n📊 First 3 predictions:")
            for i, pred in enumerate(predictions[:3], 1):
                print(f"   {i}. {pred['ds']}: {pred['yhat']:.2f} kWh (±{pred['yhat_upper'] - pred['yhat']:.2f})")
        else:
            print(f"❌ Error: {response.text}")
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    print("=" * 60)
    print("  ENERGIA Prediction API Test")
    print("=" * 60)
    
    # Check if model is loaded
    model_loaded = test_health()
    
    if not model_loaded:
        print("\n⚠️  Model not loaded. Please:")
        print("   1. Run: python train_prophet.py")
        print("   2. Restart the server")
        print("   3. Try again")
    else:
        # Test predictions
        test_predict_15min()
        test_predict_next(60)
        
    print("\n" + "=" * 60)
