# Complete Sensor Data Capture & Transmission Flow

## Overview

This guide shows **ALL** the procedures and code changes needed to capture sensor readings from ESP32 and send them to the backend for storage and display.

---

## 1. ESP32 Side (Hardware & Code)

### 1.1 Hardware Setup
**Required Components:**
- ESP32 microcontroller
- PZEM-004Tv30 energy meter module
- WiFi network connectivity

**Wiring:**
```
PZEM TX → ESP32 RX2 (GPIO16)
PZEM RX → ESP32 TX2 (GPIO17)
PZEM GND → ESP32 GND
PZEM 5V → 5V Power Supply
```

### 1.2 ESP32 Code Changes
**File:** Your Arduino sketch

**Required Libraries:**
```cpp
#include <WiFi.h>              // WiFi connectivity
#include <HTTPClient.h>        // HTTP requests
#include <ArduinoJson.h>       // JSON serialization
#include <PZEM004Tv30.h>       // PZEM module communication
```

**Configuration Constants:**
```cpp
const char* WIFI_SSID = "gecIi";
const char* WIFI_PASSWORD = "66666666";
const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-readings";
const char* DEVICE_ID = "ESP32-LAB-001";  // Unique per device
```

**Data Reading Function:**
```cpp
void readSensorAndAccumulate() {
  float voltage = pzem.voltage();
  float current = pzem.current();
  float power = pzem.power();
  float energy = pzem.energy();
  float frequency = pzem.frequency();
  float powerFactor = pzem.pf();
  
  // Accumulate values for averaging
  sumVoltage += voltage;
  sumCurrent += current;
  sumPower += power;
  sumEnergy += energy;
  sumFrequency += frequency;
  sumPowerFactor += powerFactor;
  sampleCount++;
}
```

**Data Sending Function:**
```cpp
void sendToBackend(float voltage, float current, float power,
                   float energy, float frequency, float powerFactor) {
  HTTPClient http;
  StaticJsonDocument<256> json;
  
  json["device_id"] = DEVICE_ID;
  json["voltage"] = voltage;
  json["current"] = current;
  json["power"] = power;
  json["energy"] = energy;
  json["frequency"] = frequency;
  json["power_factor"] = powerFactor;
  
  String payload;
  serializeJson(json, payload);
  
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");
  int responseCode = http.POST(payload);
  
  if (responseCode == 200) {
    Serial.println("✓ Data sent successfully");
  } else {
    Serial.print("✗ Error: ");
    Serial.println(responseCode);
  }
  http.end();
}
```

**Timing:**
- Read PZEM every **10 seconds**
- Send averaged data every **60 seconds** (6 samples)

---

## 2. Backend Side (Python/FastAPI)

### 2.1 Database Table
**Already exists:** `sensor_readings` table

```sql
CREATE TABLE sensor_readings (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    voltage NUMERIC(8,3) NOT NULL,
    current NUMERIC(8,4) NOT NULL,
    power_factor NUMERIC(5,3) NOT NULL,
    power NUMERIC(10,3) NOT NULL,
    energy NUMERIC(12,6),
    frequency NUMERIC(6,3),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_sensor_readings_device_id ON sensor_readings(device_id);
CREATE INDEX ix_sensor_readings_created_at ON sensor_readings(created_at);
```

### 2.2 Backend API Endpoint Changes

**File:** `backend/auth_api.py` (or create new `backend/sensor_api.py`)

**Add these imports:**
```python
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from datetime import datetime
from sqlalchemy import text, create_engine
```

**Create request model:**
```python
class SensorReadingRequest(BaseModel):
    device_id: str
    voltage: float
    current: float
    power_factor: float
    power: float
    energy: float | None = None
    frequency: float | None = None
```

