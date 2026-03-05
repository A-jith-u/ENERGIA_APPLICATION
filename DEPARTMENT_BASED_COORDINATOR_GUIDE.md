# Department-Based Coordinator Dashboard Guide

## Overview
This guide explains how the coordinator dashboard now shows **different interfaces for different departments**, ensuring that each technical coordinator sees **only their department's data**.

---

## Key Features

### 1. **Department-Specific Themes**
Each department has its own color scheme and branding:

| Department | Color | Icon |
|------------|-------|------|
| Computer Science | Blue | `computer` |
| Electrical Engineering | Orange | `electrical_services` |
| Electronics Engineering | Purple | `memory` |
| Mechanical Engineering | Red | `engineering` |
| ITT | Teal | `devices` |
| Civil Engineering | Brown | `construction` |

### 2. **Data Filtering by Department**
Coordinators can **only see rooms assigned to their department**:

```dart
// Example: CS coordinator sees only CS labs
_accessibleRooms = _customizationService.getAccessibleRoomsByDepartment(
  user.department, // Department.computerScience
);
// Result: ['cs_lab_101', 'cs_lab_102', 'cs_lab_201']
```

### 3. **Customized Dashboard Title**
The dashboard title changes based on department:
- **CS Coordinator**: "🏢 Computer Science ENERGIA"
- **ELE Coordinator**: "🏢 Electrical Engineering ENERGIA"
- **ECE Coordinator**: "🏢 Electronics Engineering ENERGIA"

---

## How It Works

### Login Flow

**Old Flow (Before):**
```
Login → Store Token → Navigate to Dashboard → Show ALL data
```

**New Flow (Now):**
```
Login → Create EnhancedUser with Department → Pass to Dashboard → Filter by Department
```

### Code Example

**coordinator_login.dart:**
```dart
// Use department authentication service
final authService = DepartmentAuthService();
final loginResult = await authService.loginCoordinator(id, password);

if (loginResult.success && loginResult.user != null) {
  // Navigate with user object
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => CoordinatorDashboardPage(
        user: loginResult.user, // EnhancedUser with department info
      ),
    ),
  );
}
```

**coordinator_dashboard.dart:**
```dart
class CoordinatorDashboardPage extends StatefulWidget {
  final EnhancedUser? user; // Department info here

  const CoordinatorDashboardPage({super.key, this.user});
}

// Filter rooms by department
void _filterRoomsByDepartment() {
  _accessibleRooms = _customizationService.getAccessibleRoomsByDepartment(
    _currentUser!.department,
  );
}

// Apply department theme
Widget build(BuildContext context) {
  if (_currentUser != null) {
    final departmentTheme = _customizationService.getDepartmentTheme(
      _currentUser!.department
    );
    return Theme(
      data: departmentTheme,
      child: _buildDepartmentDashboard(departmentTheme.colorScheme),
    );
  }
}
```

---

## Department-Specific UI Elements

### 1. **Department Badge** (Top Right)
Shows the coordinator's department with color-coded indicator:

```dart
Container(
  decoration: BoxDecoration(
    color: departmentColor.withOpacity(0.2),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: departmentColor, width: 1),
  ),
  child: Row(
    children: [
      Icon(departmentIcons[user.department]),
      Text(departmentNames[user.department]),
    ],
  ),
)
```

### 2. **Room Dropdowns** (Filtered by Department)
When selecting rooms, coordinators only see their department's rooms:

```dart
void _initializeSecondDropdown() {
  // Get all rooms
  _secondDropdownOptions = RoomDataSimulator.getSecondDropdownOptions(
    _firstDropdownValue,
  );
  
  // Filter by department
  if (_currentUser != null && _accessibleRooms.isNotEmpty) {
    _secondDropdownOptions = _secondDropdownOptions.where((room) {
      final roomId = room['id'] as String;
      return _accessibleRooms.contains(roomId);
    }).toList();
  }
}
```

### 3. **Department-Themed Charts**
Charts use department-specific colors:

```dart
final chartColors = _customizationService.getDepartmentChartColors(
  user.department
);
// CS: Blue gradients
// ELE: Orange gradients
// ECE: Purple gradients
```

---

## Testing Different Departments

### Test Scenario 1: CS Coordinator Login
```
Login ID: CS_COORD_001
Password: [coordinator password]
Department: Computer Science

Expected Result:
- Dashboard title: "🏢 Computer Science ENERGIA"
- Theme: Blue colors
- Visible rooms: Only CS labs
- Department badge: Blue "Computer Science"
```

### Test Scenario 2: ELE Coordinator Login
```
Login ID: ELE_COORD_001
Password: [coordinator password]
Department: Electrical Engineering

Expected Result:
- Dashboard title: "🏢 Electrical Engineering ENERGIA"
- Theme: Orange colors
- Visible rooms: Only ELE labs
- Department badge: Orange "Electrical Engineering"
```

### Test Scenario 3: ECE Coordinator Login
```
Login ID: ECE_COORD_001
Password: [coordinator password]
Department: Electronics Engineering

Expected Result:
- Dashboard title: "🏢 Electronics Engineering ENERGIA"
- Theme: Purple colors
- Visible rooms: Only ECE labs
- Department badge: Purple "Electronics Engineering"
```

---

## Data Isolation

### Room Access Control
Each coordinator can only access rooms assigned to their department:

```dart
// Example: CS Coordinator
user.getAccessibleRooms() 
// Returns: ['cs_lab_101', 'cs_lab_102', 'cs_lab_201']

// Attempting to access 'ele_lab_101' will be blocked
```

### Feature Access Control
Different departments may have different features enabled:

