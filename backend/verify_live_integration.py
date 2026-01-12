#!/usr/bin/env python3
"""
Quick verification script for Live ESP32 Integration.
Tests all components of the system.
"""

import requests
import json
import sys
from datetime import datetime, timedelta

BASE_URL = "http://localhost:5000"

def print_header(title):
    print("\n" + "="*70)
    print(f"  {title}")
    print("="*70)

def print_success(msg):
    print(f"✅ {msg}")

def print_error(msg):
    print(f"❌ {msg}")

def print_info(msg):
    print(f"ℹ️  {msg}")

def test_sensor_endpoint():
    """Test GET /api/sensor-data endpoint"""
    print_header("1. Testing Sensor Data Endpoint")
    
    try:
        response = requests.get(f"{BASE_URL}/api/sensor-data?limit=5", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print_success(f"Sensor endpoint working")
            print_info(f"Total records: {data.get('count', 0)}")
            
            if data.get('data'):
                latest = data['data'][0]
                print_info(f"Latest reading: {latest['value']} W @ {latest['timestamp']}")
                return True
            else:
                print_error("No sensor data found. Ensure ESP32 is sending data.")
                return False
        else:
            print_error(f"Sensor endpoint returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Sensor endpoint error: {e}")
        return False

def test_prediction_endpoint():
    """Test POST /model/predict_15min endpoint"""
    print_header("2. Testing Prediction Endpoint")
    
    try:
        response = requests.post(f"{BASE_URL}/model/predict_15min", 
                                json={}, 
                                headers={'Content-Type': 'application/json'},
                                timeout=10)
        if response.status_code == 200:
            data = response.json()
            print_success(f"Prediction endpoint working")
            print_info(f"Predicted energy: {data.get('predicted_energy', 'N/A')} kWh")
            print_info(f"Confidence range: {data.get('lower_bound', 'N/A')} - {data.get('upper_bound', 'N/A')}")
            print_info(f"Method: {data.get('method', 'N/A')}")
            
            # Check if live sensor data is included
            if data.get('latest_sensor_power'):
                print_success(f"Live ESP32 power: {data['latest_sensor_power']} W")
            
            return True
        else:
            print_error(f"Prediction endpoint returned {response.status_code}")
            print_info(f"Response: {response.text}")
            return False
    except Exception as e:
        print_error(f"Prediction endpoint error: {e}")
        return False

def test_recommendation_count():
    """Test GET /recommendations/count endpoint"""
    print_header("3. Testing Recommendation Count Endpoint")
    
    try:
        response = requests.get(f"{BASE_URL}/recommendations/count", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print_success(f"Recommendation count endpoint working")
            print_info(f"Total: {data.get('total', 0)}")
            print_info(f"Critical: {data.get('critical', 0)}, High: {data.get('high', 0)}, Medium: {data.get('medium', 0)}")
            return True
        else:
            print_error(f"Recommendation endpoint returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Recommendation endpoint error: {e}")
        return False

def test_health():
    """Test /health endpoint"""
    print_header("4. Testing Backend Health")
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            print_success(f"Backend is healthy")
            return True
        else:
            print_error(f"Health check returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Health check failed: {e}")
        print_info(f"Make sure backend is running: python start_server.py")
        return False

def test_flutter_json_parsing():
    """Verify JSON response is Flutter-compatible"""
    print_header("5. Verifying Flutter JSON Compatibility")
    
    try:
        # Test recommendation widget parsing
        response = requests.post(f"{BASE_URL}/recommendations", 
                                json={
                                    "user_role": "student",
                                    "department": "CS",
                                    "classroom": "CS-201"
                                },
                                timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            recs = data.get('recommendations', [])
            print_success(f"Got {len(recs)} recommendations")
            
            if recs:
                rec = recs[0]
                # Check all required fields exist (can be null)
                required_fields = ['id', 'title', 'message', 'type', 'priority', 'icon', 'timestamp']
                missing = [f for f in required_fields if f not in rec]
                
                if missing:
                    print_error(f"Missing fields: {missing}")
                    return False
                else:
                    print_success(f"All required fields present")
                    print_info(f"Sample rec: {rec['title']}")
                    return True
            else:
                print_info("No recommendations to verify (could be normal)")
                return True
        else:
            print_error(f"Recommendations endpoint returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Flutter JSON verification failed: {e}")
        return False

def main():
    print("\n")
    print("╔" + "="*68 + "╗")
    print("║" + " "*68 + "║")
    print("║" + "  LIVE ESP32 INTEGRATION - SYSTEM VERIFICATION".center(68) + "║")
    print("║" + " "*68 + "║")
    print("╚" + "="*68 + "╝")
    
    results = []
    
    print_info(f"Testing backend at: {BASE_URL}")
    print_info(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Run all tests
    results.append(("Backend Health", test_health()))
    results.append(("Sensor Endpoint", test_sensor_endpoint()))
    results.append(("Prediction Endpoint", test_prediction_endpoint()))
    results.append(("Recommendation Count", test_recommendation_count()))
    results.append(("Flutter JSON", test_flutter_json_parsing()))
    
    # Summary
    print_header("SUMMARY")
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status} - {test_name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print_success("All systems operational!")
        print_info("Your ENERGIA system is ready for live ESP32 data!")
        return 0
    else:
        print_error(f"{total - passed} test(s) failed")
        print_info("Review the errors above and fix them")
        return 1

if __name__ == "__main__":
    sys.exit(main())
