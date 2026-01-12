#!/usr/bin/env python3
"""
Sensor Data Verification Script
Check if ESP32 sensor data is being received and stored in the database.
"""

import psycopg2
from datetime import datetime, timedelta
import sys
from config import get_db_url
from urllib.parse import urlparse, unquote

def check_sensor_data():
    try:
        # Parse database URL from .env file
        db_url = get_db_url()
        parsed = urlparse(db_url)
        
        # Extract connection parameters and decode URL-encoded values
        host = parsed.hostname or "localhost"
        database = parsed.path.lstrip('/') or "energia"
        user = unquote(parsed.username) if parsed.username else "postgres"
        password = unquote(parsed.password) if parsed.password else ""
        port = parsed.port or 5432
        
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host=host,
            database=database,
            user=user,
            password=password,
            port=port
        )
        cur = conn.cursor()
        
        print("=" * 70)
        print("🔍 SENSOR DATA VERIFICATION REPORT")
        print("=" * 70)
        
        # 1. Check if sensor_data table exists
        print("\n[1] Checking sensor_data table exists...")
        cur.execute("""
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_name = 'sensor_data'
        """)
        if cur.fetchone()[0] == 0:
            print("    ❌ ERROR: sensor_data table does not exist!")
            return False
        print("    ✅ sensor_data table exists")
        
        # 1b. Check if esp32_raw_data table exists
        print("\n[1b] Checking esp32_raw_data table exists...")
        cur.execute("""
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_name = 'esp32_raw_data'
        """)
        if cur.fetchone()[0] == 0:
            print("    ❌ ERROR: esp32_raw_data table does not exist!")
            return False
        print("    ✅ esp32_raw_data table exists")
        
        # 2. Check table schema
        print("\n[2] Checking sensor_data table columns...")
        cur.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'sensor_data'
            ORDER BY ordinal_position
        """)
        columns = cur.fetchall()
        for col_name, col_type in columns:
            print(f"    • {col_name}: {col_type}")
        
        # 2b. Check esp32_raw_data schema
        print("\n[2b] Checking esp32_raw_data table columns...")
        cur.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'esp32_raw_data'
            ORDER BY ordinal_position
        """)
        columns = cur.fetchall()
        for col_name, col_type in columns:
            print(f"    • {col_name}: {col_type}")
        
        # 3. Count total records in sensor_data
        print("\n[3] Checking total records in sensor_data...")
        cur.execute("SELECT COUNT(*) FROM sensor_data")
        total_sensor = cur.fetchone()[0]
        print(f"    ✅ Total sensor_data records: {total_sensor}")
        
        # 3b. Count total records in esp32_raw_data
        print("\n[3b] Checking total records in esp32_raw_data...")
        cur.execute("SELECT COUNT(*) FROM esp32_raw_data")
        total_raw = cur.fetchone()[0]
        print(f"    ✅ Total esp32_raw_data records: {total_raw}")
        
        if total_raw == 0:
            print("    ⚠️  No raw data found yet - data should be saved here!")
            print("    ℹ️  ESP32 will send data every 60 seconds")
            print("    ℹ️  Check back in a minute")
        
        # 4. Get unique devices from esp32_raw_data
        print("\n[4] Checking connected devices (from esp32_raw_data)...")
        cur.execute("SELECT DISTINCT device_id FROM esp32_raw_data ORDER BY device_id")
        devices = [row[0] for row in cur.fetchall()]
        if devices:
            for device in devices:
                print(f"    ✅ Device: {device}")
        else:
            print("    ❌ No devices found in esp32_raw_data")
        
        # 5. Show latest records from esp32_raw_data
        if total_raw > 0:
            print("\n[5] Latest 5 records from esp32_raw_data...")
            cur.execute("""
                SELECT id, device_id, power, timestamp, processed 
                FROM esp32_raw_data 
                ORDER BY id DESC LIMIT 5
            """)
            print("    " + "-" * 80)
            for row in cur.fetchall():
                status = "✅ Processed" if row[4] == 1 else "⏳ Unprocessed"
                print(f"    ID: {row[0]} | Device: {row[1]} | Power: {row[2] if row[2] else 'N/A':.2f}W | Time: {row[3]} | {status}")
            print("    " + "-" * 80)
        
        # 6. Show raw payload sample
        if total_raw > 0:
            print("\n[6] Sample raw payload from esp32_raw_data...")
            cur.execute("""
                SELECT raw_payload 
                FROM esp32_raw_data 
                ORDER BY id DESC LIMIT 1
            """)
            raw_payload = cur.fetchone()[0]
            print(f"    {raw_payload}")
        
        # 7. Check records in last hour (esp32_raw_data)
        print("\n[7] Records in last hour (esp32_raw_data)...")
        cur.execute("""
            SELECT COUNT(*) FROM esp32_raw_data 
            WHERE timestamp > NOW() - INTERVAL '1 hour'
        """)
        last_hour = cur.fetchone()[0]
        print(f"    ✅ Records in last hour: {last_hour}")
        
        # 8. Check records in last 10 minutes (esp32_raw_data)
        print("\n[8] Records in last 10 minutes (esp32_raw_data)...")
        cur.execute("""
            SELECT COUNT(*) FROM esp32_raw_data 
            WHERE timestamp > NOW() - INTERVAL '10 minutes'
        """)
        last_10min = cur.fetchone()[0]
        if last_10min > 0:
            print(f"    ✅ Records in last 10 minutes: {last_10min}")
            print("    ✅ BACKEND IS RECEIVING RAW DATA!")
        else:
            print(f"    ⏳ No records in last 10 minutes (waiting for ESP32...)")
        
        # 9. Final verdict
        print("\n" + "=" * 70)
        if total_raw > 0:
            print("✅ SUCCESS: Backend is receiving ESP32 RAW data!")
            print("=" * 70)
            if devices:
                print(f"\nSummary:")
                print(f"  • Total raw records: {total_raw}")
                print(f"  • Devices: {', '.join(devices)}")
                print(f"  • Last 10 min: {last_10min} records")
                if last_10min > 0:
                    print(f"  • Status: Raw data is actively being received ✅")
                else:
                    print(f"  • Status: Raw data has been received before, waiting for new data...")
        else:
            print("❌ NO RAW DATA RECEIVED YET")
            print("=" * 70)
            print("\n⏳ Possible reasons:")
            print("  1. ESP32 hasn't sent data yet (sends every 60 seconds)")
            print("  2. Backend endpoint not responding")
            print("  3. ESP32 WiFi connection issue")
            print("  4. Backend code not saving to esp32_raw_data table")
            print("\nℹ️  Next steps:")
            print("  1. Check ESP32 serial monitor for:")
            print("     - 'WiFi connected' message")
            print("     - '✓ HTTP Response: 200' message")
            print("  2. Verify backend is running: python start_server.py")
            print("  3. Test endpoint manually:")
            print("     python test_esp32_save.py")
        
        print("\n" + "=" * 70)
        
        conn.close()
        return total_raw > 0
    
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = check_sensor_data()
    sys.exit(0 if success else 1)
