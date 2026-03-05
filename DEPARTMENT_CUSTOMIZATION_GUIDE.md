# Department-Based Role Customization Guide

## Overview
This implementation provides a comprehensive department-based interface customization system that allows different users (Technical Coordinators, Class Representatives, Admins) to have personalized dashboards and experiences based on their assigned department.

## Architecture

### 1. **User Role & Department Model**
**File:** `lib/models/user_role_model.dart`

Defines the core structure for department-based users:

```dart
enum UserRole {
  student,
  classRepresentative,
  technicalCoordinator,
  admin,
  superAdmin,
}

enum Department {
  computerScience,
  electrical,
  electronics,
  mechanical,
  itt,
  civilEngineering,
  admin,
}

class EnhancedUser {
  final String id;
  final String username;
  final String email;
  final String name;
  final UserRole role;
  final Department department;
  // ... other fields
}
```

**Key Methods:**
- `getDisplayTitle()` - Returns role title with department
- `canAccessFeature(String featureName)` - Checks feature access
- `getAccessibleRooms(List<String> allRooms)` - Filters rooms by department

### 2. **Department Customization Service**
**File:** `lib/services/department_customization_service.dart`

Centralized service for managing all department-specific customizations:

```dart
class DepartmentCustomizationService {
  /// Get theme data specific to a department
  ThemeData getDepartmentTheme(Department department)
  
  /// Get dashboard features available for a specific role
  List<DashboardFeature> getDashboardFeatures(
    UserRole role,
    Department department,
  )
  
  /// Get department-specific menu items
  List<DepartmentMenuItem> getDepartmentMenuItems(
    Department department,
    UserRole role,
  )
  
  /// Get customized metrics to display for a role
  List<MetricCard> getMetricsForRole(UserRole role, Department department)
  
  /// Get department-specific color scheme for charts
  Map<String, Color> getDepartmentChartColors(Department department)
}
```

