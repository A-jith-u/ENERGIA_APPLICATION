# Live Data Status - Visual Guide

## Dashboard Home Tab

### ✅ When Sensor is CONNECTED & Live Data Available:

```
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  Energy Guardian              🟢 📡 Live                   ║
║                                                            ║
║  Welcome to CS-201! 💡                                     ║
║  Live power: 2.45 kW (2450 W)                              ║
║  Updated: 14:32                                            ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

                    LIVE USAGE DATA

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   CS-201 - Live Power                                      ║
║   Active Usage                                             ║
║                                                            ║
║   2.45 Watts (W)                                           ║
║   ─────────────────────────────────────                   ║
║   Capacity: 5000.00 Watts                                  ║
║                                                            ║
║   Usage Level          ||████████░░░░░░░░ 49.0%           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

                    QUICK STATS

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   📈 Peak Today          📊 Daily Total    ℹ️ Status      ║
║   2.50 kW                0.89 kWh          Active         ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

              LIVE POWER (LAST 60 READINGS)

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  📡 Live Data                          [🔄 Refresh]       ║
║  Last 60 readings • Unit: kW                               ║
║                                                            ║
║     kW ║                                                   ║
║        ║  ╱╲                                               ║
║    2.5 ║ ╱  ╲    ╱╲      ╱╲                               ║
║        ║╱    ╲  ╱  ╲    ╱  ╲ ╱╲                           ║
║    2.0 ║      ╲╱    ╲  ╱    ╲  ╲                          ║
║        ║               ╲╱      ╱╲  ╲                      ║
║    1.5 ║                      ╱  ╲  ╲                     ║
║        ║                         ╲  ╲                    ║
║    1.0 ║─────────────────────────── ─────                ║
║        ║─────────────────────────────────                ║
║        └─────────────────────────────────                ║
║         Time (newest on left)                             ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

---

### ❌ When Sensor is OFFLINE / No Live Data:

```
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  Energy Guardian          🔴 ⚠️ No Live Data              ║
║                                                            ║
║  Welcome to CS-201! 💡                                     ║
║  No live readings available                                ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

                    LIVE USAGE DATA

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║              📡 No Live Readings Available                 ║
║                                                            ║
║            Sensor not connected or offline                 ║
║                                                            ║
║                    [🔄 Retry]                              ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

                    QUICK STATS
                    (Stats hidden)

              LIVE POWER CHART
                (Chart hidden)

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  ⚠️ No Data                           [🔄 Refresh]        ║
║  Sensor is not connected or offline                        ║
║                                                            ║
║     kW ║                                                   ║
║        ║                                                   ║
║    2.5 ║            📡                                     ║
║        ║                                                   ║
║    2.0 ║     Sensor Not Connected                          ║
║        ║     Please verify connection                      ║
║    1.5 ║                                                   ║
║        ║                                                   ║
║    1.0 ║─────────────────────────────────                ║
║        │─────────────────────────────────                ║
║        └─────────────────────────────────                ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

---

## Energy Meter Widget

### ✅ Live Data Mode:
```
╔───────────────────────────────┐
│ CS-201 - Live Power    ↗ 5.2% │
│ Active Usage                  │
│                               │
│ 2.45 Watts (W)                │
│ Capacity: 5000.00 Watts       │
│                               │
│ Usage Level                   │
│ ███████░░░░░░░░░░  49.0%     │
└───────────────────────────────┘
```

### ❌ No Data Mode:
```
╔───────────────────────────────┐
│ CS-201 - Live Power           │
│ No Data Available             │
│                               │
│ 0.00 Watts (W)                │
│ Capacity: 0.00 Watts          │
│                               │
│ Usage Level                   │
│ ░░░░░░░░░░░░░░░░░░  0.0%     │
└───────────────────────────────┘
```

---

## Charts - Status Indicators

### ✅ Live Data Available:
```
Header: "Last 60 readings • Unit: kW"
Status Badge: [🟢 📡 Live Data]
Chart: Shows line chart with data
```

### ❌ No Data Available:
```
Header: "No data available"
Status Badge: [🔴 ⚠️ No Data]
Chart Area: Shows "📡 No Live Readings Available"
            "Sensor is not connected or offline"
```

---

## Prediction Page - Sensor Status

### Real-time Updates:
- **Live (32s ago)** → Data received 32 seconds ago
- **Recent (2m ago)** → Data received 2 minutes ago
- **No recent data** → No connection to sensor

```
Current (Live):    3.2 kW     📡 Live (32s ago)
Predicted (15min): 3.8 kW
Change:           +18.8% ↑
Confidence:       85%
```

---

## Status Color Coding

| Color | Meaning | Example |
|-------|---------|---------|
| 🟢 Green | Live/Connected | "📡 Live Data" badge |
| 🔴 Red | Offline/Error | "⚠️ No Live Data" badge |
| 🟡 Orange | Active but may need attention | High usage warning |
| ⚪ Gray | Idle/Standby | Device not using power |

---

## User Actions When No Live Data

1. **See "No Live Readings Available" message**
2. **Click [🔄 Retry] button** to refresh
3. **Wait for sensor to reconnect** (auto-refresh every 60s)
4. **Manually check backend service:**
   ```bash
   # Backend should be running on port 5000
   uvicorn app_main:app --port 5000 --reload
   ```
5. **Check ESP32 sensor connection** to backend

---

## Auto-Refresh Behavior

### Dashboard Home Tab
- ⏱️ **Refresh every 60 seconds** when app is open
- 🔄 **Manual refresh** by pulling down or tapping screen
- 🟢 **Immediate update** when live data becomes available
- 🔴 **5-minute freshness window** - after 5 min no data, shows "stale"

### Prediction Page
- ⏱️ **Auto-refresh every 5 minutes**
- 📡 **Tries 4 backend URLs** in order of preference
- ⏱️ **5-second timeout** per URL attempt
- 🔄 **Manual refresh** with the refresh button

---

## Integration Points

### For Developers
- Modify auto-refresh intervals in `_WelcomeSectionState.initState()`
- Change freshness window in `SensorService.isSensorDataFresh()` (currently 5 minutes)
- Add more backend URLs in `_loadLiveData()` apiCandidates list

### For DevOps
- Ensure backend is running on port 5000
- Check ESP32 is sending data to backend
- Verify network connectivity between app and backend

---

## Summary

✅ **Live Data Indicators Are Now Present In:**
- Welcome card (badge + timestamp)
- Energy meter (status field)
- Line charts ("Live Data" or "No Data" badge)
- Stats section (smart fallback)
- Prediction page (sensor status display)

✅ **Users Can Now See:**
- Is data fresh? (timestamp + "Live" badge)
- Is sensor connected? (green/red indicator)
- When to check sensor? (no data message)
- How to retry? (retry button)

✅ **System Automatically:**
- Updates status every 60 seconds
- Checks data freshness
- Shows helpful error messages
- Provides easy retry mechanism
