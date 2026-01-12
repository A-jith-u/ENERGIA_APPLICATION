# Quick Start: ESP32 Sensor Data to Database

## In 3 Steps

### Step 1: Ensure Backend is Running
```powershell
cd backend
python -m uvicorn app_main:app --reload --host 0.0.0.0 --port 5000
```

**Alternative with Docker** (from project root):
```powershell
docker-compose up -d
```

### Step 2: Upload ESP32 Code
Your provided ESP32 code is already compatible! Just upload it to your device with:
- WiFi SSID: `gecIi`
- WiFi Password: `66666666`
- Server URL: `http://10.111.183.200:5000/api/sensor-data`
- Device ID: `ESP32-LAB-001` (or your custom ID)

### Step 3: Verify Data is Flowing
```bash
# In a terminal, check if data is arriving
curl "http://localhost:5000/api/sensor-data?limit=5"
```

You should see recent sensor readings in the response!

---

## How Data Flows

```
ESP32 (reads PZEM every 10s)
  ↓ (every 60s, sends averaged data)
Backend API POST /api/sensor-data
  ↓ (stores in database)
PostgreSQL sensor_data table
  ↓ (recommendations engine reads from here)
Recommendations & Predictions
  ↓ (displayed in Flutter app)
Dashboard & Visualizations
```

---

## What Changed From Sample Data

### Before
- System used `generate_prophet_sample_data.py`
- All data was simulated/synthetic
- No real device integration
- Testing only

### After
- Real sensor data from ESP32 PZEM module
- Actually measured electrical parameters
- HTTP POST from device to backend
- Stored in `sensor_data` table
- Recommendations based on real data

---

## Check Your Data

### Using curl/PowerShell
```powershell
# Get all sensor data
curl "http://localhost:5000/api/sensor-data"

# Get specific device's last 20 readings
curl "http://localhost:5000/api/sensor-data?device_id=ESP32-LAB-001&limit=20"

# Filter by device in PowerShell
$response = curl "http://localhost:5000/api/sensor-data?device_id=ESP32-LAB-001" | ConvertFrom-Json
$response.data | Select-Object timestamp, value | Format-Table
```

### Using SQL (if you have psql)
```sql
-- Connect to database
psql postgresql://postgres:postgres@localhost:5432/energia

-- See all sensor readings
SELECT timestamp, device_id, value FROM sensor_data ORDER BY timestamp DESC LIMIT 10;

-- Average power per device in last hour
SELECT device_id, AVG(value) as avg_power 
FROM sensor_data 
WHERE timestamp > NOW() - INTERVAL '1 hour'
GROUP BY device_id;
```

---

## Payload Reference

### What ESP32 Sends (POST to /api/sensor-data)
```json
{
  "device_id": "ESP32-LAB-001",
  "voltage": 230.5,
  "current": 2.3,
  "power": 529.15,
  "energy": 1.5,
  "frequency": 50.0,
  "power_factor": 0.95
}
```

### What Gets Stored in Database
| Field | Value | Source |
|-------|-------|--------|
| id | auto-generated | system |
| ds | current timestamp | server time |
| device_id | "ESP32-LAB-001" | from request |
| value | 529.15 | power field from request |

---

## Verify Everything Works

### 1. Check Backend is Running
```powershell
curl "http://localhost:5000/ping"
# Should return: {"status":"pong"}
```

### 2. Check Database is Running
```powershell
# If using Docker
docker-compose ps
# Should show 'db' container as 'Up'

# Or try connecting directly
psql postgresql://postgres:postgres@localhost:5432/energia -c "SELECT 1"
```

### 3. Test the Endpoint
```powershell
# Send test data
curl -X POST http://localhost:5000/api/sensor-data `
  -H "Content-Type: application/json" `
  -d '{
    "device_id": "test-esp32",
    "power": 500,
    "voltage": 230,
    "current": 2.17,
    "frequency": 50,
    "power_factor": 0.99,
    "energy": 1.0
  }'

# Should return success response
```

### 4. Retrieve Test Data
```powershell
curl "http://localhost:5000/api/sensor-data?device_id=test-esp32"
# Should show the test data you just sent
```

---

## Common Issues & Fixes

| Issue | Check | Fix |
|-------|-------|-----|
| Can't connect to backend | Is backend running? | `python -m uvicorn app_main:app --reload` |
| 404 endpoint not found | Port correct? | Use `:5000` not `:8000` for Flask, `:8000` for FastAPI |
| Database connection error | Is postgres running? | `docker-compose up -d` |
| ESP32 can't reach backend | IP address correct? | Check your network IP: `ipconfig getifaddr en0` |
| No data appearing | Serial output shows success? | Monitor ESP32 at 115200 baud |
| JSON parse error | Payload format correct? | Check all required fields present |

---

## File Locations

Important files:
- Backend code: `backend/auth_api.py` (sensor endpoints)
- Database init: `backend/db_init.py` (sensor_data table definition)
- Documentation: `ESP32_SENSOR_DATA_GUIDE.md` (detailed guide)
- Setup commands: `SETUP_AND_RUN_COMMANDS.md` (updated with sensor endpoints)

---

## That's It! 🎉

Your system is now:
✅ Capturing real sensor data from ESP32  
✅ Storing it in PostgreSQL  
✅ Ready for analysis and recommendations  
✅ No more sample data!

Your ESP32 code works exactly as-is. Just upload it, power on the device, and watch the data flow!

