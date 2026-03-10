import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    result = conn.execute(text('SELECT device_id, COUNT(*) FROM anomaly_logs WHERE is_anomaly = -1 GROUP BY device_id'))
    print('Anomalies by device (room):')
    for row in result:
        print(row)
    
    # Get unique device_ids with anomalies
    result = conn.execute(text('SELECT DISTINCT device_id FROM anomaly_logs WHERE is_anomaly = -1'))
    device_ids = [row[0] for row in result]
    print(f'Device IDs with anomalies: {device_ids}')
    
    # Update rooms to set department='CS' for these device_ids
    if device_ids:
        placeholders = ','.join([':id' + str(i) for i in range(len(device_ids))])
        params = {f'id{i}': did for i, did in enumerate(device_ids)}
        conn.execute(text(f"UPDATE rooms SET department = 'CS' WHERE room_id IN ({placeholders})"), params)
        conn.commit()
        print('Updated rooms with department CS for devices with anomalies')
    
    # Check updated rooms
    result = conn.execute(text('SELECT room_id, department FROM rooms WHERE department IS NOT NULL'))
    print('Rooms with departments:')
    for row in result:
        print(row)