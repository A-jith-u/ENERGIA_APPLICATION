"""
Inject test sensor data into the database for testing predictions.
This script generates realistic energy consumption patterns for different classrooms.
Supports both SQLite and PostgreSQL databases.
"""
import os
import random
from datetime import datetime, timedelta
from dotenv import load_dotenv
from urllib.parse import urlparse, unquote

load_dotenv()

# Parse database URL
db_url = os.getenv("DB_URL", "sqlite:///energia.db")
print(f"Raw DB_URL: {db_url}")

# Determine database type and setup connection
if db_url.startswith("sqlite"):
    import sqlite3
    DB_TYPE = "sqlite"
    # Extract SQLite path
    db_path = db_url.replace("sqlite:///", "")
    print(f"Using SQLite database at: {db_path}")
else:
    import psycopg2
    DB_TYPE = "postgresql"
    if db_url.startswith("postgresql+psycopg2://"):
        db_url = db_url.replace("postgresql+psycopg2://", "postgresql://")
    
    parsed = urlparse(db_url)
    DB_CONFIG = {
        "host": parsed.hostname or "localhost",
        "database": parsed.path.lstrip('/') if parsed.path else "energia",
        "user": parsed.username or "postgres",
        "password": unquote(parsed.password) if parsed.password else "",
        "port": parsed.port or 5432
    }
    print(f"Using PostgreSQL database at {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")

# Classroom configurations with realistic energy patterns
CLASSROOMS = {
    "CS_LAB_1": {"base": 500, "variance": 150, "pattern": "computer_lab"},
    "CS_LAB_2": {"base": 480, "variance": 140, "pattern": "computer_lab"},
    "EE_LAB_1": {"base": 600, "variance": 200, "pattern": "electrical_lab"},
    "EC_LAB_1": {"base": 550, "variance": 180, "pattern": "electronics_lab"},
    "ME_LAB_1": {"base": 700, "variance": 250, "pattern": "mechanical_lab"},
    "IT_LAB_1": {"base": 450, "variance": 120, "pattern": "computer_lab"},
}


def generate_energy_reading(classroom_id, timestamp, config):
    """Generate realistic energy reading based on time of day and classroom type."""
    hour = timestamp.hour
    
    # Base consumption
    base = config["base"]
    variance = config["variance"]
    
    # Time-based multipliers
    if 8 <= hour < 12:  # Morning classes
        multiplier = 1.2
    elif 12 <= hour < 14:  # Lunch break
        multiplier = 0.5
    elif 14 <= hour < 18:  # Afternoon classes
        multiplier = 1.1
    elif 18 <= hour < 20:  # Evening classes
        multiplier = 0.9
    else:  # Night/early morning
        multiplier = 0.2
    
    # Add some randomness
    random_factor = random.uniform(0.8, 1.2)
    
    # Calculate energy reading
    energy = base * multiplier * random_factor + random.uniform(-variance, variance)
    
    # Ensure positive value
    return max(50, energy)


def inject_data(hours_back=168):  # Default: 7 days of data
    """Inject test sensor data for the specified time period."""
    
    try:
        # Connect to database based on type
        if DB_TYPE == "sqlite":
            import sqlite3
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()
            print(f"Connected to SQLite database: {db_path}")
        else:
            import psycopg2
            conn = psycopg2.connect(**DB_CONFIG)
            cur = conn.cursor()
            print(f"Connected to PostgreSQL database: {DB_CONFIG['database']}")
        
        # Generate data points (every 15 minutes)
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=hours_back)
        current_time = start_time
        
        data_points = []
        interval_minutes = 15
        
        print(f"Generating data from {start_time} to {end_time}")
        print(f"Interval: {interval_minutes} minutes")
        
        while current_time <= end_time:
            for classroom_id, config in CLASSROOMS.items():
                energy = generate_energy_reading(classroom_id, current_time, config)
                
                data_points.append((
                    current_time,
                    classroom_id,
                    round(energy, 2)
                ))
            
            current_time += timedelta(minutes=interval_minutes)
        
        print(f"Generated {len(data_points)} data points")
        
        # Insert data into database
        if DB_TYPE == "sqlite":
            insert_query = """
                INSERT OR REPLACE INTO sensor_data (ds, device_id, value)
                VALUES (?, ?, ?)
            """
        else:
            insert_query = """
                INSERT INTO sensor_data (ds, device_id, value)
                VALUES (%s, %s, %s)
            """
        
        cur.executemany(insert_query, data_points)
        conn.commit()
        
        print(f"✅ Successfully inserted {len(data_points)} sensor data records")
        
        # Show summary
        if DB_TYPE == "sqlite":
            cur.execute("""
                SELECT device_id, 
                       COUNT(*) as count,
                       MIN(ds) as earliest,
                       MAX(ds) as latest,
                       ROUND(AVG(value), 2) as avg_energy
                FROM sensor_data
                GROUP BY device_id
                ORDER BY device_id
            """)
        else:
            cur.execute("""
                SELECT device_id, 
                       COUNT(*) as count,
                       MIN(ds) as earliest,
                       MAX(ds) as latest,
                       ROUND(AVG(value)::numeric, 2) as avg_energy
                FROM sensor_data
                GROUP BY device_id
                ORDER BY device_id
            """)
        
        print("\n📊 Data Summary:")
        print("-" * 80)
        print(f"{'Classroom':<15} {'Count':<10} {'Earliest':<20} {'Latest':<20} {'Avg Energy':<10}")
        print("-" * 80)
        
        for row in cur.fetchall():
            print(f"{row[0]:<15} {row[1]:<10} {str(row[2]):<20} {str(row[3]):<20} {row[4]:<10} kWh")
        
        cur.close()
        conn.close()
        
    except Exception as e:
        print(f"❌ Error: {e}")
        raise


if __name__ == "__main__":
    import sys
    
    hours = 168  # Default: 7 days
    if len(sys.argv) > 1:
        try:
            hours = int(sys.argv[1])
        except ValueError:
            print(f"Invalid hours value: {sys.argv[1]}, using default: {hours}")
    
    print(f"🚀 Injecting {hours} hours of test sensor data...")
    inject_data(hours_back=hours)
    print("\n✅ Done! You can now test predictions.")
