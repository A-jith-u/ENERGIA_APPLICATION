# Two-Channel Relay Setup Guide

## 🔌 Hardware Wiring

### Your Configuration

You have a **2-channel relay module** connected to ESP32:

```
ESP32 Pin          Relay Module Pin
─────────────────  ────────────────
GPIO 26 (D26)  →   IN1 (Channel 1)
GPIO 27 (D27)  →   IN2 (Channel 2)
3.3V or 5V     →   VCC
GND            →   GND
```

### Relay Channels to Rooms

Each channel can control power to a different room:

```
Relay Module          AC Power Output
──────────────────    ─────────────────────
CH1 COM + NO      →   Room 1 Power Circuit
CH2 COM + NO      →   Room 2 Power Circuit
```

**Example:**
- Channel 1 → Controls **CS-C201** (Computer Lab 1)
- Channel 2 → Controls **CS-C202** (Computer Lab 2)

---

## ⚙️ Software Configuration

### Option 1: Single ESP32 for Two Rooms (Recommended)

Upload the code **TWICE** to the same ESP32 with different device IDs:

#### Upload 1 - Channel 1
```cpp
const char* DEVICE_ID = "ESP32-CS-LAB1-CH1";  // Controls Room CS-C201
```

#### Upload 2 - Channel 2
```cpp
const char* DEVICE_ID = "ESP32-CS-LAB1-CH2";  // Controls Room CS-C202
```

**How it works:**
- The code automatically detects which channel to use from the device ID
- If device ID ends with `-CH2` or `_CH2` → uses GPIO 27 (Channel 2)
- Otherwise → uses GPIO 26 (Channel 1)

### Option 2: Separate ESP32s (One Channel Each)

If you have multiple ESP32 boards, configure each one:

```cpp
// ESP32 #1
const char* DEVICE_ID = "ESP32-CS-C201";  // Uses CH1 by default

// ESP32 #2
const char* DEVICE_ID = "ESP32-CS-C202";  // Uses CH1 by default
```

---

## 🗄️ Database Configuration

### For Two Rooms with One ESP32

```sql
-- Room 1 → Relay Channel 1
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES ('CS-C201', 'ESP32-CS-LAB1-CH1', 1, 26);

-- Room 2 → Relay Channel 2
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES ('CS-C202', 'ESP32-CS-LAB1-CH2', 2, 27);
```

### For Separate ESP32 Boards

```sql
-- Room 1 → ESP32 #1
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES ('CS-C201', 'ESP32-CS-C201', 1, 26);

-- Room 2 → ESP32 #2
INSERT INTO room_relay_mapping (room_id, relay_device_id, relay_channel, relay_pin)
VALUES ('CS-C202', 'ESP32-CS-C202', 1, 26);
```

---

## 🔧 Pin Details

### GPIO 26 (D26) - Relay Channel 1
- **Pin Number:** GPIO 26
- **Alternative Names:** D26, A2, DAC2
- **Function:** Output to relay IN1
- **Logic:** HIGH = Relay ON, LOW = Relay OFF

### GPIO 27 (D27) - Relay Channel 2
- **Pin Number:** GPIO 27
- **Alternative Names:** D27, A3
- **Function:** Output to relay IN2
- **Logic:** HIGH = Relay ON, LOW = Relay OFF

### Built-in LED - GPIO 2
- **Function:** Visual feedback (blinks 3x when relay command executed)

---

## 📊 Serial Monitor Output

When ESP32 starts, you'll see:

```
WiFi connected
IP: 192.168.1.x
Relay Channel: 1

--- Sample (1/6) ---
Voltage: 230.00
Current: 0.52
Power: 115.00
Energy: 0.15
Freq: 50.00
PF: 0.98
Relay CH1: OFF
```

If using Channel 2 device ID:
```
Relay Channel: 2
Relay CH2: OFF
```

---

## 🧪 Testing Individual Channels

### Test Channel 1 (GPIO 26)

1. Set device ID:
   ```cpp
   const char* DEVICE_ID = "ESP32-TEST-CH1";
   ```

2. Upload code

3. From Sergeant dashboard, send **OFF** command

4. **Expected Result:**
   - GPIO 26 goes LOW
   - Relay IN1 indicator turns OFF
   - Channel 1 COM-NO circuit opens
   - Serial Monitor shows: `Relay CH1 set to: OFF (LOW)`

### Test Channel 2 (GPIO 27)

1. Set device ID:
   ```cpp
   const char* DEVICE_ID = "ESP32-TEST-CH2";
   ```

2. Upload code

3. Send **OFF** command from dashboard

4. **Expected Result:**
   - GPIO 27 goes LOW
   - Relay IN2 indicator turns OFF
   - Channel 2 COM-NO circuit opens
   - Serial Monitor shows: `Relay CH2 set to: OFF (LOW)`

---

## 🔍 Troubleshooting

### Channel 1 Not Working

**Check:**
1. Wire from ESP32 GPIO 26 to Relay IN1 is connected
2. Serial Monitor shows `Relay Channel: 1`
3. Device ID does NOT end with `-CH2` or `_CH2`

