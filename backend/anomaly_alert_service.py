"""
Anomaly Alert Progression Service - Implements staged escalation.
Escalation windows: class rep (0-5 min) → coordinator (5-10 min)
→ sergeant (10-15 min) → auto-cutoff (15+ min).

In-app notifications are written to the notifications table via notify_api.
Email alerts are sent via notify_api SMTP helpers.
"""
from datetime import datetime, timedelta
from typing import Optional, List
import asyncio
import sys
import os
import importlib
from urllib.parse import quote
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


def _load_alert_mail_service():
    import importlib.util as _ilu
    _here = os.path.dirname(os.path.abspath(__file__))
    _fp = os.path.join(_here, "alert_mail_service.py")
    _spec = _ilu.spec_from_file_location("alert_mail_service", _fp)
    _mod = _ilu.module_from_spec(_spec)
    sys.modules.setdefault("alert_mail_service", _mod)
    _spec.loader.exec_module(_mod)
    return _mod


try:
    _mail_mod = _load_alert_mail_service()
    _alert_mailer = _mail_mod.AlertMailService()
    print("[Anomaly Alert Service] alert_mail_service loaded [OK]")
except Exception as _e:
    _alert_mailer = None
    print(f"[Anomaly Alert Service] alert_mail_service not available: {_e}")

