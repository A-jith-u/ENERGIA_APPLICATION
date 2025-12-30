# Quick Start - Recommendation System

## 1. Backend Setup (3 minutes)

### Ensure Database is Running
```bash
# Recommendations use the existing DB
# No additional setup needed if DB is already configured
```

### Start Backend Server
```bash
# From project root
python backend/start_server.py
```

Server will now include `/recommendations/*` endpoints.

### Test Recommendation API
```bash
# Get a JWT token first
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"your_username","password":"your_password"}'

# Use the token
TOKEN="your_jwt_token_here"

# Test recommendations endpoint
curl -X GET http://localhost:8000/recommendations/recommendations \
  -H "Authorization: Bearer $TOKEN"
```

Expected response:
```json
{
  "recommendations": [
    {
      "id": "predictive_1735470000.123",
      "title": "High Usage Predicted",
      "message": "Next 15 min: 5.20 kWh expected...",
      "type": "predictive",
      "priority": "critical",
      "action": "View prediction details",
      "data": {"predicted_energy": 5.2},
      "icon": "trending_up",
      "timestamp": "2025-12-29T10:00:00Z"
    }
  ],
  "count": 5
}
```

## 2. Frontend Setup (2 minutes)

### Update Backend URL (if not localhost)
Edit `lib/widgets/recommendation_widgets.dart` line 85:
```dart
static const String baseUrl = 'http://YOUR_BACKEND_URL:8000/recommendations';
```

### Run Flutter App
```bash
flutter run
```

## 3. See Recommendations in Action

### For Class Representatives:
1. **Login** as Class Rep
2. **Navigate to Dashboard** (Dash page)
3. **Go to Analysis Tab** (first bottom tab)
4. **Scroll to top** - Recommendations appear first
5. **Tap any recommendation** for details

### For Coordinators:
1. Login as Coordinator
2. Dashboard will show department-specific recommendations
3. Includes classroom alerts and anomaly notifications

### For Admins:
1. Login as Admin
2. Dashboard shows campus-wide recommendations
3. System health, user management, and optimization tips

## 4. Verify Everything Works

### ✅ Checklist:
- [ ] Backend server running (port 8000)
- [ ] Can get JWT token via login
- [ ] Recommendations endpoint responds
- [ ] Flutter app shows recommendation cards
- [ ] Can tap recommendations for details
- [ ] Auto-refresh works (wait 3 minutes)
- [ ] Recommendations match user role

## 5. Understanding the UI

### Recommendation Card Structure:
```
┌─────────────────────────────────────┐
│ 🔴  High Usage Predicted     HIGH  │
│                                     │
│ Next 15 min: 5.20 kWh expected.   │
│ Turn off non-essential equipment.  │
│                                     │
│ 👆 View prediction details →       │
└─────────────────────────────────────┘
```

### Color Codes:
- **🔴 Red Border**: Critical - Act now!
- **🟠 Orange Border**: High - Address soon
- **🟡 Yellow Border**: Medium - Monitor
- **🔵 Blue Border**: Low - When convenient
- **⚪ Gray Border**: Info - FYI only

### Icons:
- ⚡ Bolt: High power usage
- 📈 Trending Up: Predictions
- 💡 Lightbulb: Tips & suggestions
- ⚠️ Warning: Alerts & anomalies
- ✅ Check: All good
- 🌙 Nightlight: Evening reminders
- ☀️ Sun: Morning tips
- 🌿 Eco: Efficiency suggestions

## 6. Testing Different Scenarios

### Simulate High Usage Alert:
```sql
-- Insert high reading (for testing)
INSERT INTO pzem_readings (classroom, power, energy, ts)
VALUES ('CS-202', 5.5, 5.5, NOW());
```

Refresh recommendations - should show high usage alert.

### Simulate Prediction-Based Rec:
```bash
# Ensure Prophet model is trained and running
# Predictions automatically trigger recommendations
```

### Time-Based Recommendations:
- **Morning (6-8 AM)**: Setup tips
- **Afternoon (4-5 PM)**: Daily summary
- **Evening (5-7 PM)**: Shutdown reminders

Change system time or wait for these hours.

## 7. Customizing for Your Needs

### Adjust Thresholds
Edit `backend/recommendation_engine.py`:

```python
# Line ~90 - High usage threshold
if predicted_value > 5.0:  # Change to your threshold
    
# Line ~150 - Current usage alert
if current_usage and current_usage > 4.0:  # Adjust value

# Line ~170 - Above average percentage  
if current_usage > avg_usage * 1.3:  # Change multiplier
```

