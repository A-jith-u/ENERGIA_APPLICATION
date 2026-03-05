#!/usr/bin/env python3
"""Quick script to check for skip patterns in sensor data."""

import psycopg2
from datetime import datetime, timedelta
from config import get_db_url
from urllib.parse import urlparse, unquote

# Parse DB URL
db_url = get_db_url()
parsed = urlparse(db_url)

db_config = {
    'host': parsed.hostname or 'localhost',
    'port': parsed.port or 5432,
    'database': parsed.path.lstrip('/'),
    'user': parsed.username or 'postgres',
    'password': unquote(parsed.password) if parsed.password else 'postgres',
}

try:
    conn = psycopg2.connect(**db_config)
    cur = conn.cursor()
    
    # Check last 20 readings
    cur.execute("""
        SELECT id, ds, device_id, power 
        FROM sensor_data 
        ORDER BY ds DESC 
        LIMIT 20
    """)
    
    rows = cur.fetchall()
    
    print("LAST 20 SENSOR READINGS (most recent first):")
    print("=" * 70)
    print(f"{'ID':<6} {'TIMESTAMP':<30} {'DEVICE':<15} {'POWER(W)':<10}")
    print("-" * 70)
    
    prev_time = None
    time_diffs = []
    
    for row in reversed(rows):  # Show oldest to newest
        row_id, timestamp, device_id, power = row
        power_str = f"{power:.2f}" if power is not None else "N/A"
        print(f"{row_id:<6} {str(timestamp):<30} {device_id:<15} {power_str:<10}")
        
        if prev_time:
            diff = (timestamp - prev_time).total_seconds()
            time_diffs.append(diff)
            print(f"       --> Time diff from previous: {diff:.0f}s ({diff/60:.1f}m)")
        prev_time = timestamp
    
    print("=" * 70)
    if time_diffs:
        print(f"\nTime differences between readings:")
        print(f"  Min: {min(time_diffs):.0f}s ({min(time_diffs)/60:.1f}m)")
        print(f"  Max: {max(time_diffs):.0f}s ({max(time_diffs)/60:.1f}m)")
        print(f"  Avg: {sum(time_diffs)/len(time_diffs):.0f}s ({sum(time_diffs)/len(time_diffs)/60:.1f}m)")
    
    # Count readings per hour
    cur.execute("""
        SELECT 
            DATE_TRUNC('hour', ds) as hour,
            COUNT(*) as count
        FROM sensor_data
        WHERE ds > NOW() - INTERVAL '24 hours'
        GROUP BY DATE_TRUNC('hour', ds)
        ORDER BY hour DESC
    """)
    
    print("\nREADINGS PER HOUR (last 24 hours):")
    print("-" * 40)
    print(f"{'HOUR':<25} {'COUNT':<10}")
    print("-" * 40)
    
    for hour, count in cur.fetchall():
        expected = 60  # Should be ~60 readings per hour if every minute
        print(f"{str(hour):<25} {count:<10} (expected ~60)")
    
    cur.close()
    conn.close()
    
except Exception as e:
    print(f"ERROR: {e}")
