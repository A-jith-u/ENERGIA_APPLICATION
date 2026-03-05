# Department Customization - Quick Reference Card

## 🎯 Core Concepts

### User = Role + Department
```dart
EnhancedUser(
  id: '1',
  username: 'coord1',
  role: UserRole.technicalCoordinator,     // What they can do
  department: Department.computerScience,   // Where they work
)
```

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│   Enhanced User (Role + Dept)       │
├─────────────────────────────────────┤
│ • technicalCoordinator              │
│ • computerScience department        │
│ • CSL-101, CSL-102 rooms            │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Department Customization Service   │
├─────────────────────────────────────┤
│ • Get theme by department           │
│ • Get features by role + dept       │
│ • Get menu items                    │
│ • Get metrics to display            │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│   Department Dashboard Widget       │
├─────────────────────────────────────┤
│ • Sidebar with dept menu            │
│ • Department-themed AppBar          │
│ • Dynamic content area              │
│ • Department-colored components     │
└─────────────────────────────────────┘
```

## 📁 File Structure

```
lib/
├── models/
│   └── user_role_model.dart              # EnhancedUser, roles, depts
├── services/
│   ├── department_auth_service.dart      # Login & auth
│   └── department_customization_service.dart  # UI customization
├── widgets/
│   └── department_dashboard_widget.dart  # UI components
├── examples/
│   └── department_customization_examples.dart  # Implementation examples
backend/
├── db_init.py                            # Enhanced DB schema
└── department_api.py                     # REST API endpoints
```

## 🚀 Quick Integration

### 1. Initialize Service
```dart
final authService = DepartmentAuthService();
await authService.initialize();
```

### 2. Login
```dart
final result = await authService.loginCoordinator(
  coordinatorId: 'CCSE001',
  password: 'password',
);
if (result.success) {
  final user = result.user; // Has department!
}
```

### 3. Use Customized Dashboard
```dart
DepartmentDashboard(
  user: user,
  contentBuilder: (context) => YourContent(),
)
```

### 4. Display Themed Components
```dart
DepartmentCard(
  department: user.department,
  title: 'Card Title',
  child: Text('Content'),
)

DepartmentMetric(
  department: user.department,
  label: 'Energy',
  value: '125.5',
  unit: 'kWh',
  icon: Icons.bolt,
)
```

## 🎨 Department Colors

| Department | Color | Hex Code |
|------------|-------|----------|
| Computer Science | 🔵 Blue | #2196F3 |
| Electrical | 🟠 Orange | #FF9800 |
| Electronics | 🔴 Red | #F44336 |
| Mechanical | 🟢 Green | #4CAF50 |
| ITT | 🟣 Purple | #9C27B0 |
| Civil Engineering | 🟤 Brown | #795548 |
| Admin | ⚫ Grey | #607D8B |

## 👥 User Roles & Permissions

### Technical Coordinator
```
Department: ✅ Own department only
Features:
  ✅ view_all_data
  ✅ manage_thresholds
  ✅ view_trends
  ✅ generate_reports
  ✅ manage_rooms
  ✅ export_data
  ❌ manage_users
  ❌ system_settings
```

### Class Representative
```
Department: ✅ Own department only
Features:
  ✅ view_classroom_data
  ✅ view_trends
  ✅ generate_reports
  ❌ manage_thresholds
  ❌ manage_rooms
  ❌ export_data
```

### Department Admin
```
Department: ✅ Own department only
Features:
  ✅ All coordinator features
  ✅ manage_users
  ✅ system_settings
```

### Super Admin
```
Department: ✅ All departments
Features:
  ✅ Everything
```

## 🔐 Feature Access Check

```dart
// Check if user can access feature
if (user.canAccessFeature('manage_thresholds')) {
  // Show management UI
} else {
  // Show access denied
}

// Check if user can access room
if (authService.canAccessRoom('CSL-101')) {
  // Allow room access
}

// Get accessible rooms
List<String> rooms = authService.getAccessibleRooms();
```

## 🛢️ Database Tables

```sql
-- Enhanced Tables
coordinators
├── department (FK)
├── assigned_rooms (JSON)
├── is_active
└── last_login

class_representatives
├── department (FK)
├── section
├── assigned_rooms (JSON)
├── is_active
└── last_login

admins
├── department (FK)
├── role_level ('superadmin'|'department_admin')
├── is_active
└── last_login

rooms
└── department (FK)

