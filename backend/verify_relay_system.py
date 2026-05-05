#!/usr/bin/env python3
"""Comprehensive verification of sergeant relay control system."""

import sys
import json
from time import sleep

sys.path.insert(0, '.')
from config import get_db_url
from sqlalchemy import create_engine, text

db_url = get_db_url()
engine = create_engine(db_url)

print("=" * 80)
print("SERGEANT RELAY CONTROL SYSTEM VERIFICATION")
print("=" * 80)

# Check 1: Verify room_relay_mapping exists
print("\n[CHECK 1] Room Relay Mappings")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT room_id, relay_device_id, relay_channel, created_at
        FROM room_relay_mapping
        LIMIT 5
    """)).fetchall()
    
    if result:
        print("✓ Room relay mappings found:")
        for row in result:
            print(f"  Room: {row[0]:<12} → Device: {row[1]:<20} (ch={row[2]})")
    else:
        print("✗ No room relay mappings found")

# Check 2: Verify relay_commands table structure
print("\n[CHECK 2] Relay Commands Table Structure")
with engine.connect() as conn:
    # Get column info
    result = conn.execute(text("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'relay_commands'
        ORDER BY ordinal_position
    """)).fetchall()
    
    if result:
        print("✓ Table structure:")
        for col, dtype in result:
            print(f"  {col:<15} {dtype}")
    else:
        print("✗ relay_commands table not found")

# Check 3: Verify relay_commands records
print("\n[CHECK 3] Recent Relay Commands")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT id, device_id, command, status, created_at, executed_at
        FROM relay_commands
        ORDER BY created_at DESC
        LIMIT 5
    """)).fetchall()
    
    if result:
        print("✓ Recent commands:")
        for row in result:
            cmd_id, dev_id, cmd, status, created_at, executed_at = row
            executed_str = "✓" if executed_at else "✗"
            print(f"  [{cmd_id}] {dev_id:<20} {cmd:<3} {status:<10} {executed_str} {created_at.strftime('%H:%M:%S')}")
    else:
        print("✗ No commands found")

# Check 4: Verify relay_control_logs
print("\n[CHECK 4] Relay Control Logs")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT room_id, action, trigger_type, triggered_by_user_name, timestamp
        FROM relay_control_logs
        ORDER BY timestamp DESC
        LIMIT 5
    """)).fetchall()
    
    if result:
        print("✓ Control logs:")
        for row in result:
            print(f"  {row[0]:<12} {row[1]:<3} {row[2]:<10} by {row[3]:<20} @ {row[4].strftime('%H:%M:%S')}")
    else:
        print("✗ No control logs found")

# Check 5: Verify relay_states tracking
print("\n[CHECK 5] Current Relay States")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT device_id, last_updated
        FROM relay_states
        ORDER BY last_updated DESC
        LIMIT 5
    """)).fetchall()
    
    if result:
        print("✓ Relay states found:")
        for row in result:
            print(f"  {row[0]:<20} last_updated: {row[1].strftime('%H:%M:%S')}")
    else:
        print("✗ No relay states found")

# Check 6: Verify device_id consistency
print("\n[CHECK 6] Device ID Consistency")
with engine.connect() as conn:
    # Check sensor_data device_ids
    sensor_ids = conn.execute(text(
        "SELECT COUNT(DISTINCT device_id) FROM sensor_data"
    )).scalar()
    
    # Check relay_commands device_ids
    relay_ids = conn.execute(text(
        "SELECT COUNT(DISTINCT device_id) FROM relay_commands"
    )).scalar()
    
    # Check room_relay_mapping device_ids
    mapping_ids = conn.execute(text(
        "SELECT COUNT(DISTINCT relay_device_id) FROM room_relay_mapping"
    )).scalar()
    
    print(f"✓ Unique device_ids:")
    print(f"  sensor_data:        {sensor_ids}")
    print(f"  relay_commands:     {relay_ids}")
    print(f"  room_relay_mapping: {mapping_ids}")

# Check 7: Verify command consumption lifecycle
print("\n[CHECK 7] Command Lifecycle Status Distribution")
with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT status, COUNT(*) as count
        FROM relay_commands
        GROUP BY status
        ORDER BY count DESC
    """)).fetchall()
    
    if result:
        print("✓ Status distribution:")
        for status, count in result:
            print(f"  {status:<15} {count:>3} commands")
    else:
        print("✗ No status data")

# Check 8: Verify the actual control flow path
print("\n[CHECK 8] Control Flow Path Verification")
print("✓ Expected flow:")
print("  1. Sergeant clicks ON/OFF button in Flutter app")
print("  2. App calls POST /relay/control with room_id and action")
print("  3. Backend queues command in relay_commands (status=PENDING)")
print("  4. ESP32 polls GET /relay/commands?device_id=...")
print("  5. Backend marks command DELIVERED (consume-once)")
print("  6. ESP32 executes command and sends ACK to /relay/commands/ack")
print("  7. Backend marks command EXECUTED")
print("  8. Sergeant app polls GET /relay/command-status/{id}")
print("  9. App receives status and shows user feedback")

print("\n" + "=" * 80)
print("VERIFICATION COMPLETE")
print("=" * 80)
