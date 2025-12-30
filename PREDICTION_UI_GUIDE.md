# Prediction Page Visual Guide

## Layout Structure

```
┌────────────────────────────────────────────┐
│  ← Energy Prediction              🔄       │ AppBar (Dark Blue #1B2A3B)
├────────────────────────────────────────────┤
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │ 💡  AI-Powered Prediction            │ │
│  │     Next 15-minute energy forecast   │ │ Header Card
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │ │
│  │  ℹ️  Using Prophet ML model trained  │ │
│  │     on historical energy data        │ │
│  └──────────────────────────────────────┘ │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │  Predicted Usage    🟢 Normal        │ │
│  │                                      │ │
│  │         3.45 kWh                     │ │ Main Prediction Card
│  │                                      │ │ (Gradient background)
│  │  ┌───────────┬───────────────┐      │ │
│  │  │  Lower    │    Upper      │      │ │
│  │  │   2.87    │     4.03      │      │ │
│  │  │   kWh     │     kWh       │      │ │
│  │  └───────────┴───────────────┘      │ │
│  │  🕐 Forecast time: 10:15             │ │
│  └──────────────────────────────────────┘ │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │  Prediction Range Visualization      │ │
│  │                                      │ │
│  │    5│                                │ │
│  │     │        ▓▓▓                    │ │
│  │    4│        ▓▓▓    ░░░             │ │ Bar Chart
│  │     │  ███   ▓▓▓    ░░░             │ │
│  │    3│  ███   ▓▓▓    ░░░             │ │
│  │     │  ███   ▓▓▓    ░░░             │ │
│  │    2│  ███   ▓▓▓    ░░░             │ │
│  │     │  ███   ▓▓▓    ░░░             │ │
│  │    1│  ███   ▓▓▓    ░░░             │ │
│  │     └──────────────────────         │ │
│  │      Lower Predicted Upper          │ │
│  │      Bound   Value    Bound         │ │
│  │                                      │ │
│  │  ■ Lower Bound  ■ Predicted  ■ Upper│ │
│  └──────────────────────────────────────┘ │
│                                            │
│  ┌──────────────────────────────────────┐ │
│  │  Prediction Details                  │ │
│  │                                      │ │
│  │  ⏱️  Horizon         15 minutes      │ │
│  │  🤖  Model           Prophet         │ │ Details Card
│  │  🔄  Generated At    10:00           │ │
│  │  🧠  Confidence      High            │ │
│  │                                      │ │
│  │  ℹ️  Predictions update every 5      │ │
│  │     minutes automatically            │ │
│  └──────────────────────────────────────┘ │
│                                            │
└────────────────────────────────────────────┘
```

## Color Legend

### Status Colors:
- **🟢 Green (Normal)**: Usage < 3.5 kWh
  - Background: Light green gradient
  - Text: Dark green
  
- **🟠 Orange (Moderate)**: Usage 3.5 - 5.0 kWh
  - Background: Light orange gradient
  - Text: Dark orange
  
- **🔴 Red (High Usage)**: Usage > 5.0 kWh
  - Background: Light red gradient
  - Text: Dark red

### Chart Colors:
- **Blue Bar** (███): Lower Bound - Minimum expected usage
- **Green Bar** (▓▓▓): Predicted Value - Most likely usage (with gradient)
- **Red Bar** (░░░): Upper Bound - Maximum expected usage

## Interactive Elements

1. **Refresh Button** (Top Right)
   - Manual refresh of predictions
   - Shows loading indicator during fetch

2. **Auto-Refresh Timer**
   - Automatically updates every 5 minutes
   - No user action required

3. **Status Badge**
   - Dynamically changes based on predicted value
   - Shows icon (✓, ⓘ, ⚠) and label

## Responsive Design

- Scrollable content for smaller screens
- Card-based layout with consistent spacing
- Maximum width constraints for readability
- Padding: 20px on all sides
- Card spacing: 24px between sections

## Typography

### Headers:
- Page Title: Bold, Large
- Section Titles: Bold, Medium
- Body Text: Regular, Medium

### Values:
- Predicted Value: Display Large, Bold
- Bounds: Title Large, Bold
- Units: Body Medium, Regular

## Animation & Transitions

- Smooth loading states
- Fade transitions between data updates
- Card elevation on hover (web)
- Subtle shadow effects

## Error States

```
┌────────────────────────────────────────┐
│                                        │
│         ⚠️                             │
│                                        │
│    Failed to fetch prediction:        │
│    Connection timeout                 │
│                                        │
│    [ 🔄 Retry ]                       │
│                                        │
└────────────────────────────────────────┘
```

## Usage Tips for Class Reps

1. **Check Before Peak Hours**
   - View predictions before high-usage periods
   - Plan energy-saving actions accordingly

2. **Monitor Status Badge**
   - Green: Normal operation
   - Orange: Consider reducing non-essential loads
   - Red: Take immediate action to reduce usage

3. **Understand Confidence Intervals**
   - Lower Bound: Best-case scenario
   - Predicted: Most likely outcome
   - Upper Bound: Worst-case scenario

4. **Auto-Refresh**
   - Leave page open for continuous monitoring
   - Fresh predictions every 5 minutes
   - Manual refresh available anytime

## Integration Points

### From Class Rep Dashboard:
```
Dashboard (Dash) 
  → Analysis Tab
    → Energy Usage Prediction Tile
      → Prediction Page
```

### Navigation Path:
1. Login as Class Representative
2. Navigate to assigned classroom
3. Open Dashboard
4. Tap "Analysis" (first bottom tab)
5. Scroll to "Energy Usage Prediction"
6. Tap tile to open prediction page

## Technical Notes

- Uses HTTP POST to `/model/predict_15min`
- Handles network errors gracefully
- Caches last successful prediction
- Shows loading states appropriately
- Supports both light and dark themes
