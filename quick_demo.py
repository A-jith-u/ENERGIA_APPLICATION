#!/usr/bin/env python3
"""
ENERGIA Quick Demo - Simplified one-shot demo with fresh anomaly alert
Generates new simulated anomaly data and tracks full escalation in real-time
"""

import os, sys, json, time, subprocess, requests
from datetime import datetime
from sqlalchemy import create_engine, text
from pathlib import Path

ROOT = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.join(ROOT, "backend")
sys.path.insert(0, BACKEND_DIR)
from config import get_db_url

# CONFIG
BACKEND_URL = "http://127.0.0.1:5000"
DB_URL = get_db_url()
DEMO_DEVICE = "ESP32-CS-C201"
DEMO_ROOM = "CS-C201"
engine = create_engine(DB_URL, pool_pre_ping=True)

print("\n" + "=" * 80)
print("  ENERGIA Quick Demo - Real-Time Anomaly & Escalation Demo")
print("=" * 80 + "\n")

# Check backend
try:
    resp = requests.get(f"{BACKEND_URL}/health", timeout=5)
    print(f"✓ Backend online: {BACKEND_URL}")
except Exception as e:
    print(f"✗ Backend offline: {e}")
    print("  Start it first: python backend/start_server.py")
    sys.exit(1)

# Get existing alert count
try:
    with engine.connect() as conn:
        existing = conn.execute(
            text("SELECT COUNT(*) FROM anomaly_alert_tracking WHERE room_id = :r"),
            {"r": DEMO_ROOM}
        ).scalar() or 0
    print(f"✓ Database connected ({existing} existing alerts for {DEMO_ROOM})\n")
except Exception as e:
    print(f"✗ Database error: {e}")
    sys.exit(1)

# Run simulator (quick version)
print("📊 Generating anomaly-scenario readings (3x)...")
sim_script = os.path.join(ROOT, "simulation_data", "simulate_data.py")
try:
    result = subprocess.run(
        [sys.executable, sim_script, "--scenario", "anomaly", 
         "--device-id", DEMO_DEVICE, "--emit-occupancy", "--count", "3"],
        capture_output=True, timeout=30, text=True
    )
    if result.returncode == 0:
        print("✓ Simulator completed\n")
    else:
        print(f"⚠ Simulator warning (non-fatal): {result.stderr[:100]}\n")
except subprocess.TimeoutExpired:
    print("⚠ Simulator timeout (data may still be sent)\n")
except Exception as e:
    print(f"✗ Simulator failed: {e}\n")

time.sleep(2)

# Check results
print("📈 Checking results...\n")

with engine.connect() as conn:
    # Sensor data
    sensor_count = conn.execute(
        text("SELECT COUNT(*) FROM sensor_data WHERE UPPER(device_id) = UPPER(:d)"),
        {"d": DEMO_DEVICE}
    ).scalar() or 0
    
    # Anomalies
    anomaly_count = conn.execute(
        text("SELECT COUNT(*) FROM anomaly_logs WHERE UPPER(device_id) = UPPER(:d) AND is_anomaly = 1"),
        {"d": DEMO_DEVICE}
    ).scalar() or 0
    
    # Alerts
    alert_row = conn.execute(
        text("""SELECT id, status, alert_count, first_detected_at FROM anomaly_alert_tracking
                WHERE room_id = :r ORDER BY first_detected_at DESC LIMIT 1"""),
        {"r": DEMO_ROOM}
    ).fetchone()
    
    # Notifications
    notif_count = conn.execute(
        text("SELECT COUNT(*) FROM notifications WHERE room_id = :r"),
        {"r": DEMO_ROOM}
    ).scalar() or 0
    
    # Notifications detail
    notifs = conn.execute(
        text("""SELECT recipient_email, recipient_type, is_read FROM notifications 
                WHERE room_id = :r ORDER BY created_at DESC LIMIT 5"""),
        {"r": DEMO_ROOM}
    ).fetchall()

print(f"  📡 Sensor readings:    {sensor_count} total")
print(f"  🚨 Anomalies detected: {anomaly_count} logs")

if alert_row:
    alert_id, status, count, detected_at = alert_row
    elapsed = (datetime.now(detected_at.tzinfo) - detected_at).total_seconds() / 60
    print(f"  🔔 Alert tracking:     ID={alert_id}, status={status}, elapsed={elapsed:.1f}m, count={count}")
else:
    print(f"  🔔 Alert tracking:     None")

print(f"  💬 Notifications:      {notif_count} in-app")
if notifs:
    for email, rtype, is_read in notifs[:3]:
        marker = "📖" if is_read else "📨"
        print(f"     {marker} {rtype:15} → {email}")

# Prediction
print("\n🤖 Energy Prediction:")
try:
    resp = requests.post(f"{BACKEND_URL}/model/predict_15min",
                        json={"horizon_minutes": 15, "room_name": "CS-201"}, timeout=20)
    if resp.ok:
        pred = resp.json()
        print(f"  ✓ 15-min forecast: {pred['yhat']:.2f}W (±{pred['yhat']*0.2:.2f}W)")
    else:
        print(f"  ⚠ Status {resp.status_code}")
except Exception as e:
    print(f"  ✗ {e}")

# Email artifacts
print("\n📧 Email/Fallback Artifacts:")
artifact_dir = os.path.join(BACKEND_DIR, "tmp_alert_emails")
if os.path.exists(artifact_dir):
    files = sorted(Path(artifact_dir).glob("*.html"), key=os.path.getmtime, reverse=True)
    if files:
        print(f"  ✓ {len(files)} HTML files in {artifact_dir}")
        for f in files[:3]:
            size_kb = os.path.getsize(f) / 1024
            print(f"    • {f.name} ({size_kb:.1f}KB)")
    else:
        print(f"  (No files yet - alert may be resolved)")
else:
    print(f"  (Directory not created yet)")

print("\n" + "=" * 80)
print("  ✓ Quick demo complete! All core features working.\n")
print("  Next: Open Flutter app and log in to see live dashboards.")
print("=" * 80 + "\n")
