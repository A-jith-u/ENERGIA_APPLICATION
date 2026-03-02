# Quick Start: Testing Department-Based Dashboards

## 🚀 What We've Implemented

You now have **department-based customization** where technical coordinators from different departments see **completely different interfaces** showing only their department's data.

---

## ✅ Changes Made

### 1. **coordinator_login.dart** Updated
- ✅ Now uses `DepartmentAuthService` for login
- ✅ Creates `EnhancedUser` object with department info
- ✅ Passes user object to dashboard

### 2. **coordinator_dashboard.dart** Updated
- ✅ Accepts `EnhancedUser` parameter
- ✅ Filters rooms by department
- ✅ Applies department-specific theme
- ✅ Shows department badge in header

### 3. **Documentation Created**
- ✅ `DEPARTMENT_BASED_COORDINATOR_GUIDE.md` - Complete implementation guide
- ✅ `DEPARTMENT_VISUAL_COMPARISON.md` - Visual comparison of different departments

---

## 🧪 Testing Instructions

### Step 1: Prepare Test Data

You need coordinators with department assignments in your database:

```sql
-- Example: Create CS coordinator
INSERT INTO coordinators (
  coordinator_id, 
  name, 
  password_hash, 
  department, 
  assigned_rooms,
  is_active
) VALUES (
  'CS_COORD_001',
  'John Doe',
  'hashed_password_here',
  'computerScience',
  '["cs_lab_101", "cs_lab_102", "cs_lab_201"]',
  true
);

-- Example: Create ELE coordinator
INSERT INTO coordinators (
  coordinator_id, 
  name, 
  password_hash, 
  department, 
  assigned_rooms,
  is_active
) VALUES (
  'ELE_COORD_001',
  'Jane Smith',
  'hashed_password_here',
  'electrical',
  '["ele_lab_101", "ele_lab_102", "ele_lab_201"]',
  true
);

-- Example: Create ECE coordinator
INSERT INTO coordinators (
  coordinator_id, 
  name, 
  password_hash, 
  department, 
  assigned_rooms,
  is_active
) VALUES (
  'ECE_COORD_001',
  'Bob Johnson',
  'hashed_password_here',
  'electronics',
  '["ece_lab_101", "ece_lab_102", "ece_lab_201"]',
  true
);
```

### Step 2: Run the Application

```bash
cd e:\Flutter\flutter_application_1
flutter run
```

### Step 3: Test Each Department

#### Test 1: Computer Science Coordinator
```
Login ID: CS_COORD_001
Password: [your password]

Expected Results:
✅ Title: "🏢 Computer Science ENERGIA"
✅ Theme: Blue colors (#2196F3)
✅ Department Badge: [CS 🔵]
✅ Room Dropdown: Shows only cs_lab_101, cs_lab_102, cs_lab_201
✅ Charts: Blue color scheme
```

#### Test 2: Electrical Engineering Coordinator
```
Login ID: ELE_COORD_001
Password: [your password]

Expected Results:
✅ Title: "🏢 Electrical Engineering ENERGIA"
✅ Theme: Orange colors (#FF9800)
✅ Department Badge: [ELE 🟠]
✅ Room Dropdown: Shows only ele_lab_101, ele_lab_102, ele_lab_201
✅ Charts: Orange color scheme
```

#### Test 3: Electronics Engineering Coordinator
```
Login ID: ECE_COORD_001
Password: [your password]

Expected Results:
✅ Title: "🏢 Electronics Engineering ENERGIA"
✅ Theme: Purple colors (#9C27B0)
✅ Department Badge: [ECE 🟣]
✅ Room Dropdown: Shows only ece_lab_101, ece_lab_102, ece_lab_201
✅ Charts: Purple color scheme
```

---

## 📊 Visual Verification Checklist

For each coordinator, verify:

### Header Section
- [ ] Dashboard title shows correct department name
- [ ] Department badge (top right) shows correct department
- [ ] Department badge has correct color
- [ ] Department icon is visible

### Theme Colors
- [ ] Primary color matches department
- [ ] Cards have department-colored borders
- [ ] Buttons use department colors
- [ ] Charts use department color schemes

### Room Access
- [ ] Room dropdown shows ONLY department's rooms
- [ ] Attempting to select other rooms is impossible
- [ ] Room names match department prefix (cs_, ele_, ece_)

### Data Display
- [ ] Energy consumption data is for selected room only
- [ ] Temperature data is for selected room only
- [ ] Charts display with department colors
- [ ] All metrics are department-specific

---

## 🔍 Testing Scenarios

### Scenario 1: Data Isolation Test
**Goal:** Verify CS coordinator cannot see ELE data

1. Login as CS coordinator
2. Check room dropdown
3. Verify NO ele_lab_* rooms are visible
4. Try to manually access ELE room (should fail)

**Expected:** ✅ Only CS rooms visible

### Scenario 2: Theme Consistency Test
**Goal:** Verify theme is consistent throughout

1. Login as ELE coordinator
2. Navigate through all tabs (Overview, Rooms, Analytics, Alerts)
3. Check colors on each page

**Expected:** ✅ Orange theme on all pages

