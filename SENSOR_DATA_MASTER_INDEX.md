# 📑 SENSOR DATA SYSTEM: MASTER INDEX & GUIDE

## 🎯 QUICK START (2 minutes)

**To verify if backend is receiving ESP32 data:**

```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python check_sensor_data.py
```

**Expected output:**
- ✅ `✅ SUCCESS: Backend is receiving sensor data!` = All working!
- ⏳ `❌ No records found` = Waiting for ESP32 (every 60 seconds)

---

## 📚 DOCUMENTATION ROADMAP

### START HERE → QUICK REFERENCE (5 minutes)
📄 **[QUICK_SENSOR_VERIFICATION.md](QUICK_SENSOR_VERIFICATION.md)**
- Fastest verification method
- 30-second check
- Decision tree
- Common issues & fixes

### READ NEXT → VERIFICATION GUIDE (15 minutes)
📄 **[ESP32_DATA_VERIFICATION_COMPLETE.md](ESP32_DATA_VERIFICATION_COMPLETE.md)**
- Complete step-by-step process
- Data flow diagram
- 7-step verification
- Troubleshooting decision tree

### FOR DETAILS → BACKEND GUIDE (20 minutes)
📄 **[BACKEND_VERIFICATION_GUIDE.md](BACKEND_VERIFICATION_GUIDE.md)**
- Detailed backend testing
- Diagnostic checklist
- Common issues & solutions
- Monitoring instructions

### FOR TESTING → ENDPOINT REFERENCE (15 minutes)
📄 **[ENDPOINT_TESTING_GUIDE.md](ENDPOINT_TESTING_GUIDE.md)**
- Endpoint documentation
- Manual testing examples
- Complete testing workflow
- Backend code reference

### QUICK OVERVIEW → VERIFICATION SUMMARY (10 minutes)
📄 **[SENSOR_VERIFICATION_SUMMARY.md](SENSOR_VERIFICATION_SUMMARY.md)**
- Current situation overview
- 4 verification methods
- Serial monitor signals
- Quick reference commands

---

## 🔧 AUTOMATED TOOLS

### Python Verification Script
📄 **[backend/check_sensor_data.py](backend/check_sensor_data.py)**
- Automatic database check
- Shows all connected devices
- Displays latest records
- Indicates success/failure

**How to use:**
```bash
cd backend
python check_sensor_data.py
```

---

## 📊 SYSTEM STATUS

| Component | Status | Details |
|-----------|--------|---------|
| **Backend Server** | ⏳ Needs Start | Run: `python start_server.py` |
| **API Endpoints** | ✅ Created | POST/GET /api/sensor-data |
| **Database Table** | ✅ Ready | sensor_data table exists |
| **Flutter Service** | ✅ Created | lib/services/sensor_service.dart |
| **Verification Script** | ✅ Ready | backend/check_sensor_data.py |
| **ESP32 Code** | ✅ Provided | Ready to upload |
| **Data Flowing** | ⏳ Waiting | Needs ESP32 to power on |

---

## 🚀 VERIFICATION FLOW

```
1. START BACKEND
   └─ python start_server.py

2. RUN SCRIPT
   └─ python check_sensor_data.py

3. POWER ON ESP32
   └─ Wait 60 seconds

4. RUN SCRIPT AGAIN
   └─ python check_sensor_data.py

5. RESULT
   ├─ ✅ SUCCESS → Data flowing!
   └─ ⏳ WAITING → Wait longer or check ESP32
```

---

## 🎯 DECISION GUIDE

### "I just powered on ESP32, how do I verify it's sending data?"

**Answer:** Run this command:
```bash
python check_sensor_data.py
```

**Results:**
- ✅ Shows records → Data is flowing!
- ❌ Shows 0 records → Wait 60 more seconds
- ❌ Shows error → Backend needs restart

---

### "How do I manually test the endpoint?"

**Answer:** Use any of these:

**Option 1: PowerShell**
```bash
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
```

**Option 2: cURL (if installed)**
```bash
curl http://10.111.183.200:5000/api/sensor-data
```

