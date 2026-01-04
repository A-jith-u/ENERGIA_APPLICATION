#!/usr/bin/env python3
"""
Sensor Data Verification Script
Check if ESP32 sensor data is being received and stored in the database.
"""

import psycopg2
from datetime import datetime, timedelta
import sys

def check_sensor_data():
    try:
        # Connect to PostgreSQL
        conn = psycopg2.connect(
            host="localhost",
            database="energia",
            user="postgres",
            password="postgresql",
            port=5432
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
        
        # 3. Count total records
        print("\n[3] Checking total records in sensor_data...")
        cur.execute("SELECT COUNT(*) FROM sensor_data")
        total = cur.fetchone()[0]
        if total == 0:
            print(f"    ❌ No records found (yet)")
            print("    ℹ️  ESP32 will send data every 60 seconds")
            print("    ℹ️  Check back in a minute")
        else:
            print(f"    ✅ Total records: {total}")
        
        # 4. Get unique devices
        print("\n[4] Checking connected devices...")
        cur.execute("SELECT DISTINCT device_id FROM sensor_data ORDER BY device_id")
        devices = [row[0] for row in cur.fetchall()]
        if devices:
            for device in devices:
                print(f"    ✅ Device: {device}")
        else:
            print("    ❌ No devices found")
        
        # 5. Show latest records
        if total > 0:
            print("\n[5] Latest 5 records from sensor_data...")
            cur.execute("""
                SELECT id, device_id, value, ds 
                FROM sensor_data 
                ORDER BY id DESC LIMIT 5
            """)
            print("    " + "-" * 66)
            for row in cur.fetchall():
                print(f"    ID: {row[0]} | Device: {row[1]} | Value: {row[2]:.2f} | Time: {row[3]}")
            print("    " + "-" * 66)
        
        # 6. Check records by device (if exists)
        if 'ESP32-LAB-001' in [d[0] for d in devices]:
            print("\n[6] Records from ESP32-LAB-001...")
            cur.execute("""
                SELECT COUNT(*) FROM sensor_data 
                WHERE device_id = 'ESP32-LAB-001'
            """)
            esp32_count = cur.fetchone()[0]
            print(f"    ✅ Records from ESP32-LAB-001: {esp32_count}")
            
            # Show latest reading
            if esp32_count > 0:
                cur.execute("""
                    SELECT ds, value FROM sensor_data 
                    WHERE device_id = 'ESP32-LAB-001'
                    ORDER BY id DESC LIMIT 1
                """)
                last_reading = cur.fetchone()
                print(f"    ✅ Latest reading: {last_reading[1]:.2f}W at {last_reading[0]}")
        
        # 7. Check records in last hour
        print("\n[7] Records in last hour...")
        cur.execute("""
            SELECT COUNT(*) FROM sensor_data 
            WHERE ds > NOW() - INTERVAL '1 hour'
        """)
        last_hour = cur.fetchone()[0]
        print(f"    ✅ Records in last hour: {last_hour}")
        
        # 8. Check records in last 10 minutes
        print("\n[8] Records in last 10 minutes...")
        cur.execute("""
            SELECT COUNT(*) FROM sensor_data 
            WHERE ds > NOW() - INTERVAL '10 minutes'
        """)
        last_10min = cur.fetchone()[0]
        if last_10min > 0:
            print(f"    ✅ Records in last 10 minutes: {last_10min}")
            print("    ✅ BACKEND IS RECEIVING DATA!")
        else:
            print(f"    ⏳ No records in last 10 minutes (waiting for ESP32...)")
        
        # 9. Final verdict
        print("\n" + "=" * 70)
        if total > 0:
            print("✅ SUCCESS: Backend is receiving sensor data!")
            print("=" * 70)
            if devices:
                print(f"\nSummary:")
                print(f"  • Total records: {total}")
                print(f"  • Devices: {', '.join(devices)}")
                print(f"  • Last 10 min: {last_10min} records")
                if last_10min > 0:
                    print(f"  • Status: Data is actively being received ✅")
                else:
                    print(f"  • Status: Data has been received before, waiting for new data...")
        else:
            print("❌ NO DATA RECEIVED YET")
            print("=" * 70)
            print("\n⏳ Possible reasons:")
            print("  1. ESP32 hasn't sent data yet (sends every 60 seconds)")
            print("  2. Backend endpoint not responding")
            print("  3. ESP32 WiFi connection issue")
            print("\nℹ️  Next steps:")
            print("  1. Check ESP32 serial monitor for:")
            print("     - 'WiFi connected' message")
            print("     - '✓ HTTP Response: 200' message")
            print("  2. Verify backend is running: python start_server.py")
            print("  3. Test endpoint manually:")
            print("     curl http://10.111.183.200:5000/api/sensor-data")
        
        print("\n" + "=" * 70)
        
        conn.close()
        return total > 0
    
    except psycopg2.Error as e:
        print(f"❌ Database error: {e}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = check_sensor_data()
    sys.exit(0 if success else 1)
