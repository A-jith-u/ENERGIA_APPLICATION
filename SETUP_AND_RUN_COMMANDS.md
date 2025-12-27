# Setup and Run Commands

Complete guide to set up and run the Energia application with all necessary commands.

## Prerequisites Installation

### Install PostgreSQL (if not using Docker)
```powershell
# Windows - using Chocolatey
choco install postgresql

# Or download from https://www.postgresql.org/download/windows/
```

### Install Python Dependencies (Backend)
```powershell
cd backend
pip install -r requirements.txt
pip install -r requirements_dev.txt
```

### Install Flutter Dependencies
```powershell
flutter pub get
```

---

## Option 1: Using Docker (Recommended)

### Start All Services with Docker Compose
```powershell
# Start PostgreSQL, MQTT, and Prophet services
docker-compose up -d

# View running containers
docker-compose ps

# Stop all services
docker-compose down

# Stop and remove all data
docker-compose down -v
```

### View Docker Logs
```powershell
# View all service logs
docker-compose logs -f

# View only database logs
docker-compose logs -f db

# View only prophet service logs
docker-compose logs -f prophet

# View only mqtt logs
docker-compose logs -f mqtt
```

---

## Option 2: Running Services Locally

### Start PostgreSQL Only
```powershell
# Windows using Docker
docker-compose up -d db

# Or if PostgreSQL is installed locally
# Start PostgreSQL service (Windows)
Start-Service postgresql-x64-15

# Check service status
Get-Service postgresql-x64-15
```

### Initialize Database
```powershell
cd backend
python db_init.py
```

### Start Backend Server (Python/FastAPI)
```powershell
cd backend

# Option A: Direct uvicorn
uvicorn app_main:app --host 0.0.0.0 --port 8000

# Option B: Using Python module
python -m uvicorn app_main:app --host 0.0.0.0 --port 8000

# With auto-reload for development
uvicorn app_main:app --host 0.0.0.0 --port 8000 --reload
```

### Start Frontend (Flutter)
```powershell
# In the root directory (flutter_application_1)

# Windows Desktop
flutter run -d windows

# Android Emulator (requires emulator to be running)
flutter run -d emulator-5554

# Chrome Web
flutter run -d chrome

# List available devices
flutter devices
```

---

## Database Access Commands

### Connect to PostgreSQL Database

#### Using psql (Command Line)
```powershell
# If PostgreSQL is running in Docker
psql -U postgres -h localhost -d energia

# If PostgreSQL is installed locally
psql -U postgres -h localhost -d energia -W

# When prompted for password, enter: postgres
```

#### Inside Docker Container
```powershell
# Access PostgreSQL from inside the container
docker exec -it flutter_application_1-db-1 psql -U postgres -d energia

# Find the correct container name first
docker ps | findstr db
```

### Common PostgreSQL Commands
```sql
-- List all databases
\l

-- Connect to energia database
\c energia

-- List all tables
\dt

-- Describe users table
\d users

-- Describe sensor_data table
\d sensor_data

-- Count users
SELECT COUNT(*) FROM users;

-- View all users
SELECT id, username, role, department, created_at FROM users;

-- View sensor data
SELECT * FROM sensor_data LIMIT 10;

-- View database size
SELECT pg_size_pretty(pg_database_size('energia'));

-- Exit psql
\q
```

---

## Development Workflow

### Complete Setup for First Time

```powershell
# 1. Start Docker services
docker-compose up -d

# 2. Wait a few seconds for services to initialize
Start-Sleep -Seconds 5

# 3. Check if services are running
docker-compose ps

# 4. Install Python dependencies (from backend directory)
cd backend
pip install -r requirements.txt
pip install -r requirements_dev.txt

# 5. Install Flutter dependencies (from root directory)
cd ..
flutter pub get

# 6. Verify database is accessible
docker exec -it flutter_application_1-db-1 psql -U postgres -d energia -c "SELECT COUNT(*) FROM users;"
```

### Run Full Application Stack