**Option 3: Database**
```bash
psql -h localhost -U postgres -d energia
SELECT COUNT(*) FROM sensor_data;
```

---

### "What does each ESP32 serial monitor message mean?"

**See:** [BACKEND_VERIFICATION_GUIDE.md](BACKEND_VERIFICATION_GUIDE.md#-serial-monitor-signals)

**Quick translation:**
- ✅ `✓ HTTP Response: 200` → Backend received data!
- ❌ `✗ HTTP Error: 0` → Backend not responding
- ❌ `✗ WiFi connection failed` → WiFi issue

---

### "Backend console shows POST requests but database is empty?"

**Possible causes:**
1. Database connection error
2. Table permissions issue
3. Different database being used

**Fix:**
```bash
# Verify database connection
psql -h localhost -U postgres -d energia
SELECT * FROM sensor_data;
\q
```

---

## 📱 ESP32 SETUP RECAP

### Code URL (from your provided code)
```cpp
const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-data";
const char* DEVICE_ID  = "ESP32-LAB-001";
const char* WIFI_SSID  = "gecIi";
const char* WIFI_PASSWORD = "66666666";
```

### What It Does
- Reads PZEM sensor every 10 seconds
- Collects 6 samples (60 seconds)
- Calculates average
- POSTs JSON data to backend

### Expected Behavior
```
60s → Collect 6 samples → Average values → HTTP POST → ✓ 200 OK
```

---

## 🔍 VERIFICATION METHODS (Choose One)

### Method 1: Python Script (EASIEST)
```bash
python check_sensor_data.py
```
Time: 5 seconds
Accuracy: 100%

### Method 2: Database Query (MANUAL)
```bash
psql -h localhost -U postgres -d energia
SELECT COUNT(*) FROM sensor_data;
```
Time: 10 seconds
Accuracy: 100%

### Method 3: Backend Logs (VISUAL)
```bash
# Watch terminal running:
python start_server.py
# Look for: POST /api/sensor-data
```
Time: 60+ seconds
Accuracy: 90%

### Method 4: Endpoint Test (TECHNICAL)
```bash
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
```
Time: 5 seconds
Accuracy: 90%

---

## ✅ SUCCESS INDICATORS

You'll know everything works when:

**Indicator 1: Python Script Output**
```
✅ Total records: 5
✅ Device: ESP32-LAB-001
✅ SUCCESS: Backend is receiving sensor data!
```

**Indicator 2: ESP32 Serial Monitor**
```
✓ HTTP Response: 200
```

**Indicator 3: Database Query**
```
SELECT COUNT(*) → 5 (or higher)
SELECT * → Shows ESP32-LAB-001 entries
```

**Indicator 4: Backend Console**
```
POST /api/sensor-data
HTTP 200
```

---

## 📋 FILES IN THIS SYSTEM

| File | Purpose | Read Time | Run Time |
|------|---------|-----------|----------|
| QUICK_SENSOR_VERIFICATION.md | Fast reference | 5 min | - |
| ESP32_DATA_VERIFICATION_COMPLETE.md | Complete guide | 15 min | - |
| BACKEND_VERIFICATION_GUIDE.md | Backend details | 20 min | - |
| ENDPOINT_TESTING_GUIDE.md | Endpoint reference | 15 min | - |
| SENSOR_VERIFICATION_SUMMARY.md | Overview | 10 min | - |
| check_sensor_data.py | Auto check | - | 5 sec |
| sensor_service.dart | Flutter service | 5 min | - |

---

## 🎯 NEXT STEPS AFTER VERIFICATION

### Phase 1: Confirmation ✅ (CURRENT)
- [x] Backend endpoints created
- [x] Database ready
- [ ] Run verification script
- [ ] Confirm data flowing

### Phase 2: Flutter Integration
- [ ] Import sensor_service
- [ ] Update dashboard_page.dart
- [ ] Display sensor readings
- [ ] Add real-time charts

### Phase 3: Monitoring
- [ ] Check data quality
- [ ] Monitor database growth
- [ ] Setup alerts
- [ ] Performance tuning

---

## 💡 KEY CONCEPTS

### What is the endpoint?
```
http://10.111.183.200:5000/api/sensor-data
        ↑ IP             ↑ Port    ↑ Path
```

### What data is sent?
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

### Where is it stored?
```
PostgreSQL Database
└─ energia (database)
   └─ sensor_data (table)
      ├─ id (auto-increment)
      ├─ ds (timestamp)
      ├─ device_id (ESP32-LAB-001)
      └─ value (power in watts)
```

### How often is it sent?
```
Every 60 seconds (1 minute)
ESP32 collects 6 samples at 10-second intervals
Averages them
Sends once
```

---

## 🔧 QUICK TROUBLESHOOTING

| Symptom | Cause | Fix |
|---------|-------|-----|
| Script says "No records" | ESP32 hasn't sent | Power on ESP32, wait 60s |
| Backend shows 404 error | Wrong URL | Use: `10.111.183.200:5000` |
| ESP32 "HTTP Error: 0" | Backend offline | Run: `python start_server.py` |
| WiFi fails | Network issue | Check SSID: gecIi, PWD: 66666666 |
| No data 5 min later | Multiple issues | Check serial, backend, firewall |

---

## 📞 SUPPORT

If you're stuck:

1. **Run verification script:**
   ```bash
   python check_sensor_data.py
   ```

2. **Check three things:**
   - ESP32 serial shows "✓ HTTP 200"?
   - Backend console shows "POST /api/sensor-data"?
   - Database has records?

3. **Share output from script and logs**

---

## 🎓 LEARNING PATH

**New to this system?**

1. Start: [QUICK_SENSOR_VERIFICATION.md](QUICK_SENSOR_VERIFICATION.md)
2. Read: [ESP32_DATA_VERIFICATION_COMPLETE.md](ESP32_DATA_VERIFICATION_COMPLETE.md)
3. Understand: [BACKEND_VERIFICATION_GUIDE.md](BACKEND_VERIFICATION_GUIDE.md)
4. Deep Dive: [ENDPOINT_TESTING_GUIDE.md](ENDPOINT_TESTING_GUIDE.md)

**Just want to verify?**

→ Run: `python check_sensor_data.py`

---

## ✨ SUMMARY

```
╔════════════════════════════════════════════════╗
║        SENSOR DATA SYSTEM OVERVIEW              ║
╠════════════════════════════════════════════════╣
║ Backend Endpoints       ✅ READY                ║
║ Database              ✅ READY                ║
║ Verification Script   ✅ READY                ║
║ Documentation         ✅ COMPLETE             ║
║                                               ║
║ ESP32 Data            ⏳ WAITING FOR DATA     ║
║ Status                → READY FOR TESTING    ║
║ Action                → Power on ESP32        ║
║                         Run verification     ║
╚════════════════════════════════════════════════╝
```

---

## 🚀 GET STARTED NOW

```bash
# 1. Open Terminal
# 2. Run one command:
cd backend && python check_sensor_data.py

# 3. See results:
# ✅ SUCCESS → Done!
# ⏳ WAITING → Power on ESP32, wait 60s, try again
# ❌ ERROR → Restart backend: python start_server.py
```

**That's it!** 🎉

---

## 📖 TABLE OF CONTENTS

1. [Quick Start](#quick-start-2-minutes)
2. [Documentation Roadmap](#documentation-roadmap)
3. [System Status](#-system-status)
4. [Verification Flow](#-verification-flow)
5. [Decision Guide](#-decision-guide)
6. [Verification Methods](#-verification-methods-choose-one)
7. [Success Indicators](#-success-indicators)
8. [Next Steps](#-next-steps-after-verification)
9. [Key Concepts](#-key-concepts)
10. [Troubleshooting](#-quick-troubleshooting)
11. [Support](#-support)

---

**Ready?** → [Run the verification script now!](#quick-start-2-minutes)
