# Prediction Page - Technical Architecture

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     PREDICTION COMPARISON PAGE                   │
│                  (prediction_comparison_page.dart)               │
└──────────────────────┬──────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
   ┌─────────┐  ┌──────────────┐  ┌─────────────┐
   │ On Load │  │ Fetch        │  │ Fetch       │
   │ Display│  │ Prediction   │  │ Actual      │
   │ Live   │  │ (GET Forecast)  │ (Compare)   │
   └────┬────┘  └───────┬──────┘  └──────┬──────┘
        │                │               │
        ▼                ▼               ▼
   ┌────────────────────────────────────────────┐
   │         BACKEND API Endpoints               │
   ├────────────────────────────────────────────┤
   │ GET /api/sensor-data?limit=1440            │
   │   → Latest power reading                    │
   │   → 24h historical data                     │
   │   → For calculating avg/min/max             │
   │                                             │
   │ GET /model/predict_5min (or POST)           │
   │   OR /predict_5min (fallback)               │
   │   → Predicted power (yhat)                  │
   │   → Confidence range (yhat_lower/upper)     │
   │   → Data source (live vs historical)        │
   │                                             │
   │ GET /api/sensor-data?limit=120              │
   │   → Recent readings near prediction time    │
   │   → For accuracy comparison                 │
   └────────────────────────────────────────────┘
        │                │               │
        ▼                ▼               ▼
   ┌──────────┐  ┌──────────┐  ┌──────────────┐
   │ Readings │  │ Yhat &   │  │ Matching     │
   │ 1440     │  │ Bounds   │  │ Reading      │
   │ points   │  │ + Source │  │ Near Time    │
   └────┬─────┘  └────┬─────┘  └────┬─────────┘
        │             │             │
        └─────────────┼─────────────┘
                      │
        ┌─────────────▼──────────────┐
        │  DATA PROCESSING & STATE    │
        ├────────────────────────────┤
        │ • Parse timestamps (local) │
        │ • Extract power values      │
        │ • Calculate avg/min/max     │
        │ • Determine trend direction │
        │ • Calc accuracy percentage  │
        │ • Generate insights        │
        └────────────┬────────────────┘
                     │
        ┌────────────▼──────────────┐
        │   UPDATE WIDGET STATE      │
        ├────────────────────────────┤
        │ _latestLivePowerW          │
        │ _avgPower24h               │
        │ _maxPower24h               │
        │ _minPower24h               │
        │ _trendDirection            │
        │ _predictedW                │
        │ _accuracyPercent           │
        │ _isLiveDataBased           │
        └────────────┬────────────────┘
                     │
        ┌────────────▼──────────────┐
        │   RENDER UI CARDS          │
        ├────────────────────────────┤
        │ 1. Live Power Card         │
        │ 2. 24h Stats              │
        │ 3. Forecast Card          │
        │ 4. Accuracy Card          │
        │ 5. Insights Card          │
        └────────────────────────────┘
```

---

## API Contract Details

### 1. Live Sensor Data Endpoint

**Request:**
```http
GET /api/sensor-data?limit=1440&room=CS-201
```

**Response (JSON):**
```json
{
  "count": 1440,
  "data": [
    {
      "id": 1,
      "ds": "2026-03-05 10:30:45.123456",
      "power": 48.5,
      "value": 48.5,
      "energy": 0.0125,
      "voltage": 230.5,
      "current": 0.21,
      "frequency": 50.0,
      "power_factor": 0.98,
      "timestamp": "2026-03-05T10:30:45Z"
    },
    ...
  ]
}
```

**Field Mapping:**
- `power` or `value` or `energy` → Used for power consumption
- `ds` or `timestamp` → Converted to local time
- All 1440 readings used for 24h statistics

---

### 2. Prediction Endpoint

**Request (Get Forecast):**
```http
GET /model/predict_5min?room=CS-201
or
POST /model/predict_5min
  Content-Type: application/json
  {"horizon_minutes": 5, "room_name": "CS-201"}
```

**Response (JSON):**
```json
{
  "status": "success",
  "timestamp": "2026-03-05T10:35:00Z",
  "yhat": 52.1,
  "yhat_lower": 48.2,
  "yhat_upper": 56.0,
  "based_on_live_data": true,
  "method": "prophet_with_live_data",
  "confidence": 0.95
}
```

**Field Mapping:**
- `yhat` → Predicted power (required)
- `yhat_lower`, `yhat_upper` → Confidence interval
- `timestamp` → When prediction was made
- `based_on_live_data` → Badge display
- Any field can be null (gracefully handled)

---

### 3. Historical Comparison (Recent Readings)

**Request (Compare):**
```http
GET /api/sensor-data?limit=120&room=CS-201
```

**Response:**
```json
{
  "count": 120,
  "data": [
    {
      "ds": "2026-03-05 10:35:02.456789",
      "power": 51.8,
      "value": 51.8,
      ...
    },
    ...
  ]
}
```

**Used For:**
- Find reading closest to prediction timestamp
- Calculate actual power at that time
- Compare with prediction value
- Calculate accuracy percentage

---

## State Management Flow

### Initial State (Page Load)
```dart
_loading = false
_error = null
_latestLivePowerW = null
_latestLiveTime = null
_avgPower24h = null
_predictedW = null
_actualW = null
_accuracyPercent = null
```

### After "Get Forecast" Button
```
1. Set _loading = true
2. Call _fetchPrediction5Min()
3. Parse response → Set _predictedW, _predictedLower, _predictedUpper
4. Call _fetchLiveData() in background
5. Parse live data → Set _latestLivePowerW, _avgPower24h, etc.
6. Set _loading = false
7. UI rebuilds with new data
```

### After "Compare" Button
```
1. Set _loading = true
2. Call _fetchActualForPredictedTime()
3. Find reading nearest to _predictedForLocal
4. Extract power value → Set _actualW
5. Calculate accuracy: ((predicted - actual) / actual) * 100
6. Set _accuracyPercent
7. Set _loading = false
8. UI shows comparison card
```

---

## Error Handling Strategy

### Network Failures
```dart
// Try multiple server addresses
if (localhost fails) {
  try 127.0.0.1
  if (that fails) {
    try 192.168.160.1
    if (that fails) {
      try 10.0.2.2
      if (all fail) {
        show error: "Could not connect to backend"
      }
    }
  }
}
```

### Timeout Handling
```dart
// 15-second timeout per request
.timeout(const Duration(seconds: 15), onTimeout: () {
  throw TimeoutException('Request timed out');
});

