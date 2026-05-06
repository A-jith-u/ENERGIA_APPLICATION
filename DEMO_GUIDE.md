# ENERGIA Application - Live Demo Guide

## Quick Start (5 minutes)

### Terminal 1: Start Backend
```powershell
Set-Location c:/Users/rapha/OneDrive/Desktop/project/ENERGIA_APPLICATION/backend
../.venv/Scripts/python.exe start_server.py
```

Wait for: `INFO:     Uvicorn running on http://0.0.0.0:5000`

### Terminal 2: Run Full Demo
```powershell
Set-Location c:/Users/rapha/OneDrive/Desktop/project/ENERGIA_APPLICATION
.venv/Scripts/python.exe demo_runner.py
```

This will automatically:
✓ Verify backend health
✓ Check database connection
✓ Authenticate as admin
✓ Set up demo room (CS-C201) and class-rep mapping
✓ Generate 5 anomaly-scenario sensor readings
✓ Verify anomaly detection
✓ Check alert escalation tracking
✓ Verify in-app notifications
✓ Check email artifacts (fallback if SMTP not configured)
✓ Request 15-minute energy predictions
✓ Verify role-based access (admin, class-rep, coordinator)
✓ Verify relay control interface

---

## Optional: Live UI Demo (Flutter)

### Terminal 3: Start Flutter App
```powershell
Set-Location c:/Users/rapha/OneDrive/Desktop/project/ENERGIA_APPLICATION
flutter run -d windows
```

### Login Credentials

| Role | Username | Password | Access |
|------|----------|----------|--------|
| Admin | admin | admin123 | Full system overview |
| Class Rep | CCS001 | J0q!8p | Room-specific alerts |
| Coordinator | CCSE001 | password | Department-scoped alerts |

**Demo Room:** CS-C201 (CSE Department)
**Demo Device:** ESP32-CS-C201

---

## What to Check During Demo

### 1. Sensor Data Insertion ✓
- Console: "Sensor readings sent with power values"
- Database: Check `sensor_data` table for `device_id = 'ESP32-CS-C201'`

### 2. Anomaly Detection ✓
- Console: "Anomalies detected: X logs"
- Database: Check `anomaly_logs` where `is_anomaly = 1`
- Alert Type: `usage_without_occupancy` (high power with no occupancy)

### 3. Alert Escalation ✓
- Console: "Alert tracking: ID=X, status=active, alerts=X"
- Escalation timeline:
  - **0-5 min:** Class rep notification (room-scoped)
  - **5-10 min:** Coordinator notification (department-scoped)
  - **10-15 min:** Sergeant notification (campus-wide)
  - **15+ min:** Auto-cutoff (if unresolved)

### 4. In-App Notifications ✓
- Console lists recipients and titles
- Database: Check `notifications` table
- Columns: `recipient_email`, `recipient_type`, `title`, `room_id`

### 5. Email Delivery ✓
- If SMTP configured: Real emails sent
- If SMTP not configured: HTML files saved to `backend/tmp_alert_emails/`
  - View files in VS Code or any text editor
  - Check file timestamps match alert creation time

### 6. Energy Predictions ✓
- Console: "15-min Prediction: yhat=731.19W, margin=±146.24W"
- Response includes:
  - `yhat`: Predicted power (Watts)
  - `yhat_lower`, `yhat_upper`: 20% confidence interval
  - `is_fallback`: false (using live ensemble model)
  - Model: `energy_ensemble_90_mixed`

### 7. Role-Based Access ✓
- Console: "Login (class_representative): OK"
- Each role sees only authorized data/controls

---

## Files Involved in This Demo

| Component | File | Purpose |
|-----------|------|---------|
| Backend Server | `backend/start_server.py` | FastAPI + Uvicorn launcher |
| Sensor Ingest | `backend/auth_api.py` | POST /api/sensor-data endpoint |
| Anomaly Engine | `backend/anomaly_alert_service.py` | Detection + escalation |
| Predictions | `backend/serve_ensemble_90_mixed.py` | ML ensemble model serving |
| Notifications | `backend/notify_api.py` | In-app notification storage |
| Email Service | `backend/alert_mail_service.py` | SMTP email delivery |
| Simulator | `simulation_data/simulate_data.py` | Anomaly-scenario generator |
| Demo Runner | `demo_runner.py` | Orchestrator script |
| Flutter App | `lib/dashboard_page.dart` | Role-based dashboards |

---

## Expected Output