```powershell
# Terminal 1: Start Docker and backend
cd e:\Flutter\flutter_application_1
docker-compose up -d
Start-Sleep -Seconds 3
cd backend
uvicorn app_main:app --host 0.0.0.0 --port 8000

# Terminal 2: Start Flutter app
cd e:\Flutter\flutter_application_1
flutter run -d windows

# Terminal 3 (Optional): Monitor database
docker-compose logs -f db
```

---

## Verification Commands

### Check Services Status
```powershell
# Check if backend is running
Test-NetConnection -ComputerName localhost -Port 8000

# Check if database is running
Test-NetConnection -ComputerName localhost -Port 5432

# Check if MQTT is running
Test-NetConnection -ComputerName localhost -Port 1883
```

### Check Logs
```powershell
# Backend logs (if running in terminal)
# Check the running terminal for output

# Docker service logs
docker-compose logs -f prophet

# Database logs
docker-compose logs -f db
```

### Test Backend API
```powershell
# Test if backend is running
curl http://localhost:8000/docs

# Or using PowerShell
Invoke-WebRequest http://localhost:8000/docs
```

---

## Cleanup and Reset

### Remove All Docker Containers and Data
```powershell
# Stop all services
docker-compose down

# Remove all data volumes
docker-compose down -v

# Prune unused Docker resources
docker system prune -a
```

### Clean Flutter Build
```powershell
# Clean Flutter cache
flutter clean

# Get dependencies again
flutter pub get
```

### Clean Backend Cache
```powershell
# Remove Python cache files
Remove-Item -Recurse -Force backend/__pycache__
Remove-Item -Recurse -Force backend/.pytest_cache
```

---

## Troubleshooting

### Port Already in Use
```powershell
# Find process using port 5432 (PostgreSQL)
netstat -ano | findstr :5432

# Find process using port 8000 (Backend)
netstat -ano | findstr :8000

# Kill process by PID
Stop-Process -Id <PID> -Force
```

### Database Connection Issues
```powershell
# Test connection to PostgreSQL
psql -U postgres -h localhost -d energia -c "SELECT 1"

# Check Docker logs
docker-compose logs db

# Restart database
docker-compose restart db
```

### Backend Import Errors
```powershell
# Verify dependencies
pip list | findstr sqlalchemy|fastapi|pydantic|mqtt

# Reinstall requirements
pip install -r requirements.txt --force-reinstall
```

### Flutter Build Issues
```powershell
# Clean and rebuild
flutter clean
flutter pub get
flutter run -d windows --verbose
```

---

## API Endpoints

Once backend is running, access:

- **API Documentation (Swagger UI)**: http://localhost:8000/docs
- **Alternative API Docs (ReDoc)**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health (if implemented)
 - **Update Profile**: POST http://localhost:8000/auth/update-profile (returns refreshed JWT)
- **Request Password Reset (OTP)**: POST http://localhost:8000/auth/request-password-reset `{ "username": "<email-or-ktu-id>" }`
- **Confirm Password Reset**: POST http://localhost:8000/auth/confirm-password-reset `{ "username": "<email-or-ktu-id>", "otp": "123456", "new_password": "NewPass" }` (OTP valid 5 minutes)

---

## Environment Variables

Default environment variables are set in `docker-compose.yml`:

```
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
POSTGRES_DB: energia
DB_URL: postgresql://postgres:postgres@db:5432/energia
MQTT_BROKER: mqtt
```

To use custom values, edit `docker-compose.yml` or create a `.env` file.

---

## Quick Reference Cheat Sheet

```powershell
# Start everything
docker-compose up -d && cd backend && uvicorn app_main:app --reload

# Connect to database
psql -U postgres -h localhost -d energia

# Run Flutter app
flutter run -d windows

# View logs
docker-compose logs -f

# Stop everything
docker-compose down

# Clean rebuild
flutter clean && flutter pub get && docker-compose down -v && docker-compose up -d
```

---

## Notes

- Default password for PostgreSQL is `postgres` (change in production)
- Backend API runs on port 8000
- PostgreSQL runs on port 5432
- MQTT broker runs on port 1883
- Make sure Docker Desktop is running before using docker-compose commands
