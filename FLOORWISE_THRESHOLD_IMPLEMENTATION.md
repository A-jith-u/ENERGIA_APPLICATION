# Floorwise Dropdown & Threshold Management Implementation

## Overview
This document describes the complete implementation of floorwise cascading dropdowns and room threshold management features for the Coordinator Dashboard.

## Features Implemented

### 1. Database Changes (backend/db_init.py)

#### New Table: `rooms`
A new table has been created to store all room information with threshold settings:

```sql
CREATE TABLE rooms (
    id INTEGER PRIMARY KEY,
    room_id VARCHAR UNIQUE NOT NULL,
    room_name VARCHAR NOT NULL,
    floor_number INTEGER NOT NULL,  -- 0 = Ground floor, 1 = First floor, etc.
    threshold FLOAT DEFAULT 3.0,    -- Default threshold in kW
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Indexes Created:
- `idx_rooms_floor_number` - For efficient floor-based queries
- `idx_rooms_room_id` - For room lookup by ID

#### Seed Data:
Rooms are pre-populated across 4 floors (0-3) with:
- **Ground Floor (0)**: 6 rooms (3 classrooms, 2 labs, 1 staff room)
- **Floor 1**: 6 rooms (3 classrooms, 2 labs, 1 staff room)
- **Floor 2**: 6 rooms (3 classrooms, 2 labs, 1 staff room)
- **Floor 3**: 4 rooms (2 classrooms, 1 lab, 1 staff room)

Each room has a default threshold of 2.0-4.5 kW depending on room type.

### 2. Backend API Changes (backend/auth_api.py)

#### New Endpoints:

##### GET `/api/rooms`
Returns all rooms with their floor and threshold information.
```json
{
  "status": "success",
  "count": 22,
  "data": [
    {
      "room_id": "Floor-0-Class-G01",
      "room_name": "Class G01",
      "floor_number": 0,
      "threshold": 2.5
    },
    ...
  ]
}
```

##### GET `/api/rooms/floor/{floor_number}`
Returns all rooms on a specific floor.
```json
{
  "status": "success",
  "count": 6,
  "data": [...]
}
```

##### GET `/api/rooms/floors`
Returns all unique floors in the system.
```json
{
  "status": "success",
  "count": 4,
  "data": [
    {"floor_number": 0},
    {"floor_number": 1},
    {"floor_number": 2},
    {"floor_number": 3}
  ]
}
```

##### PUT `/api/rooms/{room_id}/threshold?threshold={value}`
Updates the threshold for a specific room.
```json
{
  "status": "success",
  "message": "Threshold updated successfully",
  "data": {
    "room_id": "Floor-1-Class-101",
    "room_name": "Class 101",
    "floor_number": 1,
    "threshold": 3.5
  }
}
```

### 3. Frontend Changes (lib/coordinator_dashboard.dart)

#### State Management Updates:
- Added `_thirdDropdownValue` - stores selected room in floorwise mode
- Added `_thirdDropdownOptions` - list of rooms/classes for selected floor
- Added `onThirdDropdownChanged()` callback for third dropdown changes

#### UI Enhancements:

##### Floorwise Three-Dropdown Layout:
When "Floor-wise" is selected in the filter type dropdown, THREE dropdowns appear in a single row:
1. **Filter Type Dropdown**: Shows "Floor-wise" (selected)
2. **Floor Dropdown**: Displays all available floors (0, 1, 2, 3)
3. **Room Dropdown**: Displays all rooms on the selected floor

The dropdowns are responsive and cascade properly:
- Selecting a floor automatically populates the room dropdown
- Selecting a room loads and displays sensor data for that room

##### Threshold Management Button:
- Located in the "Real-Time Energy Metrics" section header
- Button text: "Room Threshold Settings"
- Icon: Settings gear icon
- Opens a dialog when clicked

#### Dialog Features (ThresholdSettingsDialog):

##### Layout:
- **Header**: Gradient background with title and close button
- **Content**: Scrollable list of all rooms organized by floor
- **Footer**: Close button

##### Room Display:
Each room card shows:
- Room name (bold title)
- Floor number (subtitle)
- Current threshold value
- Edit button (when not editing)

##### Edit Mode:
When edit button is clicked:
- Current threshold value is displayed
- Text input field appears for new threshold
- Cancel button to discard changes
- Save button to apply changes

##### Functionality:
- Loads all rooms from backend API
- Displays current threshold for each room
- Allows editing and saving new thresholds
- Shows success/error messages
- Can be closed by clicking the X button or clicking outside the dialog

### 4. Model Updates (lib/models/room_data_simulator.dart)

#### New Methods:

##### `getSecondDropdownOptions(String firstDropdownValue)`
Updated to return floors when "floorwise" is selected:
```dart
case 'floorwise':
  return getFloors()
      .map((floor) => {'id': floor, 'name': floor})
      .toList();
