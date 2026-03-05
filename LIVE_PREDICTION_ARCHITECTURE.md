# Live Data Prediction - Visual Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER MOBILE APP                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Prediction Comparison Page                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ [Fetch Prediction]                                      │   │
│  │                                                          │   │
│  │ Step 1: Get 5‑minute prediction                        │   │
│  │  [📡 Live Data] ← Visual Indicator (GREEN!)            │   │
│  │  Predicted for: 2026-01-20 14:35:00                   │   │
│  │  Predicted power: 250.34 W                             │   │
│  │  ℹ️ Based on latest live sensor data (24h history)     │   │
│  │                                                          │   │
│  │ Step 2: Compare with actual reading                    │   │
│  │  [Fetch Actual Near Predicted Time]                    │   │
│  │  Actual power: 248.90 W                                │   │
│  │  Error: 1.44 W (0.6%)                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↑                                       │
│                   HTTP POST/GET                                  │
│           {"horizon_minutes": 5,                                 │
│            "room_name": "Lab1"}                                  │
│                           │                                       │
└───────────────────────────┼───────────────────────────────────────┘
                            │
                            │
┌───────────────────────────┼───────────────────────────────────────┐
│                           ↓                   BACKEND SERVICE     │
│                   FastAPI Server              (Port 5000)         │
├───────────────────────────┼───────────────────────────────────────┤
│                                                                   │
│  /predict_5min Endpoint (UPDATED)                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │  1️⃣ Fetch Live Sensor Data                             │   │
│  │     ↓                                                    │   │
│  │  2️⃣ Get Latest Timestamp                              │   │
│  │     ↓                                                    │   │
│  │  3️⃣ Create Future (Next 5 min)                         │   │
│  │     ↓                                                    │   │
│  │  4️⃣ Generate Forecast with Prophet                    │   │
│  │     ↓                                                    │   │
│  │  5️⃣ Return Result + Live Data Flag ✅                 │   │
│  │                                                          │   │
│  │  {                                                       │   │
│  │    "timestamp": "2026-01-20T14:35:00+00:00",          │   │
│  │    "yhat": 250.34,                                     │   │
│  │    "based_on_live_data": true  ← KEY!                 │   │
│  │  }                                                       │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│         ↑                                           ↑             │
│         │                                           │             │
│    REQUEST                                    RESPONSE            │
│                                                                   │
└───────────────────────────┬───────────────────────────────────────┘
                            │
                            ├─────────────────────┐
                            │                     │
          ┌─────────────────┴────────┐    ┌──────┴────────────┐
          ↓                          ↓    ↓                   ↓
      ┌────────┐  ┌────────────┐  ┌──────────────┐   ┌──────────────┐
      │ DATABASE│  │ PROPHET   │  │ LIVE SENSOR  │   │ HISTORICAL   │
      │         │  │ MODEL     │  │ DATA FETCHER │   │ FALLBACK     │
      ├────────┤  ├───────────┤  ├──────────────┤   ├──────────────┤
      │         │  │           │  │              │   │              │
      │sensor_ │  │ Trained   │  │ 24-hour data │   │ Training     │
      │data    │  │ on        │  │ Last 500 pts │   │ data         │
      │        │  │ historical│  │ 1-min resamp │   │ 250 points   │
      │250 pts │  │ patterns  │  │ Interp gaps  │   │              │
      │        │  │           │  │ Clip outliers│   │              │
      └────────┘  └───────────┘  └──────────────┘   └──────────────┘
       SQLite      Prophet.pkl    (if available)     (automatic)
```

## Data Flow Timeline

```
═══════════════════════════════════════════════════════════════════

                    TIME PROGRESSION

2026-01-15 12:37 ──┐ ← 24 hours ago (oldest sensor reading)
                   │
2026-01-16 00:00 ──┤ ← More historical data
                   │
2026-01-20 13:00 ──┤ ← Recent history
                   │
2026-01-20 14:30 ──┤ ← LATEST SENSOR READING (NOW USE THIS!)
                   │
2026-01-20 14:30:15 ┤ ← Request received
                   │
2026-01-20 14:35 ──┴─ PREDICTION GENERATED ✅
                   │
                   └─→ Return to app with "based_on_live_data: true"

═══════════════════════════════════════════════════════════════════

