# Activity Logging System - Implementation Guide

## Overview

A comprehensive activity logging system has been implemented to track all user actions throughout the ENERGIA platform. The system logs login/logout attempts, data submissions, report generation, and other critical actions with timestamps, user information, and status indicators.

## Database Schema

### activity_logs Table

```sql
CREATE TABLE activity_logs (
    id BIGINT PRIMARY KEY,
    user_id VARCHAR,           -- Username or user ID
    user_name VARCHAR,         -- Full name for display
    user_role VARCHAR,         -- admin, coordinator, student
    action_type VARCHAR,       -- login, logout, data_submission, etc.
    action_description VARCHAR,-- Detailed description
    resource_type VARCHAR,     -- sensor, report, recommendation, etc.
    resource_id VARCHAR,       -- ID of affected resource
    department VARCHAR,        -- Department involved
    ip_address VARCHAR,        -- Client IP address
    status VARCHAR,            -- success, failure, warning
    created_at TIMESTAMP,      -- Server creation time
    timestamp TIMESTAMP        -- Activity timestamp
);
```

## Backend Implementation

### 1. Activity Logger Utility (`activity_logger.py`)

Provides reusable functions for logging activities across the application:

```python
from activity_logger import log_activity

# Log an activity
log_activity(
    user_id="USER123",
    user_name="John Doe",
    user_role="admin",
    action_type="login",
    action_description="Admin successfully logged in from dashboard",
    status="success",
    ip_address="192.168.1.100"
)
```

**Functions:**
- `log_activity()` - Synchronous activity logging
- `log_activity_async()` - Non-blocking async wrapper

### 2. Activity Logging API (`activity_log_api.py`)

Mounted at `/activity/` prefix. Provides endpoints:

#### **POST /activity/log**
Log a single activity (used internally by backend modules)

```bash
curl -X POST http://localhost:8000/activity/log \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "admin1",
    "user_name": "System Admin",
    "user_role": "admin",
    "action_type": "login",
    "action_description": "Admin logged in successfully",
    "status": "success"
  }'
```

#### **GET /activity/logs**
Retrieve activity logs with filters and pagination

```bash
curl "http://localhost:8000/activity/logs?limit=20&offset=0&days=7&status=success"
```

**Query Parameters:**
- `limit` - Number of logs to return (default: 50)
- `offset` - Pagination offset (default: 0)
- `action_type` - Filter by action type
- `user_id` - Filter by user
- `user_role` - Filter by role
- `status` - Filter by status (success/failure/warning)
- `days` - Retrieve logs from last N days (default: 7)

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "user_id": "admin1",
      "user_name": "System Admin",
      "user_role": "admin",
      "action_type": "login",
      "action_description": "Admin successfully logged in",
      "resource_type": null,
      "resource_id": null,
      "department": null,
      "ip_address": "192.168.1.100",
      "status": "success",
      "timestamp": "2025-12-31T10:30:00"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 150
  }
}
```

#### **GET /activity/logs/summary**
Get activity summary (counts by action type, role, status)

```bash
curl "http://localhost:8000/activity/logs/summary?days=7"
```

**Response:**
```json
{
  "status": "success",
  "summary": {
    "total_activities": 245,
    "by_action_type": {
      "login": 87,
      "logout": 82,
      "data_submission": 45,
      "report_generation": 31
    },
    "by_user_role": {
      "student": 120,
      "coordinator": 85,
      "admin": 40
    },
    "by_status": {
      "success": 235,
      "failure": 8,
      "warning": 2
    },
    "period_days": 7
  }
}
```

#### **GET /activity/logs/user/{user_id}**
Get activity logs for a specific user

```bash
curl "http://localhost:8000/activity/logs/user/admin1?limit=20"
```

#### **DELETE /activity/logs/{log_id}**
Delete a specific log entry (admin only)

```bash
curl -X DELETE "http://localhost:8000/activity/logs/123"
```

### 3. Authentication API Integration (`auth_api.py`)

Login endpoint now logs authentication attempts:

```python
# Successful login
activity_logger.log_activity(
    user_id=str(u_id),
    user_name=name,
    user_role=role,
    action_type="login",
    action_description=f"{role.capitalize()} successfully logged in",
    status="success",
    department=dept,
    ip_address=client_ip,
)

