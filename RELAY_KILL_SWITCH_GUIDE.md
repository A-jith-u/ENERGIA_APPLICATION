# ESP32 Relay Control Kill Switch - Complete Integration Guide

## 📋 Overview

This guide explains how the **Sergeant Kill Switch** works end-to-end, from the Flutter app to the ESP32 hardware relay.

### System Architecture

```
[Sergeant Dashboard] → [Backend API] → [Database Queue] → [ESP32 Polls] → [Relay Hardware] → [Room Power]
      Flutter             FastAPI        PostgreSQL        Polling         GPIO Control      ON/OFF
```

---

## 🔄 How the Kill Switch Works

### 1. **Sergeant Triggers Kill Switch**

**Location:** Sergeant Dashboard → Room List → OFF Button

When a sergeant taps the **OFF** button for a room:

```dart
// lib/sergeant_dashboard.dart
ElevatedButton(
  onPressed: () => _controlRoomPower(roomId, 'OFF'),
  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
  child: const Text('OFF'),
)
```

This calls:

```dart
Future<void> _controlRoomPower(String roomId, String action) async {
  await controlRelay(
    token,
    roomId: roomId,
    action: action,  // "ON" or "OFF"
    reason: 'Manual power control by Sergeant dashboard',
  );
}
```

### 2. **Flutter API Sends Command**

**Location:** `lib/services/sergeant_api.dart`

```dart
Future<Map<String, dynamic>> controlRelay(
  String token, {
  required String roomId,
  required String action,
  String? reason,
}) async {
  return _postJson(
    '/relay/control',
    {
      'room_id': roomId,
      'action': action,
      if (reason != null) 'reason': reason,
    },
    token: token,
  );
}
```

**HTTP Request:**
```http
POST http://10.181.241.69:5000/api/relay/control
Authorization: Bearer <sergeant-token>
Content-Type: application/json

{
  "room_id": "CS-C201",
  "action": "OFF",
  "reason": "Manual power control by Sergeant dashboard"
}
```

### 3. **Backend Queues Command**

**Location:** `backend/relay_control_api.py`

The backend receives the command and:
1. ✅ Verifies sergeant JWT token
2. 🔍 Looks up relay device for room (e.g., `CS-C201` → `ESP32-CS-C201`)
3. 📝 Inserts command into `relay_commands` table with status `PENDING`
4. 📊 Logs action to `relay_control_logs` for audit trail

```python
@app.post("/control")
async def control_relay(request: RelayControlRequest, authorization: str):
    # Verify token
    user = verify_token(authorization, ["sergeant", "admin"])
    
    # Get device mapping for room
    mapping = conn.execute(text("""
        SELECT relay_device_id, relay_channel
        FROM room_relay_mapping
        WHERE room_id = :room_id
    """), {"room_id": request.room_id}).fetchone()
    
    # Queue command
    command_id = queue_relay_command(
        device_id=device_id,
        action=request.action.upper(),
        user_id=user["user_id"],
        user_name=user["user_name"],
        reason=request.reason
    )
    
    return {
        "status": "queued",
        "command_id": command_id,
        "note": "Command will execute within 5 seconds"
    }
```

**Database Entry:**
```sql
INSERT INTO relay_commands 
(device_id, command, sergeant_id, reason, status, created_at)
VALUES 
('ESP32-CS-C201', 'OFF', 'SGT001', 'Manual power control', 'PENDING', NOW());
```

### 4. **ESP32 Polls for Commands**

**Location:** `esp32_with_relay.ino`

Every **5 seconds**, the ESP32 polls the backend:

