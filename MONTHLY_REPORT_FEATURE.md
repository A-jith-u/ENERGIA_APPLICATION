# Monthly Report Feature - Implementation Guide

## Overview
A comprehensive monthly report system has been implemented in the GECI ENERGIA admin panel. This feature generates detailed, professional reports with analytics, graphs, recommendations, and PDF export capability.

## Features Implemented

### 1. Backend API (`backend/monthly_report_api.py`)

**Endpoints:**
- `GET /reports/monthly-report?month={month}&year={year}`
  - Generates complete monthly report with all analytics
  - Parameters: month (1-12), year (e.g., 2026)
  - Defaults to current month if not specified

- `GET /reports/monthly-report/summary?month={month}&year={year}`
  - Quick summary for preview purposes

**Report Components:**
- ✅ **Overall Statistics**
  - Total energy consumption
  - Active sensors count
  - Average/peak power metrics
  - Voltage, current, power factor analysis

- ✅ **Department-wise Breakdown**
  - Energy consumption by department
  - Sensor count per department
  - Peak power usage analysis

- ✅ **Daily Consumption Trends**
  - Day-by-day energy usage
  - Average and peak power per day

- ✅ **Peak Usage Analysis**
  - Top 10 peak power events
  - Hourly usage patterns (24-hour analysis)
  - Identifies high-consumption periods

- ✅ **Month-over-Month Comparison**
  - Percentage change from previous month
  - Trend analysis

- ✅ **Sensor Health Status**
  - Active vs inactive sensors
  - Inactive sensor identification

- ✅ **AI-Powered Recommendations**
  - Priority-based (high, medium, low)
  - Actionable suggestions for:
    - Energy consumption optimization
    - Power factor improvement
    - Department-specific actions
    - Load management
    - System maintenance

### 2. Frontend Report Page (`lib/monthly_report_page.dart`)

**Interactive Dashboard with:**

✅ **Report Header**
- Month/Year selector dropdowns
- Dynamic report loading
- Refresh capability

✅ **Visual Statistics Grid**
- 6 key metrics displayed as cards:
  - Total Energy (kWh)
  - Active Sensors
  - Total Readings
  - Average Power
  - Peak Power
  - Power Factor

✅ **Month-over-Month Card**
- Color-coded comparison (red=increase, green=decrease)
- Percentage change indicator
- Trend arrow icon

✅ **Daily Trends Line Chart**
- Interactive fl_chart line graph
- Shows energy consumption per day
- Curved line with area fill
- Day-wise breakdown

✅ **Department Breakdown Table**
- Sortable data table
- Shows all departments with:
  - Energy consumption
  - Average power
  - Peak power
  - Sensor count

✅ **Hourly Usage Pattern Bar Chart**
- 24-hour usage analysis
- Identifies peak hours
- Interactive bar chart

✅ **Recommendations Section**
- Color-coded priority badges
- Detailed descriptions
- Actionable items
- Category-based organization

✅ **System Health Status**
- Visual indicators for:
  - Active sensors (green)
  - Inactive sensors (orange)
  - Total readings (blue)

### 3. Professional PDF Export (Minimum 2 Pages)

**Page 1: Overview & Statistics**
- ✅ Professional header with logo and branding
- ✅ Executive summary
- ✅ Key statistics grid
- ✅ Month-over-month comparison
- ✅ Department-wise table
- ✅ Footer with page numbers

**Page 2: Analysis & Recommendations**
- ✅ Peak usage analysis (top events)
- ✅ Detailed recommendations with:
  - Priority indicators
  - Descriptions
  - Action items
- ✅ System health metrics
- ✅ Professional conclusion
- ✅ Confidential marking

**PDF Features:**
- ✅ A4 format, professionally styled
- ✅ Color-coded elements
- ✅ Tables with proper formatting
- ✅ Automatic filename generation
- ✅ Platform-specific save/share dialog
- ✅ Minimum 2 pages guaranteed

### 4. Admin Panel Integration

**Location:** Admin Dashboard → Admin Quick Actions

✅ **"Generate Monthly Report" Button**
- Icon: PDF document icon
- Description: "Create campus-wide consumption report"
- Action: Opens dedicated Monthly Report page
- Easy access for admins

## Installation & Setup

### 1. Backend Setup

The API is automatically mounted at `/reports` endpoint.

**Already configured in `backend/app_main.py`:**
```python
monthly_report_api = _load("monthly_report_api")
app.mount("/reports", monthly_report_api.router)
```

### 2. Frontend Dependencies

**Added to `pubspec.yaml`:**
- `intl: ^0.19.0` - For date formatting
- Already had: `pdf`, `printing`, `fl_chart`, `http`

**Run to install:**
```bash
flutter pub get
```

### 3. Start Backend Server

```bash
cd backend
python start_server.py
```

The API will be available at:
- `http://localhost:8000/reports/monthly-report`
- `http://localhost:8000/reports/monthly-report/summary`

## Usage Guide

### For Admins:

