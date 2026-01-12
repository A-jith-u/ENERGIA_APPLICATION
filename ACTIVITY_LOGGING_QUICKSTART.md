# Activity Logging System - Quick Start

## Setup

### 1. Initialize Database

Run the database initialization to create the activity_logs table:

```bash
cd e:\Flutter\flutter_application_1\backend
python db_init.py
```

Output should include:
```
DB initialized and test users ensured
```

### 2. Start Backend Server

```bash
cd e:\Flutter\flutter_application_1\backend
python start_server.py
```

Or manually:
```bash
python -m uvicorn app_main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Run Flutter App

```bash
cd e:\Flutter\flutter_application_1
flutter run
```

## Testing Activity Logs

### Test 1: Login Activity

1. Open the app and go to Admin Login
2. Enter credentials:
   - Username: `admin`
   - Password: `admin123`
3. Click Login
4. Navigate to Admin Dashboard
5. Scroll down to "Live User Activity" section
6. You should see your login activity logged with:
   - Action: "Admin successfully logged in"
   - Time: Current time
   - Status: Success (green indicator)

### Test 2: View Full Activity Logs

Using curl to check all logged activities:

```bash
curl "http://localhost:8000/activity/logs?limit=10"
```

Expected response:
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "user_id": "1",
      "user_name": "System Administrator",
      "user_role": "admin",
      "action_type": "login",
      "action_description": "Admin successfully logged in",
      "timestamp": "2025-12-31T10:30:00"
    }
  ],
  "pagination": {
    "limit": 10,
    "offset": 0,
    "total": 1
  }
}
```

### Test 3: Failed Login Attempt

1. Go to Admin Login
2. Enter wrong password: `wrongpass`
3. Click Login
4. Check logs with:

```bash
curl "http://localhost:8000/activity/logs?status=failure"
```

Should show your failed attempt with:
- Status: "failure" (red indicator)
- Description: "Failed login attempt - invalid password"

### Test 4: Activity Summary

View activity statistics:

```bash
curl "http://localhost:8000/activity/logs/summary"
```

Response shows:
- Total activities logged
- Breakdown by action type (login, logout, etc.)
- Breakdown by user role (admin, coordinator, student)
- Breakdown by status (success, failure, warning)

### Test 5: User-Specific Activity

View logs for a specific user:

```bash
curl "http://localhost:8000/activity/logs/user/1"
```

Shows all activities for user ID "1" (the admin).

## Auto-Refresh Feature

The admin dashboard automatically refreshes activity logs every 10 seconds. You can see this by:

1. Logging in from another browser/window
2. Watching the "Live User Activity" section update automatically
3. New login will appear after ~10 seconds

## Integration Verification

### Verify API is Mounted

```bash
curl http://localhost:8000/activity/ping
```

Response:
```json
{"status": "pong", "service": "activity_logging"}
```

### Verify Database Table

```bash
cd e:\Flutter\flutter_application_1\backend
python check_schema.py
```

Should show `activity_logs` table in the output.

## Common Issues

### Issue: No logs appearing

**Solution:**
1. Ensure backend is running on port 8000
2. Run `python db_init.py` to create table
3. Check backend logs for errors
4. Verify .env file has correct DB_URL

### Issue: Frontend shows "No activity logs found"

**Solution:**
1. Perform an action (login) to generate a log
2. Wait 10 seconds for auto-refresh
3. Check browser console for API errors
4. Verify backend API is responding to `/activity/logs`

### Issue: Connection timeout

**Solution:**
1. Check backend is running: `curl http://localhost:8000/ping`
2. Verify network connectivity
3. Check if port 8000 is already in use
4. Restart backend server

## Next Steps

Once activity logging is working, you can:

1. **Add more log points** to other backend APIs (recommendation engine, report generation, etc.)
2. **Create activity logs page** - Full page view of all activities with advanced filtering
3. **Set up alerts** - Email notifications for critical activities
4. **Export logs** - CSV/PDF export functionality
5. **Analytics dashboard** - Charts showing activity trends

## API Reference Quick

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/activity/logs` | GET | List all activity logs |
| `/activity/logs/summary` | GET | Get summary statistics |
| `/activity/logs/user/{id}` | GET | Get logs for specific user |
| `/activity/log` | POST | Create new log entry |
| `/activity/logs/{id}` | DELETE | Delete log entry |

## Files Modified

**Backend:**
- ✅ `db_init.py` - Added activity_logs table
- ✅ `activity_log_api.py` - NEW: Activity logging API
- ✅ `activity_logger.py` - NEW: Logging utility
- ✅ `auth_api.py` - Added login logging
- ✅ `app_main.py` - Mounted activity_log_api

**Frontend:**
- ✅ `admin_dashboard.dart` - Added _ActivityLogWidget

## Summary

The activity logging system is now fully functional with:
- ✅ Database table for storing activities
- ✅ Backend API for logging and retrieving activities
- ✅ Login/logout activity tracking
- ✅ Real-time activity display in admin dashboard
- ✅ Advanced filtering and statistics
- ✅ Automatic refresh every 10 seconds
