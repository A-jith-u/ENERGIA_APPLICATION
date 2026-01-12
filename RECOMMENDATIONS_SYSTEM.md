# Dynamic Recommendation System - ENERGIA

## Overview
A comprehensive, context-aware recommendation system that provides personalized, actionable suggestions to all user types (Admin, Coordinator, Class Representative) based on real-time data, historical patterns, predictions, and current situations.

## Architecture

### Backend Components

#### 1. Recommendation Engine (`backend/recommendation_engine.py`)
- **Core Logic**: Analyzes user context and generates recommendations
- **Multi-Role Support**: Different recommendation strategies for each user type
- **Data-Driven**: Uses DB data, predictions, anomalies, and current readings
- **Priority System**: Critical → High → Medium → Low → Info
- **Types**: Immediate, Preventive, Optimization, Informational, Predictive

#### 2. Recommendation API (`backend/recommendation_api.py`)
- **Endpoints**:
  - `GET /recommendations/recommendations` - Get personalized recommendations
  - `POST /recommendations/recommendations` - Get with explicit context
  - `GET /recommendations/recommendations/count` - Get counts by priority
  - `GET /recommendations/health` - Health check

- **Authentication**: JWT token-based (extracts user context automatically)
- **Auto-Context**: Reads role, department, classroom from token

### Frontend Components

#### 1. Recommendation Widgets (`lib/widgets/recommendation_widgets.dart`)
- **RecommendationCard**: Individual recommendation display
- **RecommendationsList**: Scrollable list with auto-refresh
- **RecommendationService**: API integration
- **Features**:
  - Color-coded by priority
  - Icon-based visual identity
  - Expandable details
  - Action buttons
  - Auto-refresh every 3 minutes

#### 2. Recommendations Page (`lib/recommendations_page.dart`)
- Full-screen view of all recommendations
- Filtering by priority and type
- Integrated into dashboards

## Recommendation Types

### For Administrators
1. **Campus-Wide Monitoring**
   - High overall energy usage alerts
   - Department-wise breakdown warnings
   - System health issues

2. **User Management**
   - Pending registrations
   - Inactive sensors
   - Hardware issues

3. **Optimization**
   - Monthly report reminders
   - System efficiency tips
   - Resource allocation suggestions

### For Coordinators
1. **Department Oversight**
   - High-usage classrooms in department
   - Anomaly notifications
   - Class rep activity tracking

2. **Preventive Actions**
   - Pattern-based warnings
   - Equipment malfunction alerts
   - Off-hours usage detection

3. **Reporting**
   - Weekly summary reminders
   - Efficiency score updates
   - Best practices suggestions

### For Class Representatives
1. **Immediate Actions**
   - High current usage warnings
   - Prediction-based alerts (next 15 min)
   - Empty classroom with equipment on
   - Usage above average

2. **Time-Based**
   - Morning setup tips
   - Evening shutdown reminders
   - Peak hour guidelines

3. **Optimization**
   - AC temperature recommendations
   - Natural lighting suggestions
   - Equipment efficiency tips

4. **Informational**
   - Daily usage summaries
   - Comparison with averages
   - Achievement badges

## Priority System

### Critical (Red) 🔴
- **Triggers**: Immediate safety/cost concerns
- **Examples**:
  - Empty classroom with high usage
  - Predicted usage > 5.0 kWh
  - Sensor failures
- **Action**: Immediate user response required

### High (Orange) 🟠
- **Triggers**: Significant issues needing attention
- **Examples**:
  - Current usage > 4.0 kW
  - Usage 30% above average
  - Multiple anomalies
- **Action**: Address within the hour

### Medium (Yellow) 🟡
- **Triggers**: Moderate concerns
- **Examples**:
  - Predicted moderate usage (3.5-5.0 kWh)
  - Efficiency score < 70%
  - Time-based reminders
- **Action**: Monitor and plan

### Low (Blue) 🔵
- **Triggers**: Minor items
- **Examples**:
  - Optimization suggestions
  - Best practice tips
  - Weekly reports
- **Action**: Review when convenient

### Info (Gray) ⚪
- **Triggers**: FYI updates
- **Examples**:
  - System running smoothly
  - Daily summaries
  - General tips
- **Action**: No action required

## Data Sources

### Real-Time Data
- `pzem_readings` table - Current power/energy readings
- Prophet predictions - ML-based forecasts
- Sensor status - Hardware health
- User activity - Login/interaction logs

### Historical Data
- 7-day averages for comparison
- Monthly trends
- Department baselines
- Time-of-day patterns

### Contextual Data
- User role and department
- Current time of day
- Day of week
- Occupancy status
- Weather (if integrated)

## API Usage

### Authentication
All endpoints require JWT token in header:
```
Authorization: Bearer <token>
```

### Get Recommendations
```bash
curl -X GET http://localhost:8000/recommendations/recommendations \
  -H "Authorization: Bearer <token>"
```

**Response:**
```json
{
  "recommendations": [
    {
      "id": "predictive_1234567890",
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
  "count": 5,
  "user": {
    "role": "student",
    "department": "Computer Science"
  }
}
```

### Get Count
```bash
curl -X GET http://localhost:8000/recommendations/recommendations/count \
  -H "Authorization: Bearer <token>"
```

