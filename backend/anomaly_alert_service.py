"""
Anomaly Alert Progression Service - Implements progressive alert reminders.
Reminder intervals: 3min → 5min → 7min from first detection.

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
                anomaly_type            TEXT,
                status                  TEXT        NOT NULL DEFAULT 'active',
                power_cut_at            TIMESTAMPTZ,
                power_restored_at       TIMESTAMPTZ,
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
        "ALTER TABLE anomaly_alert_tracking ADD COLUMN IF NOT EXISTS anomaly_type TEXT",
        "ALTER TABLE anomaly_alert_tracking ADD COLUMN IF NOT EXISTS power_restored_at TIMESTAMPTZ",
    ]:
        try:
            with engine.begin() as ac:
                ac.execute(text(col_sql))
        except Exception:
            pass
    print("[Anomaly Alert Service] anomaly_alert_tracking table ready.")


def _init_class_rep_room_mapping_table():
    """Mapping table to route class-rep notifications to the correct class/room only."""
    with engine.begin() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS class_rep_room_mapping (
                id               SERIAL PRIMARY KEY,
                room_id          TEXT NOT NULL,
                class_rep_email  TEXT NOT NULL,
                is_active        BOOLEAN NOT NULL DEFAULT TRUE,
                created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                UNIQUE(room_id, class_rep_email)
            )
        """))
        conn.execute(text(
            "CREATE INDEX IF NOT EXISTS idx_crrm_room_active ON class_rep_room_mapping(room_id, is_active)"
        ))
    print("[Anomaly Alert Service] class_rep_room_mapping table ready.")

try:
    _init_tracking_table()
except Exception as _tbl_err:
    print(f"[Anomaly Alert Service] Table init warning: {_tbl_err}")

try:
    _init_class_rep_room_mapping_table()
except Exception as _tbl_err:
    print(f"[Anomaly Alert Service] Mapping table init warning: {_tbl_err}")

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
    print("[Anomaly Alert Service] notify_api loaded [OK]")
except Exception as _e:
    _notify = None
    print(f"[Anomaly Alert Service] notify_api not available: {_e}")

# Reminder schedule (absolute minutes from first_detected_at).
# Example: if anomaly starts at 10:00, reminders fire at 10:03, 10:05, 10:07.
REMINDER_SCHEDULE = [3, 5, 7]
MAX_REMINDER_MINUTES = 60   # stop all reminders after 1 hour
AUTO_CUTOFF_THRESHOLD = 60  # auto power cutoff after 1 hour unresolved


