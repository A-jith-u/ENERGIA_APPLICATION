# ESP32 Relay Kill Switch - Quick Start

## 🎯 What You Have Now

Complete kill switch system where sergeants can control room power from the Flutter app with a single tap.

## 📂 New Files Created

1. **esp32_with_relay.ino** - Updated ESP32 code with relay control
2. **backend/relay_control_schema.sql** - Database tables for relay commands
3. **RELAY_KILL_SWITCH_GUIDE.md** - Complete integration guide (read this!)

## 🔧 What Changed in Existing Files

### Backend
- **relay_control_api.py** - Updated to use polling-based command queue instead of direct HTTP

### Already Working
- ✅ Sergeant dashboard has ON/OFF buttons (already implemented)
- ✅ `lib/services/sergeant_api.dart` has `controlRelay()` function
- ✅ Database integration ready

## 🚀 Quick Deployment (5 Steps)

### Step 1: Create Database Tables
```bash
psql -U postgres -d energia_db -f backend/relay_control_schema.sql
```

### Step 2: Add Room Mapping
```sql
-- Map room CS-C201 to ESP32-CS-C201
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES ('CS-C201', 'ESP32-CS-C201', 1, 4);
```

### Step 3: Update ESP32 Code
Open `esp32_with_relay.ino` and update:
```cpp
const char* WIFI_SSID     = "YOUR-WIFI-NAME";         // Line 8
const char* WIFI_PASSWORD = "YOUR-WIFI-PASSWORD";     // Line 9
const char* DEVICE_ID     = "ESP32-CS-C201";          // Line 13 (match mapping!)
```

Update backend IP if different:
```cpp
const char* SERVER_URL         = "http://10.181.241.69:5000/api/sensor-data";
const char* RELAY_POLL_URL     = "http://10.181.241.69:5000/api/relay/commands";
const char* RELAY_STATUS_URL   = "http://10.181.241.69:5000/api/relay/status";
```

### Step 4: Wire Relay to ESP32
```
ESP32 Pin    → Relay Module
─────────────────────────────
GPIO 26      → IN1 (Channel 1)
GPIO 27      → IN2 (Channel 2)
3.3V         → VCC
GND          → GND
```

**For Two-Channel Relay:**
- Use device ID ending with `-CH1` for Channel 1 (GPIO 26)
- Use device ID ending with `-CH2` for Channel 2 (GPIO 27)

See **TWO_CHANNEL_RELAY_SETUP.md** for detailed wiring guide.

Connect relay COM/NO to room power line.

### Step 5: Upload to ESP32
1. Open Arduino IDE
2. Select **Board:** ESP32 Dev Module
3. Select **Port:** (your COM port)
4. Click **Upload**

## ✅ Test It!

1. **Check ESP32 Serial Monitor:**
   ```
   WiFi connected
   IP: 192.168.1.x
   --- Sample (1/6) ---
   Voltage: 230.0
   Relay: OFF
   ```

2. **Open Sergeant Dashboard in App**
3. **Find Room CS-C201**
4. **Tap OFF Button**
5. **Watch:**
   - App shows success ✅
   - ESP32 LED blinks 3x 💡
   - Relay clicks (power cuts) ⚡🚫

## 🔄 How It Works (Simple)

```
Sergeant taps OFF
    ↓
Backend queues command
    ↓
ESP32 polls every 5 seconds
    ↓
ESP32 sees command "OFF"
    ↓
ESP32 sets GPIO 4 to LOW
    ↓
Relay opens
    ↓
Room power CUTS 🔌❌
    ↓
ESP32 reports "Command executed"
    ↓
Dashboard updates to show relay OFF
```

**Execution time:** Command executes within 5 seconds (next poll interval)

## 📊 Backend API Endpoints (Already Working)

### For App
- `POST /api/relay/control` - Send ON/OFF command (sergeant only)
- `GET /api/relay/device-status/{device_id}` - Get current relay state
- `GET /api/relay/all-device-status` - Get all relay states

### For ESP32  
- `GET /api/relay/commands?device_id=X` - Poll for commands (ESP32 checks every 5 sec)
- `POST /api/relay/commands/ack` - Acknowledge execution
- `POST /api/relay/status` - Report current state

## 🔍 Troubleshooting

### ESP32 Not Connecting
```cpp
// Serial Monitor shows:
Connecting WiFi........
```
**Fix:** Check WiFi credentials in code (lines 8-9)

### Command Not Executing
```sql
-- Check if command was queued:
SELECT * FROM relay_commands WHERE device_id = 'ESP32-CS-C201' ORDER BY created_at DESC LIMIT 3;
-- Should show status = 'PENDING' then 'EXECUTED'
```

**Fix:** 
- Verify device_id matches exactly (case-sensitive!)
- Check ESP32 is polling (serial monitor shows "Checking for commands...")

### Relay Not Switching
**Check:**
1. GPIO pin matches wiring: `const int RELAY_PIN = 4`
2. Relay gets power (3.3V to VCC)
3. Try inverting logic if relay is LOW-trigger type

## 📚 Full Documentation

See **RELAY_KILL_SWITCH_GUIDE.md** for:
- Complete architecture diagrams
- Database schema details
- Security considerations
- Advanced troubleshooting
- Scaling to 100+ rooms
- FAQ

## 🎯 What's Already Working

Your Sergeant Dashboard **already has** the UI buttons! Just need to:
1. Run database migration ✅
2. Upload ESP32 code ✅
3. Wire relay hardware ✅

The app-to-backend communication is already complete.

## 💡 Key Points

- **Polling-based:** ESP32 checks backend every 5 seconds (more reliable than push)
- **Queue system:** Commands never lost, execute even if ESP32 temporarily offline
- **Audit trail:** Every command logged with who/when/why
- **Scalable:** Works for 1 room or 100+ rooms
- **Secure:** Sergeant JWT auth required

## 🚨 Important Configuration

Make sure device ID in ESP32 code **exactly** matches database mapping:

```cpp
// ESP32 code
const char* DEVICE_ID = "ESP32-CS-C201";
```

```sql
-- Database
INSERT INTO room_relay_mapping (room_id, relay_device_id, ...)
VALUES ('CS-C201', 'ESP32-CS-C201', ...);
--                  ^^^^^^^^^^^^^^ Must match!
```

---

**Ready to deploy!** 🚀

Start with one room (CS-C201) to test, then replicate for other rooms.