**Test:**
```cpp
// Add to loop() for debugging
digitalWrite(RELAY_CH1_PIN, HIGH);
delay(1000);
digitalWrite(RELAY_CH1_PIN, LOW);
delay(1000);
// Should see IN1 LED blink
```

### Channel 2 Not Working

**Check:**
1. Wire from ESP32 GPIO 27 to Relay IN2 is connected
2. Device ID ends with `-CH2` or `_CH2`
3. Serial Monitor shows `Relay Channel: 2`

**Test:**
```cpp
// Add to loop() for debugging
digitalWrite(RELAY_CH2_PIN, HIGH);
delay(1000);
digitalWrite(RELAY_CH2_PIN, LOW);
delay(1000);
// Should see IN2 LED blink
```

### Both Channels Activate Together

**Problem:** Device ID doesn't specify channel correctly

**Fix:** Use explicit channel suffix:
```cpp
const char* DEVICE_ID = "ESP32-ROOM201-CH1";  // Channel 1
const char* DEVICE_ID = "ESP32-ROOM202-CH2";  // Channel 2
```

---

## 💡 Advanced: Using Both Channels Simultaneously

If you want one ESP32 to monitor sensor data for one room but control relays for TWO rooms:

### Scenario
- **PZEM sensor** measures power for CS-C201
- **Relay CH1** controls CS-C201 power
- **Relay CH2** controls CS-C202 power (different room)

### Configuration

1. **Upload code with CH1 device ID:**
   ```cpp
   const char* DEVICE_ID = "ESP32-CS-C201-CH1";
   ```
   This instance controls Channel 1.

2. **Create a second virtual device for Channel 2:**
   - You'll need to run TWO instances of the ESP32 firmware
   - OR write custom code to poll for commands for BOTH device IDs

**Limitation:** Current code only polls for commands for ONE device ID at a time.

**Solution:** For simplest deployment, use **one ESP32 per room** or **one channel per ESP32**.

---

## 📋 Quick Reference Card

| Item | Value |
|------|-------|
| **Relay IN1 Pin** | GPIO 26 (D26) |
| **Relay IN2 Pin** | GPIO 27 (D27) |
| **LED Pin** | GPIO 2 |
| **PZEM RX** | GPIO 16 (Serial2) |
| **PZEM TX** | GPIO 17 (Serial2) |
| **Polling Interval** | 5 seconds |
| **Sensor Read Interval** | 10 seconds |
| **Data Send Interval** | 60 seconds |

---

## 🎯 Deployment Checklist

For **two rooms with one ESP32**:

- [ ] Wire IN1 to GPIO 26
- [ ] Wire IN2 to GPIO 27
- [ ] Wire VCC and GND
- [ ] Upload code with device ID ending in `-CH1`
- [ ] Test Channel 1 from dashboard
- [ ] Change device ID to end with `-CH2`
- [ ] Upload code again
- [ ] Test Channel 2 from dashboard
- [ ] Add both mappings to database

---

## 🚀 Example: Controlling 4 Rooms with 2 ESP32s

### ESP32 #1 (Building A, Floor 2)

**Wiring:**
- IN1 → GPIO 26 → Controls Room A201
- IN2 → GPIO 27 → Controls Room A202

**Configuration:**

Upload 1:
```cpp
const char* DEVICE_ID = "ESP32-A2-CH1";
```

Upload 2:
```cpp
const char* DEVICE_ID = "ESP32-A2-CH2";
```

**Database:**
```sql
INSERT INTO room_relay_mapping VALUES ('A201', 'ESP32-A2-CH1', 1, 26);
INSERT INTO room_relay_mapping VALUES ('A202', 'ESP32-A2-CH2', 2, 27);
```

### ESP32 #2 (Building A, Floor 3)

**Wiring:**
- IN1 → GPIO 26 → Controls Room A301
- IN2 → GPIO 27 → Controls Room A302

**Configuration:**

Upload 1:
```cpp
const char* DEVICE_ID = "ESP32-A3-CH1";
```

Upload 2:
```cpp
const char* DEVICE_ID = "ESP32-A3-CH2";
```

**Database:**
```sql
INSERT INTO room_relay_mapping VALUES ('A301', 'ESP32-A3-CH1', 1, 26);
INSERT INTO room_relay_mapping VALUES ('A302', 'ESP32-A3-CH2', 2, 27);
```

**Result:** 2 ESP32 boards control 4 rooms total! 🎉

---

## 📞 Support

If relay doesn't switch:
1. Check wiring matches GPIO 26/27
2. Verify Serial Monitor shows correct channel number
3. Test with multimeter: GPIO should show ~3.3V when ON, 0V when OFF
4. Some relays are LOW-trigger (activate on 0V) - invert logic if needed

**Inverted Relay Fix:**
```cpp
// If your relay activates on LOW instead of HIGH
digitalWrite(RELAY_CH1_PIN, state ? LOW : HIGH);  // Inverted
```
