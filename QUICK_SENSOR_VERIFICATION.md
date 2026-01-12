# ⚡ QUICK REFERENCE: How to Verify Backend is Receiving ESP32 Data

## 🎯 FASTEST VERIFICATION (30 seconds)

```bash
# 1. Open PowerShell
# 2. Run this ONE command:

cd C:\Users\rapha\OneDrive\Desktop\project\backend && python check_sensor_data.py
```

**Look for:**
- ✅ `✓ Total records: X` = Data flowing!
- ❌ `❌ No records found (yet)` = Still waiting or endpoint issue

---

## 🔍 WHAT EACH OUTPUT MEANS

### Output 1: ✅ SUCCESS

```
✅ sensor_data table exists
✅ Total records: 5
✅ Device: ESP32-LAB-001
✅ Records in last 10 minutes: 2
✅ SUCCESS: Backend is receiving sensor data!
```

**Translation:** Everything works! Data is flowing from ESP32 to backend to database. ✅

---

### Output 2: ⏳ WAITING

```
❌ No records found (yet)
ℹ️  ESP32 will send data every 60 seconds
ℹ️  Check back in a minute
```

**Translation:** Backend is ready, but no ESP32 data yet. Wait 60 seconds and try again. ⏳

---

### Output 3: ❌ ERROR

```
❌ Database error: ...
❌ Error: ...
```

**Translation:** Backend or database issue. Check if `python start_server.py` is running.

---

## 🚀 5-MINUTE COMPLETE CHECK

### Step 1: Start Backend (if not running)
```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python start_server.py
# Wait for: INFO:     Uvicorn running on http://0.0.0.0:5000
```

### Step 2: Run Verification Script
```bash
python check_sensor_data.py
```

### Step 3: Interpret Results

| Result | Action |
|--------|--------|
| `✅ Total records: X` | ✅ Data is flowing! |
| `❌ No records: 0` | Power on ESP32 and wait 60s |
| `❌ ERROR` | Restart backend with `python start_server.py` |

### Step 4: Check ESP32 Serial Monitor
- ✅ Should show: `✓ HTTP Response: 200`
- ❌ If shows: `✗ HTTP Error` → Start backend

### Step 5: Wait & Recheck
```bash
# Wait 60 seconds, then:
python check_sensor_data.py
# Should show data from ESP32-LAB-001
```

---

## 📊 ENDPOINT STATUS

| Endpoint | URL | Status |
|----------|-----|--------|
| **Health** | `http://10.111.183.200:5000/health` | ✅ Exists |
| **POST Data** | `http://10.111.183.200:5000/api/sensor-data` | ✅ Exists |
| **GET Data** | `http://10.111.183.200:5000/api/sensor-data` | ✅ Exists |

---

## 🎯 DECISION TREE

```
Start: Is backend receiving data?
│
├─ Run: python check_sensor_data.py
│
├─ Output: "✅ SUCCESS: Backend is receiving..."
│  └─ YES → ✅ DONE! Data is flowing!
│
├─ Output: "❌ No records found (yet)"
│  ├─ Wait 60 seconds
│  ├─ Check ESP32 serial: "✓ HTTP Response: 200"?
│  ├─ If YES → Run script again
│  └─ If NO → Fix ESP32 WiFi/connection
│
└─ Output: "❌ ERROR:"
   ├─ Run: python start_server.py
   ├─ Wait 10 seconds
   └─ Try again: python check_sensor_data.py
```

---

## 🔧 COMMON ISSUES & INSTANT FIXES

| Issue | Fix |
|-------|-----|
| "❌ Error" in script | Run: `python start_server.py` (backend not running) |
| "❌ No records" | Wait 60 seconds, esp32 sends every minute |
| Endpoint 404 | IP address wrong? Should be: `10.111.183.200` |
| ESP32 "HTTP Error: 0" | Backend not responding, start it |
| ESP32 "WiFi failed" | Check WiFi: SSID=gecIi, PWD=66666666 |

---

## ✨ WHAT'S ALREADY DONE

✅ Backend endpoints created (`POST` & `GET /api/sensor-data`)
✅ Database table exists and ready
✅ Python verification script created
✅ IP configured correctly (10.111.183.200:5000)
✅ Flask server setup complete

**Waiting for:** ESP32 to power on and send data

---

## 📱 SIGNALS IN REAL-TIME

### ESP32 Serial Monitor (115200 baud)

**Every 60 seconds you should see:**

```
=== Sending 1-Minute Averaged Data ===
Samples: 6
Payload: {...}
✓ HTTP Response: 200          ← THIS IS SUCCESS! Data sent!
{"status":"success",...}      ← Backend confirmed receipt!
```

**If you see this:** Backend IS receiving data! ✅

---

## 🎯 ONE-LINER CHECKS

```bash
# Is backend running?
curl http://10.111.183.200:5000/health

# Is endpoint working?
curl http://10.111.183.200:5000/api/sensor-data

# Is data in database? (BEST)
cd backend && python check_sensor_data.py

# See recent records?
psql -h localhost -U postgres -d energia -c "SELECT * FROM sensor_data ORDER BY id DESC LIMIT 5;"
```

---

## 📋 VERIFICATION CHECKLIST

```
HARDWARE
☐ ESP32 powered on
☐ PZEM module connected (GPIO 16,17)
☐ WiFi antenna connected

NETWORK
☐ WiFi SSID: "gecIi"
☐ WiFi Password: "66666666"
☐ ESP32 shows "✓ WiFi connected"

BACKEND
☐ Server running: python start_server.py
☐ Port 5000 accessible
☐ Endpoint responds to requests

DATA
☐ ESP32 sends "POST /api/sensor-data"
☐ ESP32 receives "✓ HTTP Response: 200"
☐ Backend stores in database
☐ Database shows records

IF ALL ✅ → SYSTEM WORKING! 🎉
```

---

## 🚀 NEXT STEPS

1. ✅ **Verify Data Flowing**: Run `python check_sensor_data.py`
2. ✅ **Confirm Success**: See `✅ SUCCESS` message
3. ⏳ **Next**: Integrate into Flutter dashboard
4. ⏳ **Display**: Show real-time charts and metrics

---

## 📞 QUICK SUPPORT

**Having issues?**

1. Run: `python check_sensor_data.py`
2. Share output
3. Check one of these:
   - Is backend running?
   - Is ESP32 sending "✓ HTTP 200"?
   - Is WiFi connected?

**All set!** 🚀
