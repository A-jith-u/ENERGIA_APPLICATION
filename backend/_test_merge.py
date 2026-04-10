import requests, time
from sqlalchemy import create_engine, text

engine = create_engine("postgresql+psycopg2://postgres:ajith%40@localhost:5432/energia")

# Clean up any prior test rows
with engine.begin() as conn:
    conn.execute(text("DELETE FROM sensor_data WHERE device_id='TEST-MERGE'"))

# POST occupancy only (simulating camera device)
r1 = requests.post("http://localhost:5000/sensor-data", json={"device_id": "TEST-MERGE", "human_present": 1})
print("Occ-only POST:", r1.status_code, r1.json())

# POST power data 2 seconds later (simulating power sensor arriving slightly behind)
time.sleep(2)
r2 = requests.post("http://localhost:5000/sensor-data", json={
    "device_id": "TEST-MERGE",
    "power": 120.5, "current": 0.55, "voltage": 230.0,
    "energy": 6.1, "frequency": 50.1, "power_factor": 0.95
})
print("Power POST:    ", r2.status_code, r2.json())

# Check DB – should be ONE merged row with both occupancy and power
with engine.connect() as conn:
    rows = conn.execute(text(
        "SELECT id, ds, power, frequency, occupancy FROM sensor_data WHERE device_id='TEST-MERGE' ORDER BY ds DESC LIMIT 5"
    )).fetchall()
    print("\nRows in DB for TEST-MERGE:")
    for r in rows:
        print(f"  id={r[0]}  ds={r[1]}  power={r[2]}  freq={r[3]}  occ={r[4]}")
    if len(rows) == 1 and rows[0][2] is not None and rows[0][4] is not None:
        print("  => MERGED correctly into 1 row with both power and occupancy [OK]")
    elif len(rows) > 1:
        print(f"  => PROBLEM: {len(rows)} separate rows created instead of merging")

# Cleanup
with engine.begin() as conn:
    conn.execute(text("DELETE FROM sensor_data WHERE device_id='TEST-MERGE'"))
print("\nTest rows cleaned up.")