```

##### `getClassesByFloor(String floor)`
Returns all classroom, lab, and staff rooms on a specific floor:
```dart
static List<Map<String, dynamic>> getClassesByFloor(String floor) {
  // Returns rooms filtered by floor
}
```

##### `getAllRoomsByFloor(String floor)`
Returns all rooms on a specific floor (alternative method).

## How to Use

### For Coordinators:

#### Viewing Floorwise Data:
1. Open the Coordinator Dashboard
2. In the "Room Selection & Filtering" section, select "Floor-wise" from the first dropdown
3. Two additional dropdowns will appear:
   - Select the desired floor from the "Floor" dropdown
   - Select the specific room from the "Room" dropdown
4. Real-time energy metrics for that room will be displayed
5. Time series graphs will show energy usage data for the selected room

#### Managing Thresholds:
1. In the "Real-Time Energy Metrics" section, click the "Room Threshold Settings" button
2. A popup dialog will open showing all rooms organized by floor
3. For each room:
   - View the current threshold value
   - Click "Edit" to modify the threshold
   - Enter the new threshold value (in kW)
   - Click "Save" to apply the change
   - Or click "Cancel" to discard changes
4. Click the X button or click outside the dialog to close it

### Database Initialization:

The database is automatically initialized when the backend starts. To manually run initialization:
```bash
python -m backend.db_init
```

This will:
- Create the `rooms` table if it doesn't exist
- Seed 22 rooms across 4 floors
- Create necessary indexes for performance

## Testing Checklist

### Database Tests:
- [x] Rooms table created successfully
- [x] 22 rooms seeded with proper floor numbers and thresholds
- [x] Indexes created for optimization
- [x] All rooms have unique room_ids

### API Endpoint Tests:

#### Test GET /api/rooms
```bash
curl http://localhost:5000/api/rooms
```
Expected: Returns all 22 rooms with floor and threshold info

#### Test GET /api/rooms/floor/{floor_number}
```bash
curl http://localhost:5000/api/rooms/floor/1
```
Expected: Returns 6 rooms on Floor 1

#### Test GET /api/rooms/floors
```bash
curl http://localhost:5000/api/rooms/floors
```
Expected: Returns floors [0, 1, 2, 3]

#### Test PUT /api/rooms/{room_id}/threshold
```bash
curl -X PUT "http://localhost:5000/api/rooms/Floor-1-Class-101/threshold?threshold=3.5"
```
Expected: Updates threshold and returns updated room data

### Frontend Tests:

#### Floorwise Dropdown Tests:
1. Open Coordinator Dashboard
2. Select "Floor-wise" from filter dropdown
   - Verify three dropdowns appear in one row
   - Verify floor dropdown shows available floors
   - Verify room dropdown populates based on selected floor
3. Select different floors
   - Verify room list updates correctly
   - Verify sensor data loads for selected room
4. Switch back to other filter types
   - Verify three dropdowns disappear
   - Verify original two-dropdown layout returns

#### Threshold Management Dialog Tests:
1. Click "Room Threshold Settings" button
   - Verify dialog opens
   - Verify all rooms are displayed
   - Verify room names and floor numbers are shown
   - Verify current thresholds are displayed
2. Click "Edit" on a room
   - Verify edit mode activates
   - Verify text field appears with current value
   - Verify Cancel button discards changes
3. Modify and save a threshold
   - Enter new threshold value
   - Click Save
   - Verify success message appears
   - Verify threshold updates in the list
4. Close the dialog
   - Click X button or click outside
   - Verify dialog closes properly
   - Verify no data loss

### End-to-End Tests:

1. **Complete Workflow**:
   - Start backend server
   - Initialize database
   - Open Coordinator Dashboard
   - Select "Floor-wise" filter
   - Select a floor and room
   - Verify sensor data displays
   - Click threshold settings
   - Edit a room's threshold
   - Verify update succeeds
   - Close dialog

2. **Data Consistency**:
   - Verify same data appears in dropdown and settings dialog
   - Verify threshold changes persist after closing and reopening dialog
   - Verify room data updates correctly after threshold changes

3. **Error Handling**:
   - Test invalid threshold values (negative, non-numeric)
   - Verify appropriate error messages
   - Verify graceful handling of API failures
   - Test with backend offline - verify fallback to simulated data

## File Changes Summary

### Backend Files:
- **backend/db_init.py**
  - Added `rooms_table` definition
  - Added room seed data (22 rooms)
  - Added database indexes

- **backend/auth_api.py**
  - Added 4 new API endpoints for rooms management

### Frontend Files:
- **lib/coordinator_dashboard.dart**
  - Updated state management for floorwise dropdowns
  - Modified dropdown UI to show three columns in floorwise mode
  - Added ThresholdSettingsDialog widget
  - Added threshold management button

- **lib/models/room_data_simulator.dart**
  - Updated `getSecondDropdownOptions()` method
  - Added `getClassesByFloor()` method
  - Added `getAllRoomsByFloor()` method

## Performance Considerations

1. **Database Indexes**: Created on floor_number and room_id for O(1) lookups
2. **Lazy Loading**: Rooms are loaded only when threshold dialog is opened
3. **Caching**: Consider adding local caching if API calls become frequent
4. **Pagination**: For large deployments with many rooms, pagination can be added to the rooms list

## Future Enhancements

1. Add bulk threshold update functionality
2. Implement threshold alert notifications
3. Add threshold history/audit log
4. Export room configuration as CSV
5. Advanced filtering in threshold management dialog
6. Sort rooms by different criteria (name, floor, threshold)
7. Add room search functionality

## Troubleshooting

### Issue: Floorwise dropdown doesn't show three columns
- **Solution**: Clear cache and restart Flutter app
- **Check**: Verify `firstDropdownValue == 'floorwise'` condition

### Issue: Threshold changes not persisting
- **Solution**: Verify backend API is running
- **Check**: Verify PUT endpoint returns success status

### Issue: Rooms not loading in threshold dialog
- **Solution**: Check backend logs for API errors
- **Alternative**: Verify API endpoint `/api/rooms` responds correctly

### Issue: No rooms appear for selected floor
- **Solution**: Verify seed data was created in database
- **Check**: Query: `SELECT * FROM rooms WHERE floor_number = X;`

---

**Implementation Date**: January 26, 2026
**Status**: Complete and tested
**All syntax errors**: None (verified)
