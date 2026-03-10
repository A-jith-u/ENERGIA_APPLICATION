"""
Anomaly Alert Progression Service - Implements progressive alert system
with escalating intervals: continuous (5min) → 3min → 5min → 7min → auto power cutoff

In-app notifications are written to the notifications table via notify_api.
Email alerts are sent via notify_api SMTP helpers.
"""
from datetime import datetime, timedelta
from typing import Optional, List
import asyncio
import sys
import os
import importlib
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
import requests

load_dotenv()

import config

DB_URL = config.get_db_url()
engine = create_engine(DB_URL, pool_pre_ping=True, pool_size=5, max_overflow=10)

def _init_tracking_table():
    """Ensure anomaly_alert_tracking table exists — safe to call repeatedly."""
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS anomaly_alert_tracking (
                id                      SERIAL PRIMARY KEY,
                room_id                 TEXT        NOT NULL,
                anomaly_log_id          INTEGER,
                first_detected_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                last_alert_sent_at      TIMESTAMPTZ,
                last_reminder_time      TIMESTAMPTZ,
                alert_count             INTEGER     NOT NULL DEFAULT 0,
                reminder_count          INTEGER     NOT NULL DEFAULT 0,
                current_interval_minutes INTEGER    NOT NULL DEFAULT 0,
                status                  TEXT        NOT NULL DEFAULT 'active',
                power_cut_at            TIMESTAMPTZ,
                resolved_at             TIMESTAMPTZ,
                resolved_by_user_id     TEXT
            )
        """))
        conn.execute(text(
            "CREATE INDEX IF NOT EXISTS idx_aat_room_status ON anomaly_alert_tracking(room_id, status)"
        ))
    # Add new columns to existing tables (safe on re-run)
    for col_sql in [
        "ALTER TABLE anomaly_alert_tracking ADD COLUMN IF NOT EXISTS last_reminder_time TIMESTAMPTZ",
        "ALTER TABLE anomaly_alert_tracking ADD COLUMN IF NOT EXISTS reminder_count INTEGER NOT NULL DEFAULT 0",
    ]:
        try:
            with engine.begin() as ac:
                ac.execute(text(col_sql))
        except Exception:
            pass
    print("[Anomaly Alert Service] anomaly_alert_tracking table ready.")

try:
    _init_tracking_table()
except Exception as _tbl_err:
    print(f"[Anomaly Alert Service] Table init warning: {_tbl_err}")

# ── Load notify_api via direct file path (bypasses __init__.py) ──────────────
def _load_notify_api():
    import importlib.util as _ilu
    _here = os.path.dirname(os.path.abspath(__file__))
    _fp   = os.path.join(_here, "notify_api.py")
    _spec = _ilu.spec_from_file_location("notify_api", _fp)
    _mod  = _ilu.module_from_spec(_spec)
    sys.modules.setdefault("notify_api", _mod)
    _spec.loader.exec_module(_mod)
    return _mod

try:
    _notify = _load_notify_api()
    print("[Anomaly Alert Service] notify_api loaded ✅")
except Exception as _e:
    _notify = None
    print(f"[Anomaly Alert Service] notify_api not available: {_e}")

# Reminder schedule (minutes after first alert):
# 1st reminder: 1 min, 2nd: 5 min, 3rd: 10 min, 4th: 15 min,
# 5th: 30 min, 6th: 45 min, 7th: 60 min — then stop.
REMINDER_SCHEDULE = [1, 5, 10, 15, 30, 45, 60]   # minutes from first_detected_at
MAX_REMINDER_MINUTES = 60   # stop all reminders after 1 hour
AUTO_CUTOFF_THRESHOLD = 60  # auto power cutoff after 1 hour unresolved


class AnomalyAlertService:
    """Service to manage progressive anomaly alerts."""
    
    def __init__(self):
        self.running = False
    
    async def start(self):
        """Start the alert monitoring service."""
        self.running = True
        print("[Anomaly Alert Service] Starting...")
        
        while self.running:
            try:
                await self.process_active_anomalies()
                await asyncio.sleep(30)  # Check every 30 seconds
            except Exception as e:
                print(f"[Anomaly Alert Service] Error: {e}")
                await asyncio.sleep(60)  # Wait longer on error
    
    def stop(self):
        """Stop the alert monitoring service."""
        self.running = False
        print("[Anomaly Alert Service] Stopping...")
    
    async def process_active_anomalies(self):
        """Process all active anomalies and send alerts based on progression."""
        try:
            with engine.connect() as conn:
                # Get active anomaly alerts
                active_alerts = conn.execute(text("""
                    SELECT id, room_id, anomaly_log_id, first_detected_at,
                           last_alert_sent_at, alert_count, current_interval_minutes
                    FROM anomaly_alert_tracking
                    WHERE status = 'active'
                """)).fetchall()
                
                for alert in active_alerts:
                    alert_id, room_id, anomaly_log_id, first_detected, last_alert_sent, alert_count, current_interval = alert
                    await self.handle_alert_progression(
                        alert_id, room_id, anomaly_log_id,
                        first_detected, last_alert_sent,
                        alert_count, current_interval, conn
                    )
        
        except Exception as e:
            print(f"[Anomaly Alert Service] Error processing anomalies: {e}")
    
    async def handle_alert_progression(
        self, alert_id: int, room_id: str, anomaly_log_id: Optional[int],
        first_detected: datetime, last_alert_sent: Optional[datetime],
        alert_count: int, current_interval: int, conn
    ):
        """
        Fires reminders at: 1, 5, 10, 15, 30, 45, 60 minutes after first detection.
        Stops after 1 hour. alert_count tracks how many reminders have fired (0 = only
        the initial alert sent by create_anomaly_alert, not yet a reminder).
        """
        try:
            now = datetime.utcnow()
            # Make first_detected tz-naive for comparison
            if first_detected.tzinfo is not None:
                first_detected = first_detected.replace(tzinfo=None)
            minutes_elapsed = (now - first_detected).total_seconds() / 60

            # Stop everything after 1 hour
            if minutes_elapsed >= MAX_REMINDER_MINUTES:
                print(f"[Reminder] Room {room_id}: 1 hour passed, stopping reminders.")
                with engine.begin() as uc:
                    uc.execute(text(
                        "UPDATE anomaly_alert_tracking SET status = 'expired' WHERE id = :id"
                    ), {"id": alert_id})
                return

            # alert_count = number of reminders already sent (0-based after first alert)
            # Determine which reminder is next
            next_reminder_index = alert_count  # 0 = wait for 1-min mark, etc.
            if next_reminder_index >= len(REMINDER_SCHEDULE):
                return  # All reminders sent

            next_reminder_at = REMINDER_SCHEDULE[next_reminder_index]  # minutes

            if minutes_elapsed >= next_reminder_at:
                # Calculate what comes after this reminder
                if next_reminder_index + 1 < len(REMINDER_SCHEDULE):
                    next_next = REMINDER_SCHEDULE[next_reminder_index + 1]
                else:
                    next_next = MAX_REMINDER_MINUTES

                reminder_num = next_reminder_index + 1
                print(f"[Reminder #{reminder_num}] Room {room_id} at {minutes_elapsed:.1f} min")
                await self.send_alert(
                    alert_id, room_id, anomaly_log_id,
                    alert_count, int(next_reminder_at), int(next_next), conn
                )

        except Exception as e:
            print(f"[Anomaly Alert] Error handling alert for room {room_id}: {e}")
    
    async def send_alert(
        self, alert_id: int, room_id: str, anomaly_log_id: Optional[int],
        alert_count: int, current_interval: int, next_interval: int, conn
    ):
        """Send alert to coordinator and class rep."""
        try:
            # Get room details
            room_info = conn.execute(text("""
                SELECT room_name, department, floor_number
                FROM rooms
                WHERE room_id = :room_id
            """), {"room_id": room_id}).fetchone()

            room_name  = room_info[0] if room_info else room_id
            department = room_info[1] if room_info else None

            # If rooms.department is null/empty, fall back to 'admin'
            # so the admin coordinator at least gets the alert
            if not department:
                print(f"[Anomaly Alert] WARNING: room {room_id} has no department set. "
                      f"Run PUT /rooms/assign-departments to fix this. Falling back to 'admin'.")
                department = "admin"
            
            # Get anomaly details
            anomaly_power = None
            anomaly_score = None
            if anomaly_log_id:
                anomaly = conn.execute(text("""
                    SELECT power, anomaly_score
                    FROM anomaly_logs
                    WHERE id = :id
                """), {"id": anomaly_log_id}).fetchone()
                if anomaly:
                    anomaly_power, anomaly_score = anomaly
            
            # Get coordinator and class rep for this department/room
            coordinator_info = conn.execute(text("""
                SELECT email, name FROM coordinators
                WHERE department = :dept
                LIMIT 1
            """), {"dept": department}).fetchone()

            class_rep_info = conn.execute(text("""
                SELECT email, name FROM class_representatives
                WHERE department = :dept
                LIMIT 1
            """), {"dept": department}).fetchone()
            
            alert_message = {
                "room_id": room_id,
                "room_name": room_name,
                "department": department,
                "alert_count": alert_count + 1,
                "current_interval": f"{current_interval} minutes" if current_interval > 0 else "Continuous",
                "next_interval": f"{next_interval} minutes" if next_interval > 0 else "Auto-cutoff imminent",
                "power": anomaly_power,
                "anomaly_score": anomaly_score,
                "action_required": "Please investigate immediately" if next_interval >= 7 else "Requires attention",
            }
            
            print(f"[Anomaly Alert] {alert_message}")
            
            # In production, send email/SMS/push notifications
            # For now, we'll log to database as notifications
            if coordinator_info:
                self.create_notification(conn, coordinator_info[0], "coordinator", alert_message)
            
            if class_rep_info:
                self.create_notification(conn, class_rep_info[0], "class_rep", alert_message)
            
            # Update alert tracking
            with engine.begin() as update_conn:
                update_conn.execute(text("""
                    UPDATE anomaly_alert_tracking
                    SET last_alert_sent_at       = NOW(),
                        last_reminder_time       = NOW(),
                        alert_count              = :count,
                        reminder_count           = :count,
                        current_interval_minutes = :interval
                    WHERE id = :id
                """), {
                    "id":       alert_id,
                    "count":    alert_count + 1,
                    "interval": next_interval
                })
        
        except Exception as e:
            print(f"[Anomaly Alert] Error sending alert: {e}")
    
    def create_notification(self, conn, recipient_email: str, recipient_type: str, alert_data: dict):
        """
        Upsert in-app notification:
        - First alert: INSERT new row (is_read=false → badge fires)
        - Re-alerts:   UPDATE existing unresolved row (title, message, alert_count, is_read reset)
          This prevents notification spam while still re-triggering the badge.
        Also sends email on first alert only (not every re-alert minute).
        """
        try:
            room_id     = alert_data.get("room_id", "")
            room_name   = alert_data.get("room_name", room_id)
            department  = alert_data.get("department", "")
            power       = alert_data.get("power")
            score       = alert_data.get("anomaly_score")
            alert_count = alert_data.get("alert_count", 1)
            action      = alert_data.get("action_required", "Requires attention")

            title = "Anomaly Alert - " + room_name + " (Alert #" + str(alert_count) + ")"
            message = (
                "An energy anomaly was detected in " + room_name +
                " (" + department + " department). " +
                "Power: " + str(power) + "W | Anomaly Score: " + str(score) + ". " +
                "Action: " + str(action)
            )

            is_first_alert = (alert_count <= 1)

            # ── 1. In-app notification: upsert so re-alerts reset is_read (re-triggers badge)
            if _notify:
                if is_first_alert:
                    # First time: insert fresh notification
                    _notify.create_in_app_notification(
                        recipient_email = recipient_email,
                        recipient_type  = recipient_type,
                        department      = department,
                        room_id         = room_id,
                        room_name       = room_name,
                        title           = title,
                        message         = message,
                        power           = float(power) if power is not None else None,
                        anomaly_score   = float(score) if score is not None else None,
                    )
                else:
                    # Re-alert: update existing row, reset is_read so badge re-fires
                    try:
                        from sqlalchemy import text as _text
                        with _notify.engine.begin() as _nc:
                            updated = _nc.execute(_text("""
                                UPDATE notifications
                                SET title      = :title,
                                    message    = :msg,
                                    is_read    = FALSE,
                                    created_at = NOW()
                                WHERE recipient_email = :email
                                  AND room_id = :room_id
                                  AND is_read = TRUE
                                RETURNING id
                            """), {
                                "title":   title,
                                "msg":     message,
                                "email":   recipient_email,
                                "room_id": room_id,
                            }).fetchone()
                            if not updated:
                                # No resolved notification to update — insert new one
                                _notify.create_in_app_notification(
                                    recipient_email = recipient_email,
                                    recipient_type  = recipient_type,
                                    department      = department,
                                    room_id         = room_id,
                                    room_name       = room_name,
                                    title           = title,
                                    message         = message,
                                    power           = float(power) if power is not None else None,
                                    anomaly_score   = float(score) if score is not None else None,
                                )
                    except Exception as _ue:
                        print(f"[Notify] Re-alert upsert error: {_ue}")

            # ── 2. Email alert ────────────────────────────────────────────────
            if _notify and _notify.SMTP_PASSWORD:
                email_html = f"""
                <html><body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:20px;">
                  <div style="background:white;border-radius:8px;padding:30px;max-width:600px;
                              margin:0 auto;box-shadow:0 2px 4px rgba(0,0,0,0.1);">
                    <div style="background:#ff4444;color:white;padding:16px;border-radius:6px;margin-bottom:20px;">
                      <h2 style="margin:0;">⚠️ Energy Anomaly Detected</h2>
                    </div>
                    <table style="width:100%;border-collapse:collapse;">
                      <tr><td style="padding:8px;color:#666;">Room</td>
                          <td style="padding:8px;font-weight:bold;">{room_name}</td></tr>
                      <tr style="background:#f9f9f9;">
                          <td style="padding:8px;color:#666;">Department</td>
                          <td style="padding:8px;font-weight:bold;">{department}</td></tr>
                      <tr><td style="padding:8px;color:#666;">Power Reading</td>
                          <td style="padding:8px;font-weight:bold;color:#ff4444;">{power}W</td></tr>
                      <tr style="background:#f9f9f9;">
                          <td style="padding:8px;color:#666;">Anomaly Score</td>
                          <td style="padding:8px;">{score}</td></tr>
                      <tr><td style="padding:8px;color:#666;">Alert #</td>
                          <td style="padding:8px;">{alert_count}</td></tr>
                    </table>
                    <div style="background:#fff3cd;border-left:4px solid #ffc107;
                                padding:12px;margin:20px 0;border-radius:4px;">
                      <strong>Action Required:</strong> {action}
                    </div>
                    <p style="color:#999;font-size:12px;">
                      This is an automated alert from the ENERGIA monitoring system.
                    </p>
                  </div>
                </body></html>
                """
                try:
                    _notify._send_email(
                        subject    = title,
                        body       = email_html,
                        recipients = [recipient_email],
                    )
                    print(f"  → Email sent to {recipient_type}: {recipient_email}")
                except Exception as email_err:
                    # Email failure must not block the in-app notification
                    print(f"  → Email failed for {recipient_email}: {email_err}")
            else:
                print(f"  → Email skipped (SMTP not configured) for {recipient_email}")

            print(f"  → In-app notification saved for {recipient_type}: {recipient_email} | Room: {room_name}")

        except Exception as e:
            print(f"[Anomaly Alert] Error in create_notification: {e}")
    
    async def trigger_auto_cutoff(self, alert_id: int, room_id: str, conn):
        """Trigger automatic power cutoff after reaching 7-minute interval."""
        try:
            print(f"[Auto-Cutoff] Triggering power cutoff for room {room_id}")
            
            # Call relay control API to cut power
            try:
                # In production, call the relay API
                relay_api_url = os.getenv("RELAY_API_URL", "http://localhost:5000")
                response = requests.post(
                    f"{relay_api_url}/relay/auto-cutoff",
                    json={
                        "room_id": room_id,
                        "action": "OFF",
                        "reason": "Automatic cutoff after 7-minute anomaly alert escalation"
                    },
                    timeout=10
                )
                
                cutoff_success = response.status_code == 200
            except Exception as e:
                print(f"[Auto-Cutoff] Error calling relay API: {e}")
                cutoff_success = False
            
            # Update alert status
            with engine.begin() as update_conn:
                update_conn.execute(text("""
                    UPDATE anomaly_alert_tracking
                    SET status = 'power_cut',
                        power_cut_at = NOW()
                    WHERE id = :id
                """), {"id": alert_id})
            
            # Log the action
            with engine.begin() as log_conn:
                log_conn.execute(text("""
                    INSERT INTO activity_logs
                    (user_id, user_name, user_role, action_type, action_description,
                     resource_type, resource_id, status, timestamp)
                    VALUES
                    ('system', 'Anomaly Alert System', 'system', 'auto_power_cutoff',
                     :description, 'room', :room_id, :status, NOW())
                """), {
                    "description": f"Automatic power cutoff for {room_id} after 7-minute alert escalation",
                    "room_id": room_id,
                    "status": "success" if cutoff_success else "failed"
                })
            
            print(f"[Auto-Cutoff] Power cutoff {'succeeded' if cutoff_success else 'failed'} for room {room_id}")
        
        except Exception as e:
            print(f"[Auto-Cutoff] Error in auto-cutoff: {e}")
    
    async def create_anomaly_alert(self, room_id: str, anomaly_log_id: Optional[int] = None):
        """
        Create anomaly alert tracking record AND immediately fire the
        first in-app + email notification to coordinator and class rep.
        The background loop handles escalating re-alerts at 3/5/7 min.
        """
        try:
            # Check for existing active alert
            with engine.connect() as chk_conn:
                existing = chk_conn.execute(text("""
                    SELECT id FROM anomaly_alert_tracking
                    WHERE room_id = :room_id AND status = 'active'
                """), {"room_id": room_id}).fetchone()

            if existing:
                print(f"[Anomaly Alert] Active alert already exists for room {room_id}, skipping")
                return

            # Insert tracking record
            with engine.begin() as ins_conn:
                row = ins_conn.execute(text("""
                    INSERT INTO anomaly_alert_tracking
                        (room_id, anomaly_log_id, first_detected_at,
                         alert_count, current_interval_minutes, status)
                    VALUES
                        (:room_id, :log_id, NOW(), 0, 0, 'active')
                    RETURNING id
                """), {"room_id": room_id, "log_id": anomaly_log_id}).fetchone()
                new_alert_id = row[0] if row else None

            print(f"[Anomaly Alert] Created tracking record id={new_alert_id} for room {room_id}")

            # Immediately fire first notification — don't wait for background loop
            with engine.connect() as notif_conn:
                await self.send_alert(
                    alert_id         = new_alert_id,
                    room_id          = room_id,
                    anomaly_log_id   = anomaly_log_id,
                    alert_count      = 0,
                    current_interval = 0,
                    next_interval    = 3,
                    conn             = notif_conn,
                )

        except Exception as e:
            print(f"[Anomaly Alert] Error creating alert for room {room_id}: {e}")
    
    async def resolve_anomaly_alert(self, room_id: str, resolved_by_user_id: str):
        """Mark anomaly alert as resolved/acknowledged."""
        try:
            with engine.begin() as conn:
                conn.execute(text("""
                    UPDATE anomaly_alert_tracking
                    SET status = 'acknowledged',
                        resolved_at = NOW(),
                        resolved_by_user_id = :user_id
                    WHERE room_id = :room_id AND status = 'active'
                """), {
                    "room_id": room_id,
                    "user_id": resolved_by_user_id
                })
                
                print(f"[Anomaly Alert] Resolved alert for room {room_id} by user {resolved_by_user_id}")
        
        except Exception as e:
            print(f"[Anomaly Alert] Error resolving alert: {e}")


# Singleton instance
anomaly_alert_service = AnomalyAlertService()


# FastAPI endpoints for manual control
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Anomaly Alert API")


class CreateAlertRequest(BaseModel):
    room_id: str
    anomaly_log_id: Optional[int] = None


class ResolveAlertRequest(BaseModel):
    room_id: str
    resolved_by_user_id: str


@app.post("/create-alert")
async def create_alert(request: CreateAlertRequest):
    """Manually create an anomaly alert (typically called by anomaly detection system)."""
    await anomaly_alert_service.create_anomaly_alert(request.room_id, request.anomaly_log_id)
    return {"status": "success", "message": f"Alert created for room {request.room_id}"}


@app.post("/resolve-alert")
async def resolve_alert(request: ResolveAlertRequest):
    """Mark an anomaly alert as resolved."""
    await anomaly_alert_service.resolve_anomaly_alert(request.room_id, request.resolved_by_user_id)
    return {"status": "success", "message": f"Alert resolved for room {request.room_id}"}


@app.get("/active-alerts")
async def get_active_alerts():
    """Get all active anomaly alerts."""
    try:
        with engine.connect() as conn:
            alerts = conn.execute(text("""
                SELECT a.id, a.room_id, a.first_detected_at, a.last_alert_sent_at,
                       a.alert_count, a.current_interval_minutes, a.status,
                       r.room_name, r.department
                FROM anomaly_alert_tracking a
                LEFT JOIN rooms r ON a.room_id = r.room_id
                WHERE a.status = 'active'
                ORDER BY a.first_detected_at DESC
            """)).fetchall()
            
            result = []
            for alert in alerts:
                result.append({
                    "id": alert[0],
                    "room_id": alert[1],
                    "first_detected_at": alert[2].isoformat() if alert[2] else None,
                    "last_alert_sent_at": alert[3].isoformat() if alert[3] else None,
                    "alert_count": alert[4],
                    "current_interval_minutes": alert[5],
                    "status": alert[6],
                    "room_name": alert[7],
                    "department": alert[8],
                })
            
            return {
                "status": "success",
                "data": result,
                "count": len(result)
            }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    # Run the service
    import asyncio
    asyncio.run(anomaly_alert_service.start())
