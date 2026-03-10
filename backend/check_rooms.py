import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    result = conn.execute(text('SELECT room_id, department FROM rooms WHERE department IS NOT NULL'))
    print('Rooms with departments:')
    for row in result:
        print(row)