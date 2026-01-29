#!/usr/bin/env python3
"""
Check available sensor data tables and their structure
to ensure live data fetching works correctly.
"""

import os
import sys
from sqlalchemy import create_engine, inspect, text

DB_URL = os.environ.get("DB_URL", "postgresql://postgres:admin@localhost:5432/energia")

def check_tables():
    """List all tables in the database"""
    engine = create_engine(DB_URL)
    inspector = inspect(engine)
    
    print("📊 Database Tables:")
    print("=" * 60)
    
    tables = inspector.get_table_names()
    if not tables:
        print("❌ No tables found!")
        return
    
    for table_name in sorted(tables):
        print(f"\n📋 Table: {table_name}")
        columns = inspector.get_columns(table_name)
        for col in columns:
            print(f"   - {col['name']}: {col['type']}")
        
        # Get row count
        try:
            with engine.connect() as conn:
                result = conn.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
                count = result.scalar()
                print(f"   Total rows: {count}")
        except Exception as e:
            print(f"   ⚠️ Error counting rows: {e}")


def check_sensor_data():
    """Check for sensor data tables specifically"""
    engine = create_engine(DB_URL)
    inspector = inspect(engine)
    
    print("\n🔍 Sensor Data Tables:")
    print("=" * 60)
    
    # Common sensor table names
    sensor_tables = [
        'pzem_raw_data',
        'sensor_data',
        'energy_data',
        'pzem_data',
        'raw_data',
        'readings',
        'measurements',
    ]
    
    found_tables = []
    for table in sensor_tables:
        if table in inspector.get_table_names():
            found_tables.append(table)
            print(f"\n✅ Found: {table}")
            
            # Show recent data
            try:
                with engine.connect() as conn:
                    # Get latest records
                    query = f"SELECT * FROM {table} ORDER BY ts DESC LIMIT 5"
                    result = conn.execute(text(query))
                    rows = result.fetchall()
                    
                    if rows:
                        print(f"   Latest records:")
                        for row in rows:
                            print(f"   {dict(row)}")
            except Exception as e:
                print(f"   ⚠️ Error fetching data: {e}")
    
    if not found_tables:
        print("❌ No sensor data tables found!")
        print("   Searched for: " + ", ".join(sensor_tables))
    
    return found_tables


if __name__ == "__main__":
    print(f"🔗 Database URL: {DB_URL}\n")
    
    try:
        check_tables()
        check_sensor_data()
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