**Response:**
```json
{
  "total": 5,
  "critical": 1,
  "high": 2,
  "medium": 1,
  "low": 1,
  "info": 0
}
```

## Frontend Integration

### In Dashboard
```dart
// Add to any dashboard page
RecommendationsList(
  userToken: yourJwtToken,
  showHeader: true,
  maxItems: 3,  // Show top 3
  onSeeAllTap: () {
    // Navigate to full recommendations page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationsPage(userToken: token),
      ),
    );
  },
)
```

### Full Page
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => RecommendationsPage(userToken: token),
  ),
);
```

### Badge Count
```dart
// Show notification badge
FutureBuilder<Map<String, int>>(
  future: RecommendationService.fetchRecommendationCount(token),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final critical = snapshot.data!['critical'] ?? 0;
      return Badge(
        label: Text('$critical'),
        child: Icon(Icons.notifications),
      );
    }
    return Icon(Icons.notifications);
  },
)
```

## Customization

### Adding New Recommendation Types

#### Backend
Edit `recommendation_engine.py`:
```python
def _get_class_rep_recommendations(self, classroom, department):
    recs = []
    
    # Your custom logic
    if your_condition:
        recs.append(
            Recommendation(
                title="Your Title",
                message="Your message",
                rec_type=RecommendationType.IMMEDIATE,
                priority=RecommendationPriority.HIGH,
                action="What to do",
                data={"key": "value"},
                icon="your_icon",
            ).to_dict()
        )
    
    return recs
```

#### Frontend
Add icon mapping in `recommendation_widgets.dart`:
```dart
IconData get iconData {
  switch (icon) {
    case 'your_icon':
      return Icons.your_icon_name;
    default:
      return Icons.info_outline;
  }
}
```

### Adjusting Thresholds

In `recommendation_engine.py`, modify constants:
```python
# High usage threshold
if current_usage > 4.0:  # Change this value

# Prediction critical threshold
if predicted_value > 5.0:  # Change this value

# Above average percentage
if current_usage > avg_usage * 1.3:  # Change multiplier
```

## Testing

### Backend Test
```bash
# Start server
python backend/start_server.py

# Get token
TOKEN=$(curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}' \
  | jq -r '.access_token')

# Test recommendations
curl -X GET http://localhost:8000/recommendations/recommendations \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Frontend Test
```dart
// Test in Flutter
void testRecommendations() async {
  final recs = await RecommendationService.fetchRecommendations(token);
  print('Got ${recs.length} recommendations');
  for (var rec in recs) {
    print('${rec.priority}: ${rec.title}');
  }
}
```

## Performance Optimization

### Caching
- Recommendations cached for 3 minutes client-side
- Auto-refresh on background
- Smart invalidation on user action

### Database Queries
- Indexed queries on timestamps
- Limited to recent data (24h - 7d)
- Aggregated statistics pre-computed

### Frontend
- Lazy loading for full list
- Pagination for large datasets
- Debounced refresh triggers

## Monitoring

### Backend Metrics
- Recommendation generation time
- API response time
- Error rates by endpoint
- Cache hit rates

### User Metrics
- Recommendations viewed
- Actions taken
- Dismissal rates
- Effectiveness scores

## Best Practices

### For Developers
1. **Add Context**: Include relevant data in recommendations
2. **Clear Actions**: Every recommendation should have actionable steps
3. **Priority Balance**: Don't make everything critical
4. **Test with Real Data**: Use production-like scenarios
5. **Monitor Feedback**: Track user interactions

### For Users
1. **Check Regularly**: Review recommendations 2-3 times daily
2. **Act on Critical**: Address red/orange items immediately
3. **Plan Medium**: Schedule time for yellow items
4. **Learn from Info**: Use tips to improve habits
5. **Provide Feedback**: Report false positives

## Troubleshooting

### No Recommendations Showing
- Check JWT token validity
- Verify user role in token
- Ensure backend is running
- Check database connectivity

### Incorrect Recommendations
- Verify sensor data is current
- Check user context (role, dept)
- Review threshold settings
- Inspect DB query results

### Performance Issues
- Reduce auto-refresh frequency
- Increase caching duration
- Optimize DB queries
- Add pagination

## Future Enhancements

### Planned Features
- [ ] ML-based recommendation ranking
- [ ] User feedback loop
- [ ] A/B testing framework
- [ ] Push notifications
- [ ] Email digests
- [ ] Analytics dashboard
- [ ] Recommendation history
- [ ] Smart grouping
- [ ] Natural language actions
- [ ] Voice recommendations

### Integration Opportunities
- Weather API for seasonal tips
- Calendar for event-based recs
- IoT devices for automation
- Mobile push notifications
- Chatbot interface

## Summary

The Dynamic Recommendation System provides:
✅ **Personalized** - Different for each user role
✅ **Context-Aware** - Based on current situation
✅ **Data-Driven** - Uses real DB and prediction data
✅ **Actionable** - Clear next steps
✅ **Real-Time** - Auto-refreshing
✅ **Prioritized** - Color-coded by urgency
✅ **Scalable** - Handles all user types
✅ **Extensible** - Easy to add new types

Happy recommending! 🎯
