# ENERGIA

ENERGIA is a full-stack energy monitoring and control platform built with Flutter (frontend) and FastAPI (backend). It ingests live classroom/building sensor readings, detects anomalies, forecasts consumption, triggers role-based escalation workflows, and supports relay-based power control.

**Repository:** https://github.com/A-jith-u/ENERGIA_APPLICATION.git

This repository contains:
- A multi-role Flutter application for admin/coordinator/sergeant/class-rep workflows.
- A FastAPI backend with PostgreSQL persistence.
- ML components for anomaly detection and energy forecasting.
- Notification and alert escalation services integrated into backend processing.

## 1. Core Capabilities

- Live sensor data ingestion from ESP32/PZEM-style payloads.
- Real-time anomaly detection and anomaly logging.
- Role-based escalation pipeline:
  - Class rep (0 to 5 minutes)
  - Coordinator (5 to 10 minutes)
  - Sergeant (10 to 15 minutes)
  - Auto-cutoff for unresolved critical cases
- Forecasting endpoint mounted at /model (mixed ensemble; Prophet fallback support in runtime if available).
- Department-aware dashboards and controls.
- Relay control API with role and department restrictions.
- In-app and email notification support.
- Activity logging and reporting APIs.

## 2. High-Level Data Flow

1. Sensor posts live reading to backend endpoint /sensor-data.
2. Backend validates and stores measurements in PostgreSQL.
3. Anomaly pipeline evaluates occupancy/power conditions and ML anomaly model output.
4. Alert tracking is created/updated per room.
5. Background escalation service dispatches role-based notifications by time stage.
6. Relay APIs can trigger manual or automatic OFF actions for unresolved risk.
7. Flutter dashboards refresh from backend endpoints for alerts, analytics, and controls.

Demo mode is enabled by default in the backend startup path so the app can be showcased without live ESP32 hardware. It backfills recent minute-by-minute readings, continues streaming simulated readings, and drives the existing prediction, anomaly, notification, and email flows. Set `DEMO_MODE=0` in `backend/.env` if you want to disable it.

## 3. Tech Stack

Frontend:
- Flutter (Dart)
- HTTP client, shared preferences, charting/visualization packages

Backend:
- FastAPI + Uvicorn
- SQLAlchemy + PostgreSQL
- Python ML stack (scikit-learn, pandas, numpy, joblib)

Messaging/Notifications:
- In-app notification persistence
- SMTP email support
- Optional Firebase/FCM integration components

## 4. Repository Structure

- [lib](lib): Flutter app source (dashboards, auth, services, widgets)
- [backend](backend): FastAPI backend, ML services, DB init, routing modules
- [backend/datasets](backend/datasets): CSV datasets used by active training pipeline
- [backend/models](backend/models): Saved model artifacts
- [backend/metrics](backend/metrics): Training/evaluation outputs
- [android](android), [ios](ios), [windows](windows), [linux](linux), [macos](macos), [web](web): Flutter platform targets

## 5. Supplementary Files

This project also includes supplementary assets used for deployment support, integration, diagnostics, and hardware setup.

Configuration and environment support:
- [backend/.env.example](backend/.env.example): Environment template for backend runtime configuration.
- [docker-compose.yml](docker-compose.yml): Containerized local service orchestration.

Database and schema helpers:
- [energia.sql](energia.sql): SQL dump/reference file for DB setup and migration support.
- [backend/relay_control_schema.sql](backend/relay_control_schema.sql): Relay-specific schema script.

Hardware and device integration:
- [esp32_with_relay.ino](esp32_with_relay.ino): ESP32 firmware sketch for relay-enabled sensor integration.
- [esp32_with_relay_FIXED.ino](esp32_with_relay_FIXED.ino): Alternate/fixed ESP32 firmware variant.

Operational helper scripts:
- [backend/integration_check.py](backend/integration_check.py): Quick integration sanity checks.
- [backend/fix_csv_for_training.py](backend/fix_csv_for_training.py): Dataset cleanup helper.
- [backend/send_test_email.py](backend/send_test_email.py): SMTP verification helper.
- [backend/start_server.py](backend/start_server.py): Preferred backend launcher wrapper.

Supplementary backend notes:
- [backend/README.md](backend/README.md): Backend-focused notes and script references.

## 6. Prerequisites

