# Enhanced Prediction vs Live Comparison Page

## Overview
The prediction comparison page has been completely redesigned with comprehensive live data features, easy-to-understand metrics, and visual indicators suitable for non-technical users.

## Key Features Added

### 1. **Current Power Usage Display** 🔴 Live
- Shows real-time power consumption in large, easy-to-read format
- Color-coded status indicators:
  - **Green**: Normal usage (0-50% of limit)
  - **Orange**: Elevated usage (50-80% of limit)
  - **Red**: High usage (80%+ of limit)
- Displays current trend (📈 Increasing, 📉 Decreasing, ➡️ Stable)
- Latest reading timestamp

### 2. **24-Hour Statistics**
Three quick stat boxes showing:
- **📊 Average (24h)**: Daily average power consumption
- **⬆️ Peak (24h)**: Maximum power usage in the last 24 hours
- **⬇️ Low (24h)**: Minimum power usage in the last 24 hours

### 3. **Smart Forecast Cards**
#### Next 5 Minutes Forecast
- **Expected Power**: AI-predicted power consumption
- **Confidence Range**: Min-Max range for the prediction (when available)
- **Data Source Badge**: Shows whether forecast is based on:
  - 📡 **Live Data** (recent sensor readings - more accurate)
  - 📚 **Historical Data** (trained model - baseline)
- **Prediction Time**: When the forecast was generated

### 4. **Forecast Accuracy Comparison**
Shows side-by-side comparison when actual data is available:
- **Predicted vs Actual**: Visual comparison of forecasted vs actual power
- **Accuracy Score**: 
  - 80%+ = Green (Excellent)
  - 60-80% = Orange (Good)
  - Below 60% = Red (Fair)
- **Error Metrics**:
  - Absolute error (Watts difference)
  - Percentage error (relative difference)

### 5. **AI-Generated Insights** 💡
Non-technical friendly insights including:
- **⚡ Current Status**: How current usage compares to daily average
- **📈/📉 Trend**: Whether usage is increasing, decreasing, or stable with recommendations
- **🎯 Forecast Quality**: Assessment of how reliable the forecast is

### 6. **User-Friendly Metrics**
All metrics use:
- **Large, bold numbers** for quick scanning
- **Color-coded status** for instant understanding
- **Emoji icons** for visual recognition
- **Plain language descriptions** (no technical jargon)
- **Percentage comparisons** (e.g., "110% of daily average")

### 7. **Smart Auto-Refresh**
- 60-second countdown timer before next refresh
- Automatic timestamp tracking
- Visual "Updated at" indicator

## Data Fetched

### From Backend APIs
1. **Predictions**: `/model/predict_5min` or `/predict_5min`
   - Expected power consumption
   - Confidence intervals (yhat_lower/upper)
   - Data source (live vs historical)

2. **Live Sensor Data**: `/api/sensor-data`
   - Latest power reading
   - 24-hour historical data for statistics
   - Multiple readings for trend analysis

3. **Comparison Data**: `/api/sensor-data` (recent readings)
   - Matches prediction time with closest sensor reading
   - Calculates accuracy percentage

## User Flow

### Step 1: View Current Status
1. Page loads and displays current power usage
2. User sees live power, trend, and 24h statistics automatically
3. Color coding and emoji icons provide instant status

### Step 2: Get Forecast
1. Click "Get Forecast" button
2. Receives 5-minute prediction
3. Page shows confidence range and data source
4. See whether prediction is based on live or historical data

### Step 3: Compare (Optional)
1. Click "Compare" button
2. Page fetches actual sensor reading near prediction time
3. Shows accuracy percentage and error metrics
4. Receives AI insights about forecast quality

## Visual Design Improvements

### Color Scheme
- **Green**: Good status, normal usage, positive trends
- **Orange**: Caution, elevated usage, increasing trends
- **Red**: Critical, high usage
- **Blue**: Information, neutral, historical data
- **Purple-ish**: AI/ML insights

### Layout
```
┌─────────────────────────────────┐
│  Header with timestamp          │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  LIVE POWER READING             │
│  48.2 W                📈 ↑     │
│  📊: 42W  ⬆️: 65W  ⬇️: 15W     │
└─────────────────────────────────┘

┌─ Get Forecast ─┐ ┌─ Compare ─┐

┌─────────────────────────────────┐
│  NEXT 5 MIN FORECAST 📡 Live    │
│  52.1 W        @ 14:35          │
│  Confidence: 48W - 56W          │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  FORECAST ACCURACY    98%  ✓     │
│  52.1 W  <--->  52.0 W          │
│  Error: 0.1W (0.2%)             │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  💡 INSIGHTS                    │
│  ⚡: Using 110% of average      │
│  📈: Usage increasing           │
│  🎯: Excellent forecast         │
└─────────────────────────────────┘
```

## Technical Improvements

### Enhanced Data Processing
- ✅ Handles multiple column naming conventions (power, value, energy)
- ✅ Parses both local and ISO timestamp formats
- ✅ Graceful fallbacks when data is missing
- ✅ Calculates statistics over 24-hour periods
- ✅ Determines trends from historical data

### Error Handling
- Clear error messages for non-technical users
- Automatic fallback to different API endpoints
- 15-second timeouts to prevent hanging
- Handles missing or null data gracefully

### Performance
- Efficient data fetching from cache-friendly endpoints
- Limited to necessary data ranges (24h max)
- Auto-refresh with configurable intervals
- Smooth animations and transitions

## What Non-Tech Users Will See

### Example 1: Normal Usage
```
⚡ Current Power Usage 🔴 Live
48.2 W

Trend: ➡️ stable
Last reading: 14:35

📊: 42W average
⬆️: 65W peak  
⬇️: 15W low

💡 Using 115% of daily average
Forecast Quality: Excellent 🎯
```

### Example 2: Increasing Usage Alert
```
⚡ Current Power Usage 🔴 Live
72.5 W

Trend: 📈 increasing
Last reading: 14:38

💡 WARNING: Power usage is increasing
Consider reducing active appliances
🎯 Forecast still reliable
```

### Example 3: Good vs Actual Comparison
```
FORECAST ACCURACY: 94% ✅

Predicted: 52.1W  <-->  Actual: 54.3W
Error: 2.2W (4.2%)

Insight: Excellent forecast - great for planning
```

## Usage Tips for Non-Tech Users

1. **Quick Status Check**: Just look at the main power number and color
2. **Understanding Trends**: Green down arrow = good, red up arrow = reduce usage
3. **Forecast Accuracy**: Higher percentage = more reliable for planning
4. **Auto-Updates**: Page automatically updates - no need to refresh manually
5. **When to Use**: Great for understanding energy patterns and controlling usage

## Future Enhancement Ideas

- 📊 Weekly/monthly trend charts for non-tech users
- 🎯 Energy saving recommendations based on patterns
- 📈 Comparison with previous day/week/month
- ⚙️ Customizable warning thresholds
- 📱 Push notifications for high usage
- 💰 Estimated cost based on current consumption rate
