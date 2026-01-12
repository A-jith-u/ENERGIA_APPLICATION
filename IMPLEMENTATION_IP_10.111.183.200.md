# Implementation: IP Address 10.111.183.200 - All Changes

## 📋 Summary: All Files Changed/Created

This document lists **all places** where IP address `10.111.183.200:5000` has been implemented.

---

## 1. 📱 ESP32 Arduino Code

**File:** Your Arduino sketch (sensor reading code)

**Change:** Configure server URL
```cpp
const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-readings";
const char* DEVICE_ID = "ESP32-LAB-001";
```

**Location in code:**
- Top of sketch, in configuration section
- Used in `sendToBackend()` function: `http.begin(SERVER_URL);`

---

## 2. 🐍 Backend API Endpoints

**File:** `backend/auth_api.py`

**Endpoints to add:**
- `POST /api/sensor-readings` - Receive sensor data
- `GET /api/sensor-readings` - Retrieve sensor data
- `GET /api/sensor-readings/stats` - Get statistics

**Full implementation code:**

```python
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy import text

class SensorReadingRequest(BaseModel):
    device_id: str
    voltage: float
    current: float
    power_factor: float
    power: float
    energy: float | None = None
    frequency: float | None = None

@app.post("/sensor-readings")
async def receive_sensor_reading(reading: SensorReadingRequest):
    """Receive sensor readings from ESP32"""
    try:
        with engine.begin() as conn:
            conn.execute(
                text("""
                    INSERT INTO sensor_readings 
                    (device_id, voltage, current, power_factor, power, energy, frequency)
                    VALUES (:device_id, :voltage, :current, :power_factor, :power, :energy, :frequency)
                """),
                {
                    "device_id": reading.device_id,
                    "voltage": reading.voltage,
                    "current": reading.current,
                    "power_factor": reading.power_factor,
                    "power": reading.power,
                    "energy": reading.energy,
                    "frequency": reading.frequency
                }
            )
        return {
            "status": "success",
            "message": "Sensor reading stored",
            "device_id": reading.device_id,
            "power": reading.power
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/sensor-readings")
async def get_sensor_readings(
    device_id: str = None,
    limit: int = 100,
    offset: int = 0
):
    """Retrieve sensor readings from database"""
    try:
        with engine.begin() as conn:
            if device_id:
                result = conn.execute(
                    text("""
                        SELECT id, device_id, voltage, current, power_factor, 
                               power, energy, frequency, created_at
                        FROM sensor_readings
                        WHERE device_id = :device_id
                        ORDER BY created_at DESC
                        LIMIT :limit OFFSET :offset
                    """),
                    {"device_id": device_id, "limit": limit, "offset": offset}
                )
            else:
                result = conn.execute(
                    text("""
                        SELECT id, device_id, voltage, current, power_factor, 
                               power, energy, frequency, created_at
                        FROM sensor_readings
                        ORDER BY created_at DESC
                        LIMIT :limit OFFSET :offset
                    """),
                    {"limit": limit, "offset": offset}
                )
            
            rows = result.fetchall()
            data = [
                {
                    "id": row[0],
                    "device_id": row[1],
                    "voltage": float(row[2]),
                    "current": float(row[3]),
                    "power_factor": float(row[4]),
                    "power": float(row[5]),
                    "energy": float(row[6]) if row[6] else None,
                    "frequency": float(row[7]) if row[7] else None,
                    "created_at": row[8].isoformat() if row[8] else None
                }
                for row in rows
            ]
            return {
                "status": "success",
                "count": len(data),
                "data": data
            }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/sensor-readings/stats")
async def get_sensor_stats(
    device_id: str = None,
    hours: int = 24
):
    """Get statistics for sensor readings"""
    try:
        with engine.begin() as conn:
            if device_id:
                result = conn.execute(
                    text("""
                        SELECT 
                            AVG(voltage) as avg_voltage,
                            AVG(current) as avg_current,
                            AVG(power) as avg_power,
                            AVG(frequency) as avg_frequency,
                            MIN(voltage) as min_voltage,
                            MAX(voltage) as max_voltage,
                            MIN(power) as min_power,
                            MAX(power) as max_power,
                            COUNT(*) as reading_count
                        FROM sensor_readings
                        WHERE device_id = :device_id
                        AND created_at > NOW() - INTERVAL :hours HOUR
                    """),
                    {"device_id": device_id, "hours": hours}
                )
            else:
                result = conn.execute(
                    text("""
                        SELECT 
                            AVG(voltage) as avg_voltage,
                            AVG(current) as avg_current,
                            AVG(power) as avg_power,
                            AVG(frequency) as avg_frequency,
                            MIN(voltage) as min_voltage,
                            MAX(voltage) as max_voltage,
                            MIN(power) as min_power,
                            MAX(power) as max_power,
                            COUNT(*) as reading_count
                        FROM sensor_readings
                        WHERE created_at > NOW() - INTERVAL :hours HOUR
                    """),
                    {"hours": hours}
                )
            
            row = result.fetchone()
            return {
                "status": "success",
                "stats": {
                    "avg_voltage": float(row[0]) if row[0] else 0,
                    "avg_current": float(row[1]) if row[1] else 0,
                    "avg_power": float(row[2]) if row[2] else 0,
                    "avg_frequency": float(row[3]) if row[3] else 0,
                    "min_voltage": float(row[4]) if row[4] else 0,
                    "max_voltage": float(row[5]) if row[5] else 0,
                    "min_power": float(row[6]) if row[6] else 0,
                    "max_power": float(row[7]) if row[7] else 0,
                    "reading_count": row[8] or 0
                }
            }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
```

