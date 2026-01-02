# Quick Reference - Activity Logs & Validation

## What Was Implemented

### 1. Full Activity Logs Page ✓
- New dedicated page showing all user activities
- Click "Activity Logs" button in Admin Dashboard
- Filter by time range and status
- Shows user, action, timestamp, status, department

### 2. Email Validation ✓
- Checks RFC-compliant format
- Validates domain name
- Rejects disposable emails
- Shows clear error messages

### 3. Phone Validation ✓
- Checks 10-digit Indian phone numbers
- Validates first digit (6-9)
- Rejects sequential patterns
- Real-time validation

### 4. KTU ID Validation ✓
- Validates formats: `IDK22CS004`, `LIDK22CS070`, `TVE21CS001`, `TVM20EC045`
- Checks prefix, department, year, serial number
- Shows valid examples in error message
- Works for Class Representative role only

### 5. Full Name Validation ✓
- Minimum 3 characters
- Maximum 100 characters
- Requires first and last name
- Only letters, spaces, hyphens, dots, apostrophes

## How to Use

### View Activity Logs
1. Open Admin Dashboard
2. Scroll to "User Management" section
3. Click "Activity Logs" button
4. Use filters to narrow results
5. Click "Refresh" to reload

### Add New User (with Validation)
1. Click "Add New User" in Admin Dashboard
2. Enter **Full Name** (minimum 2 words)
   - ✓ "Rahul Krishnan"
   - ✓ "John Doe"
   - ✗ "John" (only one word)
   - ✗ "A" (too short)

3. Enter **Email** (valid institutional email)
   - ✓ rahul@geci.ac.in
   - ✓ john.doe@college.ac.in
   - ✗ invalid@tempmail.com (disposable)
   - ✗ notanemail (missing @)
   - ✗ test@ (missing domain)

4. Enter **Phone** (10-digit Indian number)
   - ✓ 9876543210
   - ✓ 8765432109
   - ✗ 1234567890 (doesn't start with 6-9)
   - ✗ 9876543210 (sequential) - actually valid
   - ✗ 987654321 (only 9 digits)

5. Select **Role**
   - Coordinator
   - Class Representative

6. If Class Representative, enter **KTU ID**
   - ✓ IDK22CS004
   - ✓ LIDK22CS070
   - ✓ TVE21CS001
   - ✓ TVM20EC045
   - ✗ ABC22CS004 (invalid prefix)
   - ✗ IDK99CS001 (invalid year)
   - ✗ IDK22XX001 (invalid department)

7. Click "Create User"

## Valid Input Examples

### KTU ID Patterns
| Prefix | Example | Valid |
|--------|---------|-------|
| IDK | IDK22CS004 | ✓ |
| LIDK | LIDK22CS070 | ✓ |
| TVE | TVE21CS001 | ✓ |
| TVM | TVM20EC045 | ✓ |

### Department Codes
| Code | Department |
|------|------------|
| CS | Computer Science |
| EC | Electronics |
| ME | Mechanical |
| EE | Electrical |
| CE | Civil |
| AD | Architecture/Design |
| IT | Information Technology |

### Email Formats
- ✓ firstname.lastname@institution.edu
- ✓ user+tag@domain.co.in
- ✓ name123@college.ac.in
- ✗ @nodomain.com (no username)
- ✗ nodomain@.com (no domain name)
- ✗ tempmail@tempmail.com (disposable)

### Phone Formats
- ✓ 9876543210 (standard)
- ✓ 8765432109 (different digit)
- ✓ 7654321098 (different digit)
- ✗ 1234567890 (starts with 1)
- ✗ 9999999999 (all same digit)
- ✗ 98765432 (only 8 digits)

## Activity Log Features

### Viewing
- **Time Range:** Last 24h, 7d, 30d, 90d
- **Status Filter:** All, Success, Failure, Warning
- **Auto-Refresh:** Every 10 seconds in dashboard
- **Manual Refresh:** Refresh button in logs page

### Information Shown
- User name who performed action
- Type of action (login, user creation, etc.)
- When it happened (relative time like "2h ago")
- Result status (success/failure/warning)
- Department (if applicable)
- IP address (in details)

### Color Coding
- 🟢 **Green** = Success
- 🔴 **Red** = Failure
- 🟠 **Orange** = Warning
- 🔵 **Blue** = Default

## Troubleshooting

### "Invalid email format"
- Make sure you have: username@domain.extension
- Example: john@example.com
- Not disposable: tempmail, guerrillamail, throwaway

### "Phone number must be 10 digits"
- Enter exactly 10 digits
- Must be Indian number (starts with 6-9)
- No spaces or special characters

### "Invalid KTU ID format"
- Use format: [PREFIX][2-digit year][2-letter dept][3-4 digit serial]
- Prefix: IDK, LIDK, TVE, or TVM
- Department: CS, EC, ME, EE, CE, AD, or IT
- Example: IDK22CS004

### Activity logs not loading
- Check backend is running
- Verify database connection
- Check API endpoint `/activity/logs`
- Try manual refresh button

## Files to Know

| File | Purpose |
|------|---------|
| `lib/activity_logs_page.dart` | Activity logs page |
| `lib/services/validators.dart` | Validation functions |
| `lib/admin_dashboard.dart` | Updated with validations |
| `lib/services/api.dart` | Activity logs API call |

## Related Documentation
- See `ACTIVITY_LOGGING_GUIDE.md` for detailed API docs
- See `ACTIVITY_LOGGING_QUICKSTART.md` for testing guide
- See `ACTIVITY_VALIDATION_IMPLEMENTATION.md` for full implementation details