### Scenario 3: Multi-Coordinator Test
**Goal:** Verify multiple coordinators can use system simultaneously

1. Login as CS coordinator on Device A
2. Login as ELE coordinator on Device B
3. Both check their dashboards

**Expected:** 
- ✅ Device A shows blue theme with CS rooms
- ✅ Device B shows orange theme with ELE rooms

---

## 🐛 Troubleshooting

### Issue 1: Dashboard Shows No Rooms
**Symptoms:** Room dropdown is empty

**Solutions:**
1. Check database: `SELECT assigned_rooms FROM coordinators WHERE coordinator_id = 'CS_COORD_001';`
2. Verify `assigned_rooms` is valid JSON array
3. Ensure room IDs match those in `RoomDataSimulator`

**Fix:**
```sql
UPDATE coordinators 
SET assigned_rooms = '["cs_lab_101", "cs_lab_102"]'
WHERE coordinator_id = 'CS_COORD_001';
```

### Issue 2: Wrong Theme Colors
**Symptoms:** CS coordinator sees orange theme

**Solutions:**
1. Check `department` field in database
2. Verify it matches enum values: 'computerScience', 'electrical', 'electronics'
3. Check `EnhancedUser` is being created correctly

**Fix:**
```sql
UPDATE coordinators 
SET department = 'computerScience'
WHERE coordinator_id = 'CS_COORD_001';
```

### Issue 3: Can See All Rooms (Not Filtered)
**Symptoms:** CS coordinator sees ELE and ECE rooms

**Solutions:**
1. Verify `EnhancedUser` object is passed to dashboard
2. Check login code passes user: `CoordinatorDashboardPage(user: loginResult.user)`
3. Verify `_filterRoomsByDepartment()` is called in `initState()`

**Fix:** Ensure coordinator_login.dart has:
```dart
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => CoordinatorDashboardPage(user: loginResult.user),
  ),
);
```

### Issue 4: Login Fails
**Symptoms:** "Login failed" error message

**Solutions:**
1. Check backend is running: `http://10.0.2.2:5000`
2. Verify coordinator exists in database
3. Check password hash matches
4. Verify department field is set

**Debug:**
```dart
// Add logging in coordinator_login.dart
print('Login attempt: $id');
print('Login result: ${loginResult.success}');
print('User: ${loginResult.user?.toJson()}');
```

---

## 📝 Expected Database Schema

Your `coordinators` table should look like this:

```sql
CREATE TABLE coordinators (
  coordinator_id VARCHAR PRIMARY KEY,
  name VARCHAR NOT NULL,
  password_hash VARCHAR NOT NULL,
  department VARCHAR NOT NULL,  -- 'computerScience', 'electrical', etc.
  assigned_rooms JSON,           -- ['cs_lab_101', 'cs_lab_102']
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🎯 Success Criteria

You've successfully implemented department-based customization if:

✅ **Different coordinators see different interfaces**
- CS coordinator sees blue theme
- ELE coordinator sees orange theme
- ECE coordinator sees purple theme

✅ **Data is isolated by department**
- Each coordinator sees only their rooms
- Room dropdowns are filtered correctly
- No cross-department data leakage

✅ **UI is customized per department**
- Department name in header
- Department badge visible
- Theme colors applied consistently
- Charts use department colors

✅ **Navigation works correctly**
- Login → Dashboard transition smooth
- User object passed correctly
- Session persists across page refreshes

---

## 🚀 Next Steps

### 1. Add More Departments
If you have Mechanical, ITT, or Civil departments:

```sql
-- Mechanical coordinator
INSERT INTO coordinators VALUES (
  'MECH_COORD_001',
  'Alice Brown',
  'hashed_password',
  'mechanical',
  '["mech_lab_101", "mech_workshop"]',
  true
);
```

### 2. Add Room Assignments
Update existing coordinators with room assignments:

```sql
UPDATE coordinators 
SET assigned_rooms = '["room1", "room2", "room3"]',
    department = 'computerScience'
WHERE coordinator_id = 'existing_coord_id';
```

### 3. Test with Real Data
Replace `RoomDataSimulator` with real database queries filtered by department:

```dart
// In coordinator_dashboard.dart
Future<void> _fetchFromDatabase({String? deviceId}) async {
  // Add department filter
  final departmentFilter = _currentUser?.department ?? '';
  final url = '$baseUrl/api/sensor-data?department=$departmentFilter&device_id=$deviceId';
  
  final response = await http.get(Uri.parse(url));
  // Process response...
}
```

---

## 📚 Documentation References

For more details, see:
- **Implementation Guide:** `DEPARTMENT_BASED_COORDINATOR_GUIDE.md`
- **Visual Comparison:** `DEPARTMENT_VISUAL_COMPARISON.md`
- **Full Architecture:** `DEPARTMENT_CUSTOMIZATION_GUIDE.md`

---

## ✨ Summary

You now have:
✅ Department-specific login  
✅ Customized dashboards per department  
✅ Data isolation (each coordinator sees only their data)  
✅ Theme customization (colors, icons, branding)  
✅ Room filtering by department  
✅ Comprehensive documentation  

**The system is ready for testing!** 🎉

Start by creating test coordinators in your database, then login and verify each department sees their unique interface.
