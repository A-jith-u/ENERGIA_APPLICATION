# Energy Visualization Widgets - Quick Reference Guide

## 🎨 Color Scheme

Use the `EnergyColorScheme` class for consistent colors:

```dart
import 'package:energia/widgets/energy_visualization_widgets.dart';

// Available colors:
EnergyColorScheme.primaryBlue      // #005BBB - Main color
EnergyColorScheme.darkHeader       // #1B2A3B - AppBar background
EnergyColorScheme.successGreen     // #4CAF50 - Normal state
EnergyColorScheme.warningOrange    // #FFA726 - Warning state
EnergyColorScheme.criticalRed      // #EF5350 - Critical state
EnergyColorScheme.infoTeal         // #26C6DA - Info state

// Helper method for severity colors:
Color color = EnergyColorScheme.getSeverityColor('High'); // Returns critical red
```

---

## 📊 Available Widgets

### 1. LiveEnergyMeter
Real-time power consumption display with trend.

```dart
LiveEnergyMeter(
  currentPower: 4.2,                      // Current kW
  maxCapacity: 8.0,                       // Max kW
  label: 'CS-201 - Live Power',          // Display label
  status: 'Active Usage',                 // Optional status
  showTrend: true,
  trendPercentage: -2.5,                 // Negative = decreasing
  onTap: () => print('Tapped!'),         // Optional callback
)
```

**Features:**
- Automatic color coding (Green/Orange/Red based on usage %)
- Progress bar visualization
- Percentage display
- Optional trend arrow

---

### 2. ResponsiveLineChart
Multi-period consumption trend visualization.

```dart
ResponsiveLineChart(
  spots: const [
    FlSpot(0, 1.5), FlSpot(1, 1.8), // ... more data points
  ],
  title: 'Today\'s Hourly Usage',
  unit: 'kW',                        // Display unit
  maxY: 5.0,                         // Y-axis max
  isMonthly: false,                  // true for 12-month view
  lineColor: EnergyColorScheme.primaryBlue,
  onRefresh: () => setState(() {}),  // Optional refresh
)
```

**Features:**
- Automatic horizontal scroll for dense data
- Responsive width based on screen size
- Grid lines and axis labels
- Gradient fill under curve
- Smooth animations

---

### 3. RoomEnergyGrid & RoomEnergyCard
Multi-room monitoring visualization.

```dart
RoomEnergyGrid(
  rooms: [
    {
      'id': 'cs201',
      'name': 'CS-201',
      'usage': 4.2,
      'capacity': 8.0,
      'status': 'Normal',
    },
    // ... more rooms
  ],
  onRoomTap: (roomId) => print('Room tapped: $roomId'),
)
```

**Features:**
- Responsive grid layout (max 200px width per card)
- Auto-wrapping on small screens
- Color-coded top border based on usage
- Progress indicator for utilization

---

### 4. ComparativeBarChart
Week or month comparison.

```dart
ComparativeBarChart(
  labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  values: const [24.5, 28.3, 25.7, 29.8, 27.2, 22.1, 20.5],
  title: 'Weekly Energy Consumption',
  unit: 'kWh',
  maxY: 35.0,
)
```

**Features:**
- Clean bar visualization
- Automatic label spacing
- Grid lines for easy reading
- Customizable units

---

### 5. AnomalyAlertCard
Individual anomaly/alert display.

```dart
AnomalyAlertCard(
  timestamp: '2 hours ago',
  event: 'High Power Consumption - AC unit running at peak load',
  severity: 'High',  // 'High', 'Medium', 'Low', 'Critical'
  onTap: () => showDetails(),
)
```

**Features:**
- Auto color-coded severity badges
- Clear timestamp and description
- Clickable with tap handler
- Professional card design

---

### 6. PredictionCard
AI prediction display with confidence.

```dart
PredictionCard(
  predictedUsage: 3.5,
  currentUsage: 3.2,
  timeframe: '15 minutes',
  confidence: 0.92,  // 0.0 to 1.0
)
```

**Features:**
- Side-by-side current vs. predicted
- Change percentage with trend icon
- Confidence level bar and percentage
- Color-coded based on change direction

---

### 7. EnergyDistributionDonut
Pie chart for energy breakdown.

```dart
EnergyDistributionDonut(
  labels: const ['AC Unit', 'Lighting', 'Lab Equipment', 'Other'],
  values: const [35.2, 22.5, 28.3, 14.0],
  title: 'CS-201 Energy Distribution',
)
```

**Features:**
- Pie chart visualization
- Legend with color indicators
- Percentage calculations
- Auto-scaling values

---

### 8. StatRow
Key metric display with icon.

```dart
StatRow(
  label: 'Total Department Usage',
  value: '18.4',
  unit: 'kW',
  icon: Icons.electric_bolt_outlined,
  color: Colors.orange,
)
```

**Features:**
- Icon + Label + Value layout
- Consistent styling
- Color-coded icons
- Perfect for summary cards