# Failed login
activity_logger.log_activity(
    user_id=req.username,
    action_type="login",
    action_description="Failed login attempt - invalid password",
    status="failure",
    ip_address=client_ip,
)
```

## Frontend Implementation

### Activity Log Widget (`admin_dashboard.dart`)

The admin dashboard now displays real-time activity logs from the backend:

**Features:**
- **Live Updates** - Fetches logs every 10 seconds
- **Smart Formatting** - Shows relative times (e.g., "2 min ago")
- **Status Indicators** - Color-coded by action type and status
- **Smart Icons** - Different icons for different action types
- **Error Handling** - Gracefully handles network errors

**Widget Structure:**
```dart
class _ActivityLogWidget extends StatefulWidget {
  // Fetches from /activity/logs endpoint
  // Auto-refreshes every 10 seconds
  // Shows last 24 hours of activity
}
```

**Action Type Icons:**
- `login` → Icons.login
- `logout` → Icons.logout
- `data_submission` → Icons.assignment_turned_in
- `report_generation` → Icons.assessment
- `alert` / `warning` → Icons.warning

**Status Colors:**
- `success` → Green (#4CAF50)
- `failure` → Red (#F44336)
- `warning` → Orange (#FF9800)
- `default` → Blue (#2196F3)

## Supported Action Types

The system supports logging these action types:

| Action Type | Description | Example |
|---|---|---|
| `login` | User authentication | Admin logged in |
| `logout` | User session end | Coordinator logged out |
| `data_submission` | Sensor data submission | Energy reading submitted |
| `report_generation` | Report creation | Weekly report generated |
| `alert` | System alert triggered | High energy consumption alert |
| `warning` | Warning issued | Anomaly detected |
| `recommendation` | Recommendation created | Energy savings recommendation |
| `maintenance` | Maintenance action | System maintenance completed |
| `user_creation` | New user registered | Student registered |

## Integration Points

### How to Log Activities in Your Code

**In Backend APIs:**

```python
from activity_logger import log_activity

# When creating a sensor reading
log_activity(
    user_id="student123",
    user_name="John Doe",
    user_role="student",
    action_type="data_submission",
    action_description="Submitted energy reading for CS_LAB_1",
    resource_type="sensor",
    resource_id="CS_LAB_1",
    department="CSE",
    status="success"
)
```

**In Recommendation Engine:**

```python
from activity_logger import log_activity

# When generating recommendations
log_activity(
    user_id="system",
    user_name="AI Engine",
    user_role="admin",
    action_type="recommendation",
    action_description="Generated AI recommendations for ECE department",
    resource_type="recommendation",
    resource_id="rec_12345",
    department="ECE",
    status="success"
)
```

**In Report Generation:**

```python
from activity_logger import log_activity

# When generating reports
log_activity(
    user_id="coordinator1",
    user_name="Dr. Priya",
    user_role="coordinator",
    action_type="report_generation",
    action_description="Generated weekly energy consumption report",
    resource_type="report",
    resource_id="weekly_2025_52",
    department="CSE",
    status="success"
)
```

## Database Initialization

When you run the database initialization script, the `activity_logs` table is automatically created:

```bash
cd e:\Flutter\flutter_application_1\backend
python db_init.py
```

The table is created with proper indexes for fast querying by:
- `timestamp` (for time-range queries)
- `user_id` (for user-specific logs)
- `action_type` (for filtering by action)

## Monitoring and Analytics

### View Recent Activities
```bash
curl "http://localhost:8000/activity/logs?limit=50&days=1"
```

### Check User Activity
```bash
curl "http://localhost:8000/activity/logs/user/admin1"
```

### Get Activity Summary
```bash
curl "http://localhost:8000/activity/logs/summary?days=30"
```

## Security Considerations

1. **IP Tracking** - Client IP is logged for all activities
2. **Failed Attempts** - Login failures are tracked with status="failure"
3. **User Attribution** - All actions tied to specific users/roles
4. **Timestamp Audit** - UTC timestamps for accurate audit trails
5. **Status Indicators** - Success/failure/warning for risk assessment

## Performance Optimization

- **Index Strategy** - Timestamp and user_id columns indexed for fast queries
- **Auto-Refresh** - Frontend refreshes every 10 seconds (configurable)
- **Pagination** - Default limit of 50 logs per request
- **Time Window** - Default 7-day window reduces query size

## Troubleshooting

### No logs appearing in admin dashboard

1. Check backend is running: `curl http://localhost:8000/ping`
2. Check API endpoint: `curl http://localhost:8000/activity/logs`
3. Verify database has `activity_logs` table: 
   ```bash
   python check_schema.py
   ```
4. Check server logs for errors

### Activity logs not being created

1. Verify activity_logger import in your module
2. Check database connection in `.env`
3. Ensure `activity_logs` table exists
4. Check for exceptions in server console

## Future Enhancements

- [ ] Bulk export of activity logs (CSV/PDF)
- [ ] Advanced filtering and search
- [ ] Activity log archive/retention policies
- [ ] Email alerts for critical activities
- [ ] Real-time WebSocket updates for admin dashboard
- [ ] Activity log analytics dashboard
- [ ] Compliance reporting (GDPR, audit trails)
