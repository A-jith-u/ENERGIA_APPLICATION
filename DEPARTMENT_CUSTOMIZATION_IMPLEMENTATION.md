# Department-Based Role Customization - Implementation Summary

## What Has Been Created

### 1. **Core Models & Services**

#### `lib/models/user_role_model.dart`
- **EnhancedUser** class with department support
- Role enumeration (Student, Class Representative, Technical Coordinator, Admin, Super Admin)
- Department enumeration (Computer Science, Electrical, Electronics, Mechanical, ITT, Civil Engineering, Admin)
- Built-in department colors, icons, and display names
- Permission checking methods
- JSON serialization for API communication

#### `lib/services/department_customization_service.dart`
- Central service for all department customizations
- Department-specific themes
- Role-based feature availability
- Menu item generation per department
- Metric customization per role/department
- Color scheme management
- Feature access control

#### `lib/services/department_auth_service.dart`
- Department-aware authentication
- Coordinator login with department assignment
- Class representative login with department
- Admin login with role levels (superadmin/department_admin)
- Session management
- Feature access validation
- Room accessibility checks

### 2. **UI Components**

#### `lib/widgets/department_dashboard_widget.dart`
- **DepartmentDashboard** - Main container widget with customized layout
- **DepartmentCard** - Themed card component
- **DepartmentMetric** - Metric display with department branding
- Sidebar for desktop views
- Department-themed app bars
- Dynamic menu rendering

### 3. **Backend Integration**

#### `backend/department_api.py`
Complete REST API for department management:
- Department CRUD operations
- User-department assignments
- Room assignments per user/department
- Coordinator and class rep management
- Department listing and configuration

#### Database Enhancements:
- Enhanced **coordinators** table with department, assigned_rooms, last_login
- Enhanced **class_representatives** table with section, assigned_rooms, last_login
- Enhanced **admins** table with department, role_level
- Enhanced **rooms** table with department assignment
- New **department_customization** table for UI configurations

### 4. **Documentation**

#### `DEPARTMENT_CUSTOMIZATION_GUIDE.md`
Comprehensive guide including:
- Architecture overview
- Database schema documentation
- API endpoint reference
- Implementation step-by-step guide
- Role-based features breakdown
- Customization examples
- Testing guide
- Troubleshooting

### 5. **Examples**

#### `lib/examples/department_customization_examples.dart`
Practical examples including:
- Enhanced coordinator login implementation
- Enhanced coordinator dashboard
- Department-specific menus
- Feature access checks
- Route configuration

---

## Key Features

### ✅ Multi-Department Support
Each department has:
- Unique color scheme
- Unique icon
- Custom dashboard layout
- Department-specific features
- Assigned rooms
- Department-specific coordinators and class representatives

### ✅ Role-Based Access Control
- **Technical Coordinator**: Department-wide energy monitoring and management
- **Class Representative**: Classroom-specific monitoring
- **Department Admin**: User management within department
- **Super Admin**: Full system access
- **Student**: Basic access

### ✅ Customizable UI Per Department
- Department-themed colors
- Department-themed icons
- Department-specific menu items
- Department-specific features
- Department-specific metrics
- Department-specific rooms

### ✅ Database-Driven Customization
- Department configurations stored in database
- Easy to add new departments
- Easy to modify features per department
- Flexible JSON storage for complex configurations

### ✅ Comprehensive API
- Full CRUD operations for departments
- User management endpoints
- Room assignment endpoints
- Department statistics endpoints

---

## How It Works

### User Flow:

1. **Login**
   ```
   User enters credentials → DepartmentAuthService authenticates
   → Database returns user with department assignment
   → User object created with department and role
   → Navigate to customized dashboard
   ```

2. **Dashboard Customization**
   ```
   User dashboard initializes → Fetch department configuration
   → Generate features based on role + department
   → Generate menu items based on department
   → Apply department theme colors
   → Render customized dashboard
   ```

3. **Feature Access**
   ```
   User attempts to access feature → Check user.canAccessFeature()
   → Check department has feature enabled
   → Check user's role allows access
   → Show or hide feature accordingly
   ```

### Data Flow:

```
EnhancedUser (contains department + role)
    ↓
DepartmentAuthService (validates + persists)
    ↓
DepartmentCustomizationService (determines UI/features)
    ↓
DepartmentDashboard Widget (renders customized view)
    ↓
Department-specific UI components
```

---

## Database Changes Summary

### New Columns Added:
| Table | Column | Type | Purpose |
|-------|--------|------|---------|
| coordinators | assigned_rooms | JSON | Rooms coordinator can access |
| coordinators | is_active | INT | User status |
| coordinators | last_login | DateTime | Track logins |
| coordinators | updated_at | DateTime | Track updates |
| class_representatives | section | String | Class section (A, B, C) |
| class_representatives | assigned_rooms | JSON | Classrooms assigned |
| class_representatives | is_active | INT | User status |
| class_representatives | last_login | DateTime | Track logins |
| class_representatives | updated_at | DateTime | Track updates |
| admins | department | String | Department managed |
| admins | role_level | String | superadmin or department_admin |
| admins | is_active | INT | User status |
| admins | last_login | DateTime | Track logins |
| admins | updated_at | DateTime | Track updates |
| rooms | department | String | Department that owns room |

### New Tables:
| Table | Purpose |
|-------|---------|
| department_customization | Stores UI/feature configs per department |

---

## API Endpoints Added

### Department Management:
- `GET /api/department/list` - Get all departments
- `GET /api/department/get/<department>` - Get department config
- `POST /api/department/create` - Create new department
- `PUT /api/department/update/<department>` - Update department