---

## 🎯 Layout Patterns

### Dashboard Overview (Student):
```dart
ListView(
  padding: const EdgeInsets.all(20),
  children: [
    // Welcome card
    Container(...),
    const SizedBox(height: 24),
    
    // Live meter
    LiveEnergyMeter(...),
    const SizedBox(height: 20),
    
    // Stats grid
    GridView.count(
      crossAxisCount: 2,
      children: [/* stat cards */],
    ),
    const SizedBox(height: 40),
    
    // Charts
    ResponsiveLineChart(...),
  ],
)
```

### Department Overview (Coordinator):
```dart
ListView(
  padding: const EdgeInsets.all(20),
  children: [
    // Welcome with stats
    Card(
      child: Column(
        children: [
          StatRow(...), // Usage
          StatRow(...), // Rooms
          StatRow(...), // Efficiency
        ],
      ),
    ),
    
    // Top consumers
    LiveEnergyMeter(...),
    LiveEnergyMeter(...),
    
    // Distribution
    EnergyDistributionDonut(...),
    
    // Comparison
    ComparativeBarChart(...),
    
    // Timeline
    ResponsiveLineChart(...),
  ],
)
```

---

## 🔄 Data Binding Examples

### Connect to Backend:

```dart
// Fetch live data
Future<void> _fetchLiveData() async {
  final response = await http.get(
    Uri.parse('http://backend:8000/energy/live/CS-201'),
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    setState(() {
      _currentPower = data['current_power'] as double;
      _maxCapacity = data['max_capacity'] as double;
      _trend = data['trend_percent'] as double;
    });
  }
}

// In build:
LiveEnergyMeter(
  currentPower: _currentPower,
  maxCapacity: _maxCapacity,
  label: 'CS-201',
  trendPercentage: _trend,
)
```

### Stream-based Updates:

```dart
// For real-time updates
stream: _energyStream, // WebSocket or polling stream
builder: (context, snapshot) {
  if (snapshot.hasData) {
    return LiveEnergyMeter(
      currentPower: snapshot.data['power'],
      maxCapacity: snapshot.data['capacity'],
      label: 'Live',
    );
  }
  return const CircularProgressIndicator();
}
```

---

## 🎨 Customization

### Color Override:
```dart
// Most widgets accept color parameter
ResponsiveLineChart(
  // ... other params
  lineColor: Colors.custom, // Override default blue
)

// Charts use gradient:
chartColors = [
  const Color(0xFF005BBB),
  const Color(0xFF0288D1),
  const Color(0xFF29B6F6),
];
```

### Size Adjustment:
```dart
// Cards have fixed width in grids
SizedBox(
  width: 200,  // Adjust card width
  height: 140, // Adjust card height
  child: RoomEnergyCard(...),
)

// Chart heights
SizedBox(
  height: 300, // Increase for more detail
  child: ResponsiveLineChart(...),
)
```

---

## 🚀 Best Practices

1. **Always import the widget library:**
   ```dart
   import 'widgets/energy_visualization_widgets.dart';
   ```

2. **Use consistent spacing:**
   ```dart
   const SizedBox(height: 24) // Between sections
   const SizedBox(height: 12) // Between cards
   ```

3. **Wrap in cards for visual separation:**
   ```dart
   Card(
     elevation: 3,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.circular(16),
     ),
     child: LiveEnergyMeter(...),
   )
   ```

4. **Provide proper context to widgets:**
   ```dart
   // Always use meaningful labels
   label: 'CS-201 - Computer Lab'
   title: 'Weekly Department Usage'
   ```

5. **Handle empty states:**
   ```dart
   if (data.isEmpty) {
     return Center(
       child: Text('No data available'),
     );
   }
   return ResponsiveLineChart(...);
   ```

6. **Test responsiveness:**
   - Mobile: ~360px width
   - Tablet: ~600px width
   - Desktop: ~1200px width

---

## 📋 Migration Checklist

- [ ] Import `energy_visualization_widgets.dart`
- [ ] Replace old card components with new ones
- [ ] Update color references to use `EnergyColorScheme`
- [ ] Adjust layout padding to 20px (main) / 24px (sections)
- [ ] Test on multiple screen sizes
- [ ] Verify dark mode appearance
- [ ] Connect real data endpoints
- [ ] Test with actual consumption data
- [ ] Verify all tap handlers work
- [ ] Performance test with large datasets

---

## 💡 Tips & Tricks

**Tip 1:** Use `GridView.count` with `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics()` to embed grids in scrollable lists.

**Tip 2:** Wrap charts in `SingleChildScrollView` horizontally for small screens.

**Tip 3:** Use `ResponsiveLineChart` for both monthly and daily views - just change `isMonthly` parameter.

**Tip 4:** Combine `LiveEnergyMeter` with `ResponsiveLineChart` for complete consumption view.

**Tip 5:** Use `EnergyColorScheme.getSeverityColor()` for automatic color selection based on severity string.
