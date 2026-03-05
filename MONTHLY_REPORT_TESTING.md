# Monthly Report Feature - Testing Checklist

## Pre-Testing Setup

### Backend Setup
- [ ] Backend dependencies installed (`pip install -r backend/requirements.txt`)
- [ ] Database is running and accessible
- [ ] Backend server starts without errors (`python backend/start_server.py`)
- [ ] Backend accessible at `http://localhost:8000`
- [ ] Ping endpoint works: `curl http://localhost:8000/ping`

### Frontend Setup
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] No compilation errors in Flutter project
- [ ] App builds successfully (`flutter build`)
- [ ] Can run app (`flutter run`)

### Database Setup
- [ ] `esp32_raw_data` table exists
- [ ] Table has sample data (run `python backend/inject_test_sensor_data.py` if needed)
- [ ] Database connection string is correct in `backend/.env`

---

## API Testing

### Test Monthly Report Endpoint

#### Test 1: Current Month
```bash
curl http://localhost:8000/reports/monthly-report
```
- [ ] Returns 200 status code
- [ ] JSON response is valid
- [ ] Contains `success: true`
- [ ] Has `overall_statistics` object
- [ ] Has `department_breakdown` array
- [ ] Has `daily_trends` array
- [ ] Has `recommendations` array

#### Test 2: Specific Month
```bash
curl "http://localhost:8000/reports/monthly-report?month=12&year=2025"
```
- [ ] Returns data for December 2025
- [ ] `report_period.month` is 12
- [ ] `report_period.year` is 2025

#### Test 3: Summary Endpoint
```bash
curl http://localhost:8000/reports/monthly-report/summary
```
- [ ] Returns quick summary
- [ ] Has `total_energy`, `active_sensors`, `total_readings`

### Verify Data Structure

Check that response includes:
- [ ] `report_period` with month, year, month_name
- [ ] `overall_statistics` with 8+ metrics
- [ ] `previous_month` statistics
- [ ] `month_over_month_change` percentage
- [ ] `department_breakdown` array (one per department)
- [ ] `daily_trends` array (one per day)
- [ ] `peak_usage_analysis` with top events and hourly pattern
- [ ] `classroom_consumption` array
- [ ] `sensor_status` with active/inactive counts
- [ ] `recommendations` array with priority, title, description, action

---

## Frontend Testing

### Navigation
- [ ] Can login as admin
- [ ] Admin dashboard loads successfully
- [ ] "Admin Quick Actions" section is visible
- [ ] "Generate Monthly Report" button is present
- [ ] Button has PDF icon
- [ ] Clicking button navigates to Monthly Report page

### Report Page Load
- [ ] Page loads without errors
- [ ] App bar shows "Monthly Energy Report" title
- [ ] Loading indicator appears initially
- [ ] Data loads within 5 seconds
- [ ] No error messages appear

### Month/Year Selection
- [ ] Month dropdown is visible and functional
- [ ] Shows all 12 months (January - December)
- [ ] Current month is selected by default
- [ ] Year dropdown is visible and functional
- [ ] Shows last 5 years
- [ ] Current year is selected by default
- [ ] Changing month/year triggers reload
- [ ] Loading indicator appears during reload
- [ ] New data displays correctly

### Statistics Cards
- [ ] 6 stat cards are displayed in grid
- [ ] Cards show: Total Energy, Active Sensors, Total Readings, Avg Power, Peak Power, Power Factor
- [ ] Each card has icon, value, and label
- [ ] Values are numeric and formatted correctly
- [ ] Icons are appropriate for each metric
- [ ] Colors are visually distinct

### Month-over-Month Card
- [ ] Comparison card is displayed
- [ ] Shows percentage change
- [ ] Displays "Increase" or "Decrease" correctly
- [ ] Arrow icon points up (increase) or down (decrease)
- [ ] Card color is red for increase, green for decrease
- [ ] Percentage is calculated correctly

### Daily Trends Chart
- [ ] Line chart is displayed
- [ ] Title: "Daily Energy Consumption Trends"
- [ ] X-axis shows days of month
- [ ] Y-axis shows energy (kWh)
- [ ] Line is smooth and curved
- [ ] Area under line is filled with light blue
- [ ] Grid lines are visible
- [ ] Hovering shows data points (if supported)

