# Department-Based Customization - Visual Diagrams

## System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                          User Login                               │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐ │
│  │ Coordinator     │  │ Class Rep       │  │ Admin            │ │
│  │ Login           │  │ Login           │  │ Login            │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬─────────┘ │
└───────────┼──────────────────────┼──────────────────┼────────────┘
            │                      │                  │
            ▼                      ▼                  ▼
┌──────────────────────────────────────────────────────────────────┐
│              DepartmentAuthService (Login Handler)               │
│                                                                   │
│  1. Validate credentials                                         │
│  2. Fetch user from database                                     │
│  3. Include department assignment                                │
│  4. Create EnhancedUser object                                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│              EnhancedUser Object Created                          │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ id: '1'                                                  │   │
│  │ username: 'coord1'                                       │   │
│  │ name: 'John Coordinator'                                 │   │
│  │ role: UserRole.technicalCoordinator  ← Defines what     │   │
│  │ department: Department.computerScience ← Defines where  │   │
│  │ createdAt: DateTime.now()                                │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│        DepartmentCustomizationService (Customization Engine)     │
│                                                                   │
│  Based on (Role + Department), determine:                        │
│                                                                   │
│  1️⃣  getDepartmentTheme()                                        │
│      └─ Color palette, font, styling                             │
│                                                                   │
│  2️⃣  getDashboardFeatures()                                      │
│      └─ Which features to show/hide                              │
│                                                                   │
│  3️⃣  getDepartmentMenuItems()                                    │
│      └─ Which menu items to display                              │
│                                                                   │
│  4️⃣  getMetricsForRole()                                         │
│      └─ Which KPIs to display                                    │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│              DepartmentDashboard (Main Widget)                   │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ AppBar (Department Color Theme)                            │ │
│  │  🔵 Computer Science | 🟠 Electrical | etc                │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Sidebar (Department-Specific Menu Items)                  │ │
│  │  • Lab Equipment Monitoring (CS only)                      │ │
│  │  • Power Distribution (ELE only)                          │ │
│  │  • HVAC Systems (MECH only)                               │ │
│  │  • Generic Features (All)                                  │ │
│  └────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Content Area                                               │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │ DepartmentCard (Themed)                              │ │ │
│  │  │ Energy Overview - With dept theme colors             │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │ DepartmentMetric Grid (Customized)                   │ │ │
│  │  │ • Total Consumption (all depts)                      │ │ │
│  │  │ • Cooling Efficiency (CS only)                       │ │ │
│  │  │ • Power Factor (ELE only)                            │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │ Department-Specific Features                         │ │ │
│  │  │ • Lab Equipment (CS)                                 │ │ │
│  │  │ • Power Distribution (ELE)                           │ │ │
│  │  │ • HVAC (MECH)                                        │ │ │
│  │  └──────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
USER INITIATES LOGIN
        │
        ▼
┌────────────────────────┐
│ Coordinator/ClassRep   │
│ Login Page             │
│ - Enter ID             │
│ - Enter Password       │
└────────────┬───────────┘
             │
             ▼
┌────────────────────────────────────┐
│ DepartmentAuthService              │
│ loginCoordinator() / loginClassRep()│
└────────────┬──────────────────────┘
             │
             ▼
┌───────────────────────────────────────────────┐
│ Database Query                                 │
│                                               │
│ SELECT id, name, email,                       │
│        coordinator_id, department,            │
│        assigned_rooms                         │
│ FROM coordinators                             │
│ WHERE coordinator_id = ? AND                  │
│       password_hash = hash(?)                 │
└────────────┬──────────────────────────────────┘
             │
             ├─── NO MATCH ──────┐
             │                   │
             ▼                   ▼
    ┌────────────────┐   ┌─────────────────┐
    │ User Found ✅  │   │ Login Failed ❌ │
    └────────┬───────┘   └─────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ Create EnhancedUser Object:         │
