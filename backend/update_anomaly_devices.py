import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    # Update anomaly_logs device_id to match room_ids
    updates = [
        ('LAB_1', 'Floor-0-Lab-G1'),
        ('ROOM_101', 'Floor-1-Class-101'),
        ('ROOM_105', 'Floor-1-Class-103'),  # assuming 105 is 103
        ('ROOM_302', 'Floor-3-Class-302'),
    ]
    for old_id, new_id in updates:
        conn.execute(text("UPDATE anomaly_logs SET device_id = :new WHERE device_id = :old"), {"new": new_id, "old": old_id})
    conn.commit()
    print('Updated anomaly device_ids')