# Architecture & Flow Diagrams

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     COORDINATOR DASHBOARD                        │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Room Selection & Filtering Section               │  │
│  │                                                            │  │
│  │  Filter Type: [All Rooms ▼]  Floor: [1 ▼]  Room: [101 ▼] │  │
│  │                                                            │  │
│  │  (Shows 3 dropdowns when "Floor-wise" is selected)        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │    Real-Time Energy Metrics  [Room Threshold Settings] │  │
│  │                                                            │  │
│  │  Voltage: 230V   Current: 5.2A   Power: 1.2kW            │  │
│  │                                                            │  │
│  │  Energy Consumed: 24.5kWh                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         Energy Usage Over Time (Graphs)                  │  │
│  │                                                            │  │
│  │         [Voltage Graph]  [Power Graph]                   │  │
│  │         [Current Graph]  [Energy Graph]                  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Floorwise Dropdown Cascade Flow

```
User selects "Floor-wise"
         │
         ▼
Three dropdowns appear in row:
┌─────────────────┬──────────────┬──────────────┐
│ Filter Type     │ Floor        │ Room         │
├─────────────────┼──────────────┼──────────────┤
│ [Floor-wise ▼]  │ [Floor 1 ▼]  │ [Class 101▼] │
└─────────────────┴──────────────┴──────────────┘
         │              │              │
         │              │              └─ Populated by
         │              │                 RoomDataSimulator
         │              │                 .getClassesByFloor()
         │              │
         │              └─ From
         │                 RoomDataSimulator
         │                 .getSecondDropdownOptions()
         │
         └─ Hardcoded in UI

User selects Floor
         │
         ▼
_onSecondDropdownChanged() called
         │
         ▼
_initializeThirdDropdown() executes
         │
         ▼
_thirdDropdownOptions updated with rooms from selected floor
         │
         ▼
Third dropdown auto-populated
         │
         ▼
User selects Room
         │
         ▼
_onThirdDropdownChanged() called
         │
         ▼
_loadSensorData() fetches data for selected room
         │
         ▼
Real-time metrics & graphs updated
```

## Threshold Management Dialog Flow

```
Click "Room Threshold Settings" Button
         │
         ▼
_showThresholdSettingsDialog() called
         │
         ▼
ThresholdSettingsDialog widget opens
         │
         ▼
_loadRooms() executes
         │
         ├─ Try API endpoint 1 (10.0.2.2:5000)
         ├─ Try API endpoint 2 (192.168.160.1:5000)
         ├─ Try API endpoint 3 (localhost:5000)
         └─ Try API endpoint 4 (127.0.0.1:5000)
         │
         ▼
GET /api/rooms successful
         │
         ▼
Parse 22 rooms from response
         │
         ▼
Create TextEditingController for each room's threshold
         │
         ▼
Display scrollable list of rooms:
┌──────────────────────────────────────┐
│  Class 101 (Floor 1)                 │
│  Threshold: 2.5 kW     [Edit Button] │
├──────────────────────────────────────┤
│  Class 102 (Floor 1)                 │
│  Threshold: 2.5 kW     [Edit Button] │
├──────────────────────────────────────┤
│  [More rooms...]                     │
└──────────────────────────────────────┘

User clicks "Edit" for a room
         │
         ▼
Edit mode activated for that room
         │
         ▼
UI transforms to:
┌──────────────────────────────────────┐
│  Class 101 (Floor 1)                 │
│  Threshold: 2.5 kW                   │
│  [Text Input: 2.5      ]             │
│  [Cancel] [Save]                     │
└──────────────────────────────────────┘

User enters new value (e.g., 3.5) and clicks "Save"
         │
         ▼
Validate input (must be numeric, positive)
         │
         ├─ Invalid? Show error message
         │
         └─ Valid? Continue...
         │
         ▼
_updateThreshold() executes
         │
         ├─ Try API endpoint 1
         ├─ Try API endpoint 2
         ├─ Try API endpoint 3
         └─ Try API endpoint 4
         │
         ▼
PUT /api/rooms/{room_id}/threshold?threshold=3.5
         │
         ▼
Backend updates database
         │
         ▼
Response received with success
         │
         ▼
Show success snackbar: "Threshold for Class 101 updated"
         │
         ▼
Update local room data
         │
         ▼
Exit edit mode, show new threshold
         │
         ▼
Back to normal room card view
```