```cpp
void checkRelayCommands() {
  HTTPClient http;
  String url = String(RELAY_POLL_URL) + "?device_id=" + DEVICE_ID;
  // RELAY_POLL_URL = "http://10.181.241.69:5000/api/relay/commands"
  
  http.begin(url);
  int httpCode = http.GET();
  
  if (httpCode == 200) {
    // Command found!
    StaticJsonDocument<256> doc;
    deserializeJson(doc, http.getString());
    
    const char* command = doc["command"];  // "ON" or "OFF"
    int commandId = doc["command_id"];
    
    if (strcmp(command, "OFF") == 0) {
      executeRelayCommand(false);
      acknowledgeCommand(commandId, false);
    }
  }
  else if (httpCode == 204) {
    // No commands pending - normal
  }
}
```

**HTTP Request from ESP32:**
```http
GET http://10.181.241.69:5000/api/relay/commands?device_id=ESP32-CS-C201
```

**Backend Response (if command pending):**
```json
{
  "command_id": 42,
  "command": "OFF",
  "device_id": "ESP32-CS-C201",
  "timestamp": "2026-03-07T14:35:22"
}
```

**Backend Response (no commands):**
```http
HTTP 204 No Content
```

### 5. **ESP32 Executes Command**

**Location:** `esp32_with_relay.ino`

```cpp
void executeRelayCommand(bool state) {
  relayState = state;
  digitalWrite(RELAY_PIN, state ? HIGH : LOW);  // Control GPIO 4
  
  // Visual feedback - blink LED 3 times
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
  
  // Report new status immediately
  reportRelayStatus();
}
```

**Hardware Action:**
- GPIO 4 (`RELAY_PIN`) → `LOW` (0V)
- Relay opens circuit
- Room power cuts OFF ⚡🚫

### 6. **ESP32 Acknowledges Execution**

**Location:** `esp32_with_relay.ino`

```cpp
void acknowledgeCommand(int commandId, bool executedState) {
  StaticJsonDocument<128> json;
  json["device_id"] = DEVICE_ID;
  json["command_id"] = commandId;
  json["executed"] = true;
  json["new_state"] = executedState ? "ON" : "OFF";

  String payload;
  serializeJson(json, payload);
  
  HTTPClient http;
  http.begin(RELAY_POLL_URL + "/ack");
  http.addHeader("Content-Type", "application/json");
  http.POST(payload);
}
```

**HTTP Request:**
```http
POST http://10.181.241.69:5000/api/relay/commands/ack
Content-Type: application/json

{
  "device_id": "ESP32-CS-C201",
  "command_id": 42,
  "executed": true,
  "new_state": "OFF"
}
```

**Backend Updates:**
```sql
-- Mark command as executed
UPDATE relay_commands 
SET status = 'EXECUTED', executed_at = NOW() 
WHERE id = 42;

-- Update device state
INSERT INTO relay_states (device_id, state, last_updated)
VALUES ('ESP32-CS-C201', 'OFF', NOW())
ON CONFLICT (device_id) 
DO UPDATE SET state = 'OFF', last_updated = NOW();
```

### 7. **Dashboard Shows Updated Status**

When the sergeant refreshes or pulls down:

```dart
Future<void> _loadData() async {
  final token = await _readToken();
  
  // Fetch relay mappings with current states
  _mappings = await getRelayMappings(token!);
  
  setState(() {
    // Update UI to show relay is OFF
  });
}
```

---

## 🛠️ Hardware Setup

### ESP32 Wiring

**Two-Channel Relay Module:**

```
ESP32              Relay Module          AC Load
─────              ─────────────         ────────
GPIO 26 ───────► IN1 (Channel 1)                    
GPIO 27 ───────► IN2 (Channel 2)
3.3V    ───────► VCC               
GND     ───────► GND               
                 CH1 COM ──────────► Room 1 Live Wire IN
                 CH1 NO  ──────────► Room 1 Live Wire OUT
                 CH2 COM ──────────► Room 2 Live Wire IN
                 CH2 NO  ──────────► Room 2 Live Wire OUT
```

**One ESP32 can control TWO rooms** with this setup!

### GPIO Pin Configuration

