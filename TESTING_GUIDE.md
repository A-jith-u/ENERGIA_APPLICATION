# Quick Testing Guide - Floorwise & Threshold Features

## Setup

### 1. Initialize Database
```bash
cd c:\Users\rapha\OneDrive\Desktop\project\ENERGIA_APPLICATION\backend
python db_init.py
```

**Expected Output:**
```
DB initialized and test users ensured
```

**Verify Database:**
```sql
-- Connect to PostgreSQL and run:
SELECT COUNT(*) FROM rooms;  -- Should return 22
SELECT DISTINCT floor_number FROM rooms ORDER BY floor_number;  -- Should return 0,1,2,3
SELECT * FROM rooms LIMIT 5;  -- View sample room data
```

### 2. Start Backend Server
```bash
cd backend
python start_server.py
# or
python app_main.py
```

### 3. Start Flutter App
```bash
cd ENERGIA_APPLICATION
flutter run
```

## Frontend Testing Scenarios

### Test 1: Floorwise Dropdown Appears
1. Navigate to Coordinator Dashboard
2. In "Room Selection & Filtering" section
3. Change first dropdown from "All Rooms" to "Floor-wise"

**Expected Result:**
- Three dropdowns appear in a single row
- First dropdown shows "Floor-wise" (selected)
- Second dropdown labeled "Floor" shows options: Floor 0, Floor 1, Floor 2, Floor 3
- Third dropdown labeled "Room" shows rooms for the currently selected floor

### Test 2: Floor Selection Cascades
1. In the floorwise mode, select different floors from the second dropdown

**Expected Result:**
- Room dropdown updates immediately
- Sensor data refreshes for the new floor's first room
- All rooms shown correspond to the selected floor

### Test 3: Room-Specific Data Loads
1. Select "Floor-wise" mode
2. Select Floor 1
3. Select "Class 101"

**Expected Result:**
- Sensor metrics update (voltage, current, power, energy)
- Time series graphs show data for Class 101
- Data refreshes every minute (timer runs)

### Test 4: Toggle Back to Other Filters
1. Select "Floor-wise"
2. Then select "Class-wise"

**Expected Result:**
- Third dropdown disappears
- Goes back to two-column layout
- Dropdown labels change appropriately

### Test 5: Threshold Management Dialog Opens
1. Navigate to "Real-Time Energy Metrics" section
2. Click "Room Threshold Settings" button

**Expected Result:**
- Dialog opens with title "Room Threshold Settings"
- Close button (X) appears in top-right
- List shows all rooms with floor information
- Current threshold displayed for each room
- Edit button available for each room

### Test 6: View All Rooms and Thresholds
1. In threshold dialog, scroll through the list

**Expected Result:**
- All 22 rooms are visible
- Rooms are grouped logically (or can be sorted)
- Floor numbers match the room data
- Sample thresholds shown (2.0-4.5 kW depending on room type)

### Test 7: Edit Room Threshold
1. Click "Edit" button on any room (e.g., "Class 101")

**Expected Result:**
- Edit mode activates for that room
- Edit button disappears
- Text field appears with current threshold value
- Cancel button appears
- Save button appears

### Test 8: Modify and Save Threshold
1. Click Edit on "Class 101" (current threshold: 2.5)
2. Clear the text field
3. Enter "3.5"
4. Click "Save"

**Expected Result:**
- Success message appears: "Threshold for Class 101 updated successfully"
- Edit mode closes
- Room card shows new threshold: "3.5 kW"
- Edit button reappears

### Test 9: Cancel Edit Without Saving
1. Click Edit on "Class 102"
2. Change the value to "4.0"
3. Click "Cancel"

**Expected Result:**
- Edit mode closes
- Threshold reverts to original value
- No success message shown
- No API call made

### Test 10: Close Dialog
1. Open threshold settings dialog
2. Click the X button in the header

**Expected Result:**
- Dialog closes smoothly
- Returns to main dashboard
- No data loss

### Test 11: Close Dialog by Clicking Outside
1. Open threshold settings dialog
2. Click on the dark area outside the dialog

