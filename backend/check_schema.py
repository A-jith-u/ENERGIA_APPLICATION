import psycopg2
from urllib.parse import unquote

conn = psycopg2.connect(
    host="localhost",
    database="energia",
    user="postgres",
    password="ajith@",
    port=5432
)
cur = conn.cursor()
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'sensor_data' 
    ORDER BY ordinal_position
""")
print("sensor_data table columns:")
for row in cur.fetchall():
    print(f"  {row[0]}: {row[1]}")
conn.close()