// If timeout, move to next endpoint
try {
  POST /model/predict_5min
} catch {
  try {
    GET /predict_5min
  } catch {
    try next server
  }
}
```

### Missing Data
```dart
// Graceful fallbacks for missing fields
double _parsePowerW(Map<String, dynamic> reading) {
  return reading['power'] ?? 
         reading['value'] ?? 
         reading['energy'] ?? 
         0.0;
}

// Check for null before operations
if (row[1] is not None) {
  device_data.add(float(row[1]))
}

// Default values
latitude_reading = _latestLivePowerW ?? 0.0
```

### Empty Data
```dart
// Check list before processing
if (readings.isEmpty) {
  show error: "No data available"
  continue to next endpoint
}

// Handle small datasets
if (powerValues.length < 3) {
  skip anomaly detection
  use fallback calculations
}
```

---

## Timestamp Handling

### Local Database Format (Sensor)
```
"ds": "2026-03-05 10:30:45.123456"
→ No timezone indicator
→ Assumed to be LOCAL time
→ Parsed as: DateTime.tryParse("2026-03-05T10:30:45.123456")
```

### ISO Format (Prophet API)
```
"timestamp": "2026-03-05T10:35:00Z"
→ 'Z' indicates UTC
→ Converted to local: DateTime.tryParse(s).toLocal()
→ Displayed as local time
```

### Display Format
```
HH:MM format (24-hour)
"14:35:00" → "14:35"
Full: "2026-03-05 14:35"
```

---

## Calculation Algorithms

### Trend Direction
```dart
if (powerValues.length > 5) {
  recentAvg = average(last 5 values)
  oldAvg = average(first 5 values)
  
  if (recentAvg > oldAvg * 1.1) {
    trend = "increasing" (📈)
  } else if (recentAvg < oldAvg * 0.9) {
    trend = "decreasing" (📉)
  } else {
    trend = "stable" (➡️)
  }
}
```

### Accuracy Percentage
```dart
accuracy = 100 - errorPercent

errorPercent = ((predicted - actual).abs() / actual) * 100
accuracy = max(0, 100 - errorPercent)

// Green: 80%+
// Orange: 60-80%
// Red: <60%
```

### 24-Hour Statistics
```dart
avgPower = sum(all power values) / count
maxPower = max(all power values)
minPower = min(all power values)

// All calculated from readings array
```

---

## Performance Optimization

### Data Limits
```
Live data request: limit=1440 (24 hours at 1-min intervals)
Recent data for comparison: limit=120 (2 hours)
→ Balances accuracy with response time

Total payload: ~10-15 KB
Processing time: <100ms
```

### Caching Strategy
```
No explicit caching
Fresh data fetched each request
(Backend may cache sensor data)
```

### Reusable Widgets
```
_StatBox    → Used 3x (avg/peak/min)
_InsightTile → Used 3x (different insights)
→ Reduces code duplication
→ Ensures consistent styling
```

---

## Testing Approach

### Unit Test Structure
```
Test data parsing:
  ✓ parsePowerW() with all column variants
  ✓ parseTimestamp() with local and ISO
  ✓ getTrendColor() for all directions
  
Test calculations:
  ✓ Accuracy percentage formula
  ✓ Statistics (avg/min/max)
  ✓ Trend determination logic

Test state management:
  ✓ State updates correctly
  ✓ Loading state transitions
  ✓ Error state handling
```

### Integration Test Structure
```
Test API calls:
  ✓ Mock /api/sensor-data endpoint
  ✓ Mock /model/predict_5min endpoint
  ✓ Verify correct requests sent
  ✓ Verify responses parsed correctly

Test UI updates:
  ✓ Page renders correctly
  ✓ Buttons enable/disable appropriately
  ✓ Error messages display
  ✓ Data updates trigger rebuild
```

---

## Security Considerations

### No Sensitive Data Stored
```
- No credentials in code
- No API keys exposed
- Passwords not logged
- User data not cached
```

### Network Security
```
- HTTP used (update to HTTPS in production)
- Timeouts prevent hanging
- Error messages are generic
- No stack traces shown to user
```

### Input Validation
```
- Room names sanitized (URI encoding)
- Timestamps validated before parsing
- Numeric values checked for valid ranges
- Null checks on all external data
```

---

## Deployment Checklist

- [ ] Backend APIs running on port 5000
- [ ] `/api/sensor-data` endpoint returns data
- [ ] `/model/predict_5min` endpoint returns predictions
- [ ] Confidence intervals (yhat_lower/upper) included
- [ ] Timestamps are correct timezone
- [ ] Flutter app compiled without errors
- [ ] Page navigates correctly
- [ ] All buttons functional
- [ ] Error handling works (disconnect backend to test)
- [ ] Network requests timeout after 15 seconds
- [ ] Color indicators update based on values
- [ ] Trending emoji appears
- [ ] Insights generate appropriate text
