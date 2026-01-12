# Activity Logs & User Validation - Implementation Summary

## Overview

Comprehensive activity logging and user input validation system has been implemented for the admin dashboard. Users can now view full activity logs and the admin user creation form has robust validation for email, phone, and KTU ID fields.

## Features Implemented

### 1. Full Activity Logs Page (`activity_logs_page.dart`)

**New dedicated page for viewing complete activity logs with:**

- **Real-time Activity History** - Shows all system activities with timestamps
- **Advanced Filtering**:
  - Last 24 hours, 7 days, 30 days, 90 days
  - Filter by status (Success, Failure, Warning)
- **Detailed Information**:
  - User name and action performed
  - Timestamp (relative: "2h ago" or exact date)
  - Status indicator with color coding
  - Department information
- **Visual Indicators**:
  - Color-coded status badges (green=success, red=failure, orange=warning)
  - Action-specific icons (login, logout, data submission, etc.)
  - User role information
- **Pagination** - Handles large volumes of logs efficiently
- **Refresh Button** - Manual refresh of logs
- **Empty State** - Friendly message when no logs found

**Access:** Click "Activity Logs" button in Admin Dashboard

### 2. User Input Validation Module (`services/validators.dart`)

Comprehensive validation functions for all user inputs:

#### **Email Validation** (`validateEmail()`)
- RFC-compliant email format checking
- Domain validation with dot requirement
- Rejects disposable email providers (tempmail, guerrillamail, etc.)
- Error messages:
  - "Email is required"
  - "Invalid email format (e.g., user@example.com)"
  - "Invalid email - must contain domain"
  - "Please use a valid institutional email"

```dart
String? error = validateEmail('invalid.email');
// Returns: "Invalid email format..."
```

#### **Phone Number Validation** (`validatePhone()`)
- Validates 10-digit Indian phone numbers
- Checks for sequential number patterns
- Validates first digit (must be 6-9 for Indian numbers)
- Error messages:
  - "Phone number is required"
  - "Phone number must be 10 digits"
  - "Invalid phone number" (all same digits)
  - "Phone number must start with 6-9"

```dart
String? error = validatePhone('9876543210');
// Returns: null (valid)

String? error = validatePhone('1234567890');
// Returns: "Phone number must start with 6-9"
```

#### **KTU ID Validation** (`validateKtuIdWithExamples()`)
- Validates KTU ID format with detailed examples
- Supports all prefix types:
  - `IDK` - Ideal Degree College
  - `LIDK` - LIDK prefix
  - `TVE` - TVE prefix
  - `TVM` - TVM prefix
- Validates department codes (CS, EC, ME, EE, CE, AD, IT)
- Checks year validity (2015 to current year + 1)
- Error messages with examples:
  - "KTU ID is required"
  - "KTU ID must start with IDK, LIDK, TVE, or TVM\nExamples: IDK22CS004, LIDK22CS070"
  - "Invalid KTU ID format\nExamples:\n• IDK22CS004\n• LIDK22CS070\n• TVE21CS001\n• TVM20EC045"

Valid KTU ID Examples:
- `IDK22CS004` ✓
- `LIDK22CS070` ✓
- `TVE21CS001` ✓
- `TVM20EC045` ✓
- `IDK22EC123` ✓

Invalid KTU ID Examples:
- `XYZ22CS001` ✗ (invalid prefix)
- `IDK99CS001` ✗ (invalid year)
- `IDK22XX001` ✗ (invalid department)
- `IDK22CS` ✗ (missing serial number)

#### **Full Name Validation** (`validateFullName()`)
- Requires at least 3 characters
- Maximum 100 characters
- Requires first and last name (space between)
- Only allows letters, spaces, hyphens, dots, apostrophes
- Error messages:
  - "Full name is required"
  - "Name must be at least 3 characters"
  - "Name is too long"
  - "Please enter first and last name"
  - "Name contains invalid characters"

#### **Batch Validation** (`validateUserForm()`)
- Validates all user fields at once
- Returns map of field errors
- Usage:
```dart
final errors = validateUserForm(
  name: _nameCtl.text,
  email: _emailCtl.text,
  phone: _phoneCtl.text,
  ktuId: _admissionCtl.text,
  role: _role,
);

if (errors['email'] != null) {
  print('Email error: ${errors['email']}');
}
```

### 3. Updated Add User Form

**Form Fields with Validation:**

1. **Full Name**
   - Validation: `validateFullName()`
   - Min 3 characters, max 100
   - Must have first and last name
   - Alphanumeric + spaces/hyphens/apostrophes only

2. **Email**
   - Validation: `validateEmail()`
   - RFC-compliant format
   - Checks for valid domain
   - Rejects disposable emails

