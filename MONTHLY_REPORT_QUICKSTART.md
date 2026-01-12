# 📊 Monthly Report Feature - Quick Start Guide

## What's New?

A comprehensive **Monthly Energy Report** system has been added to the admin panel with:
- 📈 **Interactive graphs and charts** (daily trends, hourly patterns)
- 📋 **Detailed analytics** (department breakdown, sensor status)
- 💡 **AI-powered recommendations** for energy optimization
- 📄 **Professional PDF export** (minimum 2 pages, ready to download)
- 🎯 **Easy access** from Admin Quick Actions

---

## Quick Start (3 Steps)

### 1️⃣ Install Dependencies

```bash
cd e:\Flutter\flutter_application_1
flutter pub get
```

### 2️⃣ Start Backend Server

```bash
cd backend
python start_server.py
```

Wait for: `Uvicorn running on http://0.0.0.0:8000`

### 3️⃣ Run Flutter App

```bash
flutter run
```

---

## How to Use

### For Admins:

1. **Login** to Admin Dashboard
2. Scroll to **"Admin Quick Actions"** section
3. Click **"Generate Monthly Report"** button
4. Report loads automatically for current month
5. Click **PDF icon** (top-right) to download

### Features in Report:

✅ **Select Month/Year** - Dropdown selectors at top  
✅ **View Statistics** - 6 key metrics displayed as cards  
✅ **Daily Trends** - Interactive line chart  
✅ **Department Analysis** - Table with consumption data  
✅ **Hourly Patterns** - Bar chart showing peak hours  
✅ **Recommendations** - Priority-coded suggestions  
✅ **System Health** - Sensor status indicators  

### PDF Export:

- Click the **PDF icon** in app bar
- PDF generates with **2+ pages**:
  - **Page 1:** Overview, statistics, department table
  - **Page 2:** Peak analysis, recommendations, conclusions
- File name: `Monthly_Report_January_2026.pdf`
- Save or share directly

---

## API Endpoints

Backend running at `http://localhost:8000`

### Get Full Report
```bash
GET /reports/monthly-report?month=1&year=2026
```

### Get Quick Summary
```bash
GET /reports/monthly-report/summary?month=1&year=2026
```

**Parameters:**
- `month` (optional): 1-12, defaults to current month
- `year` (optional): e.g., 2026, defaults to current year

---

## Report Contents

### 📊 Statistics
- Total Energy (kWh)
- Active Sensors
- Total Readings
- Average Power (W)
- Peak Power (W)
- Power Factor

### 📈 Analytics
- **Daily Trends:** Line graph showing energy per day
- **Department Breakdown:** Table with all departments
- **Hourly Pattern:** Bar chart of 24-hour usage
- **Peak Events:** Top 10 highest power readings
- **Month Comparison:** % change from previous month

### 💡 Recommendations
- Energy consumption optimization
- Power factor improvement
- Department-specific actions
- Load management tips
- System maintenance alerts
- Best practices

---

## Files Modified/Created

### ✨ New Files:
- `backend/monthly_report_api.py` - API endpoints
- `lib/monthly_report_page.dart` - Report UI
- `MONTHLY_REPORT_FEATURE.md` - Full documentation
- `MONTHLY_REPORT_QUICKSTART.md` - This file

### 🔧 Modified Files:
- `backend/app_main.py` - Mounted report API
- `lib/admin_dashboard.dart` - Added report button
- `pubspec.yaml` - Added `intl` package

---

## Testing

### Test Backend API:
```bash
curl http://localhost:8000/reports/monthly-report
```

Expected: JSON with report data

### Test Frontend:
1. Start backend: `python backend/start_server.py`
2. Run app: `flutter run`
3. Login as admin (username: admin, password: admin123)
4. Click "Generate Monthly Report"
5. Verify all sections load
6. Test PDF download

---

## Troubleshooting

### ❌ "Failed to load report"
**Fix:** Ensure backend is running on port 8000
```bash
cd backend
python start_server.py
```

### ❌ "No data available"
**Fix:** Ensure database has sensor readings
```bash
cd backend
python inject_test_sensor_data.py
```

### ❌ PDF not generating
**Fix:** Install dependencies
```bash
flutter pub get
```

### ❌ Graphs not showing
**Fix:** Check API response format
```bash
curl http://localhost:8000/reports/monthly-report | python -m json.tool
```

---

## Example Usage Scenarios

### Scenario 1: Monthly Review Meeting
1. Generate report for last month
2. Download PDF
3. Share with department coordinators
4. Review recommendations in meeting

### Scenario 2: Energy Audit
1. Generate reports for last 6 months
2. Compare month-over-month trends
3. Identify high-consumption periods
4. Implement recommended actions

### Scenario 3: Department Analysis
1. Open monthly report
2. Check department breakdown table
3. Identify departments with high usage
4. Schedule targeted energy audits

---

## Integration Points

### Admin Dashboard:
- **Location:** Admin Quick Actions section
- **Button:** "Generate Monthly Report"
- **Icon:** PDF document icon
- **Action:** Opens MonthlyReportPage

### Backend API:
- **Mount point:** `/reports`
- **Main endpoint:** `/monthly-report`
- **Database:** Queries `esp32_raw_data` table

### Data Flow:
```
Admin clicks button
    ↓
MonthlyReportPage loads
    ↓
API call to /reports/monthly-report
    ↓
Backend queries database
    ↓
Returns JSON with analytics
    ↓
Flutter renders charts/tables
    ↓
User downloads PDF
```

---

## Next Steps

After setup:
1. ✅ Generate your first report
2. ✅ Test PDF download
3. ✅ Review recommendations
4. ✅ Share with stakeholders
5. ✅ Set up monthly reporting schedule

---

## Support

For issues or questions:
1. Check `MONTHLY_REPORT_FEATURE.md` for detailed docs
2. Verify backend is running: `curl http://localhost:8000/ping`
3. Check logs in terminal where backend is running
4. Ensure database has recent data

---

## Summary

✅ **Professional monthly reports** with graphs and analytics  
✅ **AI-powered recommendations** for optimization  
✅ **PDF export** with 2+ pages of detailed information  
✅ **Easy access** from admin dashboard  
✅ **Month/year selection** for historical data  
✅ **Real-time data** from sensor network  

**Ready to use!** Just login as admin and click "Generate Monthly Report" 🚀
