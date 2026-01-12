# Quick Start - Energy Prediction Feature

## 1. Backend Setup (5 minutes)

### Train the Prophet Model
```bash
cd backend

# Train with sample data
python train_prophet.py --csv sample_data/prophet_training_sample.csv --horizon-minutes 15

# Or train with database
python train_prophet.py --raw-table pzem_readings --horizon-minutes 15
```

### Start Backend Server
```bash
# From project root
python backend/start_server.py
```

### Test Prediction Endpoint
```bash
curl -X POST http://localhost:8000/model/predict_15min \
  -H "Content-Type: application/json" \
  -d '{}'
```

Expected response:
```json
{
  "timestamp": "2025-12-29T10:15:00",
  "predicted_energy": 3.45,
  "lower_bound": 2.87,
  "upper_bound": 4.03,
  "generated_at": "2025-12-29T10:00:00Z",
  "horizon_minutes": 15
}
```

## 2. Frontend Setup (2 minutes)

### Update Backend URL (if not localhost)
Edit `lib/prediction_page.dart` line 37:
```dart
Uri.parse('http://YOUR_BACKEND_URL:8000/model/predict_15min'),
```

### Run Flutter App
```bash
flutter run
```

## 3. Access Prediction Feature

### Navigation:
1. **Login** as Class Representative
2. **Select Classroom** (e.g., CS-202, IT-Lab 1, etc.)
3. **Open Dashboard** (Dash)
4. **Tap "Analysis" Tab** (bottom navigation, first icon)
5. **Scroll to "Energy Usage Prediction"** tile
6. **Tap the tile** to view predictions

## 4. Verify Everything Works

### ✅ Checklist:
- [ ] Backend server running on port 8000
- [ ] Prophet model trained (models/prophet_model.joblib exists)
- [ ] Prediction endpoint responds (test with curl)
- [ ] Flutter app running
- [ ] Can navigate to prediction page
- [ ] Prediction loads successfully
- [ ] Chart displays correctly
- [ ] Auto-refresh works (wait 5 minutes)

## 5. Troubleshooting

### Backend Issues:

**"Model not found" error:**
```bash
# Train the model first
cd backend
python train_prophet.py --csv sample_data/prophet_training_sample.csv
```

**Port 8000 already in use:**
```bash
# Windows
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# Linux/Mac
lsof -ti:8000 | xargs kill -9
```

**Import errors:**
```bash
pip install -r backend/requirements.txt
```

### Frontend Issues:

**Connection refused:**
- Check backend URL in prediction_page.dart
- Ensure backend is running
- For Android emulator, use `http://10.0.2.2:8000`
- For iOS simulator, use `http://localhost:8000`
- For physical device, use your computer's IP

**UI not showing:**
- Run `flutter clean`
- Run `flutter pub get`
- Restart the app

**Chart not rendering:**
- Ensure fl_chart is in pubspec.yaml
- Run `flutter pub get`
- Hot restart (not just hot reload)

## 6. Testing Different Scenarios

### High Usage Prediction (Red Status):
Modify training data to include high values, or manually test by editing the response.

### Moderate Usage (Orange Status):
Predicted value between 3.5 - 5.0 kWh

### Normal Usage (Green Status):
Predicted value < 3.5 kWh (typical scenario)

## 7. Production Deployment

### Backend:
1. Set proper DB_URL in environment
2. Train model with real historical data
3. Deploy to cloud (AWS, Azure, GCP)
4. Use HTTPS endpoint

### Frontend:
1. Update backend URL to production
2. Build release version
3. Test on physical devices
4. Deploy to app stores

### Environment Variables:
```bash
# backend/.env
DB_URL=postgresql://user:pass@host:5432/energia
MODEL_PATH=models/prophet_model.joblib
```

## 8. Monitoring & Maintenance

### Check Model Accuracy:
```bash
cd backend
python train_prophet.py --eval-split 0.2
```

### Retrain Periodically:
```bash
# Weekly retraining recommended
python train_prophet.py --raw-table pzem_readings
```

### Monitor Predictions:
- Check prediction accuracy vs actual
- Adjust confidence intervals if needed
- Update training data regularly

## 9. User Guide for Class Reps

### When to Check:
- Before class starts
- During peak usage hours
- When planning activities

### How to Interpret:
- **Green**: Continue normal operations
- **Orange**: Monitor closely, reduce if possible
- **Red**: Take action to reduce usage

### Actions to Take:
1. Turn off unnecessary lights
2. Adjust AC settings
3. Power down unused equipment
4. Report to coordinator if consistently high

## 10. Support & Resources

### Documentation:
- [PREDICTION_FEATURE.md](PREDICTION_FEATURE.md) - Complete feature docs
- [PREDICTION_UI_GUIDE.md](PREDICTION_UI_GUIDE.md) - Visual guide

### API Endpoints:
- POST `/model/predict_15min` - Get 15-min prediction
- POST `/model/predict_next` - Flexible predictions
- GET `/model/health` - Check model status

### Need Help?
- Check logs: `backend/logs/` (if configured)
- Review error messages in app
- Test endpoint with curl
- Verify model file exists

---

## Summary

✨ **You now have:**
- AI-powered energy predictions
- Beautiful visual representation
- Auto-refreshing dashboard
- Status-based alerts
- Easy navigation for class reps

🎯 **Next Steps:**
- Train with real data
- Customize thresholds
- Add more prediction horizons
- Integrate notifications
- Export prediction reports

Happy Predicting! 🚀