**Create POST endpoint to receive data:**
```python
@app.post("/sensor-readings")
async def receive_sensor_reading(reading: SensorReadingRequest):
    """
    Receive sensor readings from ESP32 and store in database.
    
    Expected payload:
    {
        "device_id": "ESP32-LAB-001",
        "voltage": 230.5,
        "current": 2.3,
        "power": 529.15,
        "energy": 1.5,
        "frequency": 50.0,
        "power_factor": 0.95
    }
    """
    try:
        with engine.begin() as conn:
            # Insert into sensor_readings table
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
            
            # Log activity
            activity_logger.log_activity(
                conn,
                user_id=reading.device_id,
                action="sensor_reading_received",
                resource_type="sensor",
                resource_id=reading.device_id,
                details=f"Power: {reading.power}W, Voltage: {reading.voltage}V"
            )
        
        return {
            "status": "success",
            "message": "Sensor reading stored",
            "device_id": reading.device_id,
            "power": reading.power
        }
    
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
```

**Create GET endpoint to retrieve data:**
```python
@app.get("/sensor-readings")
async def get_sensor_readings(
    device_id: str = None,
    limit: int = 100,
    offset: int = 0
):
    """
    Retrieve sensor readings from database.
    
    Query params:
    - device_id: Filter by device (optional)
    - limit: Max records (default 100)
    - offset: Pagination offset
    """
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
```

**Create GET endpoint for statistics:**
```python
@app.get("/sensor-readings/stats")
async def get_sensor_stats(
    device_id: str = None,
    hours: int = 24
):
    """
    Get statistics (average, min, max) for sensor readings.
    
    Query params:
    - device_id: Filter by device
    - hours: Time range (default 24 hours)
    """
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

### 2.3 Mount Sensor API (if in separate file)

In `backend/app_main.py`, add:
```python
sensor_api = _load("sensor_api")
app.mount("/api", sensor_api.app)
```

---

## 3. Flutter App Side

### 3.1 Create Sensor Service

**File:** `lib/services/sensor_service.dart` (NEW FILE)

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

### 3.2 Update Dashboard to Display Sensor Data

**File:** `lib/dashboard_page.dart` (MODIFY)

Add import:
```dart
import 'services/sensor_service.dart';
```

Add to state:
```dart
late SensorService sensorService;
List<SensorReading> sensorReadings = [];
Map<String, dynamic> sensorStats = {};

@override
void initState() {
  super.initState();
  sensorService = SensorService();
  _fetchSensorData();
}