**Department Colors:**
- Computer Science: Blue (#2196F3)
- Electrical: Orange (#FF9800)
- Electronics: Red (#F44336)
- Mechanical: Green (#4CAF50)
- ITT: Purple (#9C27B0)
- Civil Engineering: Brown (#795548)
- Admin: Blue Grey (#607D8B)

### 3. **Department Dashboard Widget**
**File:** `lib/widgets/department_dashboard_widget.dart`

Main widget for displaying department-customized dashboards:

```dart
class DepartmentDashboard extends StatefulWidget {
  final EnhancedUser user;
  final Widget Function(BuildContext) contentBuilder;
}

// Additional widgets:
class DepartmentCard // Theme-aware card component
class DepartmentMetric // Department-branded metric display
```

**Features:**
- Dynamic sidebar with department-specific menu items
- Customized AppBar showing department and role
- Department-themed color scheme
- Role-based feature visibility

### 4. **Department Authentication Service**
**File:** `lib/services/department_auth_service.dart`

Handles authentication with department assignment:

```dart
class DepartmentAuthService {
  /// Login coordinator with department
  Future<LoginResult> loginCoordinator({
    required String coordinatorId,
    required String password,
  })
  
  /// Login class representative with department
  Future<LoginResult> loginClassRepresentative({
    required String username,
    required String password,
  })
  
  /// Login admin with department
  Future<LoginResult> loginAdmin({
    required String username,
    required String password,
  })
  
  /// Check if current user has access to a specific feature
  bool canAccessFeature(String featureName)
}
```

## Database Schema

### Enhanced Tables

#### Coordinators Table
```sql
coordinators
├── id (PK)
├── coordinator_id (UNIQUE)
├── email (UNIQUE)
├── password_hash
├── name
├── department (FK to department_customization)  -- NEW
├── assigned_rooms (JSON)                         -- NEW
├── is_active                                      -- NEW
├── last_login                                     -- NEW
├── created_at
└── updated_at                                     -- NEW
```

#### Class Representatives Table
```sql
class_representatives
├── id (PK)
├── username (UNIQUE)
├── password_hash
├── ktu_id (UNIQUE)
├── email (UNIQUE)
├── name
├── department (FK to department_customization)  -- NEW
├── year
├── section                                        -- NEW
├── assigned_rooms (JSON)                         -- NEW
├── is_active                                      -- NEW
├── last_login                                     -- NEW
├── created_at
└── updated_at                                     -- NEW
```

#### Admins Table (Enhanced)
```sql
admins
├── id (PK)
├── username (UNIQUE)
├── email (UNIQUE)
├── password_hash
├── name
├── department (FK)                               -- NEW: 'admin' for superadmin
├── role_level (NEW: 'superadmin' | 'department_admin')
├── is_active                                      -- NEW
├── last_login                                     -- NEW
├── created_at
└── updated_at                                     -- NEW
```

#### Rooms Table (Enhanced)
```sql
rooms
├── id (PK)
├── room_id (UNIQUE)
├── room_name
├── floor_number
├── department (FK)                               -- NEW: Assign rooms to departments
├── threshold
├── created_at
└── updated_at
```

#### New: Department Customization Table
```sql
department_customization
├── id (PK)
├── department (UNIQUE) -- e.g., 'computerScience', 'electrical'
├── display_name        -- e.g., 'Computer Science'
├── color_hex           -- UI color for department
├── icon_name           -- Material Design icon name
├── enabled_features    -- JSON array of features
├── dashboard_layout    -- JSON dashboard configuration
├── metrics_to_display  -- JSON array of metrics
├── custom_rooms        -- JSON array of department-specific rooms
├── created_at
└── updated_at
```

## Backend API Endpoints

**Base URL:** `/api/department`

### Department Management

#### Get All Departments
```
GET /api/department/list
Response: { departments: [...] }
```

#### Get Department Configuration
```
GET /api/department/get/<department>
Response: { config: {...} }
```

#### Create Department Configuration
```
POST /api/department/create
Body: {
  department: "computerScience",
  display_name: "Computer Science",
  color_hex: "#2196F3",
  icon_name: "computer",
  enabled_features: ["view_all_data", "manage_thresholds"],
  dashboard_layout: {...},
  metrics_to_display: ["total_consumption", "peak_load"],
  custom_rooms: ["CSL-101", "CSL-102"]
}
```

#### Update Department Configuration
```
PUT /api/department/update/<department>
Body: { /* fields to update */ }
```

### User-Department Assignment

#### Assign Rooms to Coordinator
```
POST /api/department/coordinator/<coordinator_id>/assign-rooms
Body: { room_ids: ["CSL-101", "CSL-102", "CSL-103"] }
```

#### Assign Rooms to Class Representative
```
POST /api/department/class-rep/<username>/assign-rooms
Body: { room_ids: ["Class-101", "Class-102"] }
```

#### Get Coordinator's Rooms
```
GET /api/department/get-coordinator-rooms/<coordinator_id>
```

#### Get Class Representative's Rooms
```
GET /api/department/get-class-rep-rooms/<username>
```

#### Get Department's Rooms
```
GET /api/department/rooms/<department>
```

#### Get Department's Coordinators
```
GET /api/department/coordinators/<department>
```

#### Get Department's Class Representatives
```
GET /api/department/class-representatives/<department>
```

## Implementation Guide

### Step 1: Update Your Login Pages

**File:** `lib/coordinator_login.dart` (or similar)

```dart
import 'package:energia/services/department_auth_service.dart';
import 'package:energia/models/user_role_model.dart';

class CoordinatorLoginPage extends StatefulWidget {
  @override
  State<CoordinatorLoginPage> createState() => _CoordinatorLoginPageState();
}

class _CoordinatorLoginPageState extends State<CoordinatorLoginPage> {
  final _authService = DepartmentAuthService();

  void _login() async {
    final result = await _authService.loginCoordinator(
      coordinatorId: _coordinatorIdController.text,
      password: _passwordController.text,
    );

    if (result.success && result.user != null) {
      // Navigate to customized dashboard
      Navigator.pushReplacementNamed(
        context,
        '/coordinator_dashboard',
        arguments: result.user,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Login failed')),
      );
    }
  }
}
```

### Step 2: Wrap Your Coordinator Dashboard

**File:** `lib/coordinator_dashboard.dart` (Modified)

```dart
import 'package:energia/widgets/department_dashboard_widget.dart';
import 'package:energia/models/user_role_model.dart';

class CoordinatorDashboardPage extends StatefulWidget {
  final EnhancedUser user;

  const CoordinatorDashboardPage({
    super.key,
    required this.user,
  });

  @override
  State<CoordinatorDashboardPage> createState() =>
      _CoordinatorDashboardPageState();
}

class _CoordinatorDashboardPageState extends State<CoordinatorDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return DepartmentDashboard(
      user: widget.user,
      contentBuilder: (context) {
        // Your existing dashboard content
        return SingleChildScrollView(
          child: Column(
            children: [
              // Dashboard content here
            ],
          ),
        );
      },
    );
  }
}
```

### Step 3: Use Department-Themed Widgets

```dart
// Display a metric with department theming
DepartmentMetric(
  department: user.department,
  label: 'Total Consumption',
  value: '125.5',
  unit: 'kWh',
  icon: Icons.bolt,
)

// Display a card with department theming
DepartmentCard(
  department: user.department,
  title: 'Energy Summary',
  child: Text('Your summary content'),
)
```

### Step 4: Check Feature Access

```dart
final authService = DepartmentAuthService();

if (authService.canAccessFeature('manage_thresholds')) {
  // Show threshold management UI
} else {
  // Show access denied message
}
```

## Role-Based Features

### Technical Coordinator (per department)
- ✅ View all department data
- ✅ Manage thresholds
- ✅ View trends
- ✅ Generate reports
- ✅ Manage rooms in department
- ✅ Export data
- ❌ Create other coordinators
- ❌ System settings

### Class Representative (per department)
- ✅ View classroom data only
- ✅ View trends
- ✅ Generate reports
- ❌ Manage thresholds
- ❌ Manage other classrooms
- ❌ Export data

### Department Admin
- ✅ All coordinator features
- ✅ Manage users in department
- ✅ System settings (department-level)
- ❌ Manage other departments
- ❌ System-wide settings

### Super Admin
- ✅ Full access to all features
- ✅ Manage all departments
- ✅ Create other admins
- ✅ System-wide settings

## Customization Examples

### Example 1: Add Department-Specific Feature

```dart
// In DepartmentCustomizationService
List<DashboardFeature> _getDepartmentSpecificFeatures(
  UserRole role,
  Department department,
) {
  final features = <DashboardFeature>[];

  if (role == UserRole.technicalCoordinator) {
    switch (department) {
      case Department.computerScience:
        features.add(
          DashboardFeature(
            id: 'lab_equipment',
            title: 'Lab Equipment Monitoring',
            description: 'Monitor computer lab equipment usage',
            icon: Icons.computer,
            route: '/lab_equipment_monitor',
            order: 7,
          ),
        );
        break;
      // ... other departments
    }
  }

  return features;
}
```

### Example 2: Customize Metrics Per Department

```dart
List<MetricCard> getMetricsForRole(UserRole role, Department department) {
  final metrics = <MetricCard>[];

  // Common metrics
  metrics.add(MetricCard(...));

  // Department-specific metrics
  if (department == Department.electrical) {
    metrics.add(
      MetricCard(
        id: 'power_factor',
        title: 'Power Factor',
        unit: 'PF',
        icon: Icons.electric_bolt,
        displayPriority: 4,
      ),
    );
  }

  return metrics;
}
```

### Example 3: Department-Specific Room Filtering

```dart
List<String> getAccessibleRoomsByDepartment(Department department) {
  final roomsByDept = {
    Department.computerScience: [
      'CSL-101', 'CSL-102', 'CSL-103',
      'CS-Lab-1', 'CS-Lab-2',
      'Server-Room',
    ],
    Department.electrical: [
      'ELE-101', 'ELE-102',
      'ELE-Lab-1',
      'Power-Room',
    ],
    // ... other departments
  };

  return roomsByDept[department] ?? [];
}
```

## Testing

### Test Login with Department

```dart
void testCoordinatorLogin() async {
  final authService = DepartmentAuthService();
  
  final result = await authService.loginCoordinator(
    coordinatorId: 'CCSE001',
    password: 'Coord@123',
  );

  assert(result.success);
  assert(result.user?.department == Department.computerScience);
  assert(result.user?.role == UserRole.technicalCoordinator);
}
```

### Test Feature Access

```dart
void testFeatureAccess() {
  final user = EnhancedUser(
    id: '1',
    username: 'coord1',
    email: 'coord@test.com',
    name: 'Test Coordinator',
    role: UserRole.technicalCoordinator,
    department: Department.computerScience,
    createdAt: DateTime.now(),
  );

  assert(user.canAccessFeature('view_all_data'));
  assert(user.canAccessFeature('manage_thresholds'));
  assert(!user.canAccessFeature('manage_users'));
}
```

## Migration Path

If you have existing users without department assignments:

1. **Backup Database:**
   ```sql
   CREATE TABLE coordinators_backup AS SELECT * FROM coordinators;
   ```

2. **Add Department Column:**
   ```sql
   ALTER TABLE coordinators ADD COLUMN department VARCHAR DEFAULT 'general';
   ```

3. **Assign Departments:**
   ```sql
   UPDATE coordinators SET department = 'computerScience' 
   WHERE coordinator_id LIKE 'C%';
   ```

4. **Update Frontend Routes:**
   ```dart
   // Update all navigation to pass user object with department
   Navigator.pushNamed(
     context,
     '/coordinator_dashboard',
     arguments: user, // Now includes department
   );
   ```

## Best Practices

1. **Always Check Feature Access:** Before showing UI elements, check if the user can access them
2. **Use Department Service:** Always use `DepartmentCustomizationService` for theming
3. **Cache User Data:** Store the enhanced user object in shared preferences
4. **Validate Department:** Always validate that users can only access their assigned department
5. **Audit Logging:** Log all cross-department access attempts

## Troubleshooting

### Issue: User can't see department features
- Check if `department` field is populated in database
- Verify feature is enabled in department customization
- Check `canAccessFeature()` logic

### Issue: Wrong theme colors
- Verify `departmentColors` map in `user_role_model.dart`
- Check if custom color_hex is set in database

### Issue: Rooms not assigned
- Verify `assigned_rooms` JSON format
- Check if rooms exist in rooms table
- Verify department field in rooms table matches

## Next Steps

1. Run database migrations
2. Update your login pages with new authentication service
3. Wrap your dashboards with `DepartmentDashboard` widget
4. Register the backend API endpoints
5. Test with multiple users from different departments
6. Deploy and monitor user feedback

---

For detailed API documentation, see [API_DEPARTMENT_ENDPOINTS.md](API_DEPARTMENT_ENDPOINTS.md)
