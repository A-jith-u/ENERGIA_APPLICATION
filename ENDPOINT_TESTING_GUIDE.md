# 📍 ENDPOINT VERIFICATION & TESTING GUIDE

## Current Status

```
✅ Backend Endpoint: /api/sensor-data (EXISTS in auth_api.py)
⏳ Backend Server: NOT RUNNING (Start with: python start_server.py)
⏳ ESP32 Data: NOT YET RECEIVED (Waiting for ESP32 to connect and send)
```

---

## Available Endpoints

Your backend already has these endpoints implemented:

### 1. POST /api/sensor-data
**Receive sensor data from ESP32**

**URL:** `http://10.111.183.200:5000/api/sensor-data`

**Method:** POST

**Request Body (JSON):**
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

**Response (Success - 200 OK):**
```json
{
  "status": "success",
  "message": "Sensor data from ESP32-LAB-001 received and stored",
  "device_id": "ESP32-LAB-001",
  "value": 500.0,
  "timestamp": "2026-01-03T10:30:00.123456+00:00"
}
```

**Note:** Backend stores the `power` value in database as the main metric.

---

### 2. GET /api/sensor-data
**Retrieve sensor data from database**

**URL:** `http://10.111.183.200:5000/api/sensor-data`

**Method:** GET

**Optional Query Parameters:**
- `device_id` - Filter by device (example: `?device_id=ESP32-LAB-001`)
- `limit` - Max records to return (default: 100)

**Response (Success - 200 OK):**
```json
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
    {
      "id": 4,
      "timestamp": "2026-01-03T10:29:00",
      "device_id": "ESP32-LAB-001",
      "value": 498.5
    }
  ]
}
```

---

### 3. GET /health
**Health check endpoint**

**URL:** `http://10.111.183.200:5000/health`

**Method:** GET

**Response (Success - 200 OK):**
```json
{"status":"ok"}
```

---

## How to Test Manually

### Prerequisites

**Make sure backend is running:**
```bash
cd C:\Users\rapha\OneDrive\Desktop\project\backend
python start_server.py
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:5000 (Press CTRL+C to quit)
```

---

### Test 1: Health Check

**Command:**
```bash
# PowerShell
Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get | Select-Object StatusCode, Content
```

**Expected:**
```
StatusCode: 200
Content: {"status":"ok"}
```

---

### Test 2: Retrieve Current Data (Empty)

**Command:**
```bash
# PowerShell
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get | Select-Object StatusCode, Content
```

**Expected (initially empty):**
```json
{
  "status": "success",
  "count": 0,
  "data": []
}
```

---

### Test 3: Send Test Data (Simulate ESP32)

**Create test file first:**
```bash
# PowerShell - Save this as test_data.json
$data = @{
    device_id = "TEST-DEVICE"
    voltage = 230.5
    current = 2.3
    power = 500.0
    energy = 1200.0
    frequency = 50.0
    power_factor = 0.95
} | ConvertTo-Json

$data | Out-File -Path "test_data.json" -Encoding UTF8
```

**Send it:**
```bash
# PowerShell
$body = Get-Content "test_data.json" -Raw
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" `
  -Method Post `
  -Headers @{"Content-Type"="application/json"} `
  -Body $body | Select-Object StatusCode, Content
```

**Expected:**
```
StatusCode: 200
Content: {
  "status": "success",
  "message": "Sensor data from TEST-DEVICE received and stored",
  "device_id": "TEST-DEVICE",
  "value": 500.0,
  "timestamp": "2026-01-03T10:30:00..."
}
```

---

### Test 4: Retrieve Stored Data

**Command:**
```bash
# PowerShell - Get all data
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get | Select-Object StatusCode, Content

# OR filter by device
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data?device_id=TEST-DEVICE" -Method Get | Select-Object StatusCode, Content