3. **Phone**
   - Validation: `validatePhone()`
   - 10 digit Indian phone numbers
   - Must start with 6-9
   - No sequential patterns

4. **KTU ID** (for Student Representatives)
   - Validation: `validateKtuIdWithExamples()`
   - Format: `[PREFIX][YY][DEPT][SERIAL]`
   - Examples in error message
   - Year validation

**User Feedback:**
- Real-time validation on field change
- Clear error messages displayed below each field
- Form cannot be submitted with validation errors
- Specific guidance on valid formats

### 4. Activity Logging Integration

Activity logs now track:
- User creation activities
- Login/logout attempts (success & failure)
- Data submissions
- Report generation
- System alerts and warnings

All activities include:
- User information (ID, name, role)
- Action details (type, description)
- Timestamp (server-side)
- Status (success/failure/warning)
- IP address
- Department information

## Usage Guide

### View Activity Logs

1. **In Admin Dashboard:**
   - Click "Activity Logs" button in User Management section
   - New full-page activity logs viewer opens
   
2. **Filter Options:**
   - Select time range (24h, 7d, 30d, 90d)
   - Filter by status (All, Success, Failure, Warning)
   - Click "Refresh" to reload

3. **Information Displayed:**
   - User who performed action
   - What action was performed
   - When (relative time)
   - Status indicator
   - Department (if applicable)

### Add New User

1. **Open Add User Form:**
   - Click "Add New User" in Admin Dashboard
   - Form opens with all fields

2. **Fill Form Fields:**
   - Enter full name (e.g., "Rahul Krishnan")
   - Enter email (e.g., "rahul@geci.ac.in")
   - Enter phone (e.g., "9876543210")
   - Select role (Coordinator or Class Representative)
   - If Class Rep: Select department, year, semester, class
   - If Class Rep: Enter KTU ID (e.g., "IDK22CS004")

3. **Validation Feedback:**
   - Invalid fields show red error messages
   - Error messages provide specific guidance
   - Form shows example formats
   - Cannot submit until all fields valid

4. **Submit:**
   - Click "Create User"
   - User is created and logged in activity logs

## API Integration

### Activity Logs API

**Endpoint:** `GET /activity/logs`

**Parameters:**
- `limit` - Items per page (default: 20)
- `offset` - Pagination offset (default: 0)
- `days` - Time window in days (default: 7)
- `status` - Filter by status (optional)
- `action_type` - Filter by action (optional)
- `user_id` - Filter by user (optional)

**Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1,
      "user_id": "admin1",
      "user_name": "Admin User",
      "user_role": "admin",
      "action_type": "login",
      "action_description": "Admin successfully logged in",
      "status": "success",
      "timestamp": "2025-12-31T10:30:00",
      "department": null,
      "ip_address": "192.168.1.100"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total": 150
  }
}
```

### Activity Logging Backend

Logs are automatically created for:
- User authentication (login/logout)
- User creation
- Data submissions
- Report generation
- System events

## Files Modified/Created

**New Files:**
- ✅ `lib/activity_logs_page.dart` - Full activity logs page
- ✅ `lib/services/validators.dart` - Validation functions

**Modified Files:**
- ✅ `lib/admin_dashboard.dart` - Updated imports, form validation, Activity Logs button handler
- ✅ `lib/services/api.dart` - Added `getActivityLogs()` function

## Error Handling

### Email Errors
- Generic format errors
- Domain validation errors
- Disposable email detection
- Clear recovery paths

### Phone Errors
- Too short/long numbers
- Invalid starting digit
- Sequential pattern detection
- Digit-only validation

### KTU ID Errors
- Invalid prefix detection
- Department code validation
- Year range validation
- Clear examples in error message

## Security Considerations

1. **Email Validation** - Prevents invalid/disposable emails
2. **Phone Validation** - Ensures realistic phone numbers
3. **KTU ID Validation** - Prevents invalid student IDs
4. **Activity Logging** - Tracks all user actions
5. **IP Tracking** - Logs client IP for security audit

## Testing Checklist

- [ ] Click Activity Logs button → Opens activity logs page
- [ ] Filter logs by time range → Works correctly
- [ ] Filter logs by status → Shows correct status
- [ ] Manual refresh → Loads latest logs
- [ ] Add user with invalid email → Shows error
- [ ] Add user with invalid phone → Shows error
- [ ] Add user with invalid KTU ID → Shows examples
- [ ] Add user with valid data → Creates successfully
- [ ] User creation logged → Appears in activity logs

## Future Enhancements

- [ ] Export activity logs (CSV/PDF)
- [ ] Search activity logs
- [ ] Email alerts for critical activities
- [ ] Activity log analytics dashboard
- [ ] Compliance reporting
- [ ] Archive/retention policies
- [ ] Real-time WebSocket updates
