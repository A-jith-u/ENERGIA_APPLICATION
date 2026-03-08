"""
Anomaly Alert Progression Service - Implements progressive alert system
with escalating intervals: continuous (5min) → 3min →  5min → 7min → auto power cutoff
"""
from datetime import datetime, timedelta
from typing import Optional, List
import asyncio
from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv
import requests

load_dotenv()

import config

DB_URL = config.get_db_url()
engine = create_engine(DB_URL, pool_pre_ping=True, pool_size=5, max_overflow=10)

# Alert progression schedule in minutes
ALERT_INTERVALS = [
    0,  # Continuous alerts for first 5 minutes
    3,  # Then 3-minute intervals
    5,  # Then 5-minute intervals
    7,  # Then 7-minute intervals, after which power is cut
]

INITIAL_CONTINUOUS_DURATION = 5  # Minutes of continuous alerts
AUTO_CUTOFF_THRESHOLD = 7  # Minutes - trigger power cutoff after this interval


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
        """Handle alert progression for a single anomaly."""
        try:
            now = datetime.utcnow()
            time_since_first = now - first_detected
            minutes_elapsed = time_since_first.total_seconds() / 60
            
            # Determine if we're in continuous alert phase (first 5 minutes)
            in_continuous_phase = minutes_elapsed <= INITIAL_CONTINUOUS_DURATION
            
            if in_continuous_phase:
                # Send continuous alerts (no interval checking)
                should_send = True
                next_interval = 0
            else:
                # Calculate time since last alert
                if last_alert_sent:
                    time_since_last = now - last_alert_sent
                    minutes_since_last = time_since_last.total_seconds() / 60
                else:
                    minutes_since_last = float('inf')  # Never sent, so send immediately
                
                # Determine current interval index
                interval_index = min(
                    (minutes_elapsed - INITIAL_CONTINUOUS_DURATION) // 5,  # Rough estimate
                    len(ALERT_INTERVALS) - 1
                )
                
                # Get the appropriate interval
                if current_interval == 0 and minutes_elapsed > INITIAL_CONTINUOUS_DURATION:
                    next_interval = ALERT_INTERVALS[1]  # Move to 3-minute interval
                elif current_interval == 3:
                    next_interval = 5
                elif current_interval == 5:
                    next_interval = 7
                else:
                    next_interval = current_interval
                
                # Check if enough time has passed since last alert
                should_send = minutes_since_last >= next_interval
                
                # Check if we've reached auto-cutoff threshold (7-minute interval)
                if current_interval == AUTO_CUTOFF_THRESHOLD and minutes_since_last >= AUTO_CUTOFF_THRESHOLD:
                    await self.trigger_auto_cutoff(alert_id, room_id, conn)
                    return  # Stop processing this alert after cutoff
            
            if should_send:
                await self.send_alert(
                    alert_id, room_id, anomaly_log_id,
                    alert_count, current_interval, next_interval if not in_continuous_phase else 0, conn
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
            
            room_name = room_info[0] if room_info else room_id
            department = room_info[1] if room_info else "Unknown"
            
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
                WHERE department = :dept AND is_active = 1
                LIMIT 1
            """), {"dept": department}).fetchone()
            
            class_rep_info = conn.execute(text("""
                SELECT email, name FROM class_representatives
                WHERE department = :dept AND is_active = 1
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
            
            # Update alert tracking with new interval
            with engine.begin() as update_conn:
                update_conn.execute(text("""
                    UPDATE anomaly_alert_tracking
                    SET last_alert_sent_at = NOW(),
                        alert_count = :count,
                        current_interval_minutes = :interval
                    WHERE id = :id
                """), {
                    "id": alert_id,
                    "count": alert_count + 1,
                    "interval": next_interval
                })
        
        except Exception as e:
            print(f"[Anomaly Alert] Error sending alert: {e}")
    
    def create_notification(self, conn, recipient_email: str, recipient_type: str, alert_data: dict):
        """Create a notification record (placeholder for real notification system)."""
        try:
            # This would integrate with your notification system
            # For now, just log it
            print(f"  → Notification to {recipient_type}: {recipient_email}")
            print(f"     Room: {alert_data['room_name']}, Alert #{alert_data['alert_count']}")
        except Exception as e:
            print(f"Error creating notification: {e}")
    
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
        """Create a new anomaly alert tracking record."""
        try:
            with engine.begin() as conn:
                # Check if there's already an active alert for this room
                existing = conn.execute(text("""
                    SELECT id FROM anomaly_alert_tracking
                    WHERE room_id = :room_id AND status = 'active'
                """), {"room_id": room_id}).fetchone()
                
                if existing:
                    print(f"[Anomaly Alert] Active alert already exists for room {room_id}")
                    return
                
                # Create new alert
                conn.execute(text("""
                    INSERT INTO anomaly_alert_tracking
                    (room_id, anomaly_log_id, first_detected_at, alert_count,
                     current_interval_minutes, status)
                    VALUES
                    (:room_id, :anomaly_log_id, NOW(), 0, 0, 'active')
                """), {
                    "room_id": room_id,
                    "anomaly_log_id": anomaly_log_id
                })
                
                print(f"[Anomaly Alert] Created new alert tracking for room {room_id}")
        
        except Exception as e:
            print(f"[Anomaly Alert] Error creating alert: {e}")
    
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
