import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    # Update room_ids to match device_ids
    updates = [
        ("Floor-0-Lab-G1", "LAB_1"),
        ("Floor-0-Lab-G2", "LAB_2"),
        ("Floor-1-Lab-1", "LAB_3"),
        ("Floor-1-Lab-2", "LAB_4"),
        ("Floor-2-Lab-3", "LAB_5"),
        ("Floor-2-Lab-4", "LAB_6"),
        ("Floor-3-Lab-5", "LAB_7"),
        ("Floor-1-Class-101", "ROOM_101"),
        ("Floor-1-Class-102", "ROOM_102"),
        ("Floor-1-Class-103", "ROOM_103"),
        ("Floor-2-Class-201", "ROOM_201"),
        ("Floor-2-Class-202", "ROOM_202"),
        ("Floor-2-Class-203", "ROOM_203"),
        ("Floor-3-Class-301", "ROOM_301"),
        ("Floor-3-Class-302", "ROOM_302"),
    ]
    for old_id, new_id in updates:
        conn.execute(text("UPDATE rooms SET room_id = :new WHERE room_id = :old"), {"new": new_id, "old": old_id})
    conn.commit()
    print('Updated room_ids to match device_ids')