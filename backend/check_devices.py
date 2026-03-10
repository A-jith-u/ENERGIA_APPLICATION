import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    result = conn.execute(text('SELECT DISTINCT device_id FROM sensor_data LIMIT 10'))
    print('Device IDs in sensor_data:')
    for row in result:
        print(row)