KEY INSIGHT: Prediction starts from LATEST LIVE TIME, not training end time!
```

## Request/Response Flow

```
┌─ FLUTTER APP ────────────────────────────────────────────────────┐
│                                                                   │
│  User clicks: [Fetch Prediction]                                │
│                                                                   │
│  setState({_loading = true})                                     │
│                                                                   │
│  POST /predict_5min {                                            │
│    "horizon_minutes": 5,                                         │
│    "room_name": "Lab1"                                           │
│  }                                                                │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP Request
                            │
                            ↓
┌─ BACKEND SERVICE ─────────────────────────────────────────────────┐
│                                                                   │
│  receive_request:                                                │
│    ├─ horizon_minutes: 5                                         │
│    └─ room_name: "Lab1"                                          │
│                                                                   │
│  fetch_live_data():                                              │
│    ├─ Query: SELECT * FROM sensor_data                           │
│    ├─ Result: 250 readings                                       │
│    ├─ Latest: 2026-01-20 14:30:00                                │
│    └─ Value: 245.67W                                             │
│                                                                   │
│  create_future_dates():                                          │
│    ├─ Start: 2026-01-20 14:30:00 (latest)                        │
│    ├─ End: 2026-01-20 14:35:00 (+5 min)                          │
│    └─ Periods: 5                                                 │
│                                                                   │
│  forecast = model.predict(future_df)                             │
│    ├─ Uses Prophet algorithm                                     │
│    ├─ Considers latest trends                                    │
│    └─ Returns confidence intervals                               │
│                                                                   │
│  return {                                                        │
│    "timestamp": "2026-01-20T14:35:00+00:00",                     │
│    "yhat": 250.34,                                               │
│    "yhat_lower": 220.12,                                         │
│    "yhat_upper": 280.56,                                         │
│    "generated_at": "2026-01-20T14:30:15+00:00",                  │
│    "horizon_minutes": 5,                                         │
│    "based_on_live_data": true  ← MARK AS LIVE ✅                │
│  }                                                                │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ HTTP Response
                            │
                            ↓
┌─ FLUTTER APP ────────────────────────────────────────────────────┐
│                                                                   │
│  receive_response:                                               │
│    ├─ timestamp: 2026-01-20T14:35:00+00:00 ✓                     │
│    ├─ yhat: 250.34 ✓                                             │
│    └─ based_on_live_data: true ← KEY FIELD!                      │
│                                                                   │
│  setState({                                                      │
│    _predictedForLocal: 2026-01-20 14:35:00,                      │
│    _predictedW: 250.34,                                          │
│    _isLiveDataBased: true,  ← Store this!                        │
│    _loading: false                                               │
│  })                                                               │
│                                                                   │
│  Display UI:                                                     │
│    Step 1: Get 5‑minute prediction                              │
│    [📡 Live Data]  ← GREEN CHIP SHOWS!                          │
│    Predicted for: 2026-01-20 14:35:00                           │
│    Predicted power: 250.34 W                                     │
│    ℹ️ Based on latest live sensor data (24h history)             │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## State Comparison: Before vs After

```
BEFORE (❌ OLD SYSTEM)
════════════════════════════════════════════════════════════════

Request:
  GET /predict_5min
  → No live context
  → Just generates from model

Processing:
  model.make_future_dataframe(periods=5)
  → Uses model's last known state
  → Doesn't know current reality

Response:
  {
    "timestamp": "2026-01-10T12:00:00Z",  ❌ Could be old!
    "yhat": 150.0,
    "based_on_live_data": false  ← OR field missing
  }

Display:
  Predicted for: 2026-01-10 12:00:00  ❌ Old timestamp!
  [No indicator] ← User doesn't know if it's live or not


AFTER (✅ NEW SYSTEM)
════════════════════════════════════════════════════════════════

Request:
  POST /predict_5min {
    "horizon_minutes": 5,
    "room_name": "Lab1"
  }
  → Includes live context
  → Room-aware

Processing:
  1. fetch_live_sensor_data()  ← NEW!
     → Gets latest 24h readings
     → Finds most recent timestamp
  
  2. latest_time = 2026-01-20 14:30:00
     → Uses CURRENT reality!
  
  3. model.predict(future from latest_time)
     → Forecasts from NOW
     → Accurate predictions!

Response:
  {
    "timestamp": "2026-01-20T14:35:00+00:00",  ✅ Current!
    "yhat": 250.34,
    "based_on_live_data": true  ← NEW FIELD! ✅
  }

Display:
  Predicted for: 2026-01-20 14:35:00  ✅ Current timestamp!
  [📡 Live Data]  ← Green chip shows data source! ✅
  ℹ️ Based on latest live sensor data  ← Clear explanation!
```

