# 🚀 Live Data Status - Quick Start Guide

## What Was Changed

✅ **All graphs and value displays now show:**
- 🟢 Green "📡 Live" badge when sensor is connected
- 🔴 Red "⚠️ No Live Data" message when sensor is offline
- Auto-updating timestamps showing "Updated: HH:MM"
- Helpful error messages and retry buttons when no data

---

## How to Test

### Step 1: Start Backend
```bash
cd backend
uvicorn app_main:app --port 5000 --reload
```

### Step 2: Run Flutter App
```bash
flutter run
```

### Step 3: Navigate to Dashboard Home Tab
You should see:
```
Energy Guardian          🟢 📡 Live
Welcome to CS-201! 💡
Live power: 2.45 kW (2450 W)
Updated: 14:32
```

---

## What You'll See

### When Sensor is CONNECTED ✅
- **Welcome Card:** Green "📡 Live" badge + power value + timestamp
- **Energy Meter:** Shows current kW with status "Active Usage"
- **Charts:** Shows data with "📡 Live Data" badge
- **Stats:** Displays Peak Today, Daily Total, Status
- **Updates:** Data refreshes every 60 seconds

### When Sensor is OFFLINE ❌
- **Welcome Card:** Red "⚠️ No Live Data" badge + message
- **Energy Meter:** Disabled state
- **Charts:** Shows "📡 Sensor not connected or offline" placeholder
- **Stats:** Shows "No Live Readings Available" with retry button
- **Auto-Retry:** Attempts connection every 60 seconds

---

## Key Features

| Feature | Live Data | No Data |
|---------|-----------|---------|
| Badge | 🟢 Live | 🔴 No Data |
| Power Display | 2.45 kW | — |
| Timestamp | 14:32 | Hidden |
| Charts | Shows data | "Not connected" |
| Stats | All visible | Retry button |
| Auto-Refresh | Every 60s | Every 60s |

---

## Files Changed

1. **lib/services/sensor_service.dart**
   - Added connectivity checking methods
   - Check if sensor data is fresh (within 5 minutes)

2. **lib/dashboard_page.dart**
   - Live data status in welcome card
   - Status badge (green/red)
   - "No live readings available" fallback UI
   - Timestamp display

3. **lib/widgets/energy_visualization_widgets.dart**
   - No-data placeholder in charts
   - Status badges in chart headers
   - Helpful error messages

4. **lib/prediction_page.dart**
   - Sensor status display
   - Auto-fetch latest sensor data
   - Timestamp of last update

---

## Troubleshooting

### Badge Shows Red (No Live Data)

**Check 1:** Backend is running
```bash
# Should show "Uvicorn running on http://0.0.0.0:5000"
cd backend
uvicorn app_main:app --port 5000 --reload
```

**Check 2:** ESP32 is connected to backend
```bash
# In backend folder, check if data is being inserted
python check_sensor_data.py
```

**Check 3:** Network connectivity
- Ping backend from your machine
- Check firewall settings on port 5000

### Data Updates Stopped

**Solution 1:** Pull down to refresh manually
**Solution 2:** Wait 60 seconds for auto-refresh
**Solution 3:** Close and reopen app

---

## Visual Indicators Explained

### 🟢 Green Indicators
- Live data available
- Sensor connected
- Data is fresh (< 5 minutes old)
- System is working normally

### 🔴 Red Indicators
- No live data available
- Sensor offline/disconnected
- No recent readings
- Check sensor connection

### 🟡 Orange Indicators
- Active usage detected
- Power consumption elevated
- May need attention

---

## Auto-Refresh Times

- **Dashboard Home:** 60 seconds
- **Prediction Page:** 5 minutes
- **Data Freshness Window:** 5 minutes
- **Manual Refresh:** Anytime (pull down or tap refresh)

---

## Network Fallback Order

The app tries to connect in this order:

1. `http://10.0.2.2:5000` (Android emulator preference)
2. `http://192.168.160.1:5000` (Local network)
3. `http://localhost:5000` (Local loopback)
4. `http://127.0.0.1:5000` (IPv4 loopback)

If all fail → Shows "No Live Data Available"

---

## Expected Behavior

### First Launch
```
Loading live data...
↓ (after 2-3 seconds)
🟢 📡 Live
Live power: 2.45 kW
```

### After 60 Seconds
```
Updated: 14:32
↓ (auto-refresh)
Updated: 14:33
Live power: 2.52 kW
```

### When Backend Stops
```
🟢 📡 Live
↓ (refresh every 60s attempts)
🔴 ⚠️ No Live Data
Retrying...
```

### When Backend Restarts
```
🔴 ⚠️ No Live Data
↓ (next auto-refresh)
🟢 📡 Live
Live power: 2.48 kW
```

---

## Testing Checklist

- [ ] Start backend on port 5000
- [ ] Run Flutter app
- [ ] See green "📡 Live" badge
- [ ] Wait 60 seconds, confirm data updates
- [ ] See timestamp update correctly
- [ ] Stop backend
- [ ] See red "🔴 No Live Data" badge
- [ ] See "No Live Readings Available" message
- [ ] Click [🔄 Retry] button
- [ ] Restart backend
- [ ] See status automatically update to green
- [ ] Data resumes flowing

✅ **All tests passed = Implementation successful!**

---

## Next Steps

1. **Test with live ESP32 sensor** - Verify real sensor data flows
2. **Monitor performance** - Check app responsiveness with auto-refresh
3. **User feedback** - Get feedback on visual indicators
4. **Deploy to production** - Roll out to users
5. **Optional:** Add notifications for prolonged offline periods

---

**Status:** ✅ **READY FOR TESTING**

All graphs and value displays now clearly show live sensor reading status!
