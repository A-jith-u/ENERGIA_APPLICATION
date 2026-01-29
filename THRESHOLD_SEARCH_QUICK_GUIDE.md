# Threshold & Search Features - Quick Reference

## Feature 1: Fuzzy Search in Threshold Dialog

### How to Use
1. Click "Room Threshold Settings" button on coordinator dashboard
2. Dialog opens with a search bar at the top
3. Start typing to filter rooms:
   - Search by room name: "Class", "Lab", "Staff"
   - Search by room ID: "Floor-1", "G01", "101"
   - Search by floor: "0", "1", "2", "3"

### Search Examples
| Search Query | Results |
|--------------|---------|
| `lab` | Computer Lab G1, Computer Lab G2, Computer Lab 1, ... |
| `101` | Class 101 (Floor 1) |
| `class` | Class G01, Class G02, Class 101, Class 102, ... |
| `floor 2` | All rooms on Floor 2 (Class 201, 202, 203, Lab 3, Lab 4, Staff Room) |
| `staff` | All Staff Rooms across all floors |
| `3` | All rooms on Floor 3 or with "3" in name |
| `comp` | Computer Lab G1, Computer Lab G2, Computer Lab 1, Computer Lab 2 |

### Clear Search
Click the "X" button in the search field to clear and show all rooms again

---

## Feature 2: Update Room Threshold (FIXED)

### How to Update Threshold
1. Open "Room Threshold Settings" dialog
2. Find your room (use search if needed)
3. Click the "Edit" button on the room card
4. Enter new threshold value in kW
5. Click "Save" button
6. Success message will appear in snackbar
7. Database is updated automatically

### Validation Rules
- ✅ **Valid**: 0.5, 1.0, 2.5, 3.0, 4.5, 100.0
- ❌ **Invalid**: 0, -1, -5.5, 100000000 (unreasonably high)
- ❌ **Invalid**: abc, xyz, special characters

### Current Room Thresholds (Default)
- Classrooms: 2.5 kW
- Computer Labs: 4.5 kW
- Staff Rooms: 2.0 kW

### Testing the Fix
**Before**: Threshold value changed in UI but NOT saved to database
**After**: Threshold value changed in UI AND persisted to database

To verify it's working:
1. Note current threshold of a room (e.g., "Class 101: 2.5")
2. Edit it to new value (e.g., "3.5")
3. Click Save
4. See success message
5. Close dialog and reopen it
6. Search for same room again
7. New value should be visible (3.5) - confirming it was saved

---

## Backend Improvements

### Validation Added
- Threshold must be > 0 (no zero or negative values)
- Room must exist before updating
- Clear error messages if something fails

### Error Messages
| Error | Meaning | Fix |
|-------|---------|-----|
| "Threshold must be greater than 0" | You entered 0 or negative | Enter positive number |
| "Room with ID '...' not found" | Room doesn't exist in database | Try different room |
| "Threshold value is required" | No value provided | Enter a value |

---

## Database Impact

### Rooms Table Updates
When you save a threshold:
- `threshold` column is updated with new value
- `updated_at` column is automatically set to current timestamp
- All other fields remain unchanged

### SQL Equivalent
```sql
UPDATE rooms 
SET threshold = 2.5, updated_at = NOW() 
WHERE room_id = 'Floor-1-Class-101'
```

---

## Key Improvements Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Threshold Saves** | ❌ Not saved to DB | ✅ Properly saved to DB |
| **Room Search** | ❌ No search feature | ✅ Fuzzy search added |
| **URL Encoding** | ❌ Missing | ✅ Implemented |
| **Error Messages** | ❌ Generic | ✅ Specific & helpful |
| **Input Validation** | ❌ Basic | ✅ Comprehensive |
| **UX** | Confusing | Clear & intuitive |

---

## Troubleshooting

### Problem: Save button doesn't work
**Solutions**:
1. Check if threshold value is entered
2. Ensure value is positive (> 0)
3. Try a different room
4. Restart the app

### Problem: Search doesn't find my room
**Solutions**:
1. Try different keywords (name, ID, or floor number)
2. Clear search and scroll manually
3. Check if room exists in system (should be 22 total)

### Problem: Changes don't persist after restart
**Solutions**:
1. Check if success snackbar appeared after save
2. Verify backend server is running
3. Check database connection in backend logs
4. Restart backend: `python start_server.py`

---

## API Details (For Developers)

### Endpoint
```
PUT /api/rooms/{room_id}/threshold?threshold={value}
```

### Example Request
```
PUT /api/rooms/Floor-1-Class-101/threshold?threshold=3.5
Content-Type: application/json
```

### Example Success Response (200)
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

### Example Error Response (400)
```json
{
  "detail": "Threshold value is required"
}
```
