import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    # Get anomalies with their device_ids
    result = conn.execute(text('SELECT DISTINCT device_id FROM anomaly_logs WHERE is_anomaly = -1'))
    device_ids = [row[0] for row in result]
    print(f'Device IDs in anomaly_logs: {device_ids}')
    
    # Update existing rooms with these device_ids and set department
    for device_id in device_ids:
        conn.execute(text("UPDATE rooms SET department = 'CSE' WHERE room_id = :device_id"), {"device_id": device_id})
    
    # Insert new room records if they don't exist
    for device_id in device_ids:
        # Extract floor number from device_id (e.g., "Floor-0-Lab-G1" -> floor 0, "Floor-1-Class-101" -> floor 1)
        floor = 0
        if 'Floor-' in device_id:
            parts = device_id.split('-')
            try:
                floor = int(parts[1])
            except (ValueError, IndexError):
                floor = 0
        
        # Use room_id as room_name for new records
        conn.execute(text("""
            INSERT INTO rooms (room_id, room_name, floor_number, department, threshold) 
            VALUES (:device_id, :device_id, :floor, 'CSE', 3.0)
            ON CONFLICT (room_id) DO UPDATE SET department = 'CSE'
        """), {"device_id": device_id, "floor": floor})
    
    conn.commit()
    print('Updated rooms with device_ids and department CSE')
    
    # Verify
    result = conn.execute(text('SELECT room_id, room_name, floor_number, department FROM rooms WHERE room_id IN (SELECT DISTINCT device_id FROM anomaly_logs)'))
    print('Rooms matching anomalies:')
    for row in result:
        print(row)