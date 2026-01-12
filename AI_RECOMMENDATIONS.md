# AI-Powered Recommendation System

## Overview

The ENERGIA application now features an advanced AI-powered recommendation engine that provides dynamic, context-aware energy management recommendations to all user types.

## Key Features

### 🤖 AI-Based Intelligence
- **Real-time Analysis**: Analyzes live sensor data from all connected devices
- **Predictive Insights**: Integrates with Prophet forecasting model for future consumption predictions
- **Anomaly Detection**: Automatically detects unusual energy patterns and spikes
- **Global Benchmarking**: Compares usage against global energy trends and best practices

### 📊 Data Sources
The AI engine analyzes multiple data streams:
1. **Live Sensor Data**: Real-time energy consumption from all classrooms/labs
2. **Prophet Predictions**: 15-minute ahead forecasts with confidence intervals
3. **Anomaly Detection**: Statistical analysis of usage patterns
4. **Historical Data**: 7-day rolling averages and trends
5. **Time Context**: Peak hours, off-hours, seasonal factors
6. **Global Trends**: Industry benchmarks and best practices

### 👥 Role-Based Recommendations

#### Admin Recommendations
- **Critical Alerts**: Immediate action needed for anomalies and system issues
- **Campus-Wide Insights**: Total energy usage and department-level analysis
- **Predictive Planning**: Future demand forecasts for load management
- **Optimization Opportunities**: Cost-saving measures and efficiency improvements
- **System Health**: Sensor status, device monitoring, user activity

#### Coordinator Recommendations
- **Department Analytics**: Usage patterns within their department
- **Anomaly Alerts**: Unusual patterns in specific classrooms
- **Trend Analysis**: Rising/falling consumption trends
- **Comparative Insights**: vs department average and benchmarks
- **Class Rep Management**: Inactive representatives and engagement tracking
- **Efficiency Audit**: Recommendations for departmental improvements

#### Class Representative Recommendations
- **Immediate Actions**: High usage alerts requiring quick response
- **Prediction-Linked**: Recommendations tied to next 15-min forecast
- **Daily Performance**: Today's usage vs target tracking
- **Off-Hours Alerts**: Equipment left running after classes
- **Smart Tips**: Time-based energy-saving suggestions
- **Achievement Recognition**: Positive reinforcement for good practices

## Recommendation Types

### 1. **Immediate** (🔴 Critical/High Priority)
Actions needed right now to prevent wastage or issues
- High current usage alerts
- Critical anomaly detection
- Equipment malfunction warnings

### 2. **Predictive** (🟠 Medium Priority)
Based on forecast data and future trends
- High future demand predictions
- Rising trend warnings
- Load management suggestions

### 3. **Anomaly** (⚠️ High Priority)
Unusual patterns detected by AI
- Usage spikes beyond normal range
- Off-hours consumption anomalies
- Device behavior irregularities

### 4. **Optimization** (🟡 Low/Medium Priority)
Improve efficiency and reduce costs
- Peak hour load shifting
- Equipment idle time reduction
- Temperature optimization

### 5. **Informational** (🔵 Info)
Insights and best practices
- Daily consumption reports
- Trend insights
- Energy-saving tips

## Integration with Predictions

### Automatic Recommendation Generation
Every prediction from the Prophet model is automatically paired with relevant recommendations:

```json
{
  "timestamp": "2025-12-31T00:45:00",
  "predicted_energy": 5.2,
  "recommendations": [
    {
      "title": "High Energy Usage Predicted",
      "message": "Predicted: 5.2 kWh. Reduce non-essential loads.",
      "priority": "high",
      "impact_kwh": 1.2,
      "impact_cost": 10.2
    }
  ]
}
```

### Prediction-Based Actions
- **High Prediction**: Recommendations to reduce load before peak
- **Rising Trend**: Efficiency measures and equipment checks
- **Low Prediction**: Optimal time for maintenance or shutdown
- **High Uncertainty**: Close monitoring recommendations

## Impact Metrics

Each recommendation includes estimated impact:
- **impact_kwh**: Energy savings in kilowatt-hours
- **impact_cost**: Cost savings in rupees (₹)

Example:
```json
{
  "title": "Turn Off Idle Devices",
  "impact_kwh": 2.5,
  "impact_cost": 21.25
}
```

## API Endpoints

### Get Recommendations
```
GET /recommendations/recommendations
Headers: Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "recommendations": [
    {
      "id": "predictive_1735610400.123",
      "title": "High Energy Usage Predicted",
      "message": "...",
      "type": "predictive",
      "priority": "high",
      "action": "Reduce load now",
      "icon": "warning",
      "impact_kwh": 1.5,
      "impact_cost": 12.75,
      "timestamp": "2025-12-31T00:40:00Z"
    }
  ],
  "count": 5,
  "predictions": {
    "predicted_energy": 5.2,
    "trend": "increasing",
    "confidence": 85
  },
  "live_data": {
    "current_usage": 4.8,
    "total_devices": 12,
    "active_devices": 8
  },
  "anomalies": [...]
}
```