- Flutter SDK (compatible with pubspec environment)
- Dart SDK (bundled with Flutter)
- Python 3.10+ (recommended: 3.12 compatible setup used in this project)
- PostgreSQL (required)
- Pip/venv for backend dependency isolation

## 7. Backend Setup

### 7.1 Create Python environment and install dependencies

From repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend\requirements.txt
```

### 7.2 Configure environment

Create backend .env from sample:

```powershell
Copy-Item backend\.env.example backend\.env
```

Minimum required settings in [backend/.env](backend/.env):
- DB_URL (must be PostgreSQL)
- JWT_SECRET

Optional but recommended:
- MAIL_SERVER, MAIL_PORT, MAIL_USERNAME, MAIL_PASSWORD, MAIL_FROMx thi
- MQTT_BROKER, MQTT_PORT, MQTT_TOPIC

### 7.3 Initialize database schema

```powershell
Set-Location backend
python db_init.py
```

### 7.4 Start backend

From root:

```powershell
python backend\start_server.py
```

Backend defaults:
- Host: 0.0.0.0
- Port: 5000

Health check:
- GET http://127.0.0.1:5000/health

## 8. Frontend Setup (Flutter)

From repository root:

```powershell
flutter pub get
flutter run
```

The app API service tries multiple backend candidates including localhost and emulator loopback.

## 9. Live Sensor Ingestion Contract

Primary ingestion endpoint:
- POST /sensor-data

Typical payload shape:

```json
{
  "device_id": "Floor-2-Class-202",
  "power": 1320.0,
  "current": 5.4,
  "voltage": 246.9,
  "energy": 14.1,
  "power_factor": 0.95,
  "frequency": 50.0,
  "human_present": 0
}
```

Backend processing triggered by this reading includes:
- persistence to sensor_data
- anomaly checks and anomaly_logs updates
- alert tracking lifecycle updates
- escalation/notification pipeline participation

## 10. ML and Dataset Notes

Active training CSV datasets are consolidated in:
- [backend/datasets](backend/datasets)

Current active dataset files:
- [backend/datasets/sensor_data_export.csv](backend/datasets/sensor_data_export.csv)
- [backend/datasets/preprocessed_energy_data.csv](backend/datasets/preprocessed_energy_data.csv)
- [backend/datasets/ensemble90_mixed_training_data.csv](backend/datasets/ensemble90_mixed_training_data.csv)

Key active training scripts:
- [backend/ml_scripts/preprocess.py](backend/ml_scripts/preprocess.py)
- [backend/ml_scripts/train_model.py](backend/ml_scripts/train_model.py) (Isolation Forest)
- [backend/train_ensemble_90_mixed.py](backend/train_ensemble_90_mixed.py)

Key serving script:
- [backend/serve_ensemble_90_mixed.py](backend/serve_ensemble_90_mixed.py)

## 11. Major API Groups

- Auth and user/session: routes mounted from auth_api
- Sensor ingestion and retrieval: /sensor-data, /api/sensor-data
- Anomaly alerts and escalation: /anomaly-alerts/*
- Notifications: /notify/*
- Relay controls: /relay/* and /api/relay/*
- Recommendations: /recommendations/*
- Activity logs: /activity/*
- Reports: /reports/*
- Forecast model: /model/*

## 12. Roles and Responsibilities

- Admin: global management, users/configuration oversight
- Coordinator: department-level monitoring and relay operations within scope
- Sergeant: higher-priority escalation actions and campus-level intervention
- Class Representative: first responder for room-level anomaly checks

## 13. Troubleshooting

Backend fails to start:
- Verify DB_URL is PostgreSQL and reachable.
- Ensure port 5000 is free or set PORT in environment.

Flutter shows stale analyzer errors:
- Run flutter pub get.
- Restart Dart Analysis Server in VS Code.

No notifications/emails:
- Verify notify and anomaly alert routers are mounted at startup logs.
- Check SMTP credentials in [backend/.env](backend/.env).

No relay action:
- Verify relay mappings and device online state.
- Verify role token and department scope for coordinator actions.

## 14. Security and Production Notes

- Replace default JWT secret with a strong secret.
- Store secrets via secure environment management (not plaintext in repo).
- Restrict CORS origins in production.
- Enable structured logging and centralized monitoring.
- Use HTTPS/TLS and secure database/network policies.

## 15. Development Command Summary

```powershell
# Backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend\requirements.txt
python backend\db_init.py
python backend\start_server.py

# Frontend
flutter pub get
flutter run
```