# Escalation schedule (absolute minutes from first_detected_at).
STAGE_CLASS_REP_MINUTES = 0
STAGE_COORDINATOR_MINUTES = 5
STAGE_SERGEANT_MINUTES = 10
AUTO_CUTOFF_THRESHOLD_MINUTES = 15
MAX_REMINDER_MINUTES = 120  # stop everything after 2 hours as a safety bound
PUBLIC_BASE_URL = os.environ.get("ALERT_PUBLIC_BASE_URL", "http://127.0.0.1:5000")
FRONTEND_BASE_URL = os.environ.get("FRONTEND_BASE_URL", os.environ.get("PUBLIC_BASE_URL", PUBLIC_BASE_URL))


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
                                SELECT COALESCE(NULLIF(cr.email, ''), cr.username), COALESCE(cr.name, cr.username)
                FROM class_rep_room_mapping m
                                JOIN class_representatives cr
                                    ON UPPER(COALESCE(NULLIF(cr.email, ''), cr.username)) = UPPER(m.class_rep_email)
                WHERE m.room_id = :room_id
                  AND m.is_active = TRUE
                ORDER BY m.created_at DESC
            """), {"room_id": room_id}).fetchall()
            return list(rows or [])

    def _get_active_sergeants(self) -> List[tuple]:
        """Return active sergeants (email, name).
        Sergeants are campus-level and are notified at the final escalation stage.
        """
        with engine.connect() as conn:
            rows = conn.execute(text("""
                SELECT COALESCE(NULLIF(email, ''), name), name
                FROM sergeants
                WHERE COALESCE(is_active, 1) = 1
                ORDER BY created_at DESC
            """)).fetchall()
            return list(rows or [])

    def _resolve_recipient_email(self, recipient: str, recipient_type: str) -> str:
        candidate = (recipient or '').strip()
        if '@' in candidate:
            return candidate

        try:
            with engine.connect() as conn:
                if recipient_type == 'coordinator':
                    row = conn.execute(text("""
                        SELECT email
                        FROM coordinators
                        WHERE UPPER(coordinator_id) = UPPER(:u)
                           OR UPPER(COALESCE(email, '')) = UPPER(:u)
                        ORDER BY created_at DESC
                        LIMIT 1
                    """), {"u": candidate}).fetchone()
                elif recipient_type == 'class_rep':
                    row = conn.execute(text("""
                        SELECT email
                        FROM class_representatives
                        WHERE UPPER(COALESCE(username, '')) = UPPER(:u)
                           OR UPPER(COALESCE(ktu_id, '')) = UPPER(:u)
                           OR UPPER(COALESCE(email, '')) = UPPER(:u)
                        ORDER BY created_at DESC
                        LIMIT 1
                    """), {"u": candidate}).fetchone()
                elif recipient_type == 'sergeant':
                    row = conn.execute(text("""
                        SELECT email
                        FROM sergeants
                        WHERE UPPER(COALESCE(email, '')) = UPPER(:u)
                           OR UPPER(COALESCE(name, '')) = UPPER(:u)
                        ORDER BY created_at DESC
                        LIMIT 1
                    """), {"u": candidate}).fetchone()
                else:
                    row = None

            resolved = (row[0] if row else '') if row else ''
            resolved = (resolved or '').strip()
            return resolved if '@' in resolved else candidate
        except Exception:
            return candidate

    def _classify_severity(self, anomaly_type: str, power: Optional[float], anomaly_score: Optional[float]) -> dict:
        """Return severity level + color code for notification rendering.

        Levels are NORMAL / MEDIUM / HIGH.
        """
        p = float(power or 0.0)
        s = float(anomaly_score) if anomaly_score is not None else None

        level = "NORMAL"
        color_name = "Green"
        color_hex = "#2E7D32"

        if anomaly_type == "usage_without_occupancy":
            if p >= 120 or (s is not None and s <= -0.20):
                level, color_name, color_hex = "HIGH", "Red", "#D32F2F"
            elif p >= 50 or (s is not None and s <= -0.10):
                level, color_name, color_hex = "MEDIUM", "Amber", "#F57C00"
        else:
            if p >= 150 or (s is not None and s <= -0.25):
                level, color_name, color_hex = "HIGH", "Red", "#D32F2F"
            elif p >= 80 or (s is not None and s <= -0.12):
                level, color_name, color_hex = "MEDIUM", "Amber", "#F57C00"

        return {
            "level": level,
            "color_name": color_name,
            "color_hex": color_hex,
        }

    def _recommended_next_steps(self, recipient_type: str, anomaly_type: str, severity_level: str) -> str:
        """Return short role-specific recommendation text."""
        if recipient_type == "class_rep":
            if anomaly_type == "usage_without_occupancy":
                return (
                    "Immediate step: check the classroom now, turn off unnecessary loads, "
                    "and update status in the app."
                )
            return (
                "Immediate step: check the room for high-consuming devices, reduce non-essential "
                "usage, and confirm normal state."
            )

        if recipient_type == "coordinator":
            if severity_level == "HIGH":
                return (
                    "Immediate step: contact class rep now, verify room condition, and trigger rapid "
                    "department-level response if unresolved."
                )
            return (
                "Immediate step: verify with class rep, monitor trend for 5 minutes, and escalate if it persists."
            )

        # sergeant
        if severity_level == "HIGH":
            return (
                "Immediate step: inspect room physically and prepare direct relay intervention if unsafe or unresolved."
            )
        return (
            "Immediate step: validate on-site status and keep relay action readiness while coordinator follow-up continues."
        )

    def _format_role_message(self, recipient_type: str, alert_data: dict) -> tuple[str, str, str, str]:
        """Build role-aware title/message and return with severity metadata.

        Returns: title, message, severity_level, severity_color_hex
        """
        room_id = alert_data.get("room_id", "")
        room_name = alert_data.get("room_name", room_id)
        department = alert_data.get("department", "")
        power = alert_data.get("power")
        score = alert_data.get("anomaly_score")
        anomaly_type = alert_data.get("anomaly_type") or "high_unrecognized_usage"
        stage = str(alert_data.get("stage", "escalation")).replace("_", " ")

        reason_text = (
            "Usage without occupancy"
            if anomaly_type == "usage_without_occupancy"
            else "High/unrecognized usage"
        )

        sev = self._classify_severity(anomaly_type, power, score)
        severity_level = sev["level"]
        severity_color = sev["color_hex"]
        severity_text = f"{severity_level} ({sev['color_name']}, {severity_color})"
        recommendation = self._recommended_next_steps(recipient_type, anomaly_type, severity_level)

        if recipient_type == "class_rep":
            title = f"[{severity_level}] Classroom Alert - {room_name}"
            power_text = f"{float(power):.2f}W" if power is not None else "N/A"
            message = (
                f"Classroom {room_name} ({room_id}) in {department} has an active energy anomaly. "
                f"Alert Type: {reason_text}. "
                f"Severity: {severity_text}. "
                f"Current Power: {power_text}. "
                f"Stage: {stage}. "
                f"What to do now: Visit the room, verify occupancy and loads, switch off unnecessary devices, "
                f"then acknowledge/resolve in the app once stable. "
                f"Recommendation: {recommendation}"
            )
            return title, message, severity_level, severity_color

        # coordinator + sergeant include anomaly score
        score_text = f"{float(score):.4f}" if score is not None else "N/A"
        power_text = f"{float(power):.2f}W" if power is not None else "N/A"

        role_label = "Coordinator" if recipient_type == "coordinator" else "Sergeant"
        title = f"[{severity_level}] {role_label} Escalation - {room_name}"
        message = (
            f"Room: {room_name} ({room_id}), Department: {department}. "
            f"Alert Type: {reason_text}. "
            f"Severity: {severity_text}. "
            f"Power: {power_text}. "
            f"Anomaly Score: {score_text}. "
            f"Stage: {stage}. "
            f"Recommendation: {recommendation}"
        )
        return title, message, severity_level, severity_color
    
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
        Escalation flow:
        - 0-5 min: class rep only
        - 5-10 min: coordinator
        - 10-15 min: sergeant
        - 15+ min unresolved usage_without_occupancy: auto-cutoff

        alert_count tracks escalation stages already sent:
        1=class rep, 2=coordinator, 3=sergeant.
        """
        try:
            now = datetime.utcnow()
            # Make first_detected tz-naive for comparison
            if first_detected.tzinfo is not None:
                first_detected = first_detected.replace(tzinfo=None)
            minutes_elapsed = (now - first_detected).total_seconds() / 60

            # Stop everything after 1 hour
            if minutes_elapsed >= MAX_REMINDER_MINUTES:
                print(f"[Reminder] Room {room_id}: max escalation window reached, stopping reminders.")
                with engine.begin() as uc:
                    uc.execute(text(
                        "UPDATE anomaly_alert_tracking SET status = 'expired' WHERE id = :id"
                    ), {"id": alert_id})
                return

            # Recovery path: ensure first-stage class rep notification exists.
            if alert_count < 1:
                await self.send_alert(
                    alert_id,
                    room_id,
                    anomaly_log_id,
                    alert_count,
                    STAGE_CLASS_REP_MINUTES,
                    STAGE_COORDINATOR_MINUTES,
                    conn,
                    target_roles=["class_rep"],
                    stage_label="class_rep_first_5min",
                )
                return

            if alert_count < 2 and minutes_elapsed >= STAGE_COORDINATOR_MINUTES:
                print(f"[Escalation] Room {room_id}: notifying coordinator at {minutes_elapsed:.1f} min")
                await self.send_alert(
                    alert_id,
                    room_id,
                    anomaly_log_id,
                    alert_count,
                    STAGE_COORDINATOR_MINUTES,
                    STAGE_SERGEANT_MINUTES,
                    conn,
                    target_roles=["coordinator"],
                    stage_label="coordinator_5_to_10min",
                )
                return

            if alert_count < 3 and minutes_elapsed >= STAGE_SERGEANT_MINUTES:
                print(f"[Escalation] Room {room_id}: notifying sergeant at {minutes_elapsed:.1f} min")
                await self.send_alert(
                    alert_id,
                    room_id,
                    anomaly_log_id,
                    alert_count,
                    STAGE_SERGEANT_MINUTES,
                    AUTO_CUTOFF_THRESHOLD_MINUTES,
                    conn,
                    target_roles=["sergeant"],
                    stage_label="sergeant_10_to_15min",
                )
                return

            if minutes_elapsed >= AUTO_CUTOFF_THRESHOLD_MINUTES:
                # Cut power only for occupancy-mismatch anomaly after full staged escalation.
                anomaly_type_row = conn.execute(text("""
                    SELECT anomaly_type
                    FROM anomaly_alert_tracking
                    WHERE id = :id
                    LIMIT 1
                """), {"id": alert_id}).fetchone()
                tracked_type = (anomaly_type_row[0] if anomaly_type_row else None) or ""
                if tracked_type == "usage_without_occupancy":
                    await self.trigger_auto_cutoff(alert_id, room_id, conn)

        except Exception as e:
            print(f"[Anomaly Alert] Error handling alert for room {room_id}: {e}")
    
    async def send_alert(
        self, alert_id: int, room_id: str, anomaly_log_id: Optional[int],
        alert_count: int, current_interval: int, next_interval: int, conn
        , target_roles: Optional[List[str]] = None, stage_label: str = "escalation"
    ):
        """Send alert to the selected recipient roles for the current escalation stage."""
        try:
            target_roles = target_roles or ["class_rep", "coordinator"]

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
                SELECT COALESCE(NULLIF(email, ''), coordinator_id), name FROM coordinators
                WHERE UPPER(department) = UPPER(:dept)
                ORDER BY created_at DESC
            """), {"dept": department}).fetchall()

            class_rep_infos = self._get_class_reps_for_room(room_id)
            sergeant_infos = self._get_active_sergeants()
            
            alert_message = {
                "room_id": room_id,
                "room_name": room_name,
                "department": department,
                "alert_count": alert_count + 1,
                "stage": stage_label,
                "current_interval": f"{current_interval} minutes" if current_interval > 0 else "Continuous",
                "next_interval": f"{next_interval} minutes" if next_interval > 0 else "Auto-cutoff imminent",
                "power": anomaly_power,
                "anomaly_score": anomaly_score,
                "anomaly_type": anomaly_type,
                "action_required": (
                    "Class representative action required (within first 5 minutes)."
                    if "class_rep" in target_roles
                    else "Coordinator escalation: anomaly still unresolved after 5 minutes."
                    if "coordinator" in target_roles
                    else "Sergeant escalation: unresolved after 10 minutes. Immediate intervention required."
                ),
            }
            
            print(f"[Anomaly Alert] {alert_message}")
            
            # In production, send email/SMS/push notifications
            # For now, we'll log to database as notifications
            if "coordinator" in target_roles and coordinator_infos:
                for coordinator_info in coordinator_infos:
                    self.create_notification(conn, coordinator_info[0], "coordinator", alert_message)
            
            if "class_rep" in target_roles and class_rep_infos:
                for class_rep_info in class_rep_infos:
                    self.create_notification(conn, class_rep_info[0], "class_rep", alert_message)
            elif "class_rep" in target_roles:
                print(f"[Anomaly Alert] No class-rep mapping for room {room_id}; class-rep notification skipped.")

            if "sergeant" in target_roles and sergeant_infos:
                for sergeant_info in sergeant_infos:
                    self.create_notification(conn, sergeant_info[0], "sergeant", alert_message)
            
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
            recipient_email = self._resolve_recipient_email(recipient_email, recipient_type)
            room_id = alert_data.get("room_id", "")
            room_name = alert_data.get("room_name", room_id)
            department = alert_data.get("department", "")
            power = alert_data.get("power")
            score = alert_data.get("anomaly_score")
            alert_count = alert_data.get("alert_count", 1)
            action = alert_data.get("action_required", "Requires attention")

            title, message, severity_level, severity_color = self._format_role_message(recipient_type, alert_data)
            is_first_alert = (alert_count <= 1)

            # 1) In-app notification: upsert so re-alerts refresh existing unresolved thread
            if _notify:
                notif_score = None if recipient_type == "class_rep" else (float(score) if score is not None else None)
                if is_first_alert:
                    _notify.create_in_app_notification(
                        recipient_email=recipient_email,
                        recipient_type=recipient_type,
                        department=department,
                        room_id=room_id,
                        room_name=room_name,
                        title=title,
                        message=message,
                        power=float(power) if power is not None else None,
                        anomaly_score=notif_score,
                    )
                else:
                    try:
                        from sqlalchemy import text as _text
                        with _notify.engine.begin() as _nc:
                            updated = _nc.execute(
                                _text("""
                                    UPDATE notifications
                                    SET title      = :title,
                                        message    = :msg,
                                        created_at = NOW()
                                    WHERE recipient_email = :email
                                                                            AND recipient_type = :rtype
                                      AND room_id = :room_id
                                      AND COALESCE(is_resolved, FALSE) = FALSE
                                    RETURNING id
                                """),
                                {
                                    "title": title,
                                    "msg": message,
                                    "email": recipient_email,
                                                                        "rtype": recipient_type,
                                    "room_id": room_id,
                                },
                            ).fetchone()
                            if not updated:
                                _notify.create_in_app_notification(
                                    recipient_email=recipient_email,
                                    recipient_type=recipient_type,
                                    department=department,
                                    room_id=room_id,
                                    room_name=room_name,
                                    title=title,
                                    message=message,
                                    power=float(power) if power is not None else None,
                                    anomaly_score=notif_score,
                                )
                    except Exception as _ue:
                        print(f"[Notify] Re-alert upsert error: {_ue}")

            # 2) Email alert
            if _alert_mailer and _alert_mailer.is_configured() and ('@' in recipient_email):
                role_label = recipient_type.replace('_', ' ').title()
                resolve_link = (
                    f"{PUBLIC_BASE_URL}/anomaly-alerts/resolve-alert-link"
                    f"?room_id={quote(room_id)}&resolved_by={quote(recipient_email)}"
                )
                severity_badge = (
                    f"<span style='display:inline-block;padding:4px 10px;border-radius:999px;'"
                    f"background:{severity_color};color:#fff;font-weight:700;'>"
                    f"{severity_level}</span>"
                )
                # role-specific intro and tone
                intro = {
                    'class_rep': "Hello Class Representative,",
                    'coordinator': "Hello Coordinator,",
                    'sergeant': "Hello Sergeant,",
                }.get(recipient_type, "Hello,")

                role_note = {
                    'class_rep': 'Please verify the room immediately and update the app once resolved.',
                    'coordinator': 'Please coordinate with the class rep and confirm the situation; escalate if unresolved.',
                    'sergeant': 'Please prepare to intervene if the issue persists; physical inspection may be required.',
                }.get(recipient_type, '')

                score_block = '' if recipient_type == 'class_rep' else f"<tr style=\"background:#f9f9f9;\"><td style=\"padding:8px;color:#666;\">Anomaly Score</td><td style=\"padding:8px;\">{score}</td></tr>"

                email_html = f"""
                <html><body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:20px;">
                    <div style="background:white;border-radius:8px;padding:30px;max-width:640px;margin:0 auto;box-shadow:0 4px 12px rgba(0,0,0,0.08);">
                        <div style="background:{severity_color};color:white;padding:18px;border-radius:6px;margin-bottom:18px;">
                            <h1 style="margin:0;font-size:20px;">{severity_level} Alert — {room_name}</h1>
                        </div>
                        <p style="margin:0 0 12px 0;color:#333;font-size:15px;"><strong>{intro}</strong> {role_note}</p>
                        <table style="width:100%;border-collapse:collapse;font-size:14px;color:#333;">
                            <tr><td style="padding:8px;color:#666;width:36%;">Room</td><td style="padding:8px;font-weight:700;">{room_name}</td></tr>
                            <tr style="background:#fafafa;"><td style="padding:8px;color:#666;">Department</td><td style="padding:8px;font-weight:700;">{department}</td></tr>
                            <tr><td style="padding:8px;color:#666;">Power Reading</td><td style="padding:8px;font-weight:700;color:#d32f2f;">{power if power is not None else 'N/A'} W</td></tr>
                            {score_block}
                            <tr><td style="padding:8px;color:#666;">Alert #</td><td style="padding:8px;">{alert_count}</td></tr>
                        </table>
                        <div style="margin:18px 0;padding:12px;border-radius:6px;background:#f1f8ff;border:1px solid #dbeafe;color:#0b5394;">
                            <strong>Quick Action:</strong> {action}
                        </div>
                        <div style="text-align:center;margin:20px 0;">
                            <a href="{resolve_link}" style="display:inline-block;background:#1e88e5;color:#fff;text-decoration:none;padding:12px 20px;border-radius:8px;font-weight:700;">Resolve / Acknowledge</a>
                            <div style="margin-top:10px;color:#666;font-size:13px;">Clicking the button will acknowledge this alert and stop further escalation for this room.</div>
                        </div>
                        <p style="color:#777;font-size:12px;margin-top:8px;">If you prefer to manage alerts from the dashboard, visit <a href="{FRONTEND_BASE_URL}" style="color:#1e88e5;">ENERGIA Dashboard</a>.</p>
                        <hr style="border:none;border-top:1px solid #eee;margin:18px 0;" />
                        <p style="color:#999;font-size:12px;margin:0;">This is an automated notification from ENERGIA. Replying to this email is not monitored.</p>
                    </div>
                </body></html>
                """
                try:
                    _alert_mailer.send_html_email(
                        subject=title,
                        html_body=email_html,
                        recipients=[recipient_email],
                    )
                    print(f"  -> Dedicated alert email sent to {recipient_type}: {recipient_email}")
                except Exception as email_err:
                    print(f"  -> Dedicated alert email failed for {recipient_email}: {email_err}")
                    # Fallback to existing notify_api SMTP sender if available — ensure HTML body used
                    if _notify and getattr(_notify, 'SMTP_PASSWORD', None):
                        try:
                            _notify._send_email(
                                subject=title,
                                body=email_html,
                                recipients=[recipient_email],
                            )
                            print(f"  -> Fallback notify_api email sent to {recipient_type}: {recipient_email}")
                        except Exception as fallback_err:
                            print(f"  -> Fallback notify_api email failed for {recipient_email}: {fallback_err}")
            elif _notify and _notify.SMTP_PASSWORD and ('@' in recipient_email):
                # Legacy path when dedicated mail service is not configured.
                try:
                    # Send the same HTML email for consistency
                    _notify._send_email(
                        subject=title,
                        body=email_html,
                        recipients=[recipient_email],
                    )
                    print(f"  -> Legacy notify_api email sent to {recipient_type}: {recipient_email}")
                except Exception as legacy_err:
                    print(f"  -> Legacy notify_api email failed for {recipient_email}: {legacy_err}")
            else:
                print(f"  -> Email skipped (dedicated + legacy SMTP not configured) for {recipient_email}")

            print(f"  -> In-app notification saved for {recipient_type}: {recipient_email} | Room: {room_name}")

        except Exception as e:
            print(f"[Anomaly Alert] Error in create_notification: {e}")
    
    async def trigger_auto_cutoff(self, alert_id: int, room_id: str, conn):
        """Trigger automatic power cutoff after full staged escalation window."""
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
                        "reason": "Automatic cutoff after 15-minute unresolved anomaly escalation"
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
                    sergeants = self._get_active_sergeants()
                    msg = (
                        f"Power was cut OFF automatically for {room_name} ({room_id}) due to "
                        f"unresolved anomaly after staged escalation (class rep → coordinator → sergeant)."
                    )
                    if _notify and coords:
                        for coord in coords:
                            _notify.create_in_app_notification(coord[0], "coordinator", dept, room_id, room_name,
                                                               "Auto Power Cut OFF", msg)
                    if _notify and reps:
                        for rep in reps:
                            _notify.create_in_app_notification(rep[0], "class_rep", dept, room_id, room_name,
                                                               "Auto Power Cut OFF", msg)
                    if _notify and sergeants:
                        for sgt in sergeants:
                            _notify.create_in_app_notification(sgt[0], "sergeant", dept, room_id, room_name,
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
                    "description": f"Automatic power cutoff for {room_id} after 15-minute staged alert escalation",
                    "room_id": room_id,
                    "status": "success" if cutoff_success else "failed"
                })
            
            print(f"[Auto-Cutoff] Power cutoff {'succeeded' if cutoff_success else 'failed'} for room {room_id}")
        
        except Exception as e:
            print(f"[Auto-Cutoff] Error in auto-cutoff: {e}")
    
    async def create_anomaly_alert(self, room_id: str, anomaly_log_id: Optional[int] = None):
        """
        Create anomaly alert tracking record and immediately notify class reps only.
        The background loop handles staged escalation (5/10/15 min flow).
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
                    next_interval    = STAGE_COORDINATOR_MINUTES,
                    conn             = notif_conn,
                    target_roles     = ["class_rep"],
                    stage_label      = "class_rep_first_5min",
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

            self._mark_notifications_resolved(
                room_id,
                f"Resolved via alert link by {resolved_by_user_id}",
            )

            print(f"[Anomaly Alert] Resolved alert for room {room_id} by user {resolved_by_user_id}")
        
        except Exception as e:
            print(f"[Anomaly Alert] Error resolving alert: {e}")