-- New Table
department_customization
├── department (UNIQUE)
├── display_name
├── color_hex
├── icon_name
├── enabled_features (JSON)
├── dashboard_layout (JSON)
├── metrics_to_display (JSON)
└── custom_rooms (JSON)
```

## 📡 API Endpoints

### Department Management
```
GET   /api/department/list
GET   /api/department/get/<department>
POST  /api/department/create
PUT   /api/department/update/<department>
```

### Room Assignments
```
POST  /api/department/coordinator/<id>/assign-rooms
POST  /api/department/class-rep/<username>/assign-rooms
GET   /api/department/get-coordinator-rooms/<id>
GET   /api/department/get-class-rep-rooms/<username>
GET   /api/department/rooms/<department>
```

### User Lists
```
GET   /api/department/coordinators/<department>
GET   /api/department/class-representatives/<department>
```

## 💾 Data Models

### User JSON (Login Response)
```json
{
  "id": "1",
  "username": "coord1",
  "email": "coord@test.com",
  "name": "John Coordinator",
  "role": "technicalCoordinator",
  "department": "computerScience",
  "coordinator_id": "CCSE001",
  "is_active": true,
  "created_at": "2024-01-30T10:00:00",
  "last_login": "2024-01-30T14:30:00"
}
```

### Department Config (API Response)
```json
{
  "department": "computerScience",
  "display_name": "Computer Science",
  "color_hex": "#2196F3",
  "icon_name": "computer",
  "enabled_features": [
    "view_all_data",
    "manage_thresholds"
  ],
  "metrics_to_display": [
    "total_consumption",
    "cooling_efficiency"
  ],
  "custom_rooms": [
    "CSL-101", "CSL-102"
  ]
}
```

## 🧪 Test Cases

### Login Test
```dart
final result = await authService.loginCoordinator(
  coordinatorId: 'CCSE001',
  password: 'Coord@123',
);
assert(result.success);
assert(result.user!.department == Department.computerScience);
```

### Feature Access Test
```dart
assert(user.canAccessFeature('view_all_data'));
assert(!user.canAccessFeature('manage_users'));
```

### Room Assignment Test
```dart
await authService.assignRoomsToCoordinator(
  coordinatorId: 'CCSE001',
  roomIds: ['CSL-101', 'CSL-102'],
);
var rooms = await authService.getCoordinatorRooms('CCSE001');
assert(rooms.length == 2);
```

## ⚡ Common Tasks

### Add New Department
```dart
// 1. Add to enum
enum Department {
  // ... existing
  newDept,
}

// 2. Add colors, icons, names
departmentColors[Department.newDept] = Color(0xFF...);
departmentIcons[Department.newDept] = Icons...;
departmentNames[Department.newDept] = 'New Department';

// 3. Create in database
POST /api/department/create {
  "department": "newDept",
  "display_name": "New Department",
  "color_hex": "#...",
  "icon_name": "icon_name",
  "enabled_features": [...],
  "custom_rooms": [...]
}
```

### Assign Rooms to Coordinator
```dart
final authService = DepartmentAuthService();
await authService.assignRoomsToCoordinator(
  coordinatorId: 'CCSE001',
  roomIds: ['CSL-101', 'CSL-102', 'CSL-103'],
);
```

### Get Department Features
```dart
final customizationService = DepartmentCustomizationService();
final features = customizationService.getDashboardFeatures(
  UserRole.technicalCoordinator,
  Department.computerScience,
);
```

### Apply Department Theme
```dart
final theme = customizationService.getDepartmentTheme(
  Department.computerScience,
);
return Theme(
  data: theme,
  child: YourApp(),
);
```

## 🐛 Debugging Tips

1. **Check User Department**
   ```dart
   print('User Department: ${user.department.name}');
   print('User Role: ${user.role.name}');
   ```

2. **Verify Feature Access**
   ```dart
   print('Can manage thresholds: ${user.canAccessFeature('manage_thresholds')}');
   ```

3. **Check Database**
   ```sql
   SELECT * FROM coordinators WHERE coordinator_id = 'CCSE001';
   SELECT * FROM department_customization;
   ```

4. **API Response**
   ```bash
   curl http://localhost:5000/api/department/list
   ```

## 📚 Related Files

- **Implementation Guide**: [DEPARTMENT_CUSTOMIZATION_GUIDE.md](DEPARTMENT_CUSTOMIZATION_GUIDE.md)
- **Implementation Summary**: [DEPARTMENT_CUSTOMIZATION_IMPLEMENTATION.md](DEPARTMENT_CUSTOMIZATION_IMPLEMENTATION.md)
- **Examples**: [lib/examples/department_customization_examples.dart](lib/examples/department_customization_examples.dart)

---

**Last Updated:** 2024-01-30
**Version:** 1.0
