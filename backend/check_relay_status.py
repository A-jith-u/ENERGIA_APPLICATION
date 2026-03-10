"""Check relay mappings and device status."""
from sqlalchemy import create_engine, text

engine = create_engine('postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia')

print("="*80)
print("RELAY MAPPINGS TABLE")
print("="*80)
with engine.connect() as conn:
    result = conn.execute(text('SELECT room_id, relay_device_id, relay_channel FROM relay_mappings'))
    rows = list(result)
    print(f'Total mappings: {len(rows)}')
    print('-'*80)
    print(f'{"room_id":<20} | {"relay_device_id":<25} | {"channel":<10}')
    print('-'*80)
    for r in rows[:20]:
        print(f'{r[0]:<20} | {r[1]:<25} | {r[2]:<10}')

print("\n" + "="*80)
print("RELAY DEVICE STATUS (from relay_device_status table)")
print("="*80)
with engine.connect() as conn:
    try:
        result = conn.execute(text('SELECT device_id, is_online, state, last_seen FROM relay_device_status ORDER BY last_seen DESC'))
        rows = list(result)
        print(f'Total devices: {len(rows)}')
        print('-'*80)
        print(f'{"device_id":<25} | {"online":<10} | {"state":<10} | {"last_seen":<25}')
        print('-'*80)
        for r in rows[:10]:
            print(f'{r[0]:<25} | {str(r[1]):<10} | {r[2]:<10} | {str(r[3]):<25}')
    except Exception as e:
        print(f"Table doesn't exist or error: {e}")

print("\n" + "="*80)
print("RELAY LOGS (recent activity)")
print("="*80)
with engine.connect() as conn:
    result = conn.execute(text('SELECT room_id, action, timestamp FROM relay_logs ORDER BY timestamp DESC LIMIT 10'))
    rows = list(result)
    print(f'Total recent logs: {len(rows)}')
    print('-'*80)
    print(f'{"room_id":<20} | {"action":<10} | {"timestamp":<25}')
    print('-'*80)
    for r in rows:
        print(f'{r[0]:<20} | {r[1]:<10} | {str(r[2]):<25}')