│                                     │
│ EnhancedUser(                       │
│   id: '1',                          │
│   username: 'CCSE001',              │
│   role: technical_coordinator,      │
│   department: computerScience,      │
│   assignedRooms: ['CSL-101', ...],  │
│   ... other fields                  │
│ )                                   │
└────────────┬────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│ Save to Shared Preferences               │
│                                          │
│ _prefs.setString('current_user',        │
│   jsonEncode(user.toJson()))            │
└────────────┬─────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│ Navigate to Dashboard                    │
│                                          │
│ Navigator.pushReplacementNamed(          │
│   context,                              │
│   '/coordinator_dashboard',             │
│   arguments: user ◄── Pass user object  │
│ )                                        │
└────────────┬─────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│ Dashboard Widget Created                 │
│ with EnhancedUser object                 │
└────────────┬─────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│ Query Customization Engine:              │
│                                          │
│ customizationService.getDashboard       │
│   Features(user.role, user.department)  │
└────────────┬─────────────────────────────┘
             │
             ├─ Role: technicalCoordinator │
             └─ Dept: computerScience     │
                       │
                       ▼
             ┌──────────────────────┐
             │ Features:            │
             │ ✅ view_all_data     │
             │ ✅ manage_thresholds │
             │ ✅ lab_equipment     │
             │ ❌ manage_users      │
             └──────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────┐
│ Query Theme Customization:               │
│                                          │
│ customizationService.                   │
│   getDepartmentTheme(computerScience)   │
└────────────┬─────────────────────────────┘
             │
             ├─ Color: Blue #2196F3       │
             ├─ Icon: computer            │
             └─ Theme: Material3          │
                       │
                       ▼
┌──────────────────────────────────────────┐
│ Render UI:                               │
│                                          │
│ 1. Apply Blue theme                      │
│ 2. Show CS-specific menu items           │
│ 3. Display enabled features              │
│ 4. Show CS metrics (cooling efficiency)  │
│ 5. Filter rooms to CS rooms              │
└──────────────────────────────────────────┘
```

---

## Permission Matrix by Role & Department

```
┌──────────────────┬─────────┬─────────┬──────────┬──────────┬──────────┐
│ Feature          │ Student │ ClassRep│ Coord-CS │ Admin-ELE│ Super    │
├──────────────────┼─────────┼─────────┼──────────┼──────────┼──────────┤
│ view_all_data    │    ❌   │   ❌    │    ✅    │    ✅    │    ✅    │
│ view_classroom   │    ✅   │   ✅    │    ✅    │    ✅    │    ✅    │
│ manage_threshold │    ❌   │   ❌    │    ✅    │    ✅    │    ✅    │
│ manage_users     │    ❌   │   ❌    │    ❌    │    ✅    │    ✅    │
│ lab_equipment    │    ❌   │   ❌    │    ✅    │    ❌    │    ✅    │
│ export_data      │    ❌   │   ❌    │    ✅    │    ✅    │    ✅    │
│ system_settings  │    ❌   │   ❌    │    ❌    │    ❌    │    ✅    │
└──────────────────┴─────────┴─────────┴──────────┴──────────┴──────────┘

Legend:
✅ = Has access
❌ = No access
Coord-CS = Coordinator in Computer Science Dept
Admin-ELE = Admin in Electrical Dept
Super = Super Admin (all access)
```

---

## Database Schema Relationships

```
┌──────────────────────────┐
│  coordinators            │
│  ┌────────────────────┐  │
│  │ id (PK)            │  │
│  │ coordinator_id     │  │
│  │ email              │  │
│  │ name               │  │
│  │ department (FK) ───┼──┼──┐
│  │ assigned_rooms     │  │  │
│  │ is_active          │  │  │
│  │ last_login         │  │  │
│  └────────────────────┘  │  │
└──────────────────────────┘  │
                              │
    ┌─────────────────────────┼─────────────────────┐
    │                         │                     │
    │                         ▼                     │
    │            ┌─────────────────────────────────┐
    │            │ department_customization        │
    │            │ ┌─────────────────────────────┐ │
    │            │ │ id (PK)                     │ │
    │            │ │ department (FK, UNIQUE)     │ │
    │            │ │ display_name                │ │
    │            │ │ color_hex                   │ │
    │            │ │ icon_name                   │ │
    │            │ │ enabled_features (JSON)     │ │
    │            │ │ dashboard_layout (JSON)     │ │
    │            │ │ metrics_to_display (JSON)   │ │
    │            │ │ custom_rooms (JSON)         │ │
    │            │ └─────────────────────────────┘ │
    │            └─────────────────────────────────┘
    │                         ▲
    │                         │
    ▼                         │
┌──────────────────────────┐  │
│  class_representatives   │  │
│  ┌────────────────────┐  │  │
│  │ id (PK)            │  │  │
│  │ username           │  │  │
│  │ ktu_id             │  │  │
│  │ email              │  │  │
│  │ name               │  │  │
│  │ department (FK) ───┼──┼──┘
│  │ assigned_rooms     │  │
│  │ is_active          │  │
│  │ last_login         │  │
│  └────────────────────┘  │
└──────────────────────────┘

    ┌──────────────────────────┐
    │  rooms                   │
    │  ┌────────────────────┐  │
    │  │ id (PK)            │  │
    │  │ room_id            │  │
    │  │ room_name          │  │
    │  │ floor_number       │  │
    │  │ department (FK) ───┼──┘
    │  │ threshold          │  │
    │  └────────────────────┘  │
    └──────────────────────────┘
