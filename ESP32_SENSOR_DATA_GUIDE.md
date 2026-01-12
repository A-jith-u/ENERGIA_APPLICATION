# ESP32 Sensor Data Integration Guide

## Overview

Your ESP32 with PZEM-004T module can now send real sensor data directly to the ENERGIA backend, which stores it in the PostgreSQL database instead of using sample data.

## Backend Endpoints

### 1. POST `/api/sensor-data` - Send Sensor Data

**Purpose**: Receive sensor readings from ESP32 and store them in the database.

**Request Format**:
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

**Response**:
```json
{
    "status": "success",
    "message": "Sensor data from ESP32-LAB-001 received and stored",
    "device_id": "ESP32-LAB-001",
    "value": 529.15,
    "timestamp": "2025-01-03T10:30:45.123456+00:00"
}
```

**HTTP Status Codes**:
- `200`: Data successfully stored
- `400`: Invalid request format

---

### 2. GET `/api/sensor-data` - Retrieve Sensor Data

**Purpose**: Fetch stored sensor readings from the database.

**Query Parameters**:
- `device_id` (optional): Filter by specific device ID
- `limit` (optional): Maximum records to return (default: 100)

**Examples**:

Get last 100 readings from all devices:
```
GET /api/sensor-data
```

Get last 50 readings from specific device:
```
GET /api/sensor-data?device_id=ESP32-LAB-001&limit=50
```

**Response**:
```json
{
    "status": "success",
    "count": 3,
    "data": [
        {
            "id": 456,
            "timestamp": "2025-01-03T10:30:45.123456+00:00",
            "device_id": "ESP32-LAB-001",
            "value": 529.15
        },
        {
            "id": 455,
            "timestamp": "2025-01-03T10:29:45.654321+00:00",
            "device_id": "ESP32-LAB-001",
            "value": 528.90
        },
        {
            "id": 454,
            "timestamp": "2025-01-03T10:28:45.987654+00:00",
            "device_id": "ESP32-LAB-001",
            "value": 530.25
        }
    ]
}
```

---

## ESP32 Code Modifications

Your current ESP32 code is already correctly configured! The `sendToBackend()` function sends data to:

```
http://10.111.183.200:5000/api/sensor-data
```

This matches the new endpoint we created. Your code's payload format is already compatible:

```cpp
json["device_id"] = DEVICE_ID;
json["voltage"] = voltage;
json["current"] = current;
json["power"] = power;
json["energy"] = energy;
json["frequency"] = frequency;
json["power_factor"] = powerFactor;
```

### What's Happening Now

1. **Every 10 seconds**: ESP32 reads PZEM sensor data
2. **Every 60 seconds**: Averaged values (over 6 samples) are sent to the backend
3. **Backend stores**: Data is saved in PostgreSQL `sensor_data` table
4. **Activity logged**: Each submission is recorded in `activity_logs` table

---

## Database Storage

Sensor data is stored in the `sensor_data` table:

| Column | Type | Description |
|--------|------|-------------|
| `id` | BigInteger | Unique record ID |
| `ds` | DateTime | Timestamp of the reading |
| `device_id` | String | Device identifier (e.g., "ESP32-LAB-001") |
| `value` | Float | Primary metric value (power in watts) |

---

## Verifying Data Storage

### 1. Check via API

```bash
# Get all sensor data
curl http://10.111.183.200:5000/api/sensor-data

# Get data from specific device
curl "http://10.111.183.200:5000/api/sensor-data?device_id=ESP32-LAB-001&limit=10"
```

### 2. Check via Database

```bash
# Connect to PostgreSQL
psql postgresql://postgres:postgres@localhost:5432/energia

# View sensor data
SELECT * FROM sensor_data ORDER BY ds DESC LIMIT 10;

# View count by device
SELECT device_id, COUNT(*) as reading_count, 
       MAX(ds) as latest_reading
FROM sensor_data 
GROUP BY device_id;
```

### 3. Check Activity Logs

```bash
# View sensor data submissions in activity logs
SELECT * FROM activity_logs 
WHERE action = 'data_submission' 
ORDER BY timestamp DESC 
LIMIT 10;
```

---

## Troubleshooting

### Issue: ESP32 not connecting to WiFi

**Solution**:
1. Verify SSID and password in ESP32 code
2. Check WiFi range and signal strength
3. Restart ESP32 and check serial output

### Issue: Data not appearing in database

**Check**:
1. Verify server URL is correct: `http://10.111.183.200:5000/api/sensor-data`
2. Check ESP32 serial output for HTTP response codes
3. Verify database is running: `docker-compose ps`
4. Check database connection: `python check_schema.py`

### Issue: PZEM module not detected

**Solution**:
1. Verify RX pin is 16 and TX pin is 17 in ESP32 code
2. Check PZEM wiring (RX-A, TX-B connections)
3. Ensure 3.3V logic level on PZEM pins
4. Test PZEM with multimeter for power supply

---

## Next Steps

1. **Upload** the ESP32 code to your device
2. **Power up** the ESP32 and PZEM module
3. **Monitor** the serial output to verify:
   - WiFi connection
   - PZEM initialization
   - Every 10s sensor readings
   - Every 60s HTTP POST requests
4. **Verify** data in database using API or SQL

The system will now fetch real sensor data from your devices instead of using sample data!

---

## API Base URL

Replace `10.111.183.200` with your actual server IP if different.

- **Development**: `http://localhost:5000/api`
- **Production**: `http://10.111.183.200:5000/api`

---

## Security Notes

Currently, the `/api/sensor-data` endpoint does NOT require authentication. If you want to add API key or JWT authentication, modify the endpoint accordingly in `auth_api.py`.

For production deployments, consider:
1. Adding authentication tokens
2. Rate limiting per device
3. Data validation and sanitation
4. HTTPS/TLS encryption

