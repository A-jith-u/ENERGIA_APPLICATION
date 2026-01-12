# 🚀 BACKEND VERIFICATION & TROUBLESHOOTING GUIDE

## Current Status: ⏳ WAITING FOR DATA

Based on the verification script, the backend is **READY** but no data has been received yet.

---

## ✅ What's Working

```
✅ Database table "sensor_data" exists
✅ Table schema is correct (id, ds, device_id, value)
✅ Backend endpoint /api/sensor-data is defined
✅ Database connection works
```

---

## ⏳ Why No Data Yet?

Your ESP32 will POST data to backend every **60 seconds**. Here's what you need to verify:

### 1. Is Backend Running? (CRITICAL)

**Check if backend is running:**
```bash
# Open new PowerShell and run:
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python start_server.py
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:5000
```

---

### 2. Is ESP32 Connected to WiFi?

**Look at ESP32 serial monitor output for:**

✅ You should see:
```
==================================
ENERGIA - ESP32 PZEM Energy Monitor
==================================

Connecting to WiFi: gecIi
.....
✓ WiFi connected
IP Address: 192.168.x.x

Testing PZEM module...
✓ PZEM module connected successfully!
Voltage: 230.5 V
```

❌ If you see:
```
✗ WiFi connection failed
```

**Fix:**
- Check WiFi SSID "gecIi" and password "66666666"
- Verify ESP32 is close to router
- Check WiFi network is active

---

### 3. Is ESP32 Sending Data?

**Look for in ESP32 serial monitor:**

✅ Every 60 seconds, you should see:
```
--- 10s Sensor Sample ---
Sample count: 1
Sample count: 2
Sample count: 3
Sample count: 4
Sample count: 5
Sample count: 6

=== Sending 1-Minute Averaged Data ===
Samples: 6
Payload: {"device_id":"ESP32-LAB-001","voltage":230.5,"current":2.3,"power":500.0,"energy":1200.0,"frequency":50.0,"power_factor":0.95}
✓ HTTP Response: 200
{"status":"success","message":"Sensor data from ESP32-LAB-001 received and stored",...}
```

❌ If you see:
```
✗ HTTP Error: 0
```
- Backend endpoint not responding
- Check: Is backend running? (`python start_server.py`)

❌ If you see:
```
WiFi not connected. Data not sent.
```
- WiFi is disconnected
- Check WiFi connection

---

## 🔧 TEST ENDPOINTS MANUALLY

### Test 1: Check Backend Health

```bash
curl -X GET http://10.111.183.200:5000/health
```

**Expected response:**
```json
{"status":"ok"}
```

**If fails:**
- Backend not running
- Wrong IP address
- Firewall blocking port 5000

---

### Test 2: Check Sensor Endpoint (GET)

```bash
curl -X GET "http://10.111.183.200:5000/api/sensor-data"
```

**Expected response (if no data yet):**
```json
{
  "status": "success",
  "count": 0,
  "data": []
}
```

**If endpoint exists but returns empty = waiting for ESP32 to send data**

---

### Test 3: Simulate ESP32 Data (POST)

**Test if backend accepts POST data:**

```bash
# Create test_sensor_post.json
cat > test_sensor_post.json << 'EOF'
{
  "device_id": "TEST-DEVICE",
  "voltage": 230.5,
  "current": 2.3,
  "power": 500.0,
  "energy": 1200.0,
  "frequency": 50.0,
  "power_factor": 0.95
}
EOF

# Send it
curl -X POST http://10.111.183.200:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d @test_sensor_post.json
```

**Expected response:**
```json
{
  "status": "success",
  "message": "Sensor data from TEST-DEVICE received and stored",
  "device_id": "TEST-DEVICE",
  "value": 500.0,
  "timestamp": "2026-01-03T10:30:00.123456+00:00"
}
```

---

## 📊 STEP-BY-STEP VERIFICATION PROCESS

### Step 1: Start Backend
```bash
cd backend
python start_server.py
```
⏳ Wait until you see: `Uvicorn running on http://0.0.0.0:5000`

### Step 2: Test Backend is Responding
```bash
curl -X GET http://10.111.183.200:5000/health
```
✅ Should return: `{"status":"ok"}`

### Step 3: Check Endpoint Exists
```bash
curl -X GET http://10.111.183.200:5000/api/sensor-data
```
✅ Should return: JSON with "status": "success"

### Step 4: Send Test Data
```bash
curl -X POST http://10.111.183.200:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"device_id":"TEST","voltage":230.5,"current":2.3,"power":500.0,"energy":1200.0,"frequency":50.0,"power_factor":0.95}'
```
✅ Should return: `{"status":"success",...}`

### Step 5: Verify Data in Database
```bash
cd backend
python check_sensor_data.py
```
✅ Should show: `✅ SUCCESS: Backend is receiving sensor data!`

### Step 6: Power On ESP32
- Upload code to ESP32
- Check serial monitor for WiFi connection
- Wait 60 seconds for first data send
- Check logs for: `✓ HTTP Response: 200`

### Step 7: Verify ESP32 Data in Database
```bash
cd backend
python check_sensor_data.py
```
✅ Should show ESP32-LAB-001 data

---

## 🎯 QUICK REFERENCE: WHAT EACH LOG MESSAGE MEANS

### ESP32 Serial Monitor Output