**Expected Result:**
- Dialog closes (barrierDismissible is true)
- Returns to main dashboard

### Test 12: Input Validation
1. Open threshold dialog
2. Edit a room's threshold
3. Try these invalid inputs:
   - Leave blank → Try to save
   - Enter "-5" → Try to save
   - Enter "abc" → Try to save

**Expected Result:**
- Error message: "Please enter a valid threshold value"
- No API call made
- Threshold not updated

## API Testing

### Test API Endpoints with curl

#### Get All Rooms
```bash
curl http://localhost:5000/api/rooms
```

**Expected Response:**
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

#### Get Rooms by Floor
```bash
curl http://localhost:5000/api/rooms/floor/1
```

**Expected Response:** Returns 6 rooms for Floor 1

#### Get All Floors
```bash
curl http://localhost:5000/api/rooms/floors
```

**Expected Response:**
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

#### Update Threshold
```bash
curl -X PUT "http://localhost:5000/api/rooms/Floor-1-Class-101/threshold?threshold=3.8"
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Threshold updated successfully",
  "data": {
    "room_id": "Floor-1-Class-101",
    "room_name": "Class 101",
    "floor_number": 1,
    "threshold": 3.8
  }
}
```

## Database Verification

### Check Rooms Table
```sql
SELECT * FROM rooms ORDER BY floor_number, room_name LIMIT 10;
```

**Expected:** Should show rooms with proper structure

### Check Room Count by Floor
```sql
SELECT floor_number, COUNT(*) as count FROM rooms GROUP BY floor_number ORDER BY floor_number;
```

**Expected Output:**
```
floor_number | count
0            | 6
1            | 6
2            | 6
3            | 4
```

### Verify Threshold Ranges
```sql
SELECT room_name, floor_number, threshold FROM rooms ORDER BY threshold DESC LIMIT 5;
```

**Expected:** Lab rooms should have ~4.5 kW, classrooms ~2.5 kW, staff rooms ~2.0 kW

## Performance Tests

### Test 1: Load Dialog with All Rooms
1. Click "Room Threshold Settings"
2. Measure time to load all 22 rooms

**Expected:** Should load in < 2 seconds

### Test 2: Scroll Through Room List
1. Open threshold dialog
2. Scroll through all rooms

**Expected:** Smooth scrolling without jank

### Test 3: Rapid Floor Switching
1. Select "Floor-wise"
2. Quickly switch between floors

**Expected:** Dropdowns update smoothly, no lag

## Error Handling Tests

### Test 1: Backend Offline
1. Stop the backend server
2. Try to open threshold settings dialog
3. Observe error handling

**Expected:** Error message shown, graceful degradation

### Test 2: Network Error
1. Modify API endpoint to invalid IP
2. Try to update threshold

**Expected:** Error message, retry available

### Test 3: Invalid Room ID
```bash
curl -X PUT "http://localhost:5000/api/rooms/INVALID-ROOM-ID/threshold?threshold=3.0"
```

**Expected Response:**
```json
{"detail": "Room not found"}
```

## Sign-Off Checklist

- [ ] Floorwise dropdown shows three columns when selected
- [ ] Floor dropdown populates with all floors
- [ ] Room dropdown cascades based on selected floor
- [ ] Sensor data loads correctly for selected room
- [ ] Other filter types still work (Class-wise, All Rooms, Labs & Staff)
- [ ] Threshold dialog opens successfully
- [ ] All 22 rooms are listed in dialog
- [ ] Room details (name, floor) display correctly
- [ ] Current thresholds are shown
- [ ] Edit button works
- [ ] Edit mode shows text field
- [ ] Cancel button reverts changes
- [ ] Save button updates threshold
- [ ] Success message appears after save
- [ ] Invalid inputs are rejected
- [ ] Dialog can be closed with X button
- [ ] Dialog can be closed by clicking outside
- [ ] API endpoints respond correctly
- [ ] Database has all 22 rooms
- [ ] Database has correct floor numbers and thresholds
- [ ] No syntax errors in code
- [ ] No runtime errors in console

---

**Implementation Status**: ✅ COMPLETE
**All Tests**: Ready to Execute