# Singleton instance
anomaly_alert_service = AnomalyAlertService()


# FastAPI endpoints for manual control
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
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


@app.get("/resolve-alert-link")
@app.get("/resolve-alert-link/")
async def resolve_alert_link(room_id: str, resolved_by: str):
    """Resolve an alert from a button in an email message."""
    try:
        await anomaly_alert_service.resolve_anomaly_alert(room_id, resolved_by)
        # Render a friendly acknowledgement page and redirect back to frontend dashboard
        return HTMLResponse(
            content=(
                "<html><head><meta charset='utf-8' />"
                "<meta name='viewport' content='width=device-width,initial-scale=1' />"
                "<title>Alert Acknowledged</title></head>"
                "<body style='font-family:Arial,sans-serif;background:#f4f7fb;margin:0;padding:24px;'>"
                "<div style='max-width:680px;margin:0 auto;background:#fff;border-radius:12px;padding:24px;box-shadow:0 2px 10px rgba(0,0,0,.08);'>"
                "<h2 style='margin-top:0;color:#2e7d32;'>Alert acknowledged successfully</h2>"
                f"<p style='font-size:15px;color:#333;'>Room <strong>{room_id}</strong> has been marked resolved by <strong>{resolved_by}</strong>.</p>"
                "<p style='font-size:14px;color:#666;'>You will be redirected to the dashboard shortly.</p>"
                f"<p style='font-size:13px;color:#777;'>If you are not redirected, <a href=\"{FRONTEND_BASE_URL}\">click here to open the dashboard</a>.</p>"
                f"</div>"
                f"<script>setTimeout(function() {{ window.location.href = '{FRONTEND_BASE_URL}'; }}, 3000);</script>"
                "</body></html>"
            ),
            status_code=200,
        )
    except Exception as e:
        return HTMLResponse(
            content=(
                "<html><head><meta charset='utf-8' />"
                "<meta name='viewport' content='width=device-width,initial-scale=1' />"
                "<title>Unable to Resolve Alert</title></head>"
                "<body style='font-family:Arial,sans-serif;background:#fff7f7;margin:0;padding:24px;'>"
                "<div style='max-width:680px;margin:0 auto;background:#fff;border-radius:12px;padding:24px;border:1px solid #ffcdd2;'>"
                "<h2 style='margin-top:0;color:#c62828;'>Unable to acknowledge this alert</h2>"
                "<p style='font-size:15px;color:#333;'>Please reopen the link from the latest email or resolve the alert directly in the app.</p>"
                f"<p style='font-size:13px;color:#777;'>Details: {str(e)}</p>"
                f"<p style='font-size:13px;color:#777;'>You can also open the dashboard here: <a href=\"{FRONTEND_BASE_URL}\">open dashboard</a></p>"
                "</div></body></html>"
            ),
            status_code=500,
        )


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
