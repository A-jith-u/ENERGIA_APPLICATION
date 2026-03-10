import os
os.environ['DB_URL'] = 'postgresql+psycopg2://postgres:1234@localhost:5432/energia'
from sqlalchemy import create_engine, text

engine = create_engine(os.environ['DB_URL'])
with engine.connect() as conn:
    conn.execute(text("UPDATE rooms SET department = 'CSE' WHERE department = 'CS'"))
    conn.commit()
    print('Updated CS to CSE')