| Message | Meaning | Action |
|---------|---------|--------|
| `✓ WiFi connected` | ESP32 has WiFi | ✅ Good |
| `✗ WiFi connection failed` | No WiFi | ❌ Check network |
| `✓ PZEM module connected` | Sensor detected | ✅ Good |
| `✗ ERROR: PZEM module not detected` | Sensor offline | ❌ Check connections |
| `✓ HTTP Response: 200` | Data sent successfully | ✅ Good |
| `✗ HTTP Error: 0` | Backend not responding | ❌ Start backend |
| `WiFi not connected. Data not sent.` | WiFi disconnected | ❌ Check WiFi |

### Backend Console Output

| Message | Meaning | Action |
|---------|---------|--------|
| `POST /api/sensor-data` | Data received | ✅ Good |
| `No matching route` | Endpoint not found | ❌ Restart backend |
| Connection timeout | Network issue | ❌ Check IP/firewall |

### Database Verification

| Output | Meaning | Action |
|--------|---------|--------|
| `✅ Total records: 5` | Data stored | ✅ All working! |
| `❌ No records found` | Waiting for data | ⏳ Wait 60s or check logs |
| `✅ Device: ESP32-LAB-001` | ESP32 connected | ✅ All working! |

---

## 🔍 DIAGNOSTIC CHECKLIST

```bash
# Run these commands in order and check results:

# 1. Is backend running?
curl -X GET http://10.111.183.200:5000/health
# Expected: {"status":"ok"}

# 2. Can endpoint be reached?
curl -X GET http://10.111.183.200:5000/api/sensor-data
# Expected: {"status":"success","count":X,...}

# 3. Can we POST data?
curl -X POST http://10.111.183.200:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{"device_id":"TEST","power":100}'
# Expected: {"status":"success",...}

# 4. Is data in database?
cd backend
python check_sensor_data.py
# Expected: Shows records
```

---

## 📱 How to Monitor During Testing

### Option 1: Watch Database (Every 60 seconds)

```bash
# Run in PowerShell every 60 seconds:
cd backend
python check_sensor_data.py
```

### Option 2: Watch Backend Logs

Keep terminal open with:
```bash
python start_server.py
```

Look for:
```
POST /api/sensor-data
```

### Option 3: Watch ESP32 Serial Monitor

In Arduino IDE:
- Select Tools → Serial Monitor
- Set baud rate to 115200
- Look for "✓ HTTP Response: 200"

---

## 🚨 COMMON ISSUES & SOLUTIONS

### Issue: "Connection refused" or "Network error"

**Cause:** Backend not running

**Solution:**
```bash
cd backend
python start_server.py
```

---

### Issue: "404 Not Found"

**Cause:** Wrong endpoint URL

**Solution:**
- Verify URL: `http://10.111.183.200:5000/api/sensor-data`
- Check IP address is correct
- Restart backend

---

### Issue: "HTTP Error: 0" on ESP32

**Cause 1:** Backend not responding
**Solution:**
```bash
python start_server.py
```

**Cause 2:** Wrong IP address
**Solution:**
- Change ESP32 code: `const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-data";`

**Cause 3:** Firewall blocking port
**Solution:**
- Allow port 5000 in Windows Firewall

---

### Issue: No data in database after 5 minutes

**Possible causes:**
1. ESP32 not connected to WiFi
   - Check serial monitor for "WiFi connected"
   
2. Backend not running
   - Run `python start_server.py`
   
3. PZEM module not detected
   - Check connections: GPIO 16 (RX) and GPIO 17 (TX) to PZEM
   - Check serial output for "PZEM module connected"
   
4. HTTP requests timing out
   - Check firewall
   - Ping IP address: `ping 10.111.183.200`

---

## ✅ SUCCESS INDICATORS

You'll know everything is working when:

✅ ESP32 serial shows:
```
✓ WiFi connected
✓ PZEM module connected
✓ HTTP Response: 200
```

✅ Backend shows:
```
POST /api/sensor-data - HTTP 200
```

✅ Database shows:
```
✅ Total records: 5
✅ Device: ESP32-LAB-001
✅ Records in last 10 minutes: 2
```

✅ Verification script shows:
```
✅ SUCCESS: Backend is receiving sensor data!
```

---

## 🎯 NEXT STEPS AFTER VERIFICATION

Once data is flowing (✅ All checks pass):

1. **Update Flutter Service**
   - Modify `lib/services/sensor_service.dart`
   - Change endpoint to match: `/api/sensor-data`
   
2. **Display on Dashboard**
   - Add widgets to `lib/dashboard_page.dart`
   - Show voltage, current, power readings
   - Add real-time charts
   
3. **Real-time Updates**
   - Implement polling every 30 seconds
   - Show "Last updated: X seconds ago"

---

## 📞 QUICK SUPPORT

If you need help:

1. **Run verification script:**
   ```bash
   cd backend
   python check_sensor_data.py
   ```

2. **Show me the output:**
   - What does it show? Records or empty?
   
3. **Check ESP32 serial:**
   - Is it showing "✓ HTTP Response: 200"?
   - Or "✗ HTTP Error"?

---

## Summary

**Current Status:** ✅ Backend is ready, ⏳ waiting for ESP32 data

**To verify data flow:**
1. Ensure backend is running
2. Check ESP32 is sending data (serial monitor)
3. Run `python check_sensor_data.py`
4. Data should appear within 60 seconds

**All endpoints are created and working!** ✅