```cpp
// Two-channel relay pins
const int RELAY_CH1_PIN = 26;  // IN1 connected to GPIO26 (D26)
const int RELAY_CH2_PIN = 27;  // IN2 connected to GPIO27 (D27)
const int LED_PIN = 2;         // Built-in LED for visual feedback

pinMode(RELAY_CH1_PIN, OUTPUT);
pinMode(RELAY_CH2_PIN, OUTPUT);
pinMode(LED_PIN, OUTPUT);

// Initialize both relays to OFF
digitalWrite(RELAY_CH1_PIN, LOW);
digitalWrite(RELAY_CH2_PIN, LOW);
```

### Device ID Channel Detection

The code automatically determines which channel to use based on the device ID:

```cpp
// Device ID ends with -CH2 or _CH2 → Uses Channel 2 (GPIO 27)
// Otherwise → Uses Channel 1 (GPIO 26)

String deviceIdStr = String(DEVICE_ID);
if (deviceIdStr.endsWith("-CH2") || deviceIdStr.endsWith("_CH2")) {
  relayChannel = 2;  // Use GPIO 27
} else {
  relayChannel = 1;  // Use GPIO 26 (default)
}
```

**Examples:**
- `"ESP32-CS-C201"` → Channel 1 (GPIO 26)
- `"ESP32-CS-C201-CH1"` → Channel 1 (GPIO 26)
- `"ESP32-CS-C202-CH2"` → Channel 2 (GPIO 27)

### Relay Logic

- **HIGH (3.3V)** → Relay closes → Power **ON**
- **LOW (0V)** → Relay opens → Power **OFF**

---

## 📊 Database Schema

### Core Tables

#### 1. `relay_commands` - Command Queue
```sql
CREATE TABLE relay_commands (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    command VARCHAR(10) NOT NULL,        -- "ON" or "OFF"
    sergeant_id VARCHAR(20),
    reason TEXT,
    status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, EXECUTED, FAILED
    created_at TIMESTAMP DEFAULT NOW(),
    executed_at TIMESTAMP
);
```

#### 2. `relay_states` - Current Device State
```sql
CREATE TABLE relay_states (
    device_id VARCHAR(50) PRIMARY KEY,
    state VARCHAR(10) NOT NULL,          -- "ON", "OFF", "UNKNOWN"
    last_updated TIMESTAMP DEFAULT NOW()
);
```

#### 3. `room_relay_mapping` - Room to Device Mapping
```sql
CREATE TABLE room_relay_mapping (
    id SERIAL PRIMARY KEY,
    room_id VARCHAR(20) NOT NULL UNIQUE,
    relay_device_id VARCHAR(50) NOT NULL,
    relay_channel INT NOT NULL,          -- 1 or 2
    relay_pin INT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### 4. `relay_control_logs` - Audit Trail
```sql
CREATE TABLE relay_control_logs (
    id SERIAL PRIMARY KEY,
    room_id VARCHAR(20),
    relay_channel INT,
    action VARCHAR(10) NOT NULL,
    trigger_type VARCHAR(20) NOT NULL,   -- "manual" or "auto"
    triggered_by_user_id VARCHAR(50),
    triggered_by_user_name VARCHAR(100),
    reason TEXT,
    timestamp TIMESTAMP DEFAULT NOW()
);
```

---

## 🚀 Deployment Steps

### Step 1: Database Setup

```bash
# Connect to PostgreSQL
psql -U postgres -d energia_db

# Run migration
\i backend/relay_control_schema.sql

# Verify tables
\dt relay_*

# Insert room mappings (Two-channel relay example)
# Channel 1 (GPIO 26)
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES ('CS-C201', 'ESP32-CS-LAB1-CH1', 1, 26);

