# Migration Guide: Upgrading to Department-Based Customization

## Overview
This guide helps migrate your existing user system to the new department-based role customization system.

## Pre-Migration Checklist

- [ ] Database backup created
- [ ] Test environment prepared
- [ ] Team notified of changes
- [ ] Maintenance window scheduled
- [ ] Rollback plan documented

## Step 1: Database Backup

```bash
# PostgreSQL
pg_dump energia > energia_backup_$(date +%Y%m%d_%H%M%S).sql

# MySQL
mysqldump -u root -p energia > energia_backup_$(date +%Y%m%d_%H%M%S).sql
```

## Step 2: Run Database Migrations

The `db_init.py` file now includes automatic migrations. Simply run:

```bash
python -m backend.db_init
```

This will:
1. ✅ Add missing columns to existing tables
2. ✅ Create new department_customization table
3. ✅ Preserve all existing data
4. ✅ Create indexes for performance

### Manual Migration (if needed):

```sql
-- Add columns to coordinators table
ALTER TABLE coordinators ADD COLUMN assigned_rooms TEXT;
ALTER TABLE coordinators ADD COLUMN is_active INTEGER DEFAULT 1;
ALTER TABLE coordinators ADD COLUMN last_login TIMESTAMP;
ALTER TABLE coordinators ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();

-- Add columns to class_representatives table
ALTER TABLE class_representatives ADD COLUMN section VARCHAR;
ALTER TABLE class_representatives ADD COLUMN assigned_rooms TEXT;
ALTER TABLE class_representatives ADD COLUMN is_active INTEGER DEFAULT 1;
ALTER TABLE class_representatives ADD COLUMN last_login TIMESTAMP;
ALTER TABLE class_representatives ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();

-- Add columns to admins table
ALTER TABLE admins ADD COLUMN department VARCHAR;
ALTER TABLE admins ADD COLUMN role_level VARCHAR DEFAULT 'department_admin';
ALTER TABLE admins ADD COLUMN is_active INTEGER DEFAULT 1;
ALTER TABLE admins ADD COLUMN last_login TIMESTAMP;
ALTER TABLE admins ADD COLUMN updated_at TIMESTAMP DEFAULT NOW();

-- Add column to rooms table
ALTER TABLE rooms ADD COLUMN department VARCHAR;

-- Create department_customization table
CREATE TABLE department_customization (
    id SERIAL PRIMARY KEY,
    department VARCHAR UNIQUE NOT NULL,
    display_name VARCHAR NOT NULL,
    color_hex VARCHAR NOT NULL,
    icon_name VARCHAR NOT NULL,
    enabled_features TEXT,
    dashboard_layout TEXT,
    metrics_to_display TEXT,
    custom_rooms TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

## Step 3: Migrate Existing Users to Departments

### Option A: Assign All Users to Existing Department

If you have users that should all belong to one department:

```sql
-- Assuming you have only Computer Science coordinators
UPDATE coordinators SET department = 'computerScience' WHERE department IS NULL;

-- Assuming you have only Computer Science class reps
UPDATE class_representatives SET department = 'computerScience' WHERE department IS NULL;

-- Assuming you have only Computer Science admins
UPDATE admins SET department = 'computerScience' WHERE department IS NULL;
```

### Option B: Intelligent Assignment Based on Email Domain

```sql
-- Assign based on email domain
UPDATE coordinators SET department = 'computerScience' 
WHERE email LIKE '%cse%' OR email LIKE '%cs%';

UPDATE coordinators SET department = 'electrical' 
WHERE email LIKE '%electrical%' OR email LIKE '%eee%';

-- ... repeat for other departments
```

### Option C: Manual CSV Import

1. Export users to CSV
2. Add department column
3. Fill in departments
4. Import back to database

## Step 4: Assign Rooms to Users (Optional but Recommended)

```bash
# Using the new API
curl -X POST http://localhost:5000/api/department/coordinator/CCSE001/assign-rooms \
  -H "Content-Type: application/json" \
  -d '{
    "room_ids": ["CSL-101", "CSL-102", "CSL-103", "CS-Lab-1"]
  }'

# For class representatives
curl -X POST http://localhost:5000/api/department/class-rep/ajith04/assign-rooms \
  -H "Content-Type: application/json" \
  -d '{
    "room_ids": ["Class-101"]
  }'
```

### Or via Python Script:

```python
import json
import requests

BASE_URL = "http://localhost:5000"

# Coordinators
coordinators = [
    ("CCSE001", ["CSL-101", "CSL-102", "CSL-103", "CS-Lab-1", "Server-Room"]),
    ("CELE001", ["ELE-101", "ELE-102", "Power-Room"]),
    ("CMECH01", ["MECH-101", "MECH-102", "Workshop"]),
]

for coord_id, rooms in coordinators:
    response = requests.post(
        f"{BASE_URL}/api/department/coordinator/{coord_id}/assign-rooms",
        json={"room_ids": rooms}
    )
    print(f"Assigned rooms to {coord_id}: {response.status_code}")

# Class Representatives
class_reps = [
    ("ajith04", ["Class-101"]),
    ("student_user", ["Class-102"]),
]