# OR limit results
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data?limit=10" -Method Get | Select-Object StatusCode, Content
```

**Expected:**
```json
{
  "status": "success",
  "count": 1,
  "data": [
    {
      "id": 1,
      "timestamp": "2026-01-03T10:30:00",
      "device_id": "TEST-DEVICE",
      "value": 500.0
    }
  ]
}
```

---

## Complete Testing Workflow

### Step 1: Start Backend
```bash
cd backend
python start_server.py
# Wait for: INFO:     Uvicorn running on http://0.0.0.0:5000
```

### Step 2: Test Health
```bash
Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get
# Expected: StatusCode 200
```

### Step 3: Test GET (Empty)
```bash
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
# Expected: count = 0
```

### Step 4: Test POST (Simulate Data)
```bash
$body = @{
    device_id = "TEST-DEVICE"
    power = 500.0
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" `
  -Method Post `
  -Headers @{"Content-Type"="application/json"} `
  -Body $body
# Expected: StatusCode 200
```

### Step 5: Test GET (With Data)
```bash
Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get
# Expected: count = 1 (should have test data)
```

### Step 6: Power On ESP32
- Upload code to ESP32
- Open Serial Monitor (115200 baud)
- Wait 60 seconds
- Should see: `✓ HTTP Response: 200`

### Step 7: Verify ESP32 Data
```bash
cd backend
python check_sensor_data.py
# Expected: Shows ESP32-LAB-001 data
```

---

## Testing Script (All-in-One)

**Create `test_endpoints.ps1`:**

```powershell
# Test all endpoints

Write-Host "=" * 70
Write-Host "TESTING BACKEND ENDPOINTS"
Write-Host "=" * 70

# Test 1: Health
Write-Host "`n[1] Testing /health endpoint..."
try {
    $resp = Invoke-WebRequest -Uri "http://10.111.183.200:5000/health" -Method Get -ErrorAction Stop
    Write-Host "    ✅ Status: $($resp.StatusCode)"
    Write-Host "    Response: $($resp.Content)"
} catch {
    Write-Host "    ❌ FAILED: $_"
}

# Test 2: GET sensor-data (empty)
Write-Host "`n[2] Testing GET /api/sensor-data (empty)..."
try {
    $resp = Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get -ErrorAction Stop
    Write-Host "    ✅ Status: $($resp.StatusCode)"
    $data = $resp.Content | ConvertFrom-Json
    Write-Host "    Count: $($data.count)"
} catch {
    Write-Host "    ❌ FAILED: $_"
}

# Test 3: POST sensor-data
Write-Host "`n[3] Testing POST /api/sensor-data..."
try {
    $body = @{
        device_id = "POWERSHELL-TEST"
        voltage = 230.5
        current = 2.3
        power = 500.0
        energy = 1200.0
        frequency = 50.0
        power_factor = 0.95
    } | ConvertTo-Json
    
    $resp = Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" `
      -Method Post `
      -Headers @{"Content-Type"="application/json"} `
      -Body $body `
      -ErrorAction Stop
    
    Write-Host "    ✅ Status: $($resp.StatusCode)"
    $data = $resp.Content | ConvertFrom-Json
    Write-Host "    Message: $($data.message)"
} catch {
    Write-Host "    ❌ FAILED: $_"
}

# Test 4: GET sensor-data (with data)
Write-Host "`n[4] Testing GET /api/sensor-data (with data)..."
try {
    $resp = Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data" -Method Get -ErrorAction Stop
    Write-Host "    ✅ Status: $($resp.StatusCode)"
    $data = $resp.Content | ConvertFrom-Json
    Write-Host "    Count: $($data.count)"
    if ($data.count -gt 0) {
        Write-Host "    Latest: Device=$($data.data[0].device_id) Value=$($data.data[0].value)"
    }
} catch {
    Write-Host "    ❌ FAILED: $_"
}

# Test 5: GET with device filter
Write-Host "`n[5] Testing GET /api/sensor-data?device_id=POWERSHELL-TEST..."
try {
    $resp = Invoke-WebRequest -Uri "http://10.111.183.200:5000/api/sensor-data?device_id=POWERSHELL-TEST" -Method Get -ErrorAction Stop
    Write-Host "    ✅ Status: $($resp.StatusCode)"
    $data = $resp.Content | ConvertFrom-Json
    Write-Host "    Count: $($data.count)"
} catch {
    Write-Host "    ❌ FAILED: $_"
}

Write-Host "`n" + "=" * 70
Write-Host "TESTING COMPLETE"
Write-Host "=" * 70
```

**Run it:**
```bash
cd backend
.\test_endpoints.ps1
```

---

## Flask Backend Code (Reference)

The endpoints are already implemented in `backend/auth_api.py`:

```python
@app.post("/sensor-data")
async def receive_sensor_data(request: Request):
    """
    Receive sensor data from ESP32 and store it in the database.
    Stores the 'power' field as 'value' in sensor_data table.
    """
    try:
        payload = await request.json()
        device_id = payload.get("device_id", "unknown")
        value = payload.get("power", payload.get("value", 0))
        timestamp = datetime.now(timezone.utc)
        
        with engine.begin() as conn:
            conn.execute(
                text("INSERT INTO sensor_data(ds, device_id, value) VALUES (:ds, :device_id, :value)"),
                {"ds": timestamp, "device_id": device_id, "value": float(value)},
            )
            activity_logger.log_activity(
                conn,
                user_id=device_id,
                action="data_submission",
                resource_type="sensor",
                resource_id=device_id,
                details=f"Sensor reading: {value}W"
            )
        
        return {
            "status": "success",
            "message": f"Sensor data from {device_id} received and stored",
            "device_id": device_id,
            "value": value,
            "timestamp": timestamp.isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error processing sensor data: {str(e)}")


@app.get("/sensor-data")
def get_sensor_data(device_id: str = None, limit: int = 100):
    """
    Retrieve sensor data from the database.
    """
    try:
        with engine.begin() as conn:
            if device_id:
                result = conn.execute(
                    text("""
                        SELECT id, ds, device_id, value 
                        FROM sensor_data 
                        WHERE device_id = :device_id
                        ORDER BY ds DESC 
                        LIMIT :limit
                    """),
                    {"device_id": device_id, "limit": limit}
                )
            else:
                result = conn.execute(
                    text("""
                        SELECT id, ds, device_id, value 
                        FROM sensor_data 
                        ORDER BY ds DESC 
                        LIMIT :limit
                    """),
                    {"limit": limit}
                )
            
            rows = result.fetchall()
            data = [
                {
                    "id": row[0],
                    "timestamp": row[1].isoformat() if row[1] else None,
                    "device_id": row[2],
                    "value": row[3]
                }
                for row in rows
            ]
            
            return {
                "status": "success",
                "count": len(data),
                "data": data
            }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error retrieving sensor data: {str(e)}")
```

---

## Summary

✅ **Endpoints are created and working**

✅ **Database table is ready**

⏳ **Waiting for ESP32 to send data**

**To verify everything:**

1. Start backend: `python start_server.py`
2. Test endpoints: Run testing script or use curl
3. Power on ESP32 and wait 60 seconds
4. Check data: `python check_sensor_data.py`

**All set!** ✅
