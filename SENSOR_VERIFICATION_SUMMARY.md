# 📊 SENSOR DATA FLOW: VERIFICATION & NEXT STEPS

## 🎯 Current Situation

Your ESP32 with PZEM-004T is ready to send sensor data. The backend endpoints are already created. Now you need to verify if data is flowing from ESP32 → Backend → Database.

---

## ✅ What's Already Done

| Component | Status | File/Location |
|-----------|--------|---------------|
| **Backend Endpoint** | ✅ CREATED | `backend/auth_api.py` line 906 |
| **POST /api/sensor-data** | ✅ READY | Receives & stores data |
| **GET /api/sensor-data** | ✅ READY | Retrieves stored data |
| **Database Table** | ✅ EXISTS | `sensor_data` (id, ds, device_id, value) |
| **Flutter Service** | ✅ CREATED | `lib/services/sensor_service.dart` |
| **Verification Script** | ✅ CREATED | `backend/check_sensor_data.py` |
| **IP Configuration** | ✅ DONE | 10.111.183.200:5000 |

---

## 🔍 How to Identify if Backend is Getting Data

### QUICKEST METHOD: Run Python Script

```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python check_sensor_data.py
```

**Output shows:**
- ✅ Total records in database
- ✅ Connected devices
- ✅ Latest readings
- ✅ Records in last 10 minutes

**Result:**
```
✅ Total records: 5
✅ Device: ESP32-LAB-001
✅ SUCCESS: Backend is receiving sensor data!
```

---

### 4 VERIFICATION METHODS

#### Method 1: Database Query
```bash
# Connect to PostgreSQL
psql -h localhost -U postgres -d energia

# Check records
SELECT COUNT(*) FROM sensor_data;
SELECT * FROM sensor_data ORDER BY id DESC LIMIT 5;
```

#### Method 2: Backend Console
```bash
# Keep terminal running backend
python start_server.py

# Watch for:
# POST /api/sensor-data
# HTTP 200
```

#### Method 3: Test Endpoint
```bash
# Check if endpoint responds
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
```

#### Method 4: Automated Script
```bash
python check_sensor_data.py
```

---

## 📋 ESP32 Serial Monitor Signals

### ✅ Good Signs (Data is Flowing)

```
✓ WiFi connected
IP Address: 192.168.x.x
✓ PZEM module connected successfully!

--- 10s Sensor Sample ---
Sample count: 1
Sample count: 2
...
Sample count: 6

=== Sending 1-Minute Averaged Data ===
Payload: {"device_id":"ESP32-LAB-001","voltage":230.5,"current":2.3,...}
✓ HTTP Response: 200
{"status":"success",...}
```

### ❌ Bad Signs (Troubleshoot)

```
✗ WiFi connection failed       → Check WiFi network
✗ PZEM module not detected     → Check sensor connections
✗ HTTP Error: 0                → Backend not responding
WiFi not connected. Data sent. → WiFi disconnected
```

---

## 🚀 Step-by-Step Verification Process

### 1. Ensure Backend is Running
```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python start_server.py
# Wait for: INFO:     Uvicorn running on http://0.0.0.0:5000
```

### 2. Check Backend Health
```bash
Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get
# Expected: StatusCode 200, Content: {"status":"ok"}
```

### 3. Verify Endpoint Exists
```bash
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
# Expected: StatusCode 200, "count": 0 (or more if data exists)
```

### 4. Check Database (Current)
```bash
cd backend
python check_sensor_data.py
# Expected: Shows table exists, waiting for data OR shows records
```

### 5. Power On ESP32
- Connect to power
- Open Serial Monitor (115200 baud)
- Watch for WiFi connection message

### 6. Wait 60 Seconds
- ESP32 sends data every 60 seconds
- Watch for "✓ HTTP Response: 200"

### 7. Verify Data in Database
```bash
cd backend
python check_sensor_data.py
# Expected: Shows ESP32-LAB-001 data with ✅ SUCCESS message
```

---

## 📊 Data Flow Diagram

```
ESP32 + PZEM-004T
    ↓ (Every 60 seconds)
    │ HTTP POST
    │ JSON: {device_id, voltage, current, power, frequency, energy, power_factor}
    ↓
Backend API Server (10.111.183.200:5000)
    ├─ POST /api/sensor-data
    │   ├─ Validates JSON
    │   ├─ Extracts power value
    │   └─ Stores in database
    ├─ GET /api/sensor-data
    │   └─ Retrieves stored data
    └─ Logs activity
    ↓
PostgreSQL Database (localhost:5432)
    └─ sensor_data table
        ├─ id (auto-increment)
        ├─ ds (timestamp)
        ├─ device_id (ESP32-LAB-001)
        └─ value (power in watts)
```

---

## 🔧 Backend Endpoints Reference

### POST /api/sensor-data

**Receive data from ESP32**