1. **Access the Report:**
   - Login to Admin Dashboard
   - Scroll to "Admin Quick Actions" section
   - Click "Generate Monthly Report"

2. **View Report:**
   - Report loads for current month by default
   - Use dropdowns to select different month/year
   - All graphs and analytics display automatically

3. **Download PDF:**
   - Click PDF icon in app bar (top right)
   - PDF generates with all content (minimum 2 pages)
   - Choose save location or share

4. **Refresh Data:**
   - Click refresh icon to reload latest data

## Report Content Details

### Statistics Included:
- Total energy consumption (kWh)
- Active sensor count
- Total readings count
- Average power (W)
- Peak power (W)
- Average voltage (V)
- Average current (A)
- Power factor

### Analytics Included:
- Daily consumption trends (line graph)
- Department-wise breakdown (table)
- Hourly usage patterns (bar chart)
- Peak usage events (top 10)
- Month-over-month comparison (%)

### Recommendations Include:
1. **Energy Consumption Trends**
   - Significant increases/decreases
   - Usage optimization suggestions

2. **Power Quality**
   - Power factor analysis
   - Correction recommendations

3. **Department Focus**
   - High-consumption departments
   - Targeted efficiency measures

4. **Load Management**
   - Peak hour identification
   - Load shifting suggestions

5. **System Maintenance**
   - Sensor health alerts
   - Preventive maintenance reminders

6. **Best Practices**
   - Regular maintenance schedules
   - Optimization opportunities

## Data Sources

Reports pull data from:
- `esp32_raw_data` table - All sensor readings
- Date range filtering for accurate monthly data
- Previous month for comparison
- Real-time sensor status

## Technical Specifications

### Backend:
- FastAPI router-based API
- PostgreSQL database queries
- Efficient date range filtering
- Aggregation functions for statistics
- Smart recommendation engine

### Frontend:
- Flutter Material Design
- fl_chart for visualizations
- PDF generation with pw.Document
- Responsive layout
- Error handling and loading states

### PDF Generation:
- A4 format (PdfPageFormat.a4)
- 40-point margins
- Professional styling
- Color-coded elements
- Table formatting
- Page headers/footers
- Auto-numbered pages

## File Structure

```
backend/
├── monthly_report_api.py      # NEW: Report API endpoints
└── app_main.py                # Modified: Mounted report API

lib/
├── monthly_report_page.dart   # NEW: Report UI with PDF export
└── admin_dashboard.dart       # Modified: Added report button

pubspec.yaml                   # Modified: Added intl package
```

## API Response Example

```json
{
  "success": true,
  "report_period": {
    "month": 1,
    "year": 2026,
    "month_name": "January",
    "start_date": "2026-01-01T00:00:00",
    "end_date": "2026-02-01T00:00:00",
    "days_in_month": 31
  },
  "overall_statistics": {
    "total_energy": 1234.56,
    "active_sensors": 15,
    "avg_power": 123.45,
    "peak_power": 567.89,
    ...
  },
  "month_over_month_change": -8.5,
  "department_breakdown": [...],
  "daily_trends": [...],
  "peak_usage_analysis": {...},
  "recommendations": [...]
}
```

## Testing

### Test Backend API:
```bash
# Current month report
curl http://localhost:8000/reports/monthly-report

# Specific month
curl http://localhost:8000/reports/monthly-report?month=12&year=2025

# Summary
curl http://localhost:8000/reports/monthly-report/summary
```

### Test Frontend:
1. Start backend: `python backend/start_server.py`
2. Run Flutter app: `flutter run`
3. Login as admin
4. Click "Generate Monthly Report" in Quick Actions
5. Verify all sections load correctly
6. Test PDF download

## Troubleshooting

### Backend Issues:
- **No data:** Ensure `esp32_raw_data` table has entries
- **Connection error:** Check backend is running on port 8000
- **Database error:** Verify PostgreSQL connection in DB_URL

### Frontend Issues:
- **Loading forever:** Check backend API is accessible
- **PDF not generating:** Ensure `intl` package is installed
- **Graphs not showing:** Verify data format from API

### Common Fixes:
```bash
# Install dependencies
flutter pub get

# Restart backend
cd backend
python start_server.py

# Clear Flutter build cache
flutter clean
flutter pub get
```

## Future Enhancements

Potential improvements:
- Year-over-year comparison
- Custom date range selection
- Email report delivery
- Scheduled automatic reports
- More chart types (pie, scatter)
- Export to Excel format
- Multi-language support
- Real-time report updates

## Summary

✅ **Complete Implementation:**
- Backend API with comprehensive data analysis
- Frontend page with rich visualizations
- Professional PDF export (minimum 2 pages)
- Integrated into admin quick actions
- AI-powered recommendations
- Month/year selection
- Real-time data loading

✅ **Professional Quality:**
- Industry-standard report format
- Clear, actionable insights
- Beautiful data visualizations
- Mobile and desktop compatible
- Production-ready code

The monthly report feature is now fully operational and accessible from the admin dashboard under "Admin Quick Actions" → "Generate Monthly Report".