```
================================================================================
  ENERGIA Application - End-to-End Demo
================================================================================

================================================================================
  STEP 1: Health & Connectivity Checks
================================================================================

  [✓] Backend Health                              OK  API responding
  [✓] Database Connection                         OK  1234 sensor rows

================================================================================
  STEP 2: Authentication & Demo Setup
================================================================================

  [✓] Admin Authentication                        OK  Token obtained

  Setting up demo environment...
  [✓] Assign Department                           OK  CS-C201 → CSE
  [✓] Map Class Rep                               OK  ajith@example.com → CS-C201

================================================================================
  STEP 3: Simulated Data Generation
================================================================================

  Generating 5 anomaly-scenario readings...
  [✓] Simulator Execution                         OK  5 readings sent

================================================================================
  STEP 4: Data Flow Verification
================================================================================

  [✓] Sensor Data Inserted                        OK  245 rows for ESP32-CS-C201
  [✓] Anomalies Detected                          OK  5 anomaly logs
  [✓] Alert Tracking                              OK  ID=73, status=active, alerts=5

================================================================================
  STEP 5: Notification & Alert Systems
================================================================================

  [✓] In-App Notifications                        OK  8 notification rows
      - class_rep: ajith@example.com — [ANOMALY] Usage without occupancy: 5225W
      - coordinator: coord@example.com — [ESCALATION] Class rep alert unresolved
      - sergeant: sgt@example.com — [CRITICAL] Sergeant escalation triggered

  [✓] Email Artifacts (Fallback)                  OK  3 HTML files
      - alert_73_classrep_20260506T001500Z.html (15234 bytes)
      - alert_73_coordinator_20260506T001900Z.html (15567 bytes)
      - alert_73_sergeant_20260506T002300Z.html (15891 bytes)

================================================================================
  STEP 6: Energy Prediction Service
================================================================================

  [✓] 15-min Prediction                           OK  yhat=731.19W, margin=±146.24W

================================================================================
  STEP 7: Role-Based Access Control
================================================================================

  Checking user access (roles)...
  [✓] Login (admin)                               OK  User: admin
  [✓] Login (class_representative)                OK  User: CCS001
  [✓] Login (coordinator)                         OK  User: CCSE001

================================================================================
  STEP 8: Relay Control Interface
================================================================================

  [✓] Relay Control API                           OK  Endpoint responsive

================================================================================
  FUNCTIONALITY SUMMARY
================================================================================

  Data Flow Summary:
    • Sensor readings:     245 records
    • Anomalies detected:  5 logs
    • Active alerts:       1 tracking entries
    • Notifications:       8 in-app records

  Key Features Demonstrated:
    ✓ Real-time sensor data ingestion
    ✓ Anomaly detection engine
    ✓ Alert escalation (class-rep → coordinator → sergeant)
    ✓ In-app notification delivery
    ✓ Email/SMTP fallback (HTML artifacts)
    ✓ Energy prediction (15-min horizon)
    ✓ Role-based access control
    ✓ Relay control interface

✓ Demo completed. All systems operational.
```

---

## Troubleshooting

### Backend won't start
```powershell
# Kill any existing Python processes
taskkill /IM python.exe /F

# Try again
python backend/start_server.py
```

### Database connection fails
- Verify PostgreSQL is running
- Check DB_URL in `backend/.env`
- Run: `python backend/db_init.py`

### Demo runner hangs
- Check backend logs for errors
- Ensure simulator has correct device ID
- Restart backend and try again

### Predictions show "is_fallback: true"
- This is normal if data stream is recent
- Fallback uses median of recent readings
- After more data: model converges to better accuracy

### No email artifacts
- Check `backend/tmp_alert_emails/` exists
- If SMTP configured, emails send directly (check inbox)
- Fallback only creates files when SMTP not configured

---

## Demo Talking Points

1. **Data Ingestion**: ESP32 sensors post readings every 60 seconds
2. **Anomaly Detection**: ML model identifies usage without occupancy
3. **Escalation**: Alerts follow time-based escalation: class-rep (0-5m) → coordinator (5-10m) → sergeant (10-15m)
4. **Notifications**: In-app + email delivery to authorized users by role
5. **Predictions**: 15-minute energy forecasts with ±20% confidence bands
6. **Access Control**: Role-based dashboards and controls (admin, coordinator, class-rep, sergeant)
7. **Relay Integration**: Backend can trigger power cutoff via relay for critical unresolved alerts

---

## Contact & Support

- **Repository**: https://github.com/A-jith-u/ENERGIA_APPLICATION.git
- **Backend API**: http://127.0.0.1:5000 (when running)
- **Database**: PostgreSQL (local or remote)
- **ML Model**: `backend/models/energy_ensemble_90_mixed.joblib`
