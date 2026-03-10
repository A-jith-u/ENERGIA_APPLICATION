"""List all tables in the database."""
from sqlalchemy import create_engine, text, inspect

engine = create_engine('postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia')

print("="*80)
print("ALL TABLES IN DATABASE")
print("="*80)
inspector = inspect(engine)
tables = inspector.get_table_names()
for table in sorted(tables):
    print(f"  - {table}")

print("\n" + "="*80)
print("RELAY-RELATED TABLES")
print("="*80)
relay_tables = [t for t in tables if 'relay' in t.lower()]
for table in relay_tables:
    print(f"\n[{table}]")
    with engine.connect() as conn:
        try:
            result = conn.execute(text(f'SELECT * FROM {table} LIMIT 3'))
            cols = result.keys()
            print(f"Columns: {', '.join(cols)}")
            rows = list(result)
            print(f"Row count (showing 3): {len(rows)}")
            for row in rows:
                print(f"  {dict(zip(cols, row))}")
        except Exception as e:
            print(f"  Error: {e}")
