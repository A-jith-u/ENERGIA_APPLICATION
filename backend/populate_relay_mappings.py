"""Populate room_relay_mapping table with sample data."""
import sys
sys.path.insert(0, '.')
from config import get_db_url
from sqlalchemy import create_engine, text

engine = create_engine(get_db_url())

# Sample room-relay mappings
mappings = [
    ('CS-C201', 'ESP32-CS-C201', 1, 4),
    ('CS-C202', 'ESP32-CS-C202', 1, 4),
    ('EEE-E301', 'ESP32-EEE-E301', 1, 4),
    ('EEE-E302', 'ESP32-EEE-E302', 1, 4),
    ('CSE-LAB1', 'ESP32-CSE-LAB1', 1, 4),
]

with engine.begin() as conn:
    for room_id, device_id, channel, pin in mappings:
        try:
            conn.execute(text("""
                INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin, created_at, updated_at)
                VALUES (:room_id, :device_id, :channel, :pin, NOW(), NOW())
                ON CONFLICT (room_id) DO NOTHING
            """), {
                'room_id': room_id,
                'device_id': device_id,
                'channel': channel,
                'pin': pin,
            })
            print(f'✓ Inserted mapping: {room_id} -> {device_id}')
        except Exception as e:
            print(f'✗ Failed for {room_id}: {e}')

# Verify
with engine.connect() as conn:
    result = conn.execute(text("SELECT COUNT(*) FROM room_relay_mapping")).fetchone()
    print(f'\nTotal mappings now: {result[0]}')
    
    rows = conn.execute(text("SELECT room_id, relay_device_id FROM room_relay_mapping")).fetchall()
    for row in rows:
        print(f'  - {row[0]:<15} -> {row[1]}')