void _fetchSensorData() async {
  final readings = await sensorService.getSensorReadings(
    deviceId: "ESP32-LAB-001",
    limit: 50,
  );
  final stats = await sensorService.getSensorStats(
    deviceId: "ESP32-LAB-001",
  );
  
  setState(() {
    sensorReadings = readings;
    sensorStats = stats;
  });
}
```

### 3.3 Create Sensor Display Widget

**File:** `lib/widgets/sensor_reading_widget.dart` (NEW FILE)

```dart
import 'package:flutter/material.dart';
import '../services/sensor_service.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorReadingWidget extends StatelessWidget {
  final SensorReading reading;

  const SensorReadingWidget({
    required this.reading,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reading.deviceId,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric("Voltage", "${reading.voltage.toStringAsFixed(2)}V"),
                _buildMetric("Current", "${reading.current.toStringAsFixed(3)}A"),
                _buildMetric("Power", "${reading.power.toStringAsFixed(2)}W"),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric("Frequency", "${reading.frequency?.toStringAsFixed(2) ?? 'N/A'}Hz"),
                _buildMetric("PF", "${reading.powerFactor.toStringAsFixed(3)}"),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reading.createdAt.toString(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
```

### 3.4 Create Chart Widget for Sensor Data

**File:** `lib/widgets/sensor_chart_widget.dart` (NEW FILE)

```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/sensor_service.dart';

class SensorChartWidget extends StatelessWidget {
  final List<SensorReading> readings;
  final String metric; // 'voltage', 'current', 'power', 'frequency'

  const SensorChartWidget({
    required this.readings,
    required this.metric,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    final spots = _generateSpots();
    final title = _getTitle();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                  ],
                  titlesData: const FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    return List.generate(readings.length, (index) {
      final reading = readings[index];
      final value = _getValue(reading);
      return FlSpot(index.toDouble(), value);
    });
  }

  double _getValue(SensorReading reading) {
    switch (metric) {
      case 'voltage':
        return reading.voltage;
      case 'current':
        return reading.current;
      case 'power':
        return reading.power;
      case 'frequency':
        return reading.frequency ?? 50.0;
      default:
        return reading.power;
    }
  }

  String _getTitle() {
    switch (metric) {
      case 'voltage':
        return 'Voltage (V)';
      case 'current':
        return 'Current (A)';
      case 'power':
        return 'Power (W)';
      case 'frequency':
        return 'Frequency (Hz)';
      default:
        return 'Sensor Data';
    }
  }
}
```

### 3.5 Update Dashboard Body to Show Sensor Data

**File:** `lib/dashboard_page.dart` (MODIFY in _buildPage method)

```dart
if (_index == 0) {
  // Home/Dashboard tab
  return SingleChildScrollView(
    child: Column(
      children: [
        // Display latest sensor reading
        if (sensorReadings.isNotEmpty)
          SensorReadingWidget(reading: sensorReadings.first),
        
        // Display charts
        SensorChartWidget(readings: sensorReadings, metric: 'power'),
        SensorChartWidget(readings: sensorReadings, metric: 'voltage'),
        SensorChartWidget(readings: sensorReadings, metric: 'current'),
        SensorChartWidget(readings: sensorReadings, metric: 'frequency'),
        
        // Display statistics
        if (sensorStats.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Statistics (24h)',
                    style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildStatRow('Avg Power',
                    '${sensorStats['avg_power']?.toStringAsFixed(2) ?? 'N/A'}W'),
                  _buildStatRow('Max Power',
                    '${sensorStats['max_power']?.toStringAsFixed(2) ?? 'N/A'}W'),
                  _buildStatRow('Avg Voltage',
                    '${sensorStats['avg_voltage']?.toStringAsFixed(2) ?? 'N/A'}V'),
                  _buildStatRow('Avg Current',
                    '${sensorStats['avg_current']?.toStringAsFixed(3) ?? 'N/A'}A'),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
```

---

## Summary of Changes

| Component | File | Changes |
|-----------|------|---------|
| **ESP32** | Arduino Sketch | Read PZEM data, send HTTP POST to backend |
| **Backend** | `backend/auth_api.py` | Add 3 endpoints: POST /sensor-readings, GET /sensor-readings, GET /sensor-readings/stats |
| **Database** | Already exists | `sensor_readings` table |
| **Flutter Service** | `lib/services/sensor_service.dart` | NEW - Fetch data from backend API |
| **Flutter Widgets** | `lib/widgets/sensor_reading_widget.dart` | NEW - Display single reading |
| **Flutter Widgets** | `lib/widgets/sensor_chart_widget.dart` | NEW - Display charts |
| **Flutter Dashboard** | `lib/dashboard_page.dart` | MODIFY - Integrate sensor display |

---

## Complete Flow

```
ESP32 (every 60s)
    ↓
HTTP POST to /sensor-readings
    ↓
Backend receives & stores in sensor_readings table
    ↓
Flutter app calls GET /sensor-readings
    ↓
Display in dashboard with charts & stats
```

---

## Testing Checklist

- [ ] ESP32 connects to WiFi
- [ ] ESP32 sends data to backend (check serial output)
- [ ] Backend receives data (check logs)
- [ ] Data stored in database (check psql)
- [ ] Flutter service fetches data (check network)
- [ ] Charts display on dashboard
- [ ] Stats calculate correctly
- [ ] Real-time updates work

---

## Next Steps

1. **Update Backend** - Add the 3 sensor endpoints
2. **Create Flutter Service** - Fetch sensor data from API
3. **Update Flutter UI** - Display readings, charts, stats
4. **Connect ESP32** - Upload code and power on
5. **Verify Flow** - Check data from ESP32 → Backend → Flutter

Which part would you like to implement first?