def _is_test_identifier(value: str | None) -> bool:
    """Return True when an identifier appears to be test/demo/mock data."""
    token = (value or "").strip().upper()
    if not token:
        return False
    test_markers = ("TEST", "DEMO", "MOCK", "SAMPLE", "DUMMY")
    return any(marker in token for marker in test_markers)


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

    def _infer_anomaly_type(self, power: Optional[float], occupancy: Optional[int]) -> str:
        p = float(power or 0.0)
        occ = int(occupancy or 0)
        if occ <= 0 and p >= 20.0:
            return "usage_without_occupancy"
        return "high_unrecognized_usage"

    def _latest_room_snapshot(self, room_id: str):
        with engine.connect() as conn:
            return conn.execute(text("""
                SELECT id, ds, power, occupancy, anomaly_score, is_anomaly
                FROM anomaly_logs
                WHERE device_id = :room_id
                ORDER BY ds DESC
                LIMIT 1
            """), {"room_id": room_id}).fetchone()

    def _mark_notifications_resolved(self, room_id: str, note: str):
        if not _notify:
            return
        try:
            with _notify.engine.begin() as nc:
                nc.execute(text("""
                    UPDATE notifications
                    SET is_read = TRUE,
                        is_resolved = TRUE,
                        resolved_at = NOW(),
                        resolution_note = :note,
                        title = CONCAT('[RESOLVED] ', title)
                    WHERE room_id = :room_id
                      AND COALESCE(is_resolved, FALSE) = FALSE
                """), {"room_id": room_id, "note": note})
        except Exception as e:
            print(f"[Notify] Failed to mark notifications resolved for {room_id}: {e}")

    def _get_class_reps_for_room(self, room_id: str) -> List[tuple]:
        """Return mapped active class reps (email, name) for this room.
        Class-rep alerts are class/room-scoped and should not fan out department-wide.
        """
        with engine.connect() as conn:
            rows = conn.execute(text("""
                SELECT cr.email, COALESCE(cr.name, cr.username)
                FROM class_rep_room_mapping m
                JOIN class_representatives cr ON UPPER(cr.email) = UPPER(m.class_rep_email)
                WHERE m.room_id = :room_id
                  AND m.is_active = TRUE
                ORDER BY m.created_at DESC
            """), {"room_id": room_id}).fetchall()
            return list(rows or [])
    
    async def process_active_anomalies(self):
        """Process all active anomalies and send alerts based on progression."""
        try:
            with engine.connect() as conn:
                # Get active anomaly alerts
                active_alerts = conn.execute(text("""
                    SELECT id, room_id, anomaly_log_id, first_detected_at,
                           last_alert_sent_at, alert_count, current_interval_minutes,
                           anomaly_type
                    FROM anomaly_alert_tracking
                    WHERE status = 'active'
                      AND UPPER(room_id) NOT LIKE '%TEST%'
                      AND UPPER(room_id) NOT LIKE '%DEMO%'
                      AND UPPER(room_id) NOT LIKE '%MOCK%'
                """)).fetchall()
                
                for alert in active_alerts:
                    alert_id, room_id, anomaly_log_id, first_detected, last_alert_sent, alert_count, current_interval, anomaly_type = alert

                    # Auto-resolve when anomaly no longer active for this room/type.
                    snap = self._latest_room_snapshot(room_id)
                    if not snap or int(snap[5] or 0) not in (1, -1):
                        with engine.begin() as rc:
                            rc.execute(text("""
                                UPDATE anomaly_alert_tracking
                                SET status = 'auto_resolved', resolved_at = NOW()
                                WHERE id = :id
                            """), {"id": alert_id})
                        self._mark_notifications_resolved(room_id, "Auto-resolved: anomaly cleared from live stream")
                        continue

                    current_type = self._infer_anomaly_type(snap[2], snap[3])
                    if anomaly_type and current_type != anomaly_type:
                        with engine.begin() as rc:
                            rc.execute(text("""
                                UPDATE anomaly_alert_tracking
                                SET status = 'type_switched', resolved_at = NOW()
                                WHERE id = :id
                            """), {"id": alert_id})
                        self._mark_notifications_resolved(room_id, f"Auto-resolved: anomaly type changed to {current_type}")
                        # New type should create a new tracked alert
                        await self.create_anomaly_alert(room_id, int(snap[0]))
                        continue

                    await self.handle_alert_progression(
                        alert_id, room_id, anomaly_log_id,
                        first_detected, last_alert_sent,
                        alert_count, current_interval, conn
                    )

            # Handle rooms where power was cut due to unresolved occupancy-mismatch anomaly.
            await self.process_power_cut_alerts()
        
        except Exception as e:
            print(f"[Anomaly Alert Service] Error processing anomalies: {e}")
    
    async def handle_alert_progression(
        self, alert_id: int, room_id: str, anomaly_log_id: Optional[int],
        first_detected: datetime, last_alert_sent: Optional[datetime],
        alert_count: int, current_interval: int, conn
    ):
        """
        Fires reminders at: 3, 5, 7 minutes after first detection.
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

            anomaly_type = self._infer_anomaly_type(anomaly_power, 0)
            if anomaly_log_id:
                try:
                    with engine.connect() as _tc:
                        occ_row = _tc.execute(text("SELECT occupancy FROM anomaly_logs WHERE id = :id"), {"id": anomaly_log_id}).fetchone()
                        anomaly_type = self._infer_anomaly_type(anomaly_power, occ_row[0] if occ_row else 0)
                except Exception:
                    pass
            
            # Get all coordinators for this department so primary + proxy users are both notified.
            coordinator_infos = conn.execute(text("""
                SELECT email, name FROM coordinators
                WHERE UPPER(department) = UPPER(:dept)
                ORDER BY created_at DESC
            """), {"dept": department}).fetchall()

            class_rep_infos = self._get_class_reps_for_room(room_id)
            
            alert_message = {
                "room_id": room_id,
                "room_name": room_name,
                "department": department,
                "alert_count": alert_count + 1,
                "current_interval": f"{current_interval} minutes" if current_interval > 0 else "Continuous",
                "next_interval": f"{next_interval} minutes" if next_interval > 0 else "Auto-cutoff imminent",
                "power": anomaly_power,
                "anomaly_score": anomaly_score,
                "anomaly_type": anomaly_type,
                "action_required": "Please investigate immediately" if next_interval >= 7 else "Requires attention",
            }
            
            print(f"[Anomaly Alert] {alert_message}")
            
            # In production, send email/SMS/push notifications
            # For now, we'll log to database as notifications
            if coordinator_infos:
                for coordinator_info in coordinator_infos:
                    self.create_notification(conn, coordinator_info[0], "coordinator", alert_message)
            
            if class_rep_infos:
                for class_rep_info in class_rep_infos:
                    self.create_notification(conn, class_rep_info[0], "class_rep", alert_message)
            else:
                print(f"[Anomaly Alert] No class-rep mapping for room {room_id}; class-rep notification skipped.")
            
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

            # Auto-cutoff rule for unresolved occupancy-mismatch anomalies.
            # Trigger when the escalation reaches the 7-minute reminder stage.
            if anomaly_type == "usage_without_occupancy" and current_interval >= 7:
                await self.trigger_auto_cutoff(alert_id, room_id, conn)
        
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
            reason_text = "Usage without occupancy" if alert_data.get("anomaly_type") == "usage_without_occupancy" else "High/unrecognized usage"
            message = (
                "An energy anomaly was detected in " + room_name +
                " (" + department + " department). " +
                "Power: " + str(power) + "W | Anomaly Score: " + str(score) + ". " +
                "Reason: " + reason_text + ". Action: " + str(action)
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
                    # Re-alert: update existing unresolved row (single alert thread per room)
                    try:
                        from sqlalchemy import text as _text
                        with _notify.engine.begin() as _nc:
                            updated = _nc.execute(_text("""
                                UPDATE notifications
                                SET title      = :title,
                                    message    = :msg,
                                    created_at = NOW()
                                WHERE recipient_email = :email
                                  AND room_id = :room_id
                                  AND COALESCE(is_resolved, FALSE) = FALSE
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

            # Notify coordinator and class rep that system cut power automatically.
            try:
                with engine.connect() as ic:
                    room_info = ic.execute(text("""
                        SELECT room_name, department FROM rooms WHERE room_id = :room_id LIMIT 1
                    """), {"room_id": room_id}).fetchone()
                    room_name = room_info[0] if room_info else room_id
                    dept = room_info[1] if room_info and room_info[1] else "admin"
                    coords = ic.execute(text("SELECT email FROM coordinators WHERE UPPER(department) = UPPER(:d)"), {"d": dept}).fetchall()
                    reps = self._get_class_reps_for_room(room_id)
                    msg = (
                        f"Power was cut OFF automatically for {room_name} ({room_id}) due to "
                        f"unresolved anomaly: usage without occupancy."
                    )
                    if _notify and coords:
                        for coord in coords:
                            _notify.create_in_app_notification(coord[0], "coordinator", dept, room_id, room_name,
                                                               "Auto Power Cut OFF", msg)
                    if _notify and reps:
                        for rep in reps:
                            _notify.create_in_app_notification(rep[0], "class_rep", dept, room_id, room_name,
                                                               "Auto Power Cut OFF", msg)
            except Exception as _ne:
                print(f"[Auto-Cutoff] Notification error: {_ne}")
            
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
            if _is_test_identifier(room_id):
                print(f"[Anomaly Alert] Skipping test/demo room: {room_id}")
                return

            inferred_type = "high_unrecognized_usage"
            if anomaly_log_id:
                with engine.connect() as tc:
                    _r = tc.execute(text("SELECT power, occupancy FROM anomaly_logs WHERE id = :id"), {"id": anomaly_log_id}).fetchone()
                    if _r:
                        inferred_type = self._infer_anomaly_type(_r[0], _r[1])

            # Check for existing active alert
            with engine.connect() as chk_conn:
                existing = chk_conn.execute(text("""
                    SELECT id, anomaly_type, status FROM anomaly_alert_tracking
                    WHERE room_id = :room_id AND status IN ('active','power_cut')
                    ORDER BY first_detected_at DESC
                    LIMIT 1
                """), {"room_id": room_id}).fetchone()

            if existing:
                existing_id, existing_type, existing_status = existing
                if (existing_type or "") == inferred_type:
                    # Same anomaly type persists: keep single alert thread, do not re-create.
                    with engine.begin() as uc:
                        uc.execute(text("""
                            UPDATE anomaly_alert_tracking
                            SET anomaly_log_id = COALESCE(:log_id, anomaly_log_id)
                            WHERE id = :id
                        """), {"id": existing_id, "log_id": anomaly_log_id})
                    print(f"[Anomaly Alert] Existing {inferred_type} alert for {room_id}, deduped")
                    return

                # Different anomaly type: close old thread and open a new one.
                with engine.begin() as uc:
                    uc.execute(text("""
                        UPDATE anomaly_alert_tracking
                        SET status = 'type_switched', resolved_at = NOW()
                        WHERE id = :id
                    """), {"id": existing_id})
                self._mark_notifications_resolved(room_id, f"Auto-resolved: anomaly changed to {inferred_type}")

            # Insert tracking record
            with engine.begin() as ins_conn:
                row = ins_conn.execute(text("""
                    INSERT INTO anomaly_alert_tracking
                        (room_id, anomaly_log_id, first_detected_at,
                         alert_count, current_interval_minutes, anomaly_type, status)
                    VALUES
                        (:room_id, :log_id, NOW(), 0, 0, :atype, 'active')
                    RETURNING id
                """), {"room_id": room_id, "log_id": anomaly_log_id, "atype": inferred_type}).fetchone()
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

    async def process_power_cut_alerts(self):
        """If occupancy returns in a power-cut room, auto-restore relay ON and notify users."""
        try:
            with engine.connect() as conn:
                cut_rows = conn.execute(text("""
                    SELECT id, room_id FROM anomaly_alert_tracking
                    WHERE status = 'power_cut'
                """)).fetchall()

            for cut_id, room_id in cut_rows:
                with engine.connect() as conn:
                    latest = conn.execute(text("""
                        SELECT occupancy, ds
                        FROM sensor_data
                        WHERE device_id = :room_id
                        ORDER BY ds DESC
                        LIMIT 1
                    """), {"room_id": room_id}).fetchone()

                if not latest:
                    continue
                occupancy = int(latest[0] or 0)
                if occupancy <= 0:
                    continue

                restored = False
                try:
                    relay_api_url = os.getenv("RELAY_API_URL", "http://localhost:5000")
                    resp = requests.post(
                        f"{relay_api_url}/relay/auto-cutoff",
                        json={
                            "room_id": room_id,
                            "action": "ON",
                            "reason": "Auto restore when occupancy detected again"
                        },
                        timeout=10,
                    )
                    restored = resp.status_code == 200
                except Exception as e:
                    print(f"[Auto-Restore] Relay call failed for {room_id}: {e}")

                if not restored:
                    continue

                with engine.begin() as conn:
                    conn.execute(text("""
                        UPDATE anomaly_alert_tracking
                        SET status = 'auto_restored',
                            power_restored_at = NOW(),
                            resolved_at = NOW()
                        WHERE id = :id
                    """), {"id": cut_id})

                self._mark_notifications_resolved(room_id, "Auto-restored: occupancy detected and relay turned ON")

                try:
                    with engine.connect() as ic:
                        room_info = ic.execute(text("""
                            SELECT room_name, department FROM rooms WHERE room_id = :room_id LIMIT 1
                        """), {"room_id": room_id}).fetchone()
                        room_name = room_info[0] if room_info else room_id
                        dept = room_info[1] if room_info and room_info[1] else "admin"
                        coords = ic.execute(text("SELECT email FROM coordinators WHERE UPPER(department) = UPPER(:d)"), {"d": dept}).fetchall()
                        reps = self._get_class_reps_for_room(room_id)
                        msg = (
                            f"Power was restored (ON) automatically for {room_name} ({room_id}) "
                            f"because occupancy was detected again."
                        )
                        if _notify and coords:
                            for coord in coords:
                                _notify.create_in_app_notification(coord[0], "coordinator", dept, room_id, room_name,
                                                                   "Auto Power Restore ON", msg)
                        if _notify and reps:
                            for rep in reps:
                                _notify.create_in_app_notification(rep[0], "class_rep", dept, room_id, room_name,
                                                                   "Auto Power Restore ON", msg)
                except Exception as _ne:
                    print(f"[Auto-Restore] Notification error: {_ne}")
        except Exception as e:
            print(f"[Auto-Restore] Processing error: {e}")
    
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
                  AND UPPER(a.room_id) NOT LIKE '%TEST%'
                  AND UPPER(a.room_id) NOT LIKE '%DEMO%'
                  AND UPPER(a.room_id) NOT LIKE '%MOCK%'
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
