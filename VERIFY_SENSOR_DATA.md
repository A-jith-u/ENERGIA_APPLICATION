# 🔍 VERIFY SENSOR DATA RECEPTION

## 1. UNDERSTANDING THE FLOW

Your ESP32 is sending data to:
```
http://10.111.183.200:5000/api/sensor-data
```

Payload format:
```json
{
  "device_id": "ESP32-LAB-001",
  "voltage": 230.5,
  "current": 2.3,
  "power": 500.0,
  "energy": 1200.0,
  "frequency": 50.0,
  "power_factor": 0.95
}
```

---

## 2. VERIFICATION METHODS

### Method 1: Check Backend Endpoint Directly (CURL)

**Test if endpoint exists:**
```bash
# On Windows PowerShell
curl -X GET "http://10.111.183.200:5000/api/sensor-data" `
  -Headers @{"Content-Type"="application/json"}
```

**OR with Linux/Mac:**
```bash
curl -X GET http://10.111.183.200:5000/api/sensor-data \
  -H "Content-Type: application/json"
```

Expected Response:
- ✅ **200 OK** + JSON data = Endpoint works and has data
- ❌ **404 Not Found** = Endpoint doesn't exist (need to add it)
- ❌ **Connection refused** = Backend not running

---

### Method 2: Check Database Directly

**Connect to PostgreSQL and check sensor_data table:**

```bash
# Open PowerShell and connect to DB
psql -h localhost -U postgres -d energia
```

**Then run these SQL commands:**

```sql
-- Check if data exists in sensor_data table
SELECT COUNT(*) as total_records FROM sensor_data;

-- See latest 5 records
SELECT * FROM sensor_data ORDER BY id DESC LIMIT 5;

-- See all columns
\d sensor_data

-- Check device_id ESP32-LAB-001 records
SELECT * FROM sensor_data WHERE device_id = 'ESP32-LAB-001' ORDER BY id DESC LIMIT 10;

-- Count records by device
SELECT device_id, COUNT(*) as count FROM sensor_data GROUP BY device_id;
```

---

### Method 3: Check Backend Logs

**Watch Flask logs for incoming requests:**

```bash
# In terminal running backend, look for:
POST /api/sensor-data
```

**If you see the request, backend is receiving data!**

---

### Method 4: Python Database Check Script

**Create `check_sensor_data.py`:**

```python
import psycopg2
from datetime import datetime, timedelta

# Connect to PostgreSQL
conn = psycopg2.connect(
    host="localhost",
    database="energia",
    user="postgres",
    password="postgresql",
    port=5432
)
cur = conn.cursor()

print("=" * 50)
print("SENSOR DATA VERIFICATION")
print("=" * 50)

# Check table exists
cur.execute("""
    SELECT COUNT(*) FROM information_schema.tables 
    WHERE table_name = 'sensor_data'
""")
if cur.fetchone()[0] == 0:
    print("❌ ERROR: sensor_data table does not exist!")
    conn.close()
    exit(1)

# Count total records
cur.execute("SELECT COUNT(*) FROM sensor_data")
total = cur.fetchone()[0]
print(f"\n✓ Total records in sensor_data: {total}")

# Get unique devices
cur.execute("SELECT DISTINCT device_id FROM sensor_data")
devices = [row[0] for row in cur.fetchall()]
print(f"\n✓ Connected devices: {devices}")

# Show latest records
print("\n--- Latest 5 Records ---")
cur.execute("""
    SELECT id, device_id, voltage, current, power, frequency, created_at 
    FROM sensor_data 
    ORDER BY id DESC LIMIT 5
""")
for row in cur.fetchall():
    print(f"ID: {row[0]} | Device: {row[1]} | V: {row[2]:.2f}V | I: {row[3]:.2f}A | P: {row[4]:.2f}W | F: {row[5]:.2f}Hz | Time: {row[6]}")

# Check records in last hour
cur.execute("""
    SELECT COUNT(*) FROM sensor_data 
    WHERE created_at > NOW() - INTERVAL '1 hour'
""")
last_hour = cur.fetchone()[0]
print(f"\n✓ Records in last hour: {last_hour}")

# Check for ESP32-LAB-001 specifically
cur.execute("""
    SELECT COUNT(*) FROM sensor_data 
    WHERE device_id = 'ESP32-LAB-001'
""")
esp32_count = cur.fetchone()[0]
print(f"✓ Records from ESP32-LAB-001: {esp32_count}")

if esp32_count > 0:
    print("✅ SUCCESS: Backend is receiving ESP32 data!")
