#!/usr/bin/env python3
"""Test script to verify sergeant turn on/off relay control flow."""

import sys
import requests
import json
from time import sleep

sys.path.insert(0, '.')
from config import get_db_url, get_jwt_secret
from sqlalchemy import create_engine, text
import jwt
from datetime import datetime, timedelta

BASE_URL = "http://localhost:5000"
JWT_SECRET = get_jwt_secret()
JWT_ALG = "HS256"

# Create a test sergeant token
sergeant_payload = {
    "sub": "1",
    "username": "sergeant@test.com",
    "name": "Test Sergeant",
    "role": "sergeant",
    "department": "CSE",
    "assigned_room_id": None,
    "exp": datetime.utcnow() + timedelta(hours=1),
}
sergeant_token = jwt.encode(sergeant_payload, JWT_SECRET, algorithm=JWT_ALG)

print("=" * 70)
print("SERGEANT RELAY CONTROL TEST")
print("=" * 70)

# Step 1: Test relay control endpoint
print("\n[TEST 1] Send turn ON command via /relay/control")
try:
    response = requests.post(
        f"{BASE_URL}/relay/control",
        json={
            "room_id": "CS-C201",
            "action": "ON",
            "reason": "Testing turn on button"
        },
        headers={"Authorization": f"Bearer {sergeant_token}"},
        timeout=5
    )
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Response: {json.dumps(data, indent=2)}")
    
    if response.status_code == 200:
        command_id = data.get('command_id')
        print(f"✓ Turn ON command queued successfully (command_id={command_id})")
    else:
        print(f"✗ Failed to queue command")
except Exception as e:
    print(f"✗ Error: {e}")

# Step 2: Verify command is in database
print("\n[TEST 2] Check command in relay_commands table")
try:
    db_url = get_db_url()
    engine = create_engine(db_url)
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT id, device_id, command, status, created_at 
            FROM relay_commands 
            ORDER BY created_at DESC 
            LIMIT 1
        """)).fetchone()
        
        if result:
            cmd_id, dev_id, cmd, status, created_at = result
            print(f"✓ Latest command found:")
            print(f"  ID: {cmd_id}")
            print(f"  Device: {dev_id}")
            print(f"  Command: {cmd}")
            print(f"  Status: {status}")
            print(f"  Created: {created_at}")
        else:
            print(f"✗ No commands found")
except Exception as e:
    print(f"✗ Error: {e}")

# Step 3: Test ESP32 polling endpoint
print("\n[TEST 3] Simulate ESP32 polling /relay/commands")
try:
    response = requests.get(
        f"{BASE_URL}/relay/commands?device_id=ESP32-CS-C201",
        timeout=5
    )
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Response: {json.dumps(data, indent=2)}")
    
    if data.get('command'):
        print(f"✓ ESP32 received command: {data['command']}")
    else:
        print(f"✓ No pending command (expected if already consumed)")
except Exception as e:
    print(f"✗ Error: {e}")

# Step 4: Test command status endpoint
print("\n[TEST 4] Check command status via /relay/command-status/{id}")
try:
    # Get latest command ID
    db_url = get_db_url()
    engine = create_engine(db_url)
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT id FROM relay_commands ORDER BY created_at DESC LIMIT 1
        """)).fetchone()
        
        if result:
            cmd_id = result[0]
            response = requests.get(
                f"{BASE_URL}/relay/command-status/{cmd_id}",
                headers={"Authorization": f"Bearer {sergeant_token}"},
                timeout=5
            )
            print(f"Status: {response.status_code}")
            data = response.json()
            print(f"Response: {json.dumps(data, indent=2)}")
            
            if data.get('command'):
                cmd_status = data['command'].get('queue_status')
                is_delivered = data['command'].get('is_delivered')
                print(f"✓ Command status: {cmd_status} (delivered={is_delivered})")
except Exception as e:
    print(f"✗ Error: {e}")

# Step 5: Test turn OFF command
print("\n[TEST 5] Send turn OFF command via /relay/control")
try:
    response = requests.post(
        f"{BASE_URL}/relay/control",
        json={
            "room_id": "CS-C201",
            "action": "OFF",
            "reason": "Testing turn off button"
        },
        headers={"Authorization": f"Bearer {sergeant_token}"},
        timeout=5
    )
    print(f"Status: {response.status_code}")
    data = response.json()
    print(f"Response: {json.dumps(data, indent=2)}")
    
    if response.status_code == 200:
        command_id = data.get('command_id')
        print(f"✓ Turn OFF command queued successfully (command_id={command_id})")
    else:
        print(f"✗ Failed to queue command")
except Exception as e:
    print(f"✗ Error: {e}")

print("\n" + "=" * 70)
print("TEST COMPLETE")
print("=" * 70)