```dart
// Check if coordinator can access a feature
if (user.canAccessFeature('energy_analytics')) {
  // Show analytics panel
}

// Check if coordinator can access a specific room
if (user.canAccessRoom('cs_lab_101')) {
  // Load room data
}
```

---

## Backend Integration

### Database Schema
The `coordinators` table now includes:

```sql
CREATE TABLE coordinators (
  coordinator_id VARCHAR PRIMARY KEY,
  name VARCHAR,
  password_hash VARCHAR,
  department VARCHAR,  -- 'computerScience', 'electrical', etc.
  assigned_rooms JSON, -- ['cs_lab_101', 'cs_lab_102']
  is_active BOOLEAN,
  last_login TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### API Endpoints
New department-specific endpoints:

```
GET  /api/department/coordinators/{department}
  → Get all coordinators for a department

GET  /api/department/rooms/{department}
  → Get all rooms for a department

POST /api/department/coordinator/{id}/assign-rooms
  → Assign specific rooms to a coordinator

GET  /api/department/get-coordinator-rooms/{id}
  → Get rooms assigned to a coordinator
```

---

## Migration from Old System

### Step 1: Update Existing Coordinators
Add department assignment to existing coordinators:

```sql
UPDATE coordinators 
SET department = 'computerScience',
    assigned_rooms = '["cs_lab_101", "cs_lab_102"]'
WHERE coordinator_id = 'CS_COORD_001';
```

### Step 2: Update Login Flow
Replace old login with new department authentication:

```dart
// Old
final token = await login(id, password);

// New
final authService = DepartmentAuthService();
final result = await authService.loginCoordinator(id, password);
final user = result.user; // EnhancedUser with department
```

### Step 3: Update Dashboard Navigation
Pass user object to dashboard:

```dart
// Old
Navigator.pushReplacementNamed(context, '/coordinator_dashboard');

// New
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => CoordinatorDashboardPage(user: user),
  ),
);
```

---

## Visual Differences by Department

### Computer Science (CS)
```
┌─────────────────────────────────────────┐
│ 🏢 Computer Science ENERGIA      [CS]🔵│
├─────────────────────────────────────────┤
│  Theme: Blue (#2196F3)                  │
│  Rooms: cs_lab_101, cs_lab_102, ...     │
│  Icon: Computer                          │
│  Features: Full access                   │
└─────────────────────────────────────────┘
```

### Electrical Engineering (ELE)
```
┌─────────────────────────────────────────┐
│ 🏢 Electrical Engineering ENERGIA [ELE]🟠│
├─────────────────────────────────────────┤
│  Theme: Orange (#FF9800)                │
│  Rooms: ele_lab_101, ele_lab_102, ...   │
│  Icon: Electrical Services              │
│  Features: Full access                   │
└─────────────────────────────────────────┘
```

### Electronics Engineering (ECE)
```
┌─────────────────────────────────────────┐
│ 🏢 Electronics Engineering ENERGIA [ECE]🟣│
├─────────────────────────────────────────┤
│  Theme: Purple (#9C27B0)                │
│  Rooms: ece_lab_101, ece_lab_102, ...   │
│  Icon: Memory/Chip                       │
│  Features: Full access                   │
└─────────────────────────────────────────┘
```

---

## Troubleshooting

### Issue 1: Dashboard Shows All Rooms
**Problem:** Coordinator sees rooms from other departments.

**Solution:**
1. Check if `EnhancedUser` is passed to dashboard:
   ```dart
   CoordinatorDashboardPage(user: loginResult.user)
   ```
2. Verify `assigned_rooms` in database:
   ```sql
   SELECT assigned_rooms FROM coordinators WHERE coordinator_id = 'CS_COORD_001';
   ```

### Issue 2: Wrong Theme Colors
**Problem:** CS coordinator sees orange theme (ELE colors).

**Solution:**
1. Check user's department in login response
2. Verify department mapping in `EnhancedUser.fromJson()`
3. Ensure theme is applied:
   ```dart
   final theme = _customizationService.getDepartmentTheme(user.department);
   ```

### Issue 3: No Rooms Visible
**Problem:** Dropdown shows no rooms.

**Solution:**
1. Check `assigned_rooms` is not empty in database
2. Verify room IDs match between database and `RoomDataSimulator`
3. Check filtering logic in `_initializeSecondDropdown()`

---

## Quick Reference

### File Changes
1. **coordinator_login.dart**
   - Added: `DepartmentAuthService` import
   - Added: `EnhancedUser` import
   - Modified: `_performLogin()` method
   - Added: Pass user to dashboard

2. **coordinator_dashboard.dart**
   - Added: `user` parameter to constructor
   - Added: Department filtering logic
   - Added: Department theme application
   - Modified: Room dropdown filtering

### Key Services
- **DepartmentAuthService**: Handles login with department info
- **DepartmentCustomizationService**: Provides themes, features, and room filtering
- **EnhancedUser**: User model with role and department

### Key Models
- **Department enum**: 7 departments (CS, ELE, ECE, MECH, ITT, Civil, Admin)
- **UserRole enum**: 5 roles (Student, ClassRep, Coordinator, Admin, SuperAdmin)
- **EnhancedUser class**: Combines role + department with permissions

---

## Summary

✅ **Each coordinator sees ONLY their department's data**  
✅ **Department-specific color themes applied**  
✅ **Room filtering by department**  
✅ **Department badge in UI**  
✅ **Customized dashboard titles**  
✅ **Permission-based feature access**  

The system now ensures complete data isolation between departments while providing a tailored user experience for each technical coordinator.