### Department Breakdown Table
- [ ] Table is displayed
- [ ] Headers: Department, Energy (kWh), Avg Power (W), Peak (W), Sensors
- [ ] All departments are listed
- [ ] Values are numeric and formatted
- [ ] Table is scrollable horizontally if needed
- [ ] Rows are readable

### Hourly Pattern Chart
- [ ] Bar chart is displayed
- [ ] Title: "Hourly Usage Pattern"
- [ ] X-axis shows hours (0-23)
- [ ] Y-axis shows power (W)
- [ ] 24 bars are shown
- [ ] Bars are orange color
- [ ] Peak hours are visually identifiable

### Recommendations Section
- [ ] Recommendations card is displayed
- [ ] Has lightbulb icon and title
- [ ] Multiple recommendations are shown
- [ ] Each recommendation has:
  - [ ] Priority badge (HIGH/MEDIUM/LOW)
  - [ ] Title
  - [ ] Description
  - [ ] Action item with arrow icon
- [ ] Priority badges are color-coded:
  - [ ] RED for high
  - [ ] ORANGE for medium
  - [ ] GREEN for low
- [ ] Recommendations are readable and relevant

### System Health Section
- [ ] Health status card is displayed
- [ ] Shows 3 indicators: Active Sensors, Inactive Sensors, Total Readings
- [ ] Each has icon, value, and label
- [ ] Icons are appropriate: checkmark (active), warning (inactive), document (readings)
- [ ] Colors: green (active), orange (inactive), blue (readings)

### Refresh Functionality
- [ ] Refresh icon is in app bar
- [ ] Clicking refresh icon reloads data
- [ ] Loading indicator appears during refresh
- [ ] Data updates after refresh completes

---

## PDF Export Testing

### PDF Generation
- [ ] PDF icon is visible in app bar
- [ ] Clicking PDF icon starts generation
- [ ] No errors during generation
- [ ] PDF preview or save dialog appears
- [ ] File can be saved to device

### PDF Content - Page 1
- [ ] Header with "GECI ENERGIA" branding
- [ ] Report title: "Monthly Energy Consumption Report"
- [ ] Month and year displayed (e.g., "January 2026")
- [ ] Generation date shown
- [ ] "Executive Summary" section
- [ ] Statistics grid with 6 metrics
- [ ] "Month-over-Month Analysis" section
- [ ] Comparison with percentage
- [ ] Arrow indicator (up/down)
- [ ] "Department-wise Energy Consumption" section
- [ ] Department table with data
- [ ] Footer with page number "Page 1 of 2"
- [ ] "CONFIDENTIAL" marking

### PDF Content - Page 2
- [ ] Header with report name and date
- [ ] "Peak Usage Analysis" section
- [ ] Top 5 peak events listed
- [ ] "Recommendations for Improvement" section
- [ ] At least 3 recommendations with:
  - [ ] Priority badge
  - [ ] Title
  - [ ] Description
  - [ ] Action item
- [ ] "System Health Status" section
- [ ] Health metrics displayed
- [ ] "Conclusion" section
- [ ] Professional closing text
- [ ] Footer with page number "Page 2 of 2"
- [ ] "Generated by GECI ENERGIA System"

### PDF Quality
- [ ] Text is readable
- [ ] Tables are properly formatted
- [ ] Colors are visible
- [ ] No text overflow
- [ ] Spacing is consistent
- [ ] Professional appearance
- [ ] File size is reasonable (< 1MB)
- [ ] Opens correctly in PDF reader

---

## Error Handling

### Backend Errors
Test with backend stopped:
- [ ] Frontend shows error message
- [ ] Error icon is displayed
- [ ] "Retry" button appears
- [ ] Clicking retry attempts reload
- [ ] No app crash

### No Data Scenarios
Test with empty database:
- [ ] App handles empty data gracefully
- [ ] Shows "No data available" messages
- [ ] Charts show empty state or placeholder
- [ ] Recommendations section shows default message

### Invalid Date Ranges
Test with invalid month/year:
- [ ] Backend returns appropriate error
- [ ] Frontend shows error message
- [ ] User can recover (select valid date)

