"""
Test script to verify device_id normalization in sensor data ingestion.
Tests both "CS-C201" and "ESP32-CS-C201" formats to ensure they are normalized correctly.
"""

import requests
import json
import time
from datetime import datetime

BASE_URL = "http://localhost:5000"

def test_device_id_normalization():
    """Test that device_ids are normalized regardless of input format."""
    
    print("\n" + "="*80)
    print("DEVICE ID NORMALIZATION TEST")
    print("="*80)
    
    test_cases = [
        {
            "name": "Test 1: Send with 'CS-C201' format",
            "payload": {
                "device_id": "CS-C201",
                "power": 150.5,
                "current": 0.8,
                "voltage": 230,
                "frequency": 50.0,
                "power_factor": 0.95,
                "energy": 1250.0,
                "human_present": 1,
                "relay_state": "ON"
            }
        },
        {
            "name": "Test 2: Send with 'ESP32-CS-C201' format",
            "payload": {
                "device_id": "ESP32-CS-C201",
                "power": 160.0,
                "current": 0.85,
                "voltage": 230,
                "frequency": 50.0,
                "power_factor": 0.96,
                "energy": 1260.0,
                "human_present": 1,
                "relay_state": "ON"
            }
        },
        {
            "name": "Test 3: Send with lowercase 'esp32-cs-c201' format",
            "payload": {
                "device_id": "esp32-cs-c201",
                "power": 155.0,
                "current": 0.82,
                "voltage": 230,
                "frequency": 50.0,
                "power_factor": 0.95,
                "energy": 1255.0,
                "human_present": 1,
                "relay_state": "ON"
            }
        }
    ]
    
    for test_case in test_cases:
        print(f"\n{test_case['name']}")
        print(f"Input device_id: {test_case['payload']['device_id']}")
        
        try:
            response = requests.post(
                f"{BASE_URL}/api/sensor-data",
                json=test_case['payload'],
                timeout=5
            )
            
            if response.status_code == 200:
                print(f"✓ Request successful (Status 200)")
                result = response.json()
                print(f"  Response: {result}")
            else:
                print(f"✗ Request failed (Status {response.status_code})")
                print(f"  Response: {response.text}")
        
        except Exception as e:
            print(f"✗ Error: {str(e)}")
        
        time.sleep(1)
    
    # Query the database to verify normalization
    print("\n" + "-"*80)
    print("VERIFICATION: Checking database for stored device_ids")
    print("-"*80)
    
    try:
        from sqlalchemy import create_engine, text
        
        # Use the same connection string as the backend
        DATABASE_URL = "postgresql://admin_user:admin_pass@localhost:5432/energia_v3"
        engine = create_engine(DATABASE_URL)
        
        with engine.begin() as conn:
            # Check what device_ids are stored in sensor_data for CS-C201
            result = conn.execute(
                text("""
                    SELECT DISTINCT device_id, COUNT(*) as count, MAX(ds) as latest
                    FROM sensor_data 
                    WHERE device_id LIKE '%C201%' OR device_id LIKE '%CS%'
                    GROUP BY device_id
                    ORDER BY device_id
                """)
            ).fetchall()
            
            print("\n✓ Device IDs found in sensor_data table:")
            if result:
                for row in result:
                    print(f"  Device ID: {row[0]:<25} | Count: {row[1]:>4} | Latest: {row[2]}")
            else:
                print("  No records found")
            
            # Check relay_states table
            print("\n✓ Device IDs found in relay_states table:")
            result_relay = conn.execute(
                text("""
                    SELECT device_id, state, last_updated
                    FROM relay_states 
                    WHERE device_id LIKE '%C201%' OR device_id LIKE '%CS%'
                    ORDER BY device_id
                """)
            ).fetchall()
            
            if result_relay:
                for row in result_relay:
                    print(f"  Device ID: {row[0]:<25} | State: {row[1]:<5} | Updated: {row[2]}")
            else:
                print("  No records found")
    
    except Exception as e:
        print(f"\n✗ Database query error: {str(e)}")
    
    print("\n" + "="*80)
    print("TEST COMPLETE")
    print("="*80)
    print("\nExpected Result:")
    print("  All device_ids should be normalized to 'ESP32-CS-C201' format")
    print("  regardless of input format (CS-C201, esp32-cs-c201, ESP32-CS-C201, etc.)")
    print("="*80 + "\n")

if __name__ == "__main__":
    test_device_id_normalization()