## Database Relationships

```
┌────────────────────────────────┐
│           ROOMS TABLE          │
├────────────────────────────────┤
│ id (PK)          [INTEGER]     │
│ room_id (UK)     [VARCHAR]     │
│ room_name        [VARCHAR]     │
│ floor_number     [INTEGER] ◄── Indexed
│ threshold        [FLOAT]       │
│ created_at       [TIMESTAMP]   │
│ updated_at       [TIMESTAMP]   │
└────────────────────────────────┘
         │
         │ Foreign key relationship
         │ (implicit through floor_number)
         ▼
┌────────────────────────────────┐
│      LOGICAL FLOORS (0-3)      │
│                                │
│  Floor 0 (Ground):  6 rooms    │
│  Floor 1:          6 rooms    │
│  Floor 2:          6 rooms    │
│  Floor 3:          4 rooms    │
│  ─────────────────────────────  │
│  Total:           22 rooms    │
└────────────────────────────────┘
```

## Data Flow Diagram

```
FRONTEND (Flutter)                  BACKEND (Python/FastAPI)              DATABASE (PostgreSQL)
─────────────────────────────────────────────────────────────────────────────────────────────

┌──────────────────┐
│ Coordinator      │
│ Dashboard        │
└────────┬─────────┘
         │
         │ SELECT "Floor-wise"
         ▼
┌──────────────────┐
│ Initialize       │ ──────GET /api/floors──────────────────────────────────────┐
│ Dropdowns        │                                                             │
└────────┬─────────┘                                                             │
         │                                                                       │
         │ SELECT Floor 1                                                        ▼
         ▼                                                                   ┌──────────────┐
┌──────────────────┐                                                         │ Query floors │
│ Load room list   │ ──────GET /api/rooms/floor/1──────────────────────────▶│ from rooms   │
│ for Floor 1      │                                                         │ table        │
└────────┬─────────┘                                                         └──────────────┘
         │                                                                       │
         │ SELECT Class 101                                                      │
         ▼                                                                       │
┌──────────────────┐                                                             │
│ Load sensor      │ ──────GET /api/sensor-data──────────────────────────────────┤
│ data for         │                                                             │
│ Class 101        │                                                             │
└────────┬─────────┘                                                             │
         │                                                                       │
         │ Display metrics & graphs                                             │
         ▼                                                                       │
┌──────────────────┐                                                             │
│ Metrics          │                                                             │
│ Updated          │                                                             │
└──────────────────┘                                                             │
         │                                                                       │
         │ CLICK "Room Threshold Settings"                                      │
         ▼                                                                       │
┌──────────────────┐                                                             │
│ Open Dialog      │ ──────GET /api/rooms───────────────────────────────────────┤
│ for Thresholds   │                                                             │
└────────┬─────────┘                                                             │
         │                                                                       │
         │ Display all 22 rooms with current thresholds                         │
         ▼                                                                       │
┌──────────────────┐                                                             │
│ Room List        │                                                             │
│ displayed        │                                                             │
└────────┬─────────┘                                                             │
         │                                                                       │
         │ CLICK Edit on Class 101                                              │
         ▼                                                                       │
┌──────────────────┐                                                             │
│ Enter edit mode  │                                                             │
│ Show text field  │                                                             │
└────────┬─────────┘                                                             │
         │                                                                       │
         │ Enter 3.5 kW and click Save                                          │
         ▼                                                                       │
┌──────────────────┐                                                             │
│ Validate input   │                                                             │
│ (numeric,        │                                                             │
│  positive)       │                                                             │
└────────┬─────────┘                                                             │
         │                                                                       │
         │ Valid ✓                                                               │
         ▼                                                                       │
┌──────────────────┐                                                             │
│ Send update      │ ──PUT /api/rooms/Floor-1-Class-101/threshold?threshold=3.5─┤
│ request          │                                                             │
└────────┬─────────┘                                                             ▼
         │                                                                   ┌──────────────┐
         │ Response: Success                                                │ UPDATE rooms │
         │◀──────────────────────────────────────────────────────────────────│ set          │
         │                                                                   │ threshold =  │
         │                                                                   │ 3.5          │
         │                                                                   └──────────────┘
         │
         ▼
┌──────────────────┐
│ Show success     │
│ message          │
│ Update local     │
│ threshold        │
└──────────────────┘
         │
         │ Close dialog
         ▼
┌──────────────────┐
│ Dashboard        │
│ refreshed        │
└──────────────────┘
```