### Get Prediction with Recommendations
```
POST /model/predict_15min
Body: {}
```

**Response:**
```json
{
  "predicted_energy": 5.2,
  "lower_bound": 4.1,
  "upper_bound": 6.3,
  "timestamp": "2025-12-31T00:45:00",
  "recommendations": [
    {
      "title": "High Energy Usage Predicted",
      "priority": "high",
      "action": "Reduce load before peak"
    }
  ],
  "recommendation_count": 3
}
```

## Configuration

### Global Trends & Benchmarks
Located in `ai_recommendation_engine.py`:

```python
GLOBAL_TRENDS = {
    "classroom_average_kwh_per_hour": 3.5,
    "lab_average_kwh_per_hour": 5.2,
    "peak_hours": [10, 11, 14, 15, 16],
    "off_peak_hours": [0, 1, 2, 3, 4, 5, 6, 7, 20, 21, 22, 23],
    "optimal_ac_temp": 24,
    "energy_cost_per_kwh": 8.5,  # Rupees
}
```

These can be customized based on your institution's specific patterns and local electricity rates.

## Anomaly Detection

### Statistical Analysis
The AI engine uses statistical methods to detect anomalies:
- **Spike Detection**: Values exceeding 2σ (standard deviations) from mean
- **Off-Hours Detection**: Unusual usage during non-working hours
- **Trend Analysis**: Sustained increase or decrease patterns

### Severity Levels
- **High**: Immediate attention required (>3σ deviation)
- **Medium**: Should investigate (>2σ deviation)
- **Low**: Monitor (unusual but not critical)

## Best Practices Integration

The system incorporates global energy management best practices:
1. **Peak Load Management**: Shift non-essential loads to off-peak hours
2. **Temperature Optimization**: Maintain AC at 24°C for efficiency
3. **Equipment Management**: Power down idle devices
4. **Occupancy Awareness**: Adjust usage based on room occupancy
5. **Preventive Maintenance**: Early detection of equipment issues

## Future Enhancements

Planned improvements:
- [ ] Machine learning model for pattern recognition
- [ ] Integration with weather data for seasonal adjustments
- [ ] Occupancy sensor integration
- [ ] Automated control suggestions
- [ ] Gamification and leaderboards
- [ ] Mobile push notifications
- [ ] Voice assistant integration

## Technical Architecture

```
┌─────────────────────────────────────────────┐
│         AI Recommendation Engine            │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  Live    │  │ Prophet  │  │ Anomaly  │ │
│  │  Data    │  │Prediction│  │Detection │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘ │
│       │             │             │        │
│       └─────────────┴─────────────┘        │
│                     │                       │
│              ┌──────▼──────┐               │
│              │AI Processing│               │
│              │   Engine    │               │
│              └──────┬──────┘               │
│                     │                       │
│       ┌─────────────┼─────────────┐        │
│       │             │             │        │
│  ┌────▼────┐   ┌───▼────┐   ┌───▼────┐  │
│  │  Admin  │   │Coordi- │   │ Class  │  │
│  │  Recs   │   │ nator  │   │  Rep   │  │
│  └─────────┘   └────────┘   └────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

## Database Schema

### Required Tables
- `sensor_data`: Live energy readings
- `prophet_predictions`: Forecast data (optional, uses fallback)
- User tables with role information

### Recommended Indexes
```sql
CREATE INDEX idx_sensor_data_ds ON sensor_data(ds DESC);
CREATE INDEX idx_sensor_data_device ON sensor_data(device_id, ds DESC);
```

## Performance Considerations

- **Caching**: Recommendations are generated on-demand
- **Query Optimization**: Uses efficient SQL with time-based filtering
- **Fallback Mechanisms**: Works even without prediction table
- **Error Handling**: Graceful degradation if services unavailable

## Testing

Test the recommendation system:

```bash
# Start backend
cd backend
python start_server.py

# Test recommendations endpoint (requires JWT token)
curl -H "Authorization: Bearer <token>" \
  http://localhost:8000/recommendations/recommendations

# Test prediction with recommendations
curl -X POST http://localhost:8000/model/predict_15min \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Troubleshooting

### No Recommendations Generated
- Check database connection
- Ensure sensor data is being ingested
- Verify JWT token is valid

### Predictions Not Available
- Check if Prophet model is loaded
- Verify model path in environment
- Check sensor_data table has recent data

### Anomaly Detection Not Working
- Ensure sufficient historical data (>3 data points)
- Check time window (uses last 1 hour)
- Verify statistical thresholds

## Support

For issues or questions:
1. Check logs in backend terminal
2. Verify database connectivity
3. Review API response error messages
4. Consult technical documentation