for username, rooms in class_reps:
    response = requests.post(
        f"{BASE_URL}/api/department/class-rep/{username}/assign-rooms",
        json={"room_ids": rooms}
    )
    print(f"Assigned rooms to {username}: {response.status_code}")
```

## Step 5: Create Department Configurations

Initialize all departments with their configurations:

```python
# Script to initialize departments
import requests
import json

BASE_URL = "http://localhost:5000"

departments = [
    {
        "department": "computerScience",
        "display_name": "Computer Science",
        "color_hex": "#2196F3",
        "icon_name": "computer",
        "enabled_features": [
            "view_all_data", "manage_thresholds", "view_trends",
            "generate_reports", "manage_rooms", "export_data"
        ],
        "metrics_to_display": [
            "total_consumption", "peak_load", "avg_load", "cooling_efficiency"
        ],
        "custom_rooms": ["CSL-101", "CSL-102", "CSL-103", "CS-Lab-1", "CS-Lab-2", "Server-Room"]
    },
    {
        "department": "electrical",
        "display_name": "Electrical",
        "color_hex": "#FF9800",
        "icon_name": "electric_bolt",
        "enabled_features": [
            "view_all_data", "manage_thresholds", "view_trends",
            "generate_reports", "manage_rooms", "export_data"
        ],
        "metrics_to_display": [
            "total_consumption", "peak_load", "avg_load", "power_factor"
        ],
        "custom_rooms": ["ELE-101", "ELE-102", "ELE-Lab-1", "Power-Room"]
    },
    # ... add other departments
]

for dept in departments:
    response = requests.post(
        f"{BASE_URL}/api/department/create",
        json=dept
    )
    print(f"Created department {dept['department']}: {response.status_code}")
```

Or run SQL directly:

```sql
INSERT INTO department_customization (
    department, display_name, color_hex, icon_name,
    enabled_features, metrics_to_display, custom_rooms
) VALUES (
    'computerScience', 'Computer Science', '#2196F3', 'computer',
    '["view_all_data", "manage_thresholds", "view_trends", "generate_reports", "manage_rooms", "export_data"]',
    '["total_consumption", "peak_load", "avg_load", "cooling_efficiency"]',
    '["CSL-101", "CSL-102", "CSL-103", "CS-Lab-1", "CS-Lab-2", "Server-Room"]'
),
(
    'electrical', 'Electrical', '#FF9800', 'electric_bolt',
    '["view_all_data", "manage_thresholds", "view_trends", "generate_reports", "manage_rooms", "export_data"]',
    '["total_consumption", "peak_load", "avg_load", "power_factor"]',
    '["ELE-101", "ELE-102", "ELE-Lab-1", "Power-Room"]'
);
```

## Step 6: Update Backend Code

### In `app_main.py` or similar:

```python
# Add these imports
from department_api import init_department_api

# In your app initialization:
init_department_api(app, engine, metadata)
```

## Step 7: Update Frontend Code

### Update Login Pages:

```dart
// OLD CODE
void _login() async {
  final response = await http.post(...);
  // ...
}

// NEW CODE
void _login() async {
  final authService = DepartmentAuthService();
  final result = await authService.loginCoordinator(
    coordinatorId: _coordinatorIdController.text,
    password: _passwordController.text,
  );
  
  if (result.success && result.user != null) {
    Navigator.pushReplacementNamed(
      context,
      '/coordinator_dashboard',
      arguments: result.user, // NEW: Pass user with department
    );
  }
}
```

### Update Dashboard Pages:

```dart
// OLD CODE
class CoordinatorDashboardPage extends StatefulWidget {
  const CoordinatorDashboardPage({super.key});
  @override
  State<CoordinatorDashboardPage> createState() => ...
}

// NEW CODE
class CoordinatorDashboardPage extends StatefulWidget {
  final EnhancedUser user;
  
  const CoordinatorDashboardPage({
    super.key,
    required this.user,
  });
  @override
  State<CoordinatorDashboardPage> createState() => ...
}