# Channel 2 (GPIO 27) - same ESP32, different channel
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES ('CS-C202', 'ESP32-CS-LAB1-CH2', 2, 27);
```

### Step 2: Configure ESP32

1. **Update WiFi credentials:**
   ```cpp
   const char* WIFI_SSID     = "YOUR-WIFI-NAME";
   const char* WIFI_PASSWORD = "YOUR-WIFI-PASSWORD";
   ```

2. **Update server IP:**
   ```cpp
   const char* SERVER_URL         = "http://10.181.241.69:5000/api/sensor-data";
   const char* RELAY_POLL_URL     = "http://10.181.241.69:5000/api/relay/commands";
   const char* RELAY_STATUS_URL   = "http://10.181.241.69:5000/api/relay/status";
   ```

3. **Set device ID (for two-channel relay):**
   ```cpp
   // For Channel 1 (GPIO 26)
   const char* DEVICE_ID = "ESP32-CS-LAB1-CH1";
   
   // To use Channel 2 (GPIO 27), change to:
   // const char* DEVICE_ID = "ESP32-CS-LAB1-CH2";
   ```
   
   **Note:** Device ID ending with `-CH2` or `_CH2` uses Channel 2 (GPIO 27).  
   Otherwise, uses Channel 1 (GPIO 26) by default.

4. **Upload code:**
   ```bash
   # In Arduino IDE
   Tools → Board → ESP32 Dev Module
   Tools → Port → COM3 (your port)
   Sketch → Upload
   ```

### Step 3: Mount Backend API

**Location:** `backend/app_main.py`

```python
from relay_control_api import app as relay_app

# Mount relay control API
app.mount("/api/relay", relay_app)
```

Restart backend:
```bash
cd backend
python app_main.py
# Backend running on http://0.0.0.0:5000
```

### Step 4: Test End-to-End

#### Test 1: Check ESP32 Connection
```bash
# ESP32 Serial Monitor should show:
WiFi connected
IP: 192.168.1.x
--- Sample (1/6) ---
Voltage: 230.00
Current: 0.50
Power: 115.00
Relay: OFF
```

#### Test 2: Send Command from App
1. Open Sergeant Dashboard
2. Find room "CS-C201"
3. Tap **OFF** button
4. Watch for:
   - ✅ Success notification in app
   - ✅ ESP32 LED blinks 3 times
   - ✅ Serial Monitor shows "RELAY COMMAND RECEIVED"

#### Test 3: Verify Database
```sql
-- Check command was queued and executed
SELECT * FROM relay_commands 
WHERE device_id = 'ESP32-CS-C201' 
ORDER BY created_at DESC 
LIMIT 5;

-- Check current state
SELECT * FROM relay_states 
WHERE device_id = 'ESP32-CS-C201';

-- Check audit log
SELECT * FROM relay_control_logs 
ORDER BY timestamp DESC 
LIMIT 10;
```

---

## 🔍 Troubleshooting

### Issue 1: ESP32 Not Receiving Commands

**Symptom:** Tap OFF button, no relay action  
**Debug:**

```cpp
// ESP32 Serial Monitor
=== HTTP POLL ===
GET http://10.181.241.69:5000/api/relay/commands?device_id=ESP32-CS-C201
HTTP Status: 204  // No commands (wrong!)
```

**Fix:**
1. Check room mapping exists:
   ```sql
   SELECT * FROM room_relay_mapping WHERE room_id = 'CS-C201';
   ```
2. Check command was queued:
   ```sql
   SELECT * FROM relay_commands WHERE device_id = 'ESP32-CS-C201' AND status = 'PENDING';
   ```
3. Verify device_id matches exactly (case-sensitive!)

### Issue 2: Command Queued but Never Executes

**Symptom:** Database shows `PENDING` forever  
**Debug:**

```sql
SELECT device_id, command, status, created_at 
FROM relay_commands 
WHERE status = 'PENDING' 
AND created_at < NOW() - INTERVAL '1 minute';
```

**Possible Causes:**
- ESP32 offline (check WiFi)
- Device ID mismatch
- ESP32 polling disabled
- Network firewall blocking HTTP

**Fix:**
```cpp
// Check ESP32 Serial Monitor
// Should see every 5 seconds:
Poll interval: 5000ms
Checking for commands...
```

### Issue 3: Relay State Stale

**Symptom:** Dashboard shows "UNKNOWN" or old state  
**Debug:**

```sql
SELECT device_id, state, last_updated,
       EXTRACT(EPOCH FROM (NOW() - last_updated)) AS age_seconds
