#!/usr/bin/env python3
"""
Test the prediction endpoint with live data
"""

import requests
import json
import time

BASE_URL = "http://localhost:5000"

def test_predict_5min():
    """Test the /predict_5min endpoint"""
    print("🔍 Testing /predict_5min endpoint...")
    print("=" * 60)
    
    # Test 1: GET request
    print("\n1️⃣ Testing GET request:")
    try:
        resp = requests.get(f"{BASE_URL}/predict_5min", timeout=10)
        print(f"   Status: {resp.status_code}")
        if resp.status_code == 200:
            data = resp.json()
            print(f"   Response: {json.dumps(data, indent=2)}")
        else:
            print(f"   Error: {resp.text}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    # Test 2: POST request with room name
    print("\n2️⃣ Testing POST request with room name:")
    try:
        payload = {
            "horizon_minutes": 5,
            "room_name": "Lab1"
        }
        resp = requests.post(
            f"{BASE_URL}/predict_5min",
            json=payload,
            timeout=10
        )
        print(f"   Status: {resp.status_code}")
        if resp.status_code == 200:
            data = resp.json()
            print(f"   Response: {json.dumps(data, indent=2)}")
            
            # Check for live data indicator
            if data.get('based_on_live_data'):
                print("   ✅ Prediction is based on LIVE DATA")
            else:
                print("   ⚠️  Prediction is based on historical data")
        else:
            print(f"   Error: {resp.text}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    # Test 3: POST request with 15-minute horizon
    print("\n3️⃣ Testing /predict_15min endpoint:")
    try:
        payload = {
            "horizon_minutes": 15,
            "room_name": "Lab1"
        }
        resp = requests.post(
            f"{BASE_URL}/predict_15min",
            json=payload,
            timeout=10
        )
        print(f"   Status: {resp.status_code}")
        if resp.status_code == 200:
            data = resp.json()
            print(f"   Response: {json.dumps(data, indent=2)}")
        else:
            print(f"   Error: {resp.text}")
    except Exception as e:
        print(f"   ❌ Error: {e}")


def test_health():
    """Test the /health endpoint"""
    print("\n\n🏥 Testing /health endpoint...")
    print("=" * 60)
    
    try:
        resp = requests.get(f"{BASE_URL}/health", timeout=5)
        print(f"Status: {resp.status_code}")
        print(f"Response: {json.dumps(resp.json(), indent=2)}")
    except Exception as e:
        print(f"❌ Error: {e}")


if __name__ == "__main__":
    print(f"🚀 Testing prediction service at {BASE_URL}\n")
    
    test_health()
    test_predict_5min()
    
    print("\n\n✅ Tests complete!")