## State Management Diagram

```
_CoordinatorDashboardPageState
│
├─ _currentIndex: int = 0
│  └─ Tracks active tab (Overview, Rooms, Analytics, Alerts)
│
├─ _firstDropdownValue: String = 'all'
│  └─ Values: 'floorwise', 'classwise', 'all', 'others'
│  └─ Affects layout and second dropdown content
│
├─ _secondDropdownValue: String = ''
│  └─ When 'floorwise': Floor (e.g., "Floor 1")
│  └─ When 'classwise': Class name
│  └─ When 'all': Room name
│  └─ When 'others': Lab/Staff room name
│  └─ Triggers third dropdown update (if floorwise)
│  └─ Triggers sensor data reload
│
├─ _thirdDropdownValue: String = '' (NEW)
│  └─ Only used when 'floorwise' is selected
│  └─ Contains selected room ID
│  └─ Used to load sensor data
│
├─ _secondDropdownOptions: List<Map>
│  └─ Populated by RoomDataSimulator.getSecondDropdownOptions()
│  └─ For floorwise: List of floors
│  └─ For classwise: List of classes
│  └─ For all: List of all rooms
│  └─ For others: List of labs and staff rooms
│
├─ _thirdDropdownOptions: List<Map> (NEW)
│  └─ Only populated when 'floorwise' is selected
│  └─ Populated by RoomDataSimulator.getClassesByFloor()
│  └─ Contains rooms on selected floor
│
├─ _sensorData: Map<String, dynamic>?
│  └─ Current room's sensor data (voltage, current, power, energy)
│
├─ _timeSeriesData: List<Map<String, dynamic>>?
│  └─ Historical sensor data for graphs (24 data points)
│
├─ _loadingData: bool = true
│  └─ Shows loading indicator while fetching data
│
└─ _dataRefreshTimer: Timer?
   └─ Refreshes data every minute
```

## UI Layout Comparison

### Normal Mode (Not Floorwise)
```
┌───────────────────────────────────────────────┐
│         Room Selection & Filtering            │
│                                               │
│ [Filter Type▼]  [Select Item▼]               │
└───────────────────────────────────────────────┘
```

### Floorwise Mode
```
┌─────────────────────────────────────────────────────┐
│         Room Selection & Filtering                  │
│                                                     │
│ [Filter Type▼]  [Floor▼]      [Room▼]              │
└─────────────────────────────────────────────────────┘
```

## Error Handling Flow

```
API Call Made
│
├─ Try Endpoint 1 (10.0.2.2:5000)
│  └─ Timeout? → Try next
│  └─ Success? → Return data
│  └─ Error? → Try next
│
├─ Try Endpoint 2 (192.168.160.1:5000)
│  └─ Timeout? → Try next
│  └─ Success? → Return data
│  └─ Error? → Try next
│
├─ Try Endpoint 3 (localhost:5000)
│  └─ Timeout? → Try next
│  └─ Success? → Return data
│  └─ Error? → Try next
│
├─ Try Endpoint 4 (127.0.0.1:5000)
│  └─ Timeout? → All failed
│  └─ Success? → Return data
│  └─ Error? → All failed
│
└─ All endpoints failed
   └─ Show error message to user
   └─ Optionally: Fall back to simulated data
```

---

**These diagrams illustrate the complete architecture and data flow of the implemented features.**