// In build method:
@override
Widget build(BuildContext context) {
  return DepartmentDashboard(
    user: widget.user,
    contentBuilder: (context) {
      // Your existing dashboard content
      return YourDashboardContent();
    },
  );
}
```

### Update Route Handlers:

```dart
// In MaterialApp routes:
routes: {
  '/coordinator_dashboard': (context) {
    final user = ModalRoute.of(context)?.settings.arguments as EnhancedUser?;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Error: User not found')),
      );
    }
    return CoordinatorDashboardPage(user: user);
  },
}
```

## Step 8: Test the Migration

### Unit Tests:

```dart
void testMigration() async {
  final authService = DepartmentAuthService();
  await authService.initialize();
  
  // Test coordinator login
  var result = await authService.loginCoordinator(
    coordinatorId: 'CCSE001',
    password: 'Coord@123',
  );
  assert(result.success);
  assert(result.user?.department == Department.computerScience);
  
  // Test feature access
  var canManageThresholds = result.user!.canAccessFeature('manage_thresholds');
  assert(canManageThresholds);
  
  // Test room access
  var rooms = result.user!.getAccessibleRooms(['CSL-101', 'CSL-102', 'ELE-101']);
  assert(rooms.contains('CSL-101'));
  assert(!rooms.contains('ELE-101'));
}
```

### Integration Tests:

```dart
void testLoginFlow() async {
  // 1. Launch app
  await tester.pumpWidget(const MyApp());
  
  // 2. Navigate to login
  await tester.tap(find.text('Coordinator Login'));
  await tester.pumpAndSettle();
  
  // 3. Enter credentials
  await tester.enterText(find.byType(TextField).at(0), 'CCSE001');
  await tester.enterText(find.byType(TextField).at(1), 'Coord@123');
  
  // 4. Login
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
  
  // 5. Verify department theme applied
  expect(find.byType(DepartmentDashboard), findsOneWidget);
  
  // 6. Verify department-specific widgets
  expect(find.byType(DepartmentCard), findsWidgets);
}
```

### Manual Testing Checklist:

- [ ] Coordinator from CS can login
- [ ] CS coordinator sees CS-specific rooms
- [ ] CS coordinator sees CS-specific features
- [ ] CS coordinator dashboard is blue
- [ ] CS coordinator menu items are CS-specific
- [ ] CS coordinator can't see ELE rooms
- [ ] Admin can see all departments
- [ ] Class rep sees their assigned classroom
- [ ] Logout works properly
- [ ] Re-login works properly

## Step 9: Rollback Plan

If migration fails, you have two options:

### Option 1: Quick Rollback
```bash
# Restore from backup
psql energia < energia_backup_20240130_120000.sql
```

### Option 2: Partial Rollback
```sql
-- If new columns cause issues, you can drop them
ALTER TABLE coordinators DROP COLUMN assigned_rooms;
ALTER TABLE coordinators DROP COLUMN is_active;
ALTER TABLE coordinators DROP COLUMN last_login;
ALTER TABLE coordinators DROP COLUMN updated_at;

-- And restore from backup views
```

## Step 10: Post-Migration

### Verification:

```bash
# Check all coordinators have department
SELECT COUNT(*) FROM coordinators WHERE department IS NULL;
# Should return 0

# Check department customization is populated
SELECT COUNT(*) FROM department_customization;
# Should return >= 6 (one per department)

# Check rooms are assigned
SELECT COUNT(*) FROM rooms WHERE department IS NOT NULL;
# Should return > 0
```

### Monitoring:

1. Watch error logs for first 24 hours
2. Monitor performance (new queries)
3. Gather user feedback
4. Track login success rate

### Optimization (Optional):

```sql
-- Create indexes for better performance
CREATE INDEX idx_coordinators_department ON coordinators(department);
CREATE INDEX idx_class_reps_department ON class_representatives(department);
CREATE INDEX idx_rooms_department ON rooms(department);
CREATE INDEX idx_dept_customization_dept ON department_customization(department);
```

## Troubleshooting

### Issue: Users can't login after migration

**Cause:** Password hashes may not be compatible
**Solution:** Re-seed users with new passwords

```sql
-- Re-seed default users
DELETE FROM coordinators WHERE coordinator_id LIKE 'C%';
-- Then run db_init.py again
```

### Issue: Department shows as NULL

**Cause:** Users not assigned to department
**Solution:** Run step 3 again

```sql
UPDATE coordinators SET department = 'computerScience' 
WHERE department IS NULL;
```

### Issue: Wrong theme colors

**Cause:** color_hex not in database
**Solution:** Re-create department configurations

```bash
python scripts/init_departments.py
```

### Issue: Rooms not accessible

**Cause:** assigned_rooms JSON format wrong
**Solution:** Verify JSON format and re-assign

```python
# Correct format:
["CSL-101", "CSL-102", "CSL-103"]

# Not:
[{"id": "CSL-101"}]
```

## Performance Impact

### Expected:
- Slight increase in login time (1-2ms)
- Additional queries for customization
- Negligible dashboard load time increase

### Optimization:
- Customization service caches results
- Database indexes on department columns
- Consider Redis caching for department configs

## Timeline

| Step | Duration | Notes |
|------|----------|-------|
| Backup | 10 min | Critical - don't skip |
| Database Migration | 5 min | Run db_init.py |
| User Department Assignment | 15 min | Could be automated |
| Room Assignments | 10 min | Optional but recommended |
| Backend Update | 10 min | Import department_api.py |
| Frontend Update | 30 min | Update login & dashboard pages |
| Testing | 1 hour | Comprehensive testing |
| Deployment | 15 min | Deploy updates |
| Monitoring | Ongoing | Watch for issues |

**Total Time:** ~2 hours

## Support

If you encounter issues during migration:

1. Check [DEPARTMENT_CUSTOMIZATION_GUIDE.md](DEPARTMENT_CUSTOMIZATION_GUIDE.md) for details
2. Review [Troubleshooting](DEPARTMENT_CUSTOMIZATION_QUICK_REFERENCE.md#-debugging-tips) section
3. Check application logs for errors
4. Verify database schema matches expected structure
5. Review API responses for data format issues

---

**Migration Guide v1.0**
**Created:** 2024-01-30
