import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    # First, check current rooms
    result = conn.execute(text('SELECT room_id, department FROM rooms'))
    print('Current rooms:')
    for row in result:
        print(row)
    
    # Update rooms to have department CS
    conn.execute(text("UPDATE rooms SET department = 'CS' WHERE room_id LIKE '%ROOM%' OR room_id LIKE '%LAB%'"))
    conn.commit()
    print('Updated rooms with department CS')
    
    # Check again
    result = conn.execute(text('SELECT room_id, department FROM rooms'))
    print('Updated rooms:')
    for row in result:
        print(row)