## Prediction Accuracy Improvement

```
SCENARIO: Lab has sensors, we want to predict power in 5 minutes

BEFORE (Historical only):
  ├─ Last training data: 2026-01-10 12:00
  ├─ Current time: 2026-01-20 14:30
  ├─ Gap: 10 days, 2.5 hours ❌
  ├─ Model says: "I don't know what's happening now!"
  ├─ Prediction: 150W (guess from old patterns)
  ├─ Actual 5 min later: 250W
  └─ Error: 100W (67%) ❌ VERY WRONG!

AFTER (Live data):
  ├─ Current sensor reading: 2026-01-20 14:30 = 245W
  ├─ Latest data age: 0 minutes ✅
  ├─ Model says: "Lab is using 245W RIGHT NOW"
  ├─ Trend: Stable (no change expected)
  ├─ Prediction: 250W (slight increase, similar patterns)
  ├─ Actual 5 min later: 248W
  └─ Error: 2W (0.8%) ✅ VERY ACCURATE!
```

## Component Interactions

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                       │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Prediction Comparison Page                         │  │
│  │ - _isLiveDataBased (state)                         │  │
│  │ - _fetchPrediction5Min() (method)                  │  │
│  │ - Green/Blue chips (UI)                            │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │ HTTP
                       │
┌──────────────────────┴───────────────────────────────────┐
│                  Backend API Layer                        │
│  FastAPI / serve_prophet.py                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │ POST /predict_5min                                 │  │
│  │ ├─ _fetch_live_sensor_data()      (NEW)            │  │
│  │ ├─ _predict_payload_with_live_data()  (NEW)        │  │
│  │ └─ Returns: timestamp, yhat, based_on_live_data   │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────┬───────────────────────────────────┘
                       │ SQL / File IO
                       │
        ┌──────────────┼──────────────┐
        ↓              ↓              ↓
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Database   │ │   Prophet    │ │ Environment  │
│              │ │   Model      │ │ Variables    │
│ - sensor_data│ │              │ │              │
│ - 24h data   │ │ - Trained on │ │ - DB_URL     │
│ - 250 points │ │   historical │ │ - MODEL_PATH │
│              │ │ - Serialized │ │              │
└──────────────┘ └──────────────┘ └──────────────┘
```

## Visual Flow: Click to Result

```
USER ACTION:
═════════════════════════════════════════════════════════════════

    Flutter App
          │
          ↓
    [ Fetch Prediction ] ← User clicks this button
          │
          ↓ (setState: _loading = true)
    ┌───────────────────┐
    │ Loading... ⏳      │
    └───────────────────┘
          │
          ↓ (HTTP POST to backend)
          │
    Backend Processing
          │
          ├─→ Fetch live sensor data from DB ✅
          ├─→ Get latest timestamp: 14:30:00 ✅
          ├─→ Create future: 14:30:00 → 14:35:00 ✅
          ├─→ Run Prophet forecast ✅
          └─→ Mark: "based_on_live_data: true" ✅
          │
          ↓ (HTTP response)
          │
    Flutter Receives
          │
          ├─→ Parse response ✅
          ├─→ Set _isLiveDataBased = true ✅
          └─→ setState() triggers rebuild
          │
          ↓
    ┌──────────────────────────────────────┐
    │ Step 1: Get 5‑minute prediction      │
    │         [📡 Live Data]  ← GREEN! ✅  │
    │ Predicted for: 2026-01-20 14:35:00  │
    │ Predicted power: 250.34 W            │
    │ ℹ️ Based on latest live sensor data   │
    └──────────────────────────────────────┘
          │
          ↓
    🎉 SUCCESS! Prediction shown with live indicator
```

---

This visual architecture shows how the live data prediction system is structured and how all components interact to deliver accurate, real-time forecasts to the user.
