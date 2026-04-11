from sqlalchemy import create_engine, text

engine = create_engine("postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia")

with engine.connect() as conn:
    # 1. Column list
    cols = conn.execute(text(
        "SELECT column_name, data_type FROM information_schema.columns "
        "WHERE table_name='sensor_data' ORDER BY ordinal_position"
    )).fetchall()
    print("=== sensor_data COLUMNS ===")
    for c in cols:
        print(f"  {c[0]:<25} {c[1]}")

    # 2. Latest 5 rows
    rows = conn.execute(text(
        "SELECT id, ds, device_id, power, current, voltage, energy, frequency, power_factor, occupancy "
        "FROM sensor_data ORDER BY ds DESC LIMIT 5"
    )).fetchall()
    print("\n=== LATEST 5 ROWS ===")
    for r in rows:
        print(f"  id={r[0]}  ds={r[1]}  device={r[2]}  power={r[3]}  current={r[4]}  "
              f"voltage={r[5]}  energy={r[6]}  freq={r[7]}  pf={r[8]}  occ={r[9]}")

    # 3. Frequency coverage
    cnt = conn.execute(text("SELECT COUNT(*) FROM sensor_data WHERE frequency IS NOT NULL")).scalar()
    total = conn.execute(text("SELECT COUNT(*) FROM sensor_data")).scalar()
    print(f"\n=== frequency non-null: {cnt} / {total} total rows ===")

    # 4. Most recent row that actually has a frequency value
    recent_freq = conn.execute(text(
        "SELECT id, ds, device_id, power, frequency FROM sensor_data "
        "WHERE frequency IS NOT NULL ORDER BY ds DESC LIMIT 3"
    )).fetchall()
    print("\n=== MOST RECENT ROWS WITH frequency ===")
    if recent_freq:
        for r in recent_freq:
            print(f"  id={r[0]}  ds={r[1]}  device={r[2]}  power={r[3]}  freq={r[4]}")
    else:
        print("  (none yet — frequency column exists but no values saved yet)")