### Add Custom Icons
Edit `lib/widgets/recommendation_widgets.dart`:

```dart
IconData get iconData {
  switch (icon) {
    case 'your_custom_icon':
      return Icons.your_icon_name;
    // ... existing cases
  }
}
```

### Change Auto-Refresh Interval
Edit `lib/widgets/recommendation_widgets.dart` line 129:

```dart
_refreshTimer = Timer.periodic(
  const Duration(minutes: 3),  // Change to your interval
  (_) => _fetchRecommendations(),
);
```

## 8. Integrating into Other Pages

### Add to Any Dashboard:
```dart
import 'widgets/recommendation_widgets.dart';

// In your widget build method:
RecommendationsList(
  userToken: yourJwtToken,
  showHeader: true,
  maxItems: 3,  // Show top 3 recommendations
)
```

### Show Count Badge:
```dart
FutureBuilder<Map<String, int>>(
  future: RecommendationService.fetchRecommendationCount(token),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final count = snapshot.data!['critical'] ?? 0;
      if (count > 0) {
        return Badge(
          label: Text('$count'),
          child: Icon(Icons.lightbulb),
        );
      }
    }
    return Icon(Icons.lightbulb);
  },
)
```

### Open Full Page:
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationsPage(userToken: token),
      ),
    );
  },
  child: Text('View All Recommendations'),
)
```

## 9. Troubleshooting

### "No recommendations" message
**Cause**: No data or all systems normal
**Solution**: This is actually good! Means no issues detected.

### "Failed to load recommendations"
**Checks**:
```bash
# 1. Backend running?
curl http://localhost:8000/recommendations/health

# 2. Token valid?
echo $TOKEN

# 3. Network connectivity?
ping localhost

# 4. Check logs
# Backend terminal should show requests
```

### Recommendations not updating
**Solutions**:
- Pull down to refresh manually
- Check auto-refresh timer (3 min interval)
- Verify backend has new data
- Restart app if needed

### Wrong recommendations for user
**Checks**:
- Verify JWT token has correct role
- Check user's department setting
- Review token decode in backend logs

## 10. Production Deployment

### Backend
```bash
# Use production DB
export DB_URL="postgresql://user:pass@prod-host:5432/energia"

# Use production secret
export JWT_SECRET="your-secure-production-secret"

# Start with uvicorn
uvicorn backend.app_main:app --host 0.0.0.0 --port 8000 --workers 4
```

### Frontend
```dart
// Update baseUrl in recommendation_widgets.dart
static const String baseUrl = 'https://your-domain.com/recommendations';
```

Build and deploy:
```bash
flutter build apk --release
# or
flutter build ios --release
```

## 11. Monitoring & Analytics

### Check Recommendation Counts:
```bash
# Per user
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/recommendations/recommendations/count

# Response
{"total": 5, "critical": 1, "high": 2, "medium": 1, "low": 1}
```

### Database Queries:
```sql
-- Recent high usage readings
SELECT classroom, power, ts 
FROM pzem_readings 
WHERE power > 4.0 
ORDER BY ts DESC 
LIMIT 10;

-- Active predictions
SELECT * FROM prophet_predictions 
ORDER BY generated_at DESC 
LIMIT 1;
```

## 12. Next Steps

### Immediate:
- ✅ Test with different user roles
- ✅ Verify all recommendation types appear
- ✅ Check mobile responsiveness
- ✅ Test offline behavior

### Short Term:
- [ ] Add user feedback mechanism
- [ ] Track recommendation effectiveness
- [ ] Implement dismissible cards
- [ ] Add recommendation history

### Long Term:
- [ ] ML-based personalization
- [ ] Push notifications
- [ ] Voice-activated recommendations
- [ ] Predictive scheduling

---

## Summary

You now have:
- 🎯 **Dynamic recommendations** for all user types
- 🔄 **Auto-refreshing** every 3 minutes
- 🎨 **Beautiful UI** with priority colors
- 📊 **Data-driven** using real DB data
- 🚀 **Real-time** context-aware suggestions
- 📱 **Mobile-ready** responsive design

**Ready to use!** Login and check your personalized recommendations. 🌟

Need help? Check [RECOMMENDATIONS_SYSTEM.md](RECOMMENDATIONS_SYSTEM.md) for detailed documentation.