---

## Performance Testing

### Load Times
- [ ] Initial report loads in < 5 seconds
- [ ] Month change loads in < 3 seconds
- [ ] PDF generation completes in < 5 seconds
- [ ] No significant lag in UI

### Memory Usage
- [ ] App doesn't consume excessive memory
- [ ] No memory leaks after multiple navigations
- [ ] Charts render smoothly without stuttering

### Data Volume
Test with large datasets:
- [ ] Handles 1000+ readings without issues
- [ ] Charts scale appropriately
- [ ] Tables paginate or scroll smoothly
- [ ] PDF generates without timeout

---

## Cross-Platform Testing

### Desktop (Windows)
- [ ] App runs on Windows
- [ ] All features work correctly
- [ ] PDF save dialog works
- [ ] Charts render properly

### Web (if applicable)
- [ ] App runs in browser
- [ ] All features work
- [ ] PDF download works

### Mobile (Android/iOS)
- [ ] App runs on mobile device
- [ ] Touch interactions work
- [ ] PDF share sheet works
- [ ] Layout is responsive

---

## Integration Testing

### End-to-End Flow
- [ ] Admin login → Dashboard → Generate Report → View → Download PDF
- [ ] All steps complete without errors
- [ ] Data is consistent across steps
- [ ] PDF matches on-screen data

### Data Consistency
- [ ] API data matches database records
- [ ] Frontend displays match API responses
- [ ] PDF content matches frontend display
- [ ] Calculations are accurate (percentages, totals, averages)

---

## User Acceptance Testing

### Usability
- [ ] Report is easy to understand
- [ ] Navigation is intuitive
- [ ] Information is clearly presented
- [ ] Recommendations are actionable

### Professional Quality
- [ ] Report looks professional
- [ ] Suitable for stakeholder presentation
- [ ] Data visualization is effective
- [ ] PDF is shareable quality

### Completeness
- [ ] All requested features implemented
- [ ] Report has minimum 2 pages (PDF)
- [ ] Contains graphs ✓
- [ ] Contains analytical details ✓
- [ ] Contains recommendations ✓
- [ ] Contains correct information ✓
- [ ] Downloadable as PDF ✓

---

## Final Checklist

### Documentation
- [ ] MONTHLY_REPORT_FEATURE.md exists
- [ ] MONTHLY_REPORT_QUICKSTART.md exists
- [ ] MONTHLY_REPORT_VISUAL.md exists
- [ ] MONTHLY_REPORT_TESTING.md (this file) exists
- [ ] All documentation is accurate

### Code Quality
- [ ] No compilation errors
- [ ] No runtime errors
- [ ] Code is readable and documented
- [ ] Follows project conventions

### Deployment Readiness
- [ ] Feature works in development
- [ ] Ready for production deployment
- [ ] All dependencies documented
- [ ] Setup instructions clear

---

## Test Results

### Date Tested: _____________

### Tested By: _____________

### Environment:
- Backend: Python version ____
- Frontend: Flutter version ____
- Database: PostgreSQL version ____
- OS: ____

### Overall Status:
- [ ] ✅ All tests passed
- [ ] ⚠️ Some tests failed (document below)
- [ ] ❌ Major issues found

### Issues Found:
```
1. 
2. 
3. 
```

### Notes:
```




```

---

## Sign-Off

Feature is ready for production when:
- [ ] All API tests pass
- [ ] All frontend tests pass
- [ ] PDF export works correctly
- [ ] No critical bugs found
- [ ] Documentation is complete
- [ ] Performance is acceptable

**Approved By:** _____________  
**Date:** _____________  
**Signature:** _____________

---

## Quick Test Commands

### Backend
```bash
# Start backend
cd backend
python start_server.py

# Test API
curl http://localhost:8000/reports/monthly-report

# Check logs
# (view terminal output)
```

### Frontend
```bash
# Run app
flutter run

# Build app
flutter build

# Get dependencies
flutter pub get
```

### Database
```bash
# Check data
cd backend
python check_sensor_data.py

# Add test data if needed
python inject_test_sensor_data.py
```

---

**Testing Status:** Ready for execution  
**Last Updated:** January 5, 2026
