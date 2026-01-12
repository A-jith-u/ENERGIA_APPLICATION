# Energy Prediction Feature - Implementation Summary

## Overview
Added AI-powered energy usage prediction for class representatives to forecast the next 15 minutes of energy consumption.

## Backend Changes

### 1. Updated Prophet Model API (`backend/serve_prophet.py`)
- Added new endpoint `/predict_15min` for 15-minute interval predictions
- Returns single prediction point 15 minutes from now
- Response includes:
  - `timestamp`: When the prediction is for
  - `predicted_energy`: Expected energy usage (kWh)
  - `lower_bound`: Lower confidence interval
  - `upper_bound`: Upper confidence interval
  - `generated_at`: When prediction was generated
  - `horizon_minutes`: 15

**Example Request:**
```bash
POST http://localhost:8000/model/predict_15min
Content-Type: application/json
{}
```

**Example Response:**
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

## Frontend Changes

### 1. New Prediction Page (`lib/prediction_page.dart`)
Created a comprehensive prediction visualization page with:

#### Features:
- **Auto-refresh**: Updates predictions every 5 minutes
- **Status Indicators**: 
  - Green (Normal): < 3.5 kWh
  - Orange (Moderate): 3.5 - 5.0 kWh
  - Red (High Usage): > 5.0 kWh

#### Visual Components:

##### Header Section
- AI-powered prediction badge
- Model information
- Clear description

##### Main Prediction Card
- Large predicted value display with units (kWh)
- Status indicator badge (Normal/Moderate/High)
- Lower and upper bounds displayed prominently
- Forecast timestamp
- Gradient background based on status

##### Bar Chart Visualization
- Three bars showing:
  1. Lower Bound (Blue)
  2. Predicted Value (Green gradient)
  3. Upper Bound (Red)
- Clear labels and legend
- Grid lines for easy reading

##### Details Section
- Prediction horizon (15 minutes)
- Model type (Prophet by Facebook)
- Generation timestamp
- Confidence level
- Auto-refresh notification

### 2. Updated Class Rep Dashboard (`lib/adm_cspage.dart`)
- Added "Energy Usage Prediction" tile in Analysis section
- Purple-themed tile with "AI" badge
- Navigates to new prediction page
- Positioned between Daily Usage Profile and Anomaly Report

## Usage Instructions

### For Backend:
1. Ensure Prophet model is trained:
```bash
cd backend
python train_prophet.py --csv sample_data/prophet_training_sample.csv
```

2. Start the backend server:
```bash
python start_server.py
```

3. Test the prediction endpoint:
```bash
curl -X POST http://localhost:8000/model/predict_15min \
  -H "Content-Type: application/json" \
  -d '{}'
```

### For Frontend:
1. Navigate to Class Rep Dashboard (Dash)
2. Go to "Analysis" tab (first tab)
3. Tap on "Energy Usage Prediction" tile
4. View AI-powered forecast with visualization

**Update Backend URL:**
In `lib/prediction_page.dart`, line 37, update:
```dart
Uri.parse('http://localhost:8000/model/predict_15min')
```
to your actual backend URL.

## Visual Design Highlights

### Color Scheme:
- **Normal Usage**: Green gradient (`Colors.green.shade400-700`)
- **Moderate Usage**: Orange (`Colors.orange`)
- **High Usage**: Red (`Colors.red`)
- **Lower Bound**: Blue (`Colors.blue.shade400`)
- **Upper Bound**: Red (`Colors.red.shade400`)

### Chart Features:
- Rounded bar tops for modern look
- Gradient on predicted value bar
- Clear axis labels and titles
- Legend for easy interpretation
- Responsive height (250px)

### Card Design:
- Elevated cards with rounded corners (16px radius)
- Subtle shadows for depth
- Gradient backgrounds for status indication
- Icon-driven design language
- Consistent spacing and padding

## Technical Details

### Prediction Model:
- **Model**: Facebook Prophet
- **Frequency**: 15-minute intervals
- **Horizon**: Next 15 minutes (1 prediction point)
- **Confidence Interval**: 95% (yhat_lower to yhat_upper)

### Auto-Refresh:
- Timer-based refresh every 5 minutes
- Manual refresh available via AppBar button
- Loading states during refresh
- Error handling with retry option

### Error Handling:
- Network error display
- Model not found handling
- Empty state management
- Graceful degradation

## Future Enhancements
- [ ] Multiple prediction horizons (30 min, 1 hour, etc.)
- [ ] Historical prediction accuracy tracking
- [ ] Comparison with actual consumption
- [ ] Push notifications for high predicted usage
- [ ] Multiple prediction points on timeline
- [ ] Save prediction history
- [ ] Export prediction reports

## Dependencies Required

### Backend:
- `pandas` - Already in requirements.txt
- `prophet` - Already in requirements.txt
- `joblib` - Already in requirements.txt

### Frontend:
- `fl_chart` - Already in pubspec.yaml
- `http` - Already in pubspec.yaml

No additional dependencies needed!