FROM relay_states
WHERE device_id = 'ESP32-CS-C201';
```

**Fix:**
- If `age_seconds` > 30: ESP32 not reporting status
- Check `reportRelayStatus()` is being called
- Verify `RELAY_STATUS_URL` is correct

### Issue 4: Relay Physically Not Switching

**Symptom:** Command executes, but room power stays on  
**Debug:**

```cpp
// ESP32 Serial Monitor should show:
=== RELAY COMMAND RECEIVED ===
Command: OFF
✓ Relay turned OFF
digitalWrite(RELAY_PIN, LOW);
```

**Possible Causes:**
1. **Wrong GPIO pin** - Check wiring vs `const int RELAY_PIN = 4`
2. **Relay logic inverted** - Some relays trigger on LOW instead of HIGH
3. **Insufficient power** - Relay needs 5V, ESP32 GPIO is 3.3V
4. **Relay module broken** - Test with multimeter

**Fix for inverted logic:**
```cpp
// Change in executeRelayCommand():
digitalWrite(RELAY_PIN, state ? LOW : HIGH);  // Inverted!
```

---

## 📈 Performance & Scalability

### Timing Breakdown
- **Sergeant tap** → Backend: `~200ms` (HTTP POST)
- **Backend** → Database insert: `~5ms`
- **ESP32 poll** (worst case): `~5 seconds` (next poll interval)
- **ESP32 execute** → Relay: `~50ms` (GPIO write)
- **Total worst case:** **~5.3 seconds** from button tap to power cut

### Optimization for Critical Scenarios

For **emergency cutoffs** (anomaly alerts), reduce polling:

```cpp
const unsigned long POLL_INTERVAL = 2000;  // 2 seconds instead of 5
```

**Trade-off:**  
✅ Faster response  
❌ More network traffic (30 polls/min vs 12 polls/min)

### Scaling to 100+ Rooms

**Current load (per device):**
- 12 GET requests/min (polling)
- 1-2 POST requests/min (sensor data)
- 0-5 POST requests/hour (commands)

**100 devices = 1,200 requests/min** → Backend can handle easily

**Database optimization:**
```sql
-- Auto-cleanup old commands
CREATE INDEX idx_relay_commands_created_at ON relay_commands(created_at);

-- Periodically delete executed commands older than 7 days
DELETE FROM relay_commands 
WHERE status IN ('EXECUTED', 'FAILED') 
AND executed_at < NOW() - INTERVAL '7 days';
```

---

## 🔐 Security Considerations

### 1. **JWT Authentication**
- Only sergeants and admins can control relays
- Token verified on every `/relay/control` request
- ESP32 polling does NOT require auth (device ID is implicit auth)

### 2. **Audit Trail**
Every command logged with:
- Who triggered it (sergeant ID)
- When it happened
- Why (reason field)
- Result (executed/failed)

### 3. **Prevent Unauthorized Access**

**Risk:** Someone on the network sends fake commands to `/relay/commands`

**Mitigation:**
- Require API key header for ESP32 endpoints
- Verify device IP against whitelist
- Use HTTPS in production

Example:
```cpp
// ESP32 adds API key to polling requests
http.addHeader("X-Device-Key", DEVICE_API_KEY);
```

```python
# Backend validates
@app.get("/commands")
async def get_pending_commands(device_id: str, x_device_key: str = Header(None)):
    if x_device_key != os.getenv("DEVICE_API_KEY"):
        raise HTTPException(status_code=403, detail="Invalid device key")