```

---

## Department Color Palette

```
COMPUTER SCIENCE          ELECTRICAL
┌──────────────┐         ┌──────────────┐
│              │         │              │
│   🔵 BLUE    │         │   🟠 ORANGE  │
│   #2196F3    │         │   #FF9800    │
│              │         │              │
└──────────────┘         └──────────────┘

ELECTRONICS              MECHANICAL
┌──────────────┐         ┌──────────────┐
│              │         │              │
│   🔴 RED     │         │   🟢 GREEN   │
│   #F44336    │         │   #4CAF50    │
│              │         │              │
└──────────────┘         └──────────────┘

ITT                      CIVIL ENGINEERING
┌──────────────┐         ┌──────────────┐
│              │         │              │
│   🟣 PURPLE  │         │   🟤 BROWN   │
│   #9C27B0    │         │   #795548    │
│              │         │              │
└──────────────┘         └──────────────┘

ADMIN
┌──────────────┐
│              │
│   ⚫ GREY    │
│   #607D8B    │
│              │
└──────────────┘
```

---

## User Journey Flowchart

```
                        START
                         │
                         ▼
                   ┌─────────────┐
                   │ Open App    │
                   └──────┬──────┘
                          │
                          ▼
                   ┌─────────────────┐
                   │ Check Session   │
                   │ (Shared Prefs)  │
                   └────────┬────────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
            VALID       EXPIRED      INVALID
                │           │           │
                ▼           ▼           ▼
            ┌─────┐   ┌─────────┐  ┌─────────┐
            │Skip │   │Show     │  │Show     │
            │Auth │   │Login UI │  │Login UI │
            └──┬──┘   └────┬────┘  └────┬────┘
               │           │             │
               └─────────┬─┴─────────────┘
                         │
                         ▼
              ┌────────────────────────┐
              │ Enter Credentials      │
              │ - Coordinator ID/User  │
              │ - Password             │
              └────────────┬───────────┘
                          │
                          ▼
              ┌────────────────────────┐
              │ Click Login Button     │
              └────────────┬───────────┘
                          │
                          ▼
              ┌────────────────────────┐
              │ Authenticate           │
              │ (DepartmentAuthService)│
              └────────────┬───────────┘
                          │
                ┌─────────┼─────────┐
                │         │         │
           SUCCESS    FAILURE    ERROR
                │         │         │
                ▼         ▼         ▼
            ┌─────┐  ┌────┐  ┌─────────┐
            │Load │  │Show│  │Show     │
            │User │  │Err │  │Error    │
            │Data │  └────┘  │Dialog   │
            └──┬──┘          └────┬────┘
               │                  │
               ▼                  └──→ Retry Login
        ┌─────────────┐
        │Query Dept   │
        │Customization│
        └──────┬──────┘
               │
               ▼
        ┌─────────────────────────┐
        │Get Theme, Features,     │
        │Menu Items, Metrics      │
        └──────┬──────────────────┘
               │
               ▼
        ┌──────────────────────────┐
        │Navigate to Department   │
        │Customized Dashboard     │
        └──────┬───────────────────┘
               │
               ▼
        ┌──────────────────────────┐
        │Render Dashboard with:   │
        │ • Department Colors     │
        │ • Dept Menu Items       │
        │ • Role-Based Features   │
        │ • Dept Metrics          │
        └──────┬───────────────────┘
               │
               ▼
        ┌──────────────────────────┐
        │Dashboard Ready          │
        │User can interact        │
        └──────┬───────────────────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
    ┌────┐      ┌──────┐
    │Use │      │Logout│
    │App │      │ Exit │
    └────┘      └──────┘
