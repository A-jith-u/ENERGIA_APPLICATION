# Coordinator Dashboard - Quick Start Guide

## Dashboard Layout

```
┌─────────────────────────────────────────────────────────┐
│  🏢 CS Department ENERGIA              [Logout Button]   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ╔════════════════════════════════════════════════════╗ │
│  ║ Welcome, Department Leader!                        ║ │
│  ║ CS Department Energy Coordinator                   ║ │
│  ║ Orchestrating efficiency across multiple rooms...  ║ │
│  ║                                                    ║ │
│  ║ Your leadership drives campus-wide transformation ║ │
│  ╚════════════════════════════════════════════════════╝ │
└─────────────────────────────────────────────────────────┘

Room Selection & Filtering

┌─────────────────────────────────────────────────────────┐
│ Filter Type                                             │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ▼ All Rooms                                        │ │
│ │ • Floor-wise                                       │ │
│ │ • Class-wise                                       │ │
│ │ • All Rooms                                        │ │
│ │ • Labs & Staff Rooms                               │ │
│ └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Select Room                                             │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ▼ Floor-1-Class-101                                │ │
│ │ • Floor-1-Class-102                                │ │
│ │ • Floor-1-Class-103                                │ │
│ │ • Floor-2-Class-201                                │ │
│ │ • ... (and more)                                   │ │
│ └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘

Real-Time Energy Metrics

┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ ⚡ Voltage   │  │ ⚙️ Current   │  │ 🔌 Power    │  │ 🌱 Energy   │
│              │  │              │  │              │  │              │
│   230.0 V    │  │    1.20 A    │  │  2.50 kW    │  │  42.50 kWh  │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘

Energy Usage Over Time

┌─────────────────────────────────────────────────────────┐
│ Power Consumption (kW)                                  │
│ ┌───────────────────────────────────────────────────┐   │
│ │                    ╱╲                              │   │
│ │                   ╱  ╲                             │   │
│ │                  ╱    ╲╱╲                          │   │
│ │  ╱╲            ╱        ╲  ╲                       │   │
│ │ ╱  ╲╱╲╱───────╱          ╲  ╲╱───────              │   │
│ │                                                    │   │
│ └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Current Draw (A)                                        │
│ ┌───────────────────────────────────────────────────┐   │
│ │  Similar visualization for current over time     │   │
│ └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ Energy Consumed (kWh)                                   │
│ ┌───────────────────────────────────────────────────┐   │
│ │  Cumulative energy line showing trend            │   │
│ └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ [Overview] [Rooms] [Analytics] [Alerts]                │
└─────────────────────────────────────────────────────────┘
```

## Dropdown Filter Combinations

### Option 1: Floor-wise
```
First Dropdown: "Floor-wise"
       ↓
Second Dropdown shows:
  • Floor 1
  • Floor 2
  • Floor 3
       ↓
Displays: All rooms (classes, labs, staff rooms) on that floor
```

### Option 2: Class-wise
```
First Dropdown: "Class-wise"
       ↓
Second Dropdown shows:
  • Floor-1-Class-101
  • Floor-1-Class-102
  • Floor-1-Class-103
  • Floor-2-Class-201
  • Floor-2-Class-202
  • Floor-2-Class-203
  • Floor-3-Class-301
  • Floor-3-Class-302
       ↓
Displays: Energy metrics for selected classroom
```

### Option 3: All Rooms
```
First Dropdown: "All Rooms"
       ↓
Second Dropdown shows:
  • All available rooms (classes, labs, staff rooms)
  • Complete list of 21 rooms
       ↓
Displays: Energy metrics for selected room
```

### Option 4: Labs & Staff Rooms
```
First Dropdown: "Labs & Staff Rooms"
       ↓
Second Dropdown shows:
  • Floor-1-Lab-1
  • Floor-1-Lab-2
  • Floor-1-StaffRoom
  • Floor-2-Lab-3
  • Floor-2-Lab-4
  • Floor-2-StaffRoom
  • Floor-3-Lab-5
  • Floor-3-StaffRoom
       ↓
Displays: Energy metrics for labs and staff rooms only
```

## Room Structure Breakdown

### Floor 1
- **Classes**: 101, 102, 103
- **Labs**: Lab 1, Lab 2
- **Staff Room**: 1 room

### Floor 2
- **Classes**: 201, 202, 203
- **Labs**: Lab 3, Lab 4
- **Staff Room**: 1 room

### Floor 3
- **Classes**: 301, 302
- **Labs**: Lab 5 (Electronics Lab)
- **Staff Room**: 1 room

**Total: 21 Rooms**
- 8 Classrooms
- 5 Computer Labs + 1 Electronics Lab
- 3 Staff Rooms

## Data Display Explained

### Voltage
- Standard AC supply voltage
- Expected: 230V (±10%)
- Color: Blue

### Current
- Electrical current draw
- Measured in Amperes (A)
- Color: Orange

### Power
- Real-time power consumption
- Measured in Kilowatts (kW)
- Color: Red

### Energy Consumed
- Cumulative energy usage
- Measured in Kilowatt-hours (kWh)
- Color: Green

## Time-Series Graphs

### 24-Hour Data Points
- Each graph shows 24 data points (hourly averages)
- X-axis: Time progression (0-24 hours)
- Y-axis: Value in respective units

### Graph Features
- Smooth curves for better visualization
- Semi-transparent area below curve for emphasis
- Grid lines for easy reading
- Responsive height (200 pixels)

## Automatic Features

✅ **Auto Refresh**: Data updates every 60 seconds
✅ **Fallback Data**: If API unavailable, uses simulated data
✅ **Responsive Layout**: Works on all screen sizes
✅ **Theme Support**: Adapts to light/dark theme

## How Data is Generated

When database is unavailable, simulated data includes:

1. **Base Load** - Different for each room type
   - Classes: 2.3-2.6 kW
   - Labs: 3.9-4.3 kW
   - Staff Rooms: 1.8-2.0 kW

2. **Time-based Variance** - Simulates real usage patterns
   - Night (20:00-08:00): 40% of base load
   - Morning (08:00-10:00): 80% of base load
   - Day (10:00-17:00): 120% of base load (peak)
   - Evening (17:00-20:00): 90% of base load

3. **Electrical Parameters** - Realistic values
   - Voltage: 230V (standard)
   - Frequency: 50Hz (India standard)
   - Power Factor: 0.95 (typical)

## Tips for Effective Use

1. **Monitor Peak Hours** - 10:00-17:00 shows highest consumption
2. **Compare Rooms** - Use "All Rooms" to identify high consumers
3. **Floor Analysis** - Use "Floor-wise" to balance load across floors
4. **Lab Management** - Use "Labs & Staff Rooms" to monitor equipment usage
5. **Trends** - Check graphs to understand daily patterns

---

**Last Updated**: January 24, 2026
**Dashboard Version**: 2.0 (Reconstructed)