```

---

## 📝 API Endpoints Summary

### For Sergeant App

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/relay/control` | POST | ✅ Sergeant | Queue ON/OFF command |
| `/relay/device-status/{device_id}` | GET | ✅ Sergeant | Get live relay state |
| `/relay/all-device-status` | GET | ✅ Sergeant | Get all relay states |
| `/relay/logs` | GET | ✅ Sergeant | Get audit trail |

### For ESP32

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/relay/commands?device_id=X` | GET | ❌ No | Poll for pending commands |
| `/relay/commands/ack` | POST | ❌ No | Acknowledge execution |
| `/relay/status` | POST | ❌ No | Report current state |

---

## 🎯 Next Steps

### Phase 1: Basic Deployment ✅
- [x] ESP32 code with relay control
- [x] Backend polling endpoints
- [x] Database schema
- [x] App UI integration

### Phase 2: Enhanced Features
- [ ] Real-time WebSocket updates (instant feedback without polling)
- [ ] Scheduled power cutoffs (e.g., auto-off at 6 PM)
- [ ] Energy-based auto-cutoff (cut power if usage > threshold)
- [ ] Multi-channel relay support (control 2 circuits per ESP32)

### Phase 3: Advanced Monitoring
- [ ] Relay health monitoring (detect failed relays)
- [ ] Power consumption before/after cutoff metrics
- [ ] Alert escalation integration (auto-cutoff after 7 min alert)
- [ ] Sergeant notification when relay fails to respond

---

## 📚 Files Reference

### ESP32
- `esp32_with_relay.ino` - Complete ESP32 code with PZEM + relay

### Backend
- `backend/relay_control_api.py` - Relay control API endpoints
- `backend/relay_control_schema.sql` - Database tables

### Flutter App
- `lib/services/sergeant_api.dart` - `controlRelay()` function
- `lib/sergeant_dashboard.dart` - UI with ON/OFF buttons

### Database
- Table: `relay_commands` - Command queue
- Table: `relay_states` - Current device states
- Table: `room_relay_mapping` - Room to device mapping
- Table: `relay_control_logs` - Audit trail

---

## 💡 FAQ

**Q: What happens if ESP32 loses WiFi during a command?**  
A: Command stays `PENDING` in database. When ESP32 reconnects, it polls and executes the command. Commands don't expire.

**Q: Can I control relay from the web (not just app)?**  
A: Yes! Same API endpoints work from any HTTP client. Just need sergeant JWT token.

**Q: How do I know if relay actually switched?**  
A: ESP32 acknowledges execution. Check `relay_states` table or use `/relay/device-status/{device_id}` endpoint.

**Q: Can I manually test relay without the app?**  
A: Yes, use `curl`:
```bash
curl -X POST http://10.181.241.69:5000/api/relay/control \
  -H "Authorization: Bearer <sergeant-token>" \
  -H "Content-Type: application/json" \
  -d '{"room_id": "CS-C201", "action": "OFF"}'
```

**Q: What if two sergeants send conflicting commands?**  
A: Commands execute in order (FIFO). Last command wins. Both logged in audit trail.

---

## ✅ Checklist for Go-Live

- [ ] Database tables created (`relay_control_schema.sql`)
- [ ] Room mappings configured (`room_relay_mapping`)
- [ ] ESP32 flashed with updated code
- [ ] ESP32 connected to WiFi (check serial monitor)
- [ ] ESP32 polling successfully (HTTP 204 every 5 sec)
- [ ] Backend API mounted at `/api/relay`
- [ ] Test command from app to ESP32 works
- [ ] Relay physically switches room power
- [ ] Audit logs recording properly
- [ ] Sergeant can see live relay state in dashboard

---

**🎉 Your Kill Switch is Ready!**

The sergeant can now control room power with a single tap. Commands queue reliably, execute within 5 seconds, and everything is logged for audit.