```

---

## Component Hierarchy

```
MyApp (MaterialApp)
│
├── Role Selection Page
│   ├── Student Login
│   ├── Coordinator Login
│   └── Admin Login
│
└── Authentication
    │
    ├── DepartmentAuthService
    │   ├── loginCoordinator()
    │   ├── loginClassRepresentative()
    │   └── loginAdmin()
    │
    └── EnhancedUser Object Created
        │
        ├── Department Dashboard
        │   │
        │   ├── App Bar (Themed)
        │   ├── Sidebar (Dept Menu)
        │   │   ├── DepartmentMenuItem
        │   │   ├── DepartmentMenuItem
        │   │   └── ...
        │   │
        │   └── Content Area
        │       ├── DepartmentCard
        │       │   └── [Custom Content]
        │       │
        │       ├── Metrics Grid
        │       │   ├── DepartmentMetric
        │       │   ├── DepartmentMetric
        │       │   └── ...
        │       │
        │       └── Features List
        │           ├── FeatureCard
        │           ├── FeatureCard
        │           └── ...
        │
        └── Database (PostgreSQL)
            ├── coordinators
            ├── class_representatives
            ├── admins
            ├── rooms
            └── department_customization
```

---

## API Call Sequence Diagram

```
CLIENT                              SERVER

 │                                    │
 │───── POST /api/coordinator/login ─→│
 │  {                                 │
 │    coordinator_id: "CCSE001"       │
 │    password: "Coord@123"           │
 │  }                                 │
 │                                    │
 │                        ┌──────────┐│
 │                        │ Verify   ││
 │                        │ Creds    ││
 │                        │ in DB    ││
 │                        └──────────┘│
 │                                    │
 │                        ┌──────────┐│
 │                        │ Load     ││
 │                        │ Dept     ││
 │                        │ Config   ││
 │                        └──────────┘│
 │                                    │
 │←─ 200 OK ──────────────────────────│
 │  {                                 │
 │    id: 1                           │
 │    username: "CCSE001"             │
 │    department: "computerScience"   │
 │    role: "technicalCoordinator"    │
 │    token: "jwt_token_here"         │
 │  }                                 │
 │                                    │
 │───── GET /api/department/get/computerScience ─→│
 │                                    │
 │                        ┌──────────┐│
 │                        │ Fetch    ││
 │                        │ Dept     ││
 │                        │ Config   ││
 │                        └──────────┘│
 │                                    │
 │←─ 200 OK ──────────────────────────│
 │  {                                 │
 │    department: "computerScience"   │
 │    display_name: "Computer Science"│
 │    color_hex: "#2196F3"            │
 │    enabled_features: [...]         │
 │    metrics_to_display: [...]       │
 │  }                                 │
 │                                    │
 │───── GET /api/department/get-coordinator-rooms/CCSE001 ─→│
 │                                    │
 │                        ┌──────────┐│
 │                        │ Fetch    ││
 │                        │ Assigned ││
 │                        │ Rooms    ││
 │                        └──────────┘│
 │                                    │
 │←─ 200 OK ──────────────────────────│
 │  {                                 │
 │    assigned_rooms: [              │
 │      {room_id: "CSL-101", ...},   │
 │      {room_id: "CSL-102", ...},   │
 │      ...                           │
 │    ]                               │
 │  }                                 │
 │                                    │
 └── UI Rendered with Department Customization ──→│
    (Colors, Menu Items, Features, Metrics)
```

---

## State Management Flow

```
┌────────────────────────────────────┐
│  SharedPreferences (Local Storage) │
│                                    │
│  current_user (JSON)               │
│  ├─ id                             │
│  ├─ username                       │
│  ├─ role                           │
│  ├─ department ◄── KEY FIELD      │
│  ├─ assigned_rooms                 │
│  └─ ...                            │
│                                    │
│  auth_token                        │
│  user_department                   │
│  user_role                         │
└────────────────────────────────────┘
           │
           │ (on app restart)
           │
           ▼
┌────────────────────────────────────┐
│ DepartmentAuthService              │
│                                    │
│ restoreSession()                   │
│ ├─ Read current_user from prefs   │
│ ├─ Deserialize JSON               │
│ ├─ Create EnhancedUser object     │
│ └─ Return user (with department)  │
└────────────────────────────────────┘
           │
           │
           ▼
┌────────────────────────────────────┐
│ DepartmentCustomizationService     │
│                                    │
│ getDepartmentTheme(dept)           │
│ getDashboardFeatures(role, dept)   │
│ getDepartmentMenuItems(dept, role) │
│ getMetricsForRole(role, dept)      │
└────────────────────────────────────┘
           │
           │
           ▼
┌────────────────────────────────────┐
│ UI Rendering                       │
│                                    │
│ Theme Applied                      │
│ Features Displayed                 │
│ Menu Rendered                      │
│ Metrics Shown                      │
└────────────────────────────────────┘
```

---

**End of Visual Diagrams**