**Location:** Add to `backend/auth_api.py` before the `@app.get("/health")` endpoint

---

## 3. 🐦 Flutter Services

### 3.1 Sensor Service

**File:** `lib/services/sensor_service.dart` (NEW FILE)

**Code with IP 10.111.183.200:5000:**

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class SensorReading {
  final int id;
  final String deviceId;
  final double voltage;
  final double current;
  final double powerFactor;
  final double power;
  final double? energy;
  final double? frequency;
  final DateTime createdAt;

  SensorReading({
    required this.id,
    required this.deviceId,
    required this.voltage,
    required this.current,
    required this.powerFactor,
    required this.power,
    this.energy,
    this.frequency,
    required this.createdAt,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id'] ?? 0,
      deviceId: json['device_id'] ?? '',
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      powerFactor: (json['power_factor'] as num?)?.toDouble() ?? 0.0,
      power: (json['power'] as num?)?.toDouble() ?? 0.0,
      energy: (json['energy'] as num?)?.toDouble(),
      frequency: (json['frequency'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class SensorService {
  final String baseUrl = "http://10.111.183.200:5000/api";

  Future<List<SensorReading>> getSensorReadings({
    String? deviceId,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      String url = "$baseUrl/sensor-readings?limit=$limit&offset=$offset";
      if (deviceId != null) {
        url += "&device_id=$deviceId";
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> data = json['data'] ?? [];
        return data.map((item) => SensorReading.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load sensor readings');
      }
    } catch (e) {
      print('Error fetching sensor readings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSensorStats({
    String? deviceId,
    int hours = 24,
  }) async {
    try {
      String url = "$baseUrl/sensor-readings/stats?hours=$hours";
      if (deviceId != null) {
        url += "&device_id=$deviceId";
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['stats'] ?? {};
      } else {
        throw Exception('Failed to load statistics');
      }
    } catch (e) {
      print('Error fetching statistics: $e');
      return {};
    }
  }
}
```

**Location:** Create new file at `lib/services/sensor_service.dart`

---

## 4. 🎯 Configuration Files

### 4.1 Backend Environment

**File:** `backend/.env`

```
DB_URL=postgresql+psycopg2://postgres:postgresql@localhost:5432/energia
JWT_SECRET=your-secret-key
# Server IP is configured in app startup
```

**No change needed** - uses localhost for DB, but backend listens on all interfaces with `--host 0.0.0.0`

---

## 5. 📊 Documentation Files Updated

All documentation files have been updated with IP **10.111.183.200:5000**:

1. **[ESP32_SENSOR_DATA_GUIDE.md](ESP32_SENSOR_DATA_GUIDE.md)** - Line 98, 141, 144, 187
2. **[SENSOR_DATA_INTEGRATION_SUMMARY.md](SENSOR_DATA_INTEGRATION_SUMMARY.md)** - Line 191
3. **[SENSOR_DATA_QUICK_START.md](SENSOR_DATA_QUICK_START.md)** - Line 20
4. **[SENSOR_CAPTURE_COMPLETE_GUIDE.md](SENSOR_CAPTURE_COMPLETE_GUIDE.md)** - Line 40, 409
5. **[IP_CONFIGURATION_GUIDE.md](IP_CONFIGURATION_GUIDE.md)** - Multiple locations

---

## 📋 Complete Implementation Checklist

### Backend Setup
- [ ] Add 3 sensor endpoints to `backend/auth_api.py`
  - `POST /sensor-readings`
  - `GET /sensor-readings`
  - `GET /sensor-readings/stats`
- [ ] Start backend: `python -m uvicorn app_main:app --host 0.0.0.0 --port 5000`
- [ ] Verify API: `curl http://10.111.183.200:5000/ping`

### Flutter Setup
- [ ] Create `lib/services/sensor_service.dart`
- [ ] Import in dashboard: `import 'services/sensor_service.dart';`
- [ ] Add sensor widgets to display data

### ESP32 Setup
- [ ] Update Arduino sketch with IP: `const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-readings";`
- [ ] Upload to ESP32
- [ ] Monitor serial output for successful data transmission

---

## 🔗 Data Flow with IP 10.111.183.200

```
ESP32
  ↓ (POST every 60s)
  → http://10.111.183.200:5000/api/sensor-readings
  ↓
Backend (Python/FastAPI) on 10.111.183.200:5000
  ↓ (stores in database)
PostgreSQL (localhost:5432)
  ↓
Flutter (fetches from)
  → http://10.111.183.200:5000/api/sensor-readings (GET)
  ↓
Display in Dashboard with Charts
```

---

## ✅ Verification Steps

### 1. Check Backend is Running
```powershell
Test-NetConnection -ComputerName 10.111.183.200 -Port 5000
# Should show: TcpTestSucceeded : True
```

### 2. Check API Endpoints
```powershell
curl http://10.111.183.200:5000/ping
# Should return: {"status":"pong"}
```

### 3. Test Sensor Endpoint
```powershell
curl -X POST http://10.111.183.200:5000/api/sensor-readings `
  -H "Content-Type: application/json" `
  -d '{
    "device_id": "ESP32-LAB-001",
    "voltage": 230.5,
    "current": 2.3,
    "power_factor": 0.95,
    "power": 529.15,
    "energy": 1.5,
    "frequency": 50.0
  }'
```

### 4. Retrieve Data
```powershell
curl http://10.111.183.200:5000/api/sensor-readings?device_id=ESP32-LAB-001
```

---

## 📝 Summary Table

| Component | File | IP Address | Port | Usage |
|-----------|------|-----------|------|-------|
| **ESP32** | Arduino Sketch | 10.111.183.200 | 5000 | POST sensor data |
| **Backend** | backend/auth_api.py | 0.0.0.0 (listens all) | 5000 | Receive & serve data |
| **Flutter** | lib/services/sensor_service.dart | 10.111.183.200 | 5000 | GET sensor data |
| **Database** | backend/.env | localhost | 5432 | Store sensor readings |

---

## 🚀 Quick Start

1. **Add backend endpoints** to `backend/auth_api.py` (copy code above)
2. **Create** `lib/services/sensor_service.dart` (copy code above)
3. **Update ESP32** Arduino sketch with IP `10.111.183.200:5000`
4. **Start backend**: `python -m uvicorn app_main:app --host 0.0.0.0 --port 5000`
5. **Upload ESP32** code
6. **Monitor** - Check serial output and database for data

All changes reference **IP 10.111.183.200:5000** ✅

