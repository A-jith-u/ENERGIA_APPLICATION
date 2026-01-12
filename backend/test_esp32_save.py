#!/usr/bin/env python3
"""Test script to verify ESP32 raw data is being saved."""

import requests
import json
from config import get_db_url
from urllib.parse import urlparse, unquote
import psycopg2

# Send test data to sensor endpoint
url = "http://127.0.0.1:5000/auth/sensor-data"
payload = {
    "device_id": "ESP32-TEST-001",
    "voltage": 230.5,
    "current": 2.3,
    "power": 529.15,
    "energy": 1.5,
    "frequency": 50.0,
    "power_factor": 0.95,
}

print("📤 Sending test ESP32 data to backend...")
print(f"Payload: {json.dumps(payload, indent=2)}")

try:
    response = requests.post(url, json=payload, timeout=5)
    print(f"\n✅ Backend response: {response.status_code}")
    print(f"Response: {response.json()}\n")
except Exception as e:
    print(f"❌ Error sending data: {e}\n")

# Now check if it was saved in the database
print("📊 Checking database for saved data...\n")

try:
    db_url = get_db_url()
    parsed = urlparse(db_url)
    
    host = parsed.hostname or "localhost"
    database = parsed.path.lstrip('/') or "energia"
    user = unquote(parsed.username) if parsed.username else "postgres"
    password = unquote(parsed.password) if parsed.password else ""
    port = parsed.port or 5432
    
    conn = psycopg2.connect(
        host=host,
        database=database,
        user=user,
        password=password,
        port=port
    )
    cur = conn.cursor()
    
    # Check esp32_raw_data table
    cur.execute("SELECT id, device_id, timestamp, processed FROM esp32_raw_data ORDER BY timestamp DESC LIMIT 5")
    rows = cur.fetchall()
    
    if rows:
        print("✅ Found data in esp32_raw_data table:")
        for row in rows:
            print(f"   ID: {row[0]}, Device: {row[1]}, Time: {row[2]}, Processed: {row[3]}")
    else:
        print("❌ No data found in esp32_raw_data table")
        
        # Check sensor_data table instead
        cur.execute("SELECT id, device_id, ds FROM sensor_data ORDER BY ds DESC LIMIT 5")
        rows = cur.fetchall()
        if rows:
            print("\n✅ But found data in sensor_data table:")
            for row in rows:
                print(f"   ID: {row[0]}, Device: {row[1]}, Time: {row[2]}")
    
    cur.close()
    conn.close()
    
except Exception as e:
    print(f"❌ Database error: {e}")
