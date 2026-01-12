# Sensor Data Integration - Implementation Summary

## What Was Done

You now have a complete backend infrastructure to capture real sensor data from your ESP32 device instead of using sample data.

---

## Components Added/Modified

### 1. Backend API Endpoints (auth_api.py)

Two new endpoints were added to handle sensor data:

#### POST `/api/sensor-data`
- **Purpose**: Receive sensor readings from ESP32
- **Input**: JSON with device_id, voltage, current, power, energy, frequency, power_factor
- **Output**: Confirmation with stored data
- **Storage**: Data automatically inserted into `sensor_data` table
- **Activity**: Logged in `activity_logs` table for audit trail

#### GET `/api/sensor-data`
- **Purpose**: Retrieve sensor data from database
- **Query Params**: device_id (optional), limit (default 100)
- **Output**: Array of sensor readings with timestamps
- **Use Case**: Pull historical data for analysis, visualizations, predictions

---

## How It Works

### Data Flow

```
ESP32 (PZEM Sensor)
    ↓
    └─→ Every 10s: Read PZEM module
    └─→ Every 60s: Send averaged data via HTTP POST
        ↓
    Backend API (/api/sensor-data)
        ↓
        ├─→ Parse JSON payload
        ├─→ Extract device_id, voltage, current, power, etc.
        ├─→ Use power (watts) as primary metric value
        ├─→ Store in sensor_data table with timestamp
        └─→ Log activity in activity_logs table
        ↓
    PostgreSQL Database
        ├─ sensor_data table: timestamp, device_id, value
        └─ activity_logs table: audit trail
        ↓
    Recommendations Engine
        ├─ Fetches real data from sensor_data table
        ├─ Analyzes patterns and anomalies
        └─ Generates recommendations
        ↓
    Flutter Frontend
        └─ Displays real-time energy metrics and trends
```

---

## Database Schema

### sensor_data table

| Column | Type | Description |
|--------|------|-------------|
| id | BigInteger (PK) | Unique identifier |
| ds | DateTime | Timestamp of reading |
| device_id | String | ESP32 device identifier |
| value | Float | Power reading in watts |

**Example query**:
```sql
SELECT * FROM sensor_data 
WHERE device_id = 'ESP32-LAB-001' 
ORDER BY ds DESC 
LIMIT 10;
```

---

## Testing the Integration

### 1. Manual HTTP Test

**Send test data**:
```bash
curl -X POST http://localhost:5000/api/sensor-data \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "ESP32-LAB-001",
    "voltage": 230.5,
    "current": 2.3,
    "power": 529.15,
    "energy": 1.5,
    "frequency": 50.0,
    "power_factor": 0.95
  }'
```

**Expected Response**:
```json
{
  "status": "success",
  "message": "Sensor data from ESP32-LAB-001 received and stored",
  "device_id": "ESP32-LAB-001",
  "value": 529.15,
  "timestamp": "2025-01-03T10:30:45.123456+00:00"
}
```

**Retrieve data**:
```bash
curl "http://localhost:5000/api/sensor-data?device_id=ESP32-LAB-001&limit=10"
```

### 2. Verify in Database

```sql
-- Connect to database
psql -U postgres -h localhost -d energia

-- View recent sensor data
SELECT * FROM sensor_data ORDER BY ds DESC LIMIT 10;

-- Count readings per device
SELECT device_id, COUNT(*) as count 
FROM sensor_data 
GROUP BY device_id;

-- Check activity logs
SELECT * FROM activity_logs 
WHERE action = 'data_submission' 
ORDER BY timestamp DESC LIMIT 5;
```

### 3. Monitor ESP32 Serial Output

Upload your ESP32 code and monitor the serial port at 115200 baud:

```
==================================
ENERGIA - ESP32 PZEM Energy Monitor
GEC Idukki - IoT Energy Management
==================================

Connecting to WiFi: gecIi
.............
✓ WiFi connected
IP Address: 192.168.x.x

--- 10s Sensor Sample ---
Voltage: 230.45 V
Current: 2.30 A
Power: 529.15 W
Sample count: 1

[... repeats every 10 seconds ...]

=== Sending 1-Minute Averaged Data ===
Samples: 6
Payload: {"device_id":"ESP32-LAB-001","voltage":230.48,"current":2.31,"power":529.08,"energy":1.50,"frequency":50.00,"power_factor":0.95}
✓ HTTP Response: 200
{"status":"success","message":"Sensor data from ESP32-LAB-001 received and stored","device_id":"ESP32-LAB-001","value":529.08,"timestamp":"2025-01-03T10:30:45.123456+00:00"}
```

---

## Key Features

✅ **Real Data**: No more sample/test data for sensor readings  
✅ **Multiple Devices**: Support for multiple ESP32 devices with unique IDs  
✅ **Persistent Storage**: All readings stored in PostgreSQL  
✅ **Audit Trail**: Activity logging for compliance and debugging  
✅ **Historical Analysis**: Retrieve past readings for trends and predictions  
✅ **No Authentication**: Sensor endpoint is public (for IoT devices)  
✅ **Error Handling**: Graceful error responses with meaningful messages  
✅ **Performance**: Efficient database inserts with batch timestamps  

---

## Configuration

### ESP32 Settings (in your code)

```cpp
const char* WIFI_SSID     = "gecIi";              // Change to your WiFi
const char* WIFI_PASSWORD = "66666666";           // Change to your password
const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-data";
const char* DEVICE_ID  = "ESP32-LAB-001";         // Unique per device
const unsigned long READ_INTERVAL = 10000;        // 10 seconds
const unsigned long SEND_INTERVAL = 60000;        // 1 minute
```

### Backend Configuration (.env)

```
DB_URL=postgresql://postgres:postgres@localhost:5432/energia
JWT_SECRET=your-secret-key-here
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
```

---

## Recommendations Engine Integration

The AI Recommendation Engine now has access to real sensor data:

```python
# From ai_recommendation_engine.py
SELECT AVG(value) FROM sensor_data 
WHERE device_id = ? AND ds > NOW() - INTERVAL '24 hours'
```

This powers:
- **Energy Consumption Analysis**: Real patterns vs expected
- **Anomaly Detection**: Unexpected consumption spikes
- **Predictive Recommendations**: Optimize based on actual data
- **Trend Analysis**: Historical patterns for forecasting

---

## Next Steps

1. **Upload ESP32 Code**: Transfer your modified code to the device
2. **Power On**: Connect ESP32 and PZEM module
3. **Monitor**: Watch serial output for successful operation
4. **Verify**: Check database for incoming data
5. **Analyze**: Use the API to fetch historical data
6. **Optimize**: Adjust recommendations based on real data patterns

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| 404 Not Found | Ensure server is running on correct port (5000) |
| Connection Refused | Start backend: `python -m uvicorn app_main:app --reload` |
| JSON Parse Error | Verify ESP32 payload format matches expected schema |
| Database Error | Check DB_URL in .env and database is running |
| WiFi Connection Failed | Verify SSID/password in ESP32 code |
| PZEM Not Detected | Check RX/TX pin connections and power supply |

---

## Documentation Files

- [ESP32_SENSOR_DATA_GUIDE.md](ESP32_SENSOR_DATA_GUIDE.md) - Detailed API and usage guide
- [SETUP_AND_RUN_COMMANDS.md](SETUP_AND_RUN_COMMANDS.md) - Updated with sensor endpoints
- [AI_RECOMMENDATIONS.md](AI_RECOMMENDATIONS.md) - How recommendations use sensor data

---

## Support

For issues or questions:
1. Check the ESP32 serial output
2. Verify database connectivity: `python check_schema.py`
3. Test API manually with curl
4. Check docker-compose logs: `docker-compose logs -f`

The system is now ready to capture real sensor data from your ESP32!

