# 🔍 ESP32 SENSOR DATA VERIFICATION: COMPLETE GUIDE

## Current Status Report

```
╔═══════════════════════════════════════════════════════════════╗
║                    SYSTEM STATUS REPORT                       ║
╠═══════════════════════════════════════════════════════════════╣
║ Database Table              ✅ EXISTS (sensor_data)           ║
║ Backend Endpoints           ✅ CREATED (/api/sensor-data)     ║
║ Backend Server              ⏳ NOT RUNNING (start needed)     ║
║ ESP32 Code                  ✅ PROVIDED                       ║
║ Data Received               ⏳ WAITING (0 records)             ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## How to Identify if Backend is Receiving Data

### Method 1: Automatic Verification (RECOMMENDED)

**Run this Python script to check everything:**

```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python check_sensor_data.py
```

**Output will show:**
```
✅ Total records: 5
✅ Device: ESP32-LAB-001
✅ SUCCESS: Backend is receiving sensor data!
```

**Or if waiting:**
```
❌ No records found (yet)
ℹ️  ESP32 will send data every 60 seconds
```

---

### Method 2: Manual Database Query

**Connect to PostgreSQL:**

```bash
# Open PowerShell
psql -h localhost -U postgres -d energia

# Then run:
SELECT COUNT(*) as total_records FROM sensor_data;
SELECT * FROM sensor_data ORDER BY id DESC LIMIT 5;
```

**Results:**
- ✅ If you see records → Backend is receiving data!
- ❌ If you see 0 records → Still waiting or endpoint issue

---

### Method 3: Check Backend Logs

**Keep terminal open while running backend:**

```bash
cd backend
python start_server.py
```

**Watch for HTTP requests:**
- ✅ You should see: `POST /api/sensor-data`
- ✅ Followed by: `HTTP 200` response code

If you see these messages, backend is receiving data!

---

### Method 4: Test Endpoint Manually

**Test if endpoint is working:**

```bash
# Test 1: Health check
Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get

# Test 2: Get data endpoint
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get