### User Management:
- `POST /api/department/coordinator/<id>/assign-rooms` - Assign rooms to coordinator
- `POST /api/department/class-rep/<username>/assign-rooms` - Assign rooms to class rep
- `GET /api/department/get-coordinator-rooms/<id>` - Get coordinator's rooms
- `GET /api/department/get-class-rep-rooms/<username>` - Get class rep's rooms
- `GET /api/department/rooms/<department>` - Get all department rooms
- `GET /api/department/coordinators/<department>` - Get department coordinators
- `GET /api/department/class-representatives/<department>` - Get department class reps

---

## Integration Steps

### Step 1: Initialize Services
```dart
final authService = DepartmentAuthService();
await authService.initialize();
final customizationService = DepartmentCustomizationService();
```

### Step 2: Update Login Pages
- Replace login logic with `DepartmentAuthService.login*()`
- Pass resulting `EnhancedUser` to dashboard

### Step 3: Wrap Dashboards
- Use `DepartmentDashboard` widget as wrapper
- Pass user and content builder

### Step 4: Use Themed Widgets
- Replace plain cards with `DepartmentCard`
- Replace plain metrics with `DepartmentMetric`
- Use customization service for menus

### Step 5: Register Backend Routes
- Import `department_api.py`
- Call `init_department_api(app, engine, metadata)`

---

## Environment Setup

### Backend Requirements:
```python
# In requirements.txt
Flask
Flask-CORS
SQLAlchemy
passlib
```

### Frontend Requirements:
```yaml
# In pubspec.yaml
dependencies:
  shared_preferences: ^2.5.3
  http: ^1.1.0
  flutter:
    sdk: flutter
```

---

## Configuration Example

### Setting Up a New Department:

```python
POST /api/department/create
{
  "department": "computerScience",
  "display_name": "Computer Science",
  "color_hex": "#2196F3",
  "icon_name": "computer",
  "enabled_features": [
    "view_all_data",
    "manage_thresholds",
    "view_trends",
    "generate_reports",
    "manage_rooms",
    "export_data"
  ],
  "metrics_to_display": [
    "total_consumption",
    "peak_load",
    "avg_load",
    "cooling_efficiency"
  ],
  "custom_rooms": [
    "CSL-101", "CSL-102", "CSL-103",
    "CS-Lab-1", "CS-Lab-2", "Server-Room"
  ]
}
```

---

## Current Limitations & Future Enhancements

### Limitations:
1. ⚠️ Departments are enum-based (limited to predefined set)
2. ⚠️ Features are hard-coded in service
3. ⚠️ Colors are not dynamically updateable from UI

### Future Enhancements:
1. 🔄 Make departments fully dynamic (database-driven enum)
2. 🔄 Create admin UI for managing departments
3. 🔄 Create admin UI for feature toggling per department
4. 🔄 Add advanced permission system
5. 🔄 Add department hierarchy (parent/child departments)
6. 🔄 Add cross-department reporting
7. 🔄 Add department analytics
8. 🔄 Add department budgeting features

---

## Testing Checklist

- [ ] Login with different coordinator credentials (different departments)
- [ ] Verify dashboard theme changes per department
- [ ] Verify menu items are department-specific
- [ ] Verify features are shown/hidden based on role
- [ ] Test room assignments per coordinator
- [ ] Test room assignments per class rep
- [ ] Verify API endpoints return correct data
- [ ] Test cross-department access restrictions
- [ ] Test feature access control
- [ ] Test logout and session persistence

---

## Support & Troubleshooting

### Common Issues:

**Issue: Department not showing in UI**
- Solution: Check if department is in `Department` enum
- Solution: Verify database has department in customization table

**Issue: Wrong colors/icons**
- Solution: Verify maps in `user_role_model.dart`
- Solution: Check database customization config

**Issue: Features not visible**
- Solution: Verify in `getDashboardFeatures()` method
- Solution: Check database enabled_features JSON

**Issue: Rooms not assigned**
- Solution: Verify API call to assign rooms
- Solution: Check room IDs match database
- Solution: Verify department match

---

## Files Created/Modified

### New Files:
```
lib/models/user_role_model.dart
lib/services/department_customization_service.dart
lib/services/department_auth_service.dart
lib/widgets/department_dashboard_widget.dart
lib/examples/department_customization_examples.dart
backend/department_api.py
DEPARTMENT_CUSTOMIZATION_GUIDE.md
```

### Modified Files:
```
backend/db_init.py (enhanced with new tables/columns)
```

---

## Next Actions

1. **Register the backend API**
   - Import in `app_main.py`
   - Initialize with database

2. **Update existing login pages**
   - Use `EnhancedCoordinatorLoginPage` as reference
   - Update navigation to pass user object

3. **Wrap existing dashboards**
   - Use `EnhancedCoordinatorDashboard` as reference
   - Apply to all role dashboards

4. **Test comprehensively**
   - Run through testing checklist
   - Get user feedback

5. **Deploy**
   - Backup production database
   - Run migrations
   - Deploy updated app and backend

---

## Quick Start Commands

```bash
# Backend: Initialize database with new schema
python -m backend.db_init

# Backend: Run with new department API
python -m backend.start_server

# Flutter: Run example with new system
flutter run -d <device>

# Test login endpoints
curl http://localhost:5000/api/department/list
curl http://localhost:5000/api/department/get/computerScience
```

---

For detailed implementation, see **DEPARTMENT_CUSTOMIZATION_GUIDE.md**
