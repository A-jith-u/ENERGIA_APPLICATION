# IP Address Configuration for Sensor Readings

## Summary: Where to Change IP

You need to change the IP address in **4 key places**:

---

## 1. 📱 ESP32 Code (Arduino Sketch)

**File:** Your Arduino sketch

**Change this line:**
```cpp
const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-readings";
```

**Replace with your backend server IP:**
```cpp
const char* SERVER_URL = "http://YOUR_SERVER_IP:5000/api/sensor-readings";
```

**Examples:**
- If backend runs on same machine as ESP32's WiFi network: `http://192.168.x.x:5000/api/sensor-readings`
- If backend runs locally on your PC: `http://localhost:5000/api/sensor-readings` (won't work for ESP32 remote)
- If backend on different machine: `http://10.111.183.200:5000/api/sensor-readings`

---

## 2. 🎯 Flutter Service

**File:** `lib/services/sensor_service.dart` (you'll create this)

**Change this line:**
```dart
final String baseUrl = "http://10.111.183.200:5000/api";
```

**Replace with:**
```dart
final String baseUrl = "http://YOUR_SERVER_IP:5000/api";
```

**Examples:**
```dart
// For backend on same network
final String baseUrl = "http://192.168.x.x:5000/api";

// For backend on different machine
final String baseUrl = "http://10.111.183.200:5000/api";

// For local testing
final String baseUrl = "http://localhost:5000/api";
```

---

## 3. ⚙️ Backend Configuration (Optional)

**File:** `backend/.env`

Currently uses `localhost` for database:
```
DB_URL=postgresql+psycopg2://postgres:postgresql@localhost:5432/energia
```

**Change to your database server IP if needed:**
```
DB_URL=postgresql+psycopg2://postgres:postgresql@10.111.183.200:5432/energia
```

---

## 4. 🔧 Backend Server Address

**File:** `backend/app_main.py` or terminal command

When you start the backend, it runs on:
```powershell
python -m uvicorn app_main:app --host 0.0.0.0 --port 5000
```

**This means:**
- `--host 0.0.0.0` = Listens on all network interfaces (good for remote access)
- `--port 5000` = Uses port 5000

**Get your backend server IP:**

**Windows (PowerShell):**
```powershell
ipconfig
# Look for "IPv4 Address" like 192.168.x.x or 10.111.183.200
```

**Linux/Mac:**
```bash
ifconfig
# or
ip addr
```

---

## How to Find Your Server IP

### Option 1: Use the actual machine IP (Recommended)

**Windows PowerShell:**
```powershell
$env:Path += ";C:\Program Files\PostgreSQL\18\bin"
ipconfig
```

Look for:
```
IPv4 Address . . . . . . . . . . . : 192.168.1.100
```

### Option 2: Use localhost (for testing on same machine)
If ESP32 and backend are on same WiFi network:
```
http://192.168.x.x:5000/api
```

### Option 3: Check your network
If your network is `192.168.1.x`, your backend server IP is something like:
- `192.168.1.5`
- `192.168.1.10`
- `10.111.183.200` (as you mentioned)

---

## Complete Example Configuration

### Example 1: Backend on PC (192.168.1.10)

**ESP32 Code:**
```cpp
const char* SERVER_URL = "http://192.168.1.10:5000/api/sensor-readings";
```

**Flutter Service:**
```dart
final String baseUrl = "http://192.168.1.10:5000/api";
```

**Backend .env:**
```
DB_URL=postgresql+psycopg2://postgres:postgresql@localhost:5432/energia
```

### Example 2: Backend on Remote Server (10.111.183.200)

**ESP32 Code:**
```cpp
const char* SERVER_URL = "http://10.111.183.200:5000/api/sensor-readings";
```

**Flutter Service:**
```dart
final String baseUrl = "http://10.111.183.200:5000/api";
```

**Backend .env:**
```
DB_URL=postgresql+psycopg2://postgres:postgresql@10.111.183.200:5432/energia
```

---

## Testing Your Configuration

### 1. Test if backend is accessible

**From Windows PowerShell:**
```powershell
Test-NetConnection -ComputerName YOUR_SERVER_IP -Port 5000
```

Should return: `TcpTestSucceeded : True`

### 2. Test from ESP32 Serial Monitor

Upload your ESP32 code and watch the serial output:
```
Connecting to WiFi: gecIi
✓ WiFi connected
IP Address: 192.168.x.x

=== Sending 1-Minute Averaged Data ===
✓ HTTP Response: 200
{"status":"success",...}
```

### 3. Test from Flutter

If the service connects successfully:
```dart
final readings = await sensorService.getSensorReadings();
// Should return sensor data
```

---

## Checklist: Before You Start

- [ ] Find your backend server IP using `ipconfig`
- [ ] Update **ESP32 code** with correct SERVER_URL
- [ ] Update **Flutter sensor_service.dart** with correct baseUrl
- [ ] Update **backend/.env** if database is on different machine
- [ ] Test connectivity: `ping YOUR_SERVER_IP`
- [ ] Test port: `Test-NetConnection -ComputerName YOUR_SERVER_IP -Port 5000`
- [ ] Start backend: `python -m uvicorn app_main:app --host 0.0.0.0 --port 5000`

---

## Common Issues

| Problem | Solution |
|---------|----------|
| "Connection refused" | Wrong IP or backend not running |
| "Timeout" | IP is correct but port is wrong or firewall blocks it |
| "Cannot find host" | IP address is invalid, check with `ipconfig` |
| "ESP32 can't reach backend" | Use actual network IP, not `localhost` |
| "Flutter can't fetch data" | Use same IP as ESP32, or your PC's IP if testing locally |

---

## Quick Reference

**3 places to update with YOUR_SERVER_IP:**

1. **ESP32**: `const char* SERVER_URL = "http://YOUR_SERVER_IP:5000/api/sensor-readings";`
2. **Flutter**: `final String baseUrl = "http://YOUR_SERVER_IP:5000/api";`
3. **Backend .env**: `DB_URL=postgresql+psycopg2://postgres:postgresql@YOUR_SERVER_IP:5432/energia` (if remote)

That's it! 🎯

