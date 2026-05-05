#!/usr/bin/env python3
"""Test script to verify device_id fix for coordinator sensor data."""

import sys
sys.path.insert(0, '.')
from config import get_db_url
from sqlalchemy import create_engine, text

db_url = get_db_url()
engine = create_engine(db_url)

# Test the exact query that the coordinator page runs
with engine.connect() as conn:
    # Simulate coordinator looking for CS-C201 data (or assigned_room_id = 'CS-C201')
    device_id = 'CS-C201'
    
    print(f'Testing query for device_id: {device_id}\n')
    
    # This simulates _build_device_candidates
    candidates = []
    token = device_id.strip().upper()
    candidates.append(token)  # CS-C201
    
    # Try with ESP32 prefix
    if not token.startswith('ESP32-'):
        candidates.append('ESP32-' + token)  # ESP32-CS-C201
    
    print('Candidate device_ids to search:')
    for c in candidates:
        print(f'  {c}')
    
    # Now test the actual sensor_data query
    params = {}
    for idx, cand in enumerate(candidates):
        params[f'did_{idx}'] = cand
    
    clauses = [f"UPPER(sd.device_id) = UPPER(:did_{idx})" for idx in range(len(candidates))]
    where_clause = 'WHERE (' + ' OR '.join(clauses) + ')'
    
    query = f"""
        SELECT sd.id, sd.ds, sd.device_id, sd.power
        FROM sensor_data sd
        {where_clause}
        ORDER BY sd.ds DESC
        LIMIT 5
    """
    
    result = conn.execute(text(query), params).fetchall()
    
    print(f'\nQuery found {len(result)} records:')
    for row in result:
        print(f'  ID: {row[0]}, Time: {row[1]}, Device: {row[2]}, Power: {row[3]}')
    
    # Also check how many records we have per device
    print('\n\nTotal records by device_id:')
    all_devices = conn.execute(text('SELECT device_id, COUNT(*) as cnt FROM sensor_data GROUP BY device_id')).fetchall()
    for device, count in all_devices:
        print(f'  {device}: {count} records')
