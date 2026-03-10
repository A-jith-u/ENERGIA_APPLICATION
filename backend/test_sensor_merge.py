"""Test script to verify camera and power sensor data merging."""
import os
import requests
import time
from datetime import datetime

BASE_URL = "http://localhost:5000/api/sensor-data"
DEVICE_ID = "ESP32-TEST-MERGE"
TEST4_WAIT_SECONDS = int(os.environ.get("TEST4_WAIT_SECONDS", "5"))

def send_power_data():
    """Simulate ESP32 power sensor sending data."""
    payload = {
        "device_id": DEVICE_ID,
        "power": 250.5,
        "current": 1.25,
        "voltage": 240.0,
        "energy": 5.5,
        "power_factor": 0.95
    }
    response = requests.post(BASE_URL, json=payload)
    print(f"[{datetime.now()}] Power data sent: {response.status_code}")
    return response.json()

def send_occupancy_data(human_present):
    """Simulate camera module sending occupancy data."""
    payload = {
        "device_id": DEVICE_ID,
        "human_present": human_present
    }
    response = requests.post(BASE_URL, json=payload)
    print(f"[{datetime.now()}] Occupancy data sent (human_present={human_present}): {response.status_code}")
    return response.json()

def send_combined_data():
    """Simulate both sensors sending in same payload."""
    payload = {
        "device_id": DEVICE_ID,
        "power": 180.3,
        "current": 0.89,
        "voltage": 238.5,
        "energy": 6.2,
        "power_factor": 0.88,
        "human_present": 1
    }
    response = requests.post(BASE_URL, json=payload)
    print(f"[{datetime.now()}] Combined data sent: {response.status_code}")
    return response.json()

def check_database():
    """Query the latest record for this device."""
    from sqlalchemy import create_engine, text
    engine = create_engine('postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia')
    with engine.connect() as conn:
        result = conn.execute(
            text("""SELECT ds, power, current, voltage, energy, occupancy 
                    FROM sensor_data 
                    WHERE device_id = :id 
                    ORDER BY ds DESC LIMIT 5"""),
            {"id": DEVICE_ID}
        )
        print("\n" + "="*80)
        print(f"Latest records for {DEVICE_ID}:")
        print("-"*80)
        print(f"{'Timestamp':<25} {'Power':<10} {'Current':<10} {'Voltage':<10} {'Energy':<10} {'Occupancy':<10}")
        print("-"*80)
        for row in result:
            print(f"{str(row[0]):<25} {str(row[1]):<10} {str(row[2]):<10} {str(row[3]):<10} {str(row[4]):<10} {str(row[5]):<10}")
        print("="*80 + "\n")

if __name__ == "__main__":
    print("\n" + "="*80)
    print("TEST 1: Send power data first, then occupancy (should merge)")
    print("="*80)
    send_power_data()
    time.sleep(2)
    send_occupancy_data(1)
    time.sleep(1)
    check_database()
    
    print("\n" + "="*80)
    print("TEST 2: Send occupancy data first, then power (should merge)")
    print("="*80)
    send_occupancy_data(0)
    time.sleep(2)
    send_power_data()
    time.sleep(1)
    check_database()
    
    print("\n" + "="*80)
    print("TEST 3: Send combined data (both in same payload)")
    print("="*80)
    send_combined_data()
    time.sleep(1)
    check_database()
    
    print("\n" + "="*80)
    print("TEST 4: Send only occupancy (should NOT zero out power values)")
    print("="*80)
    print(f"Waiting {TEST4_WAIT_SECONDS}s before sending occupancy-only payload...")
    print("Set env TEST4_WAIT_SECONDS=360 for full >5 minute new-row validation.")
    time.sleep(TEST4_WAIT_SECONDS)
    send_occupancy_data(1)
    time.sleep(1)
    check_database()
    
    print("\n✅ All tests completed! Check the results above.")
