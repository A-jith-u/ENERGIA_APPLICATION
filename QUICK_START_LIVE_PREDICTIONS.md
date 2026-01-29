# Quick Start Guide - Live Data Predictions

## 🎯 What's New

Your prediction system now fetches **LIVE SENSOR DATA** instead of using old historical data. This means predictions are accurate to the current moment, predicting 5 minutes into the future based on what's happening RIGHT NOW.

## ✅ Quick Setup (5 minutes)

### 1. Start Backend Service
```bash
# Terminal 1: Navigate to backend
cd backend

# Start the prediction service
uvicorn serve_prophet:app --port 5000 --reload
```

You should see:
```
✓ Prophet model loaded from models/prophet_model.joblib
✓ Model loaded on startup
Uvicorn running on http://127.0.0.1:5000
```

### 2. Verify Everything Works
```bash
# Terminal 2: Run quick test
cd backend
python test_live_prediction.py
```

Look for:
- ✅ Status: 200 (OK)
- ✅ `"based_on_live_data": true` (MOST IMPORTANT!)

### 3. Open Flutter App
```bash
flutter run
```

Navigate to: **Prediction Comparison Page** → Select a room

### 4. Fetch Prediction
Click "Fetch Prediction" button and look for:
- 🟢 **Green "📡 Live Data" chip** = Using current sensor readings ✅
- 🔵 Blue "📊 Historical" chip = Using old training data ⚠️

## 🔍 Expected Output

### Terminal Output (Backend)
```
🔍 Fetching live sensor data: prophet_preprocessed
✅ Loaded 250 live sensor readings
   Range: 0.00 - 500.00
   Latest: 2026-01-20 14:30:00 = 245.67W
📊 Using live sensor data for prediction
   Latest live data: 2026-01-20 14:30:00
   Current time: 2026-01-20 14:30:15.123456+00:00
   Predicting 5 periods from 2026-01-20 14:30:00 to 2026-01-20 14:35:00
```

### Flutter UI Output
```
Step 1: Get 5‑minute prediction [📡 Live Data]  ← Green chip!
Predicted for: 2026-01-20 14:35:00
Predicted power: 250.34 W
ℹ️ Based on latest live sensor data (24h history)
```

### API Response
```json
{
  "timestamp": "2026-01-20T14:35:00+00:00",
  "yhat": 250.34,
  "yhat_lower": 220.12,
  "yhat_upper": 280.56,
  "generated_at": "2026-01-20T14:30:15+00:00",
  "horizon_minutes": 5,
  "based_on_live_data": true
}
```

## 📚 Key Files Changed

### Backend
- **`serve_prophet.py`** - Main prediction service with live data fetching

### Frontend
- **`lib/prediction_comparison_page.dart`** - UI updated with live data indicator

### Tools & Docs
- **`check_live_sensor_tables.py`** - Debug database structure
- **`test_live_prediction.py`** - Test the prediction endpoint
- **`integration_check.py`** - Full system health check
- **`LIVE_DATA_PREDICTION_FIX.md`** - Complete technical documentation

## 🐛 Troubleshooting

### Problem: Green chip shows but value seems old
```
Step: Check if sensor data is recent
Run: python check_live_sensor_tables.py
Look for "Latest:" timestamp - should be within last minute
```

### Problem: Shows "📊 Historical" (blue) instead of "📡 Live Data" (green)
```
Step 1: Check backend logs for "based_on_live_data: false"
Step 2: Run: python check_live_sensor_tables.py
Step 3: Verify sensor_data has recent readings (within 24h)
Step 4: If empty, predictions use historical training data (prophet_preprocessed)
```

### Problem: Backend returns 404 or timeout
```
Step 1: Verify backend is running on port 5000
Step 2: Check firewall isn't blocking localhost:5000
Step 3: Try manual test: python test_live_prediction.py
Step 4: Check database connection: python check_live_sensor_tables.py
```

### Problem: Prediction timestamps are wrong
```
Step 1: Check if database timestamps are in correct timezone
Step 2: Verify Flask/FastAPI timezone handling
Step 3: Compare backend timestamp with "generated_at" field
```

## 🎓 How It Works

### Before (Old System)
```
GET /predict_5min
→ Prophet uses its internal model state
→ Model was trained on historical data
→ Predictions are based on patterns, not current reality
❌ Can be very outdated
```

### After (New System - NOW ACTIVE!)
```
GET /predict_5min
→ Fetch latest 24 hours of sensor data
→ Find the most recent reading timestamp
→ Create future from that timestamp + 5 minutes
→ Generate prediction
→ Include "based_on_live_data: true" flag
✅ Predictions use current reality
```

### Example Timeline
```
TIME SCALE:
2026-01-20 14:25:00 ────── Oldest sensor reading (24h ago)
2026-01-20 14:30:00 ────── LATEST sensor reading  ← START HERE
                   |
2026-01-20 14:30:15 ────── Request received
                   |
                   └──→ Predict for 14:35:00  ← 5 min into future

RESULT: Prediction for 5 minutes from NOW ✅
```

## 📊 Performance

- **Latency**: ~1-2 seconds (includes DB fetch)
- **Accuracy**: Much better (uses live context)
- **Database load**: Minimal
- **Predictions**: Realistic and current

## ✨ Next Steps (Optional)

1. **Monitor prediction accuracy**: Compare predicted vs actual power at timestamp
2. **Multi-room support**: Modify room name parameter for room-specific predictions
3. **Real-time updates**: WebSocket for continuous live predictions
4. **Confidence scores**: See how confident the prediction is based on data freshness

## 🤔 Questions?

1. **How often is prediction updated?** - Every time you click "Fetch Prediction"
2. **Can I see historical predictions?** - Check `prophet_predictions` table in database
3. **How much data does it use?** - Last 24 hours (resampled to 1-minute intervals)
4. **What if no live data?** - Falls back to historical training data
5. **Can I change the 5-minute horizon?** - Yes, modify `horizon_minutes` parameter

## ✅ Verification Checklist

- [ ] Backend running on port 5000
- [ ] `test_live_prediction.py` shows `"based_on_live_data": true`
- [ ] Flutter app shows green "📡 Live Data" chip
- [ ] Predicted timestamp is ~5 minutes from now
- [ ] Predicted power value is reasonable (0-1000W range typically)
- [ ] Database has recent sensor readings

If all checked ✅, you're all set! **Live data predictions are now active!**

---

**Last Updated**: 2026-01-20  
**Status**: ✅ Active and ready to use  
**Documentation**: See `/LIVE_DATA_PREDICTION_FIX.md` for technical details