else:
    print("❌ No data from ESP32-LAB-001 yet")

conn.close()
print("\n" + "=" * 50)
```

**Run it:**
```bash
cd backend
python check_sensor_data.py
```

---

## 3. WHAT EACH RESPONSE MEANS

| Scenario | What It Means | Next Step |
|----------|---------------|-----------|
| ✅ Database shows records | Backend received data | Data is flowing! |
| ❌ 404 error on endpoint | Endpoint not created | Add endpoint to auth_api.py |
| ❌ Connection refused | Backend not running | Start backend: `python start_server.py` |
| ✅ Endpoint returns data | Everything working | Integrate into Flutter |
| ❌ ESP32 shows "HTTP Error" | Backend endpoint missing | Create endpoint |
| ✅ Flutter displays data | Complete success! | All done! |

---

## 4. QUICK CHECKLIST

```
☐ Step 1: Is backend running?
   → Run: python start_server.py (in backend folder)

☐ Step 2: Does endpoint exist?
   → Test: curl http://10.111.183.200:5000/api/sensor-data

☐ Step 3: Is ESP32 connected to WiFi?
   → Check: ESP32 serial output shows "WiFi connected"

☐ Step 4: Is data in database?
   → Run: python check_sensor_data.py

☐ Step 5: Is endpoint receiving POST requests?
   → Watch: Backend console logs for POST /api/sensor-data

If all YES → Data is flowing! ✅
```

---

## 5. ENDPOINT STATUS

**Current Status:** ⏳ **PENDING - NEEDS TO BE CREATED**

**Endpoint Definition:**
- **URL:** `POST http://10.111.183.200:5000/api/sensor-data`
- **Method:** POST
- **Expected Payload:** JSON with voltage, current, power, etc.
- **Table:** `sensor_data` in PostgreSQL
- **Status Code:** Should return 200 or 201

**File to Edit:** `backend/auth_api.py`

---

## 6. TROUBLESHOOTING

### Problem: "Connection refused"
```
❌ ERROR: ('Connection refused')
```
**Solution:**
```bash
# Check if backend is running
python backend/start_server.py

# Check if port 5000 is listening
netstat -an | find "5000"
```

### Problem: "404 Not Found"
```
❌ ERROR: 404 Not Found
```
**Solution:**
- Endpoint `/api/sensor-data` doesn't exist
- Need to add endpoint to `auth_api.py`

### Problem: ESP32 shows "HTTP Error: 0"
```
✗ HTTP Error: 0
```
**Solution:**
- Backend endpoint not responding
- Check if endpoint is created
- Check server is running

### Problem: No data in database
```
✓ Total records: 0
```
**Solution:**
1. Check ESP32 is sending requests (check serial output)
2. Check endpoint is receiving POST requests
3. Check database table exists: `SELECT * FROM sensor_data LIMIT 1;`

---

## 7. EXPECTED LOG OUTPUT (ESP32)

When working correctly, you should see:

```
=== Sending 1-Minute Averaged Data ===
Samples: 6
Payload: {"device_id":"ESP32-LAB-001","voltage":230.5,"current":2.3,"power":500.0,"energy":1200.0,"frequency":50.0,"power_factor":0.95}
✓ HTTP Response: 200
```

If you see:
- ✅ "✓ HTTP Response: 200" → Data received by backend!
- ❌ "✗ HTTP Error: 0" → Endpoint doesn't exist or backend not running
- ❌ "WiFi not connected" → ESP32 WiFi issue

---

## 8. NEXT STEPS

**IF data is being received:**
1. ✅ Backend endpoint created
2. ✅ Database stores data
3. → Next: Update Flutter service to fetch this data
4. → Then: Display on dashboard

**IF data is NOT being received:**
1. → Create the backend endpoint
2. → Restart backend
3. → Verify ESP32 is sending (check serial monitor)
4. → Try again

---

## 9. QUICK START VERIFICATION

```bash
# 1. Run this script
cd backend
python check_sensor_data.py

# 2. Expected output:
# ✓ Total records in sensor_data: 5
# ✓ Connected devices: ['ESP32-LAB-001']
# ✓ Records in last hour: 5
# ✓ Records from ESP32-LAB-001: 5
# ✅ SUCCESS: Backend is receiving ESP32 data!
```

---

## Summary

**To verify data flow:**
1. Check database: `python check_sensor_data.py`
2. Check endpoint: `curl http://10.111.183.200:5000/api/sensor-data`
3. Check logs: Watch backend console
4. Check ESP32: Watch serial output for "✓ HTTP Response: 200"

**If all steps pass = Data is flowing!** ✅
