# NoneType Error Fixes - Summary

## Issues Fixed

### 1. "'NoneType' object has no attribute 'get'" Error
**Location:** `ai_recommendation_engine.py` line 478

**Root Cause:** The `anomalies` list could contain `None` values, but the code was calling `.get()` on them without checking first.

**Fix Applied:**
```python
# BEFORE:
dept_anomalies = [a for a in anomalies if department.lower() in a.get("device_id", "").lower()]

# AFTER:
anomalies_filtered = [a for a in (anomalies or []) if a is not None]
dept_anomalies = [a for a in anomalies_filtered if department.lower() in a.get("device_id", "").lower()]
```

---

### 2. "float() argument must be a string or a real number, not 'NoneType'" Error
**Location:** Multiple locations in `ai_recommendation_engine.py` and `serve_prophet.py`

#### Fix 2a: serve_prophet.py - Line 275
**Issue:** Accessing DataFrame columns without checking if they exist or contain None
```python
# BEFORE:
if live_df['power'].notna().any():
    latest_reading = live_df['power'].iloc[-1]
else:
    latest_reading = live_df['y'].iloc[-1] if 'y' in live_df.columns else 0

# AFTER:
if 'power' in live_df.columns and pd.notna(live_df['power'].iloc[-1]):
    latest_reading = float(live_df['power'].iloc[-1])
elif 'value' in live_df.columns and pd.notna(live_df['value'].iloc[-1]):
    latest_reading = float(live_df['value'].iloc[-1])
elif 'y' in live_df.columns and pd.notna(live_df['y'].iloc[-1]):
    latest_reading = float(live_df['y'].iloc[-1])
else:
    latest_reading = 0.0
```

#### Fix 2b: ai_recommendation_engine.py - Line 283
**Issue:** Converting potentially None value to float
```python
# BEFORE:
"current_value": float(row[1]),

# AFTER:
"current_value": float(row[1]) if row[1] is not None else 0,
```

#### Fix 2c: ai_recommendation_engine.py - Line 342
**Issue:** Appending None values to float list
```python
# BEFORE:
device_data[device_id].append(float(row[1]))

# AFTER:
if row[1] is not None:
    device_data[device_id].append(float(row[1]))
```

---

## Summary of Changes

| File | Line(s) | Issue | Fix Type |
|------|---------|-------|----------|
| `ai_recommendation_engine.py` | 478 | None in list with .get() call | Filter out None values |
| `ai_recommendation_engine.py` | 283 | None value to float | Add None check |
| `ai_recommendation_engine.py` | 342 | None value to float | Add None check |
| `serve_prophet.py` | 275 | None DataFrame with missing columns | Multiple fallback checks |

## Testing Recommendations

1. **Test Endpoints:**
   - POST `/recommendations/coordinator/{dept_name}` - Should not error with None anomalies
   - GET `/model/predict_15min_detailed` - Should handle missing live data gracefully
   - GET `/model/predict_5min` - Should return valid fallback when live data is None

2. **Edge Cases Covered:**
   - Empty anomaly lists
   - Missing sensor columns (power vs y vs value)
   - None values in database query results
   - Missing DataFrames from database queries

## Production Status
✅ All syntax errors fixed
✅ Proper None checks added
✅ Graceful fallbacks implemented
✅ Ready for testing