# Test 3: Post test data (simulate ESP32)
$body = @{
    device_id = "TEST"
    power = 500.0
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" `
  -Method Post `
  -Headers @{"Content-Type"="application/json"} `
  -Body $body
```

**Expected:**
- Status Code: 200
- Response includes: `"status":"success"`

If endpoints respond → Backend is working!

---

## Complete Verification Workflow

### Step 1: Start Backend Server

```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python start_server.py
```

**You should see:**
```
INFO:     Uvicorn running on http://0.0.0.0:5000
```

✅ Backend is now listening on port 5000

---

### Step 2: Verify Backend is Responding

```bash
# PowerShell
$response = Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get
Write-Host "Status: $($response.StatusCode)"
Write-Host "Content: $($response.Content)"
```

**Expected Output:**
```
Status: 200
Content: {"status":"ok"}
```

✅ Backend is responding to requests

---

### Step 3: Check Endpoint Exists

```bash
# PowerShell
$response = Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
Write-Host "Status: $($response.StatusCode)"
Write-Host "Content: $($response.Content)"
```

**Expected Output:**
```
Status: 200
Content: {
  "status": "success",
  "count": 0,
  "data": []
}
```

✅ Endpoint exists and is reachable

---

### Step 4: Send Test Data to Verify Endpoint Works

```bash
# PowerShell
$testData = @{
    device_id = "TEST-DEVICE"
    voltage = 230.5
    current = 2.3
    power = 500.0
    energy = 1200.0
    frequency = 50.0
    power_factor = 0.95
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" `
  -Method Post `
  -Headers @{"Content-Type"="application/json"} `
  -Body $testData

Write-Host "Status: $($response.StatusCode)"
Write-Host "Content: $($response.Content)"
```

**Expected Output:**
```
Status: 200
Content: {
  "status": "success",
  "message": "Sensor data from TEST-DEVICE received and stored",
  "device_id": "TEST-DEVICE",
  "value": 500.0,
  "timestamp": "2026-01-03T..."
}
```

✅ Endpoint accepts and stores data

---

### Step 5: Verify Data in Database

```bash
# PowerShell
cd backend
python check_sensor_data.py
```

**Expected Output:**
```
✅ sensor_data table exists
✅ Total records: 1
✅ Device: TEST-DEVICE
✅ Latest reading: 500.00W
```

✅ Data successfully stored in database

---

### Step 6: Power On ESP32 and Wait

**Now that backend is verified:**

1. Upload the provided ESP32 code to your ESP32
2. Open Arduino Serial Monitor (115200 baud)
3. Watch for these messages:

✅ **Good signs:**
```
✓ WiFi connected
IP Address: 192.168.x.x
✓ PZEM module connected successfully!
--- 10s Sensor Sample ---
Sample count: 1
...
Sample count: 6
=== Sending 1-Minute Averaged Data ===
Payload: {"device_id":"ESP32-LAB-001",...}
✓ HTTP Response: 200
```

❌ **Bad signs:**
```
✗ WiFi connection failed
✗ PZEM module not detected!
✗ HTTP Error: 0
```

---

### Step 7: Verify ESP32 Data in Database

**After ESP32 sends data (60 seconds), run:**

```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python check_sensor_data.py
```

**Expected Output:**
```
✅ Total records: 1
✅ Device: ESP32-LAB-001
✅ Records in last 10 minutes: 1
✅ SUCCESS: Backend is receiving sensor data!
```

✅ **COMPLETE SUCCESS!** Data is flowing from ESP32 → Backend → Database

---

## Quick Verification Checklist

```
☐ Step 1: Backend Running
  Command: python start_server.py
  Expected: "Uvicorn running on http://0.0.0.0:5000"

☐ Step 2: Health Check
  Command: Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get
  Expected: StatusCode 200

☐ Step 3: Endpoint Exists
  Command: Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
  Expected: StatusCode 200, "count": 0

☐ Step 4: POST Works
  Command: Send test JSON data via POST
  Expected: StatusCode 200, "status": "success"

☐ Step 5: Data in Database
  Command: python check_sensor_data.py
  Expected: Shows 1 record from TEST-DEVICE

☐ Step 6: ESP32 Connected
  Expected: Serial monitor shows "✓ WiFi connected"

☐ Step 7: Data Flowing
  Command: python check_sensor_data.py (after 60 seconds)
  Expected: Shows data from ESP32-LAB-001
  
✅ IF ALL CHECKS PASS → SYSTEM IS WORKING!
```

---

## What Each Signal Means

### ESP32 Serial Monitor Signals

| Signal | Meaning | Status |
|--------|---------|--------|
| `✓ WiFi connected` | ESP32 has network | ✅ Good |
| `✗ WiFi connection failed` | No WiFi | ❌ Check network |
| `✓ PZEM module connected` | Sensor detected | ✅ Good |
| `✗ PZEM module not detected` | Sensor offline | ❌ Check connections |
| `--- 10s Sensor Sample ---` | Reading sensor | ✅ Good |
| `Sample count: 6` | 60-second cycle ready | ✅ Good |
| `Payload: {...}` | Data to send | ✅ Good |
| `✓ HTTP Response: 200` | Backend received | ✅ **SUCCESS** |
| `✗ HTTP Error: 0` | Backend not responding | ❌ Start backend |
| `WiFi not connected` | Disconnected | ❌ Check WiFi |

### Backend Console Signals

| Signal | Meaning | Status |
|--------|---------|--------|
| `POST /api/sensor-data` | Request received | ✅ Data flowing |
| `HTTP 200` | Success response | ✅ Stored |
| `Connection refused` | Backend down | ❌ Start server |
| `No matching route` | Endpoint missing | ❌ Restart |

### Database Signals

| Signal | Meaning | Status |
|--------|---------|--------|
| `Total records: 5` | Data present | ✅ Stored |
| `Total records: 0` | No data | ⏳ Waiting |
| `Device: ESP32-LAB-001` | Specific device | ✅ Identified |
| `Records in last 10min: 2` | Active data | ✅ Flowing |

---

## Troubleshooting Decision Tree

```
START
│
├─ Is backend running?
│  ├─ YES → Go to Step 2
│  └─ NO → Run: python start_server.py
│
├─ Does health endpoint respond?
│  ├─ YES → Go to Step 3
│  └─ NO → Check: IP address, port, firewall
│
├─ Does /api/sensor-data endpoint exist?
│  ├─ YES → Go to Step 4
│  └─ NO → Check: auth_api.py (should be at line 906)
│
├─ Can you POST test data?
│  ├─ YES → Go to Step 5
│  └─ NO → Check: JSON format, headers
│
├─ Is test data in database?
│  ├─ YES → Go to Step 6
│  └─ NO → Check: Database connection, table permissions
│
├─ Is ESP32 connected to WiFi?
│  ├─ YES → Go to Step 7
│  └─ NO → Check: WiFi SSID, password, router
│
├─ Is ESP32 sending HTTP requests?
│  ├─ YES → Go to Step 8
│  └─ NO → Check: Serial monitor, IP address
│
└─ Is ESP32 data in database?
   ├─ YES → ✅ SUCCESS!
   └─ NO → Run: python check_sensor_data.py
```

---

## Complete Flow Diagram

```
┌──────────────────────────────────────┐
│   ESP32 with PZEM-004T Module        │
│  (Reads every 10s, sends every 60s)  │
└────────────────┬─────────────────────┘
                 │
                 │ HTTP POST
                 │ JSON: {device_id, voltage, current, power, ...}
                 │
                 ▼
┌──────────────────────────────────────┐
│   Backend FastAPI Server             │
│   http://10.111.183.200:5000         │
│   POST /api/sensor-data              │
└────────────────┬─────────────────────┘
                 │
                 │ Validate & Store
                 │
                 ▼
┌──────────────────────────────────────┐
│   PostgreSQL Database                │
│   localhost:5432 - energia           │
│   Table: sensor_data                 │
│   (id, ds, device_id, value)         │
└────────────────┬─────────────────────┘
                 │
                 │ Query & Fetch
                 │
                 ▼
┌──────────────────────────────────────┐
│   Flutter Mobile App                 │
│   GET /api/sensor-data               │
│   Display charts & metrics           │
└──────────────────────────────────────┘
```

---

## Next Steps After Verification

**Once you confirm data is flowing (✅ all checks pass):**

### 1. Update Flutter Service
- Modify `lib/services/sensor_service.dart`
- Change endpoint if needed: `/api/sensor-data`

### 2. Integrate into Dashboard
- Update `lib/dashboard_page.dart`
- Import `sensor_service`
- Display voltage, current, power readings
- Add real-time charts

### 3. Real-time Updates
- Implement polling every 30 seconds
- Show "Last updated: X seconds ago"

### 4. Production Deployment
- Test with multiple ESP32s
- Monitor database growth
- Set up data retention policy

---

## Files You Now Have

✅ `VERIFY_SENSOR_DATA.md` - Quick verification methods
✅ `BACKEND_VERIFICATION_GUIDE.md` - Detailed backend testing
✅ `ENDPOINT_TESTING_GUIDE.md` - Endpoint reference and testing
✅ `backend/check_sensor_data.py` - Automated verification script
✅ `lib/services/sensor_service.dart` - Flutter service (ready)

---

## Quick Reference Commands

```bash
# Start backend
cd backend
python start_server.py

# Check data in database
cd backend
python check_sensor_data.py

# Connect to database directly
psql -h localhost -U postgres -d energia

# Test health endpoint
Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get

# Test sensor endpoint
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get

# View latest records in database
# SELECT * FROM sensor_data ORDER BY id DESC LIMIT 5;
```

---

## Summary

**To verify if backend is receiving sensor data:**

1. **Automatic**: Run `python check_sensor_data.py`
2. **Manual**: Query database with `SELECT * FROM sensor_data;`
3. **Backend**: Watch console for `POST /api/sensor-data`
4. **Testing**: Send test data and verify response

**Status**: Everything is ready! Just need ESP32 to send data. ✅

**Next**: Wait for ESP32 to power on and start sending data (every 60 seconds).

---

## Support

If you need to verify:
1. Run: `python check_sensor_data.py`
2. Share the output
3. Check backend console for errors
4. Check ESP32 serial monitor for WiFi/HTTP status
5. Verify IP address is correct: `10.111.183.200:5000`
