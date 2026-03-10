"""Test relay API endpoints"""
import requests

BASE_URL = "http://localhost:5000/relay"

# Note: Need valid sergeant token to access these endpoints
# For now, let's check if endpoints exist

print("="*80)
print("Testing /relay/mappings endpoint")
print("="*80)
try:
    # Try without auth - should get 401
    resp = requests.get(f"{BASE_URL}/mappings")
    print(f"Status: {resp.status_code}")
    print(f"Response: {resp.text[:200]}")
except Exception as e:
    print(f"Error: {e}")

print("\n" + "="*80)
print("Testing /relay/all-device-status endpoint")
print("="*80)
try:
    # Try without auth - should get 401
    resp = requests.get(f"{BASE_URL}/all-device-status")
    print(f"Status: {resp.status_code}")
    print(f"Response: {resp.text[:200]}")
except Exception as e:
    print(f"Error: {e}")

# Now check what the database actually has
print("\n" + "="*80)
print("Direct database check")
print("="*80)
from sqlalchemy import create_engine, text
from datetime import datetime

engine = create_engine('postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia')

print("\n1. Room-Relay Mappings:")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT room_id, relay_device_id, relay_channel 
        FROM room_relay_mapping
    """))
    for row in result:
        print(f"   {row[0]} → {row[1]} (channel {row[2]})")

print("\n2. Relay Device States:")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT device_id, state, last_updated 
        FROM relay_states
    """))
    now = datetime.now()
    for row in result:
        age_seconds = (now - row[2]).total_seconds()
        is_online = age_seconds < 30
        print(f"   {row[0]}: state={row[1]}, last_seen={age_seconds:.0f}s ago, online={is_online}")

print("\n3. Recent Sensor Data (shows which devices are actually transmitting):")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT DISTINCT device_id, MAX(ds) as last_seen
        FROM sensor_data
        WHERE ds > NOW() - INTERVAL '1 day'
        GROUP BY device_id
        ORDER BY last_seen DESC
    """))
    now = datetime.now()
for row in result:
        age = (now.replace(tzinfo=None) - row[1].replace(tzinfo=None)).total_seconds()
        print(f"   {row[0]}: {age:.0f}s ago")