```
URL: http://10.111.183.200:5000/api/sensor-data
Method: POST
Content-Type: application/json

Request Body:
{
  "device_id": "ESP32-LAB-001",
  "voltage": 230.5,
  "current": 2.3,
  "power": 500.0,
  "energy": 1200.0,
  "frequency": 50.0,
  "power_factor": 0.95
}

Response (200 OK):
{
  "status": "success",
  "message": "Sensor data from ESP32-LAB-001 received and stored",
  "device_id": "ESP32-LAB-001",
  "value": 500.0,
  "timestamp": "2026-01-03T10:30:00..."
}
```

### GET /api/sensor-data

**Retrieve stored data**

```
URL: http://10.111.183.200:5000/api/sensor-data
Method: GET
Optional: ?device_id=ESP32-LAB-001&limit=10

Response (200 OK):
{
  "status": "success",
  "count": 5,
  "data": [
    {
      "id": 5,
      "timestamp": "2026-01-03T10:30:00",
      "device_id": "ESP32-LAB-001",
      "value": 500.0
    },
    ...
  ]
}
```

---

## 📁 Documentation Files Created

| File | Purpose | Read Time |
|------|---------|-----------|
| `VERIFY_SENSOR_DATA.md` | Quick verification methods | 5 min |
| `BACKEND_VERIFICATION_GUIDE.md` | Complete backend testing | 10 min |
| `ENDPOINT_TESTING_GUIDE.md` | Endpoint reference & tests | 10 min |
| `ESP32_DATA_VERIFICATION_COMPLETE.md` | Comprehensive guide | 15 min |
| `backend/check_sensor_data.py` | Automated verification | Run it |

---

## 🎯 Quick Verification Commands

```bash
# 1. Start backend (if not running)
cd backend
python start_server.py

# 2. Check if data is in database (FASTEST)
python check_sensor_data.py

# 3. Manual database check
psql -h localhost -U postgres -d energia
SELECT COUNT(*) FROM sensor_data;
\q

# 4. Test endpoint manually
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
```

---

## ⏱️ Expected Timeline

```
T+0:00   - Power on ESP32
T+0:10   - ESP32 reads sensor data (sample 1)
T+0:20   - Sample 2
T+0:30   - Sample 3
T+0:40   - Sample 4
T+0:50   - Sample 5
T+1:00   - Sample 6 + HTTP POST to backend ✓
          Backend receives and stores ✓
          Database has 1 record ✓
T+2:00   - Second reading sent
T+3:00   - Third reading sent
```

---

## 🔍 Troubleshooting Quick Reference

| Problem | Check | Solution |
|---------|-------|----------|
| Backend not responding | Is it running? | `python start_server.py` |
| Endpoint returns 404 | URL correct? | Check: `http://10.111.183.200:5000/api/sensor-data` |
| ESP32 shows HTTP Error | Backend running? | Restart with `python start_server.py` |
| No WiFi | WiFi network? | Check SSID: "gecIi" password: "66666666" |
| PZEM not detected | Connections? | Check GPIO 16,17 connected to PZEM |
| No data after 5 min | Any errors? | Check `python check_sensor_data.py` |

---

## ✅ Success Indicators

You'll know everything is working when:

```
✅ Backend console shows: POST /api/sensor-data
✅ ESP32 serial shows: ✓ HTTP Response: 200
✅ Database query shows: SELECT COUNT(*) = 5 (or more)
✅ Script shows: ✅ SUCCESS: Backend is receiving sensor data!
```

---

## 📱 Integration Path (Next Steps)

### Phase 1: Verification ✅ (CURRENT)
- [x] Create backend endpoints
- [x] Create verification script
- [ ] Confirm data is flowing

### Phase 2: Flutter Integration
- [ ] Update Flutter service
- [ ] Integrate into dashboard
- [ ] Display charts & metrics

### Phase 3: Production
- [ ] Test multiple ESP32s
- [ ] Monitor data quality
- [ ] Set up alerts

---

## 📞 If You Need Help

**Run this and share output:**
```bash
cd backend
python check_sensor_data.py
```

**Also check:**
1. Is ESP32 showing "✓ HTTP Response: 200"?
2. Is backend showing "POST /api/sensor-data"?
3. What's the database error (if any)?

---

## Summary

```
╔════════════════════════════════════════════════════╗
║         VERIFICATION STATUS CHECKLIST              ║
╠════════════════════════════════════════════════════╣
║ Backend Endpoint        ✅ EXISTS                  ║
║ Database Table          ✅ EXISTS                  ║
║ Python Script           ✅ CREATED                 ║
║ Documentation           ✅ 4 GUIDES                ║
║ IP Configuration        ✅ DONE (10.111.183.200)   ║
║                                                    ║
║ ESP32 Data              ⏳ WAITING                 ║
║ Next Step               → Power on ESP32           ║
║                           Wait 60 seconds          ║
║                           Run check script         ║
╚════════════════════════════════════════════════════╝
```

---

## Final Checklist

```
☐ Backend running?        → python start_server.py
☐ Data in database?       → python check_sensor_data.py
☐ ESP32 powered on?       → Serial monitor shows WiFi
☐ HTTP successful?        → Serial shows "✓ HTTP 200"
☐ 60 seconds passed?      → Wait for first data send

✅ If all checked → Data is flowing!
```

**Ready to proceed!** 🚀
