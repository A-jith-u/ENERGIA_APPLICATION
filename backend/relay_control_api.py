"""
Relay Control API - Controls two-channel relay modules for automatic and manual
power cutoff in classrooms and departments.
"""
from datetime import datetime
from typing import Optional
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
from sqlalchemy import create_engine, text
import jwt
import os
import requests
from dotenv import load_dotenv

load_dotenv()

import config

DB_URL = config.get_db_url()
engine = create_engine(DB_URL, pool_pre_ping=True)

app = FastAPI(title="Relay Control API")

JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key")
ALGORITHM = "HS256"
RELAY_ONLINE_TIMEOUT_SECONDS = 180


class RelayControlRequest(BaseModel):
    """Model for relay control request."""
    room_id: str
    action: str  # 'ON' or 'OFF'
    reason: Optional[str] = None


class RoomRelayMapping(BaseModel):
    """Model for creating/updating room-relay mapping."""
    room_id: str
    relay_device_id: str
    relay_channel: int  # 1 or 2
    relay_pin: Optional[int] = None


def verify_token(authorization: Optional[str], required_roles: list):
    """Verify JWT token and check role authorization."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authentication required")
    
    token = authorization.replace("Bearer ", "")
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        role = payload.get("role")
        user_id = payload.get("sub") or payload.get("sergeant_id") or payload.get("user_id")
        user_name = payload.get("name") or payload.get("user_name")
        department = payload.get("department")
        
        if role not in required_roles:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. Required roles: {', '.join(required_roles)}"
            )
        
        return {"role": role, "user_id": user_id, "user_name": user_name, "department": department}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid token")


def queue_relay_command(device_id: str, action: str, user_id: str, user_name: str, reason: str = None) -> int:
    """
    Queue a relay command for ESP32 to poll and execute.
    This is more reliable than direct HTTP in campus networks.
    
    Returns command_id for tracking.
    """
    try:
        with engine.begin() as conn:
            # Insert command into queue
            result = conn.execute(text("""
                INSERT INTO relay_commands
                (device_id, command, sergeant_id, reason, status, created_at)
                VALUES (:device_id, :command, :user_id, :reason, 'PENDING', NOW())
                RETURNING id
            """), {
                "device_id": device_id,
                "command": action,
                "user_id": user_id,
                "reason": reason or f"{action} command by {user_name}"
            })
            
            command_id = result.fetchone()[0]
            print(f"[Relay Control] Command {command_id} queued: {action} for device {device_id}")
            return command_id
            
    except Exception as e:
        print(f"[Relay Control] Error queuing command: {e}")
        raise


def get_command_status(command_id: int) -> dict:
    """
    Check if a queued command has been executed.
    """
    try:
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT status, executed_at
                FROM relay_commands
                WHERE id = :command_id
            """), {"command_id": command_id}).fetchone()
            
            if result:
                return {
                    "status": result[0],
                    "executed_at": result[1].isoformat() if result[1] else None
                }
            return None
    except Exception as e:
        print(f"[Relay Control] Error checking command status: {e}")
        return None


@app.post("/control")
async def control_relay(request: RelayControlRequest, authorization: Optional[str] = Header(None)):
    """
    Control power relay for a specific room.
    Accessible by sergeants and admins.
    """
    try:
        # Verify authorization (sergeant, admin, or coordinator)
        user = verify_token(authorization, ["sergeant", "admin", "coordinator"])
        
        # Validate action
        if request.action.upper() not in ["ON", "OFF"]:
            raise HTTPException(status_code=400, detail="Action must be 'ON' or 'OFF'")
        
        with engine.begin() as conn:
            # Get relay mapping for the room
            mapping = conn.execute(text("""
                SELECT relay_device_id, relay_channel, relay_pin
                FROM room_relay_mapping
                WHERE room_id = :room_id
            """), {"room_id": request.room_id}).fetchone()
            
            if not mapping:
                raise HTTPException(
                    status_code=404,
                    detail=f"No relay mapping found for room {request.room_id}"
                )
            
            device_id, channel, pin = mapping

            # Coordinators can control only rooms in their own department.
            if user["role"] == "coordinator":
                room_dept_row = conn.execute(text("""
                    SELECT COALESCE(
                        NULLIF(TRIM(UPPER(r.department)), ''),
                        CASE
                            WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE'
                            ELSE UPPER(split_part(m.room_id, '-', 1))
                        END
                    ) AS department
                    FROM room_relay_mapping m
                    LEFT JOIN rooms r ON UPPER(r.room_id) = UPPER(m.room_id)
                    WHERE UPPER(m.room_id) = UPPER(:room_id)
                    LIMIT 1
                """), {"room_id": request.room_id}).fetchone()

                room_department = (room_dept_row[0] if room_dept_row else "") or ""
                user_department = (user.get("department") or "")
                if not user_department or room_department.upper() != user_department.strip().upper():
                    raise HTTPException(
                        status_code=403,
                        detail="Coordinator can only control relay for rooms in their own department",
                    )
            
            # Queue command for ESP32 to poll
            command_id = queue_relay_command(
                device_id=device_id,
                action=request.action.upper(),
                user_id=user["user_id"],
                user_name=user["user_name"],
                reason=request.reason
            )
            
            # Log the control action
            conn.execute(text("""
                INSERT INTO relay_control_logs
                (room_id, relay_channel, action, trigger_type, 
                 triggered_by_user_id, triggered_by_user_name, reason, timestamp)
                VALUES
                (:room_id, :channel, :action, 'manual',
                 :user_id, :user_name, :reason, NOW())
            """), {
                "room_id": request.room_id,
                "channel": channel,
                "action": request.action.upper(),
                "user_id": user["user_id"],
                "user_name": user["user_name"],
                "reason": request.reason or f"Manual {request.action.lower()} by {user['role']}"
            })
            
            return {
                "status": "queued",
                "message": f"Power {request.action.upper()} command queued for {request.room_id}",
                "room_id": request.room_id,
                "action": request.action.upper(),
                "command_id": command_id,
                "device_id": device_id,
                "note": "Command will execute within 5 seconds when device polls"
            }
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error controlling relay: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/auto-cutoff")
async def auto_cutoff_relay(request: RelayControlRequest):
    """
    Automatic power cutoff triggered by anomaly alert system.
    Internal API - no authentication required (called from backend services).
    """
    try:
        with engine.begin() as conn:
            # Get relay mapping
            mapping = conn.execute(text("""
                SELECT relay_device_id, relay_channel
                FROM room_relay_mapping
                WHERE room_id = :room_id
            """), {"room_id": request.room_id}).fetchone()
            
            if not mapping:
                print(f"[Auto-Cutoff] No relay mapping for room {request.room_id}")
                return {
                    "status": "skipped",
                    "message": f"No relay configured for {request.room_id}"
                }
            
            device_id, channel = mapping
            
            action = request.action.upper().strip()
            if action not in {"ON", "OFF"}:
                raise HTTPException(status_code=400, detail="Action must be ON or OFF")

            # Queue relay command
            command_id = queue_relay_command(
                device_id=device_id,
                action=action,
                user_id="system",
                user_name="Anomaly Alert System",
                reason=request.reason or (
                    "Automatic cutoff after unresolved anomaly" if action == "OFF"
                    else "Automatic restore after occupancy detected"
                )
            )
            
            # Log automatic cutoff
            conn.execute(text("""
                INSERT INTO relay_control_logs
                (room_id, relay_channel, action, trigger_type,
                 triggered_by_user_id, triggered_by_user_name, reason, timestamp)
                VALUES
                (:room_id, :channel, :action, 'auto',
                 'system', 'Anomaly Alert System', :reason, NOW())
            """), {
                "room_id": request.room_id,
                "channel": channel,
                "action": action,
                "reason": request.reason or (
                    "Automatic cutoff after unresolved anomaly" if action == "OFF"
                    else "Automatic restore after occupancy detected"
                )
            })
            
            return {
                "status": "queued",
                "message": f"Automatic power {action} queued for {request.room_id}",
                "room_id": request.room_id,
                "action": action,
                "command_id": command_id,
                "note": "Command will execute within 5 seconds"
            }
    
    except Exception as e:
        print(f"Error in auto-cutoff: {e}")
        return {
            "status": "error",
            "message": str(e)
        }


@app.get("/room-status/{room_id}")
async def get_room_relay_status(room_id: str, authorization: Optional[str] = Header(None)):
    """Get current relay status and recent control history for a room."""
    try:
        verify_token(authorization, ["sergeant", "admin", "coordinator"])
        
        with engine.connect() as conn:
            # Get relay mapping
            mapping = conn.execute(text("""
                SELECT relay_device_id, relay_channel
                FROM room_relay_mapping
                WHERE room_id = :room_id
            """), {"room_id": room_id}).fetchone()
            
            if not mapping:
                return {
                    "status": "success",
                    "room_id": room_id,
                    "relay_configured": False,
                    "message": "No relay configured for this room"
                }
            
            device_id, channel = mapping
            
            # Get recent control logs
            logs = conn.execute(text("""
                SELECT action, trigger_type, triggered_by_user_name, reason, timestamp
                FROM relay_control_logs
                WHERE room_id = :room_id
                ORDER BY timestamp DESC
                LIMIT 10
            """), {"room_id": room_id}).fetchall()
            
            control_history = []
            for log in logs:
                control_history.append({
                    "action": log[0],
                    "trigger_type": log[1],
                    "triggered_by": log[2],
                    "reason": log[3],
                    "timestamp": log[4].isoformat() if log[4] else None,
                })
            
            # Get last action
            last_action = control_history[0]["action"] if control_history else "UNKNOWN"
            
            return {
                "status": "success",
                "room_id": room_id,
                "relay_configured": True,
                "device_id": device_id,
                "channel": channel,
                "last_action": last_action,
                "control_history": control_history,
            }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/logs")
async def get_relay_control_logs(
    limit: int = 50,
    room_id: Optional[str] = None,
    authorization: Optional[str] = Header(None)
):
    """Get relay control logs with optional filtering."""
    try:
        verify_token(authorization, ["sergeant", "admin"])
        
        with engine.connect() as conn:
            query = """
                SELECT room_id, relay_channel, action, trigger_type,
                       triggered_by_user_name, reason, timestamp
                FROM relay_control_logs
            """
            params = {"limit": min(limit, 500)}
            
            if room_id:
                query += " WHERE room_id = :room_id"
                params["room_id"] = room_id
            
            query += " ORDER BY timestamp DESC LIMIT :limit"
            
            logs = conn.execute(text(query), params).fetchall()
            
            result = []
            for log in logs:
                result.append({
                    "room_id": log[0],
                    "relay_channel": log[1],
                    "action": log[2],
                    "trigger_type": log[3],
                    "triggered_by": log[4],
                    "reason": log[5],
                    "timestamp": log[6].isoformat() if log[6] else None,
                })
            
            return {
                "status": "success",
                "data": result,
                "count": len(result),
            }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/mapping")
async def create_room_relay_mapping(mapping: RoomRelayMapping, authorization: Optional[str] = Header(None)):
    """Create or update room-relay mapping. Admin only."""
    try:
        verify_token(authorization, ["admin"])
        
        if mapping.relay_channel not in [1, 2]:
            raise HTTPException(status_code=400, detail="Relay channel must be 1 or 2")
        
        with engine.begin() as conn:
            # Check if mapping exists
            existing = conn.execute(text("""
                SELECT id FROM room_relay_mapping WHERE room_id = :room_id
            """), {"room_id": mapping.room_id}).fetchone()
            
            if existing:
                # Update existing
                conn.execute(text("""
                    UPDATE room_relay_mapping
                    SET relay_device_id = :device_id,
                        relay_channel = :channel,
                        relay_pin = :pin,
                        updated_at = NOW()
                    WHERE room_id = :room_id
                """), {
                    "room_id": mapping.room_id,
                    "device_id": mapping.relay_device_id,
                    "channel": mapping.relay_channel,
                    "pin": mapping.relay_pin,
                })
                message = "Room relay mapping updated"
            else:
                # Insert new
                conn.execute(text("""
                    INSERT INTO room_relay_mapping
                    (room_id, relay_device_id, relay_channel, relay_pin, created_at, updated_at)
                    VALUES
                    (:room_id, :device_id, :channel, :pin, NOW(), NOW())
                """), {
                    "room_id": mapping.room_id,
                    "device_id": mapping.relay_device_id,
                    "channel": mapping.relay_channel,
                    "pin": mapping.relay_pin,
                })
                message = "Room relay mapping created"
            
            return {
                "status": "success",
                "message": message,
                "mapping": {
                    "room_id": mapping.room_id,
                    "relay_device_id": mapping.relay_device_id,
                    "relay_channel": mapping.relay_channel,
                    "relay_pin": mapping.relay_pin,
                }
            }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/mappings")
async def list_room_relay_mappings(authorization: Optional[str] = Header(None)):
    """List all room-relay mappings."""
    try:
        user = verify_token(authorization, ["sergeant", "admin", "coordinator"])
        
        with engine.connect() as conn:
            where_clause = ""
            params = {}
            if user["role"] == "coordinator":
                dept = (user.get("department") or "").strip()
                if not dept:
                    raise HTTPException(status_code=403, detail="Coordinator department missing in token")
                where_clause = """
                WHERE COALESCE(
                    NULLIF(TRIM(UPPER(r.department)), ''),
                    CASE
                        WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE'
                        ELSE UPPER(split_part(m.room_id, '-', 1))
                    END
                ) = UPPER(:department)
                """
                params["department"] = dept

            result = conn.execute(text(f"""
                SELECT m.room_id, m.relay_device_id, m.relay_channel, m.relay_pin,
                       r.room_name, r.department, r.floor_number
                FROM room_relay_mapping m
                LEFT JOIN rooms r ON m.room_id = r.room_id
                {where_clause}
                ORDER BY r.department, r.floor_number, r.room_name
            """), params).fetchall()
            
            mappings = []
            for row in result:
                mappings.append({
                    "room_id": row[0],
                    "relay_device_id": row[1],
                    "relay_channel": row[2],
                    "relay_pin": row[3],
                    "room_name": row[4],
                    "department": row[5],
                    "floor_number": row[6],
                })
            
            return {
                "status": "success",
                "data": mappings,
                "count": len(mappings),
            }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== ESP32 POLLING ENDPOINTS ====================

@app.get("/commands")
async def get_pending_commands(device_id: str):
    """
    ESP32 polls this endpoint to check for pending relay commands.
    Returns oldest unacknowledged command for the device.
    """
    try:
        with engine.connect() as conn:
            # Get oldest pending command
            result = conn.execute(text("""
                SELECT id, command, created_at
                FROM relay_commands
                WHERE device_id = :device_id
                AND status = 'PENDING'
                ORDER BY created_at ASC
                LIMIT 1
            """), {"device_id": device_id}).fetchone()
            
            if result:
                command_id, command, created_at = result
                return {
                    "command_id": command_id,
                    "command": command,
                    "device_id": device_id,
                    "timestamp": created_at.isoformat()
                }
            else:
                # No pending commands - return 204 No Content
                from fastapi import Response
                return Response(status_code=204)
                
    except Exception as e:
        print(f"Error fetching commands: {e}")
        raise HTTPException(status_code=500, detail=str(e))


class CommandAck(BaseModel):
    """Model for ESP32 command acknowledgment."""
    device_id: str
    command_id: int
    executed: bool
    new_state: str  # "ON" or "OFF"


@app.post("/commands/ack")
async def acknowledge_command(ack: CommandAck):
    """
    ESP32 acknowledges command execution.
    Updates command status and device relay state.
    """
    try:
        with engine.begin() as conn:
            # Update command status
            conn.execute(text("""
                UPDATE relay_commands
                SET status = :status, executed_at = NOW()
                WHERE id = :command_id AND device_id = :device_id
            """), {
                "status": 'EXECUTED' if ack.executed else 'FAILED',
                "command_id": ack.command_id,
                "device_id": ack.device_id
            })
            
            # Update device relay state
            conn.execute(text("""
                INSERT INTO relay_states (device_id, state, last_updated)
                VALUES (:device_id, :state, NOW())
                ON CONFLICT (device_id)
                DO UPDATE SET state = :state, last_updated = NOW()
            """), {
                "device_id": ack.device_id,
                "state": ack.new_state
            })
            
            return {
                "success": True,
                "message": f"Command {ack.command_id} acknowledged",
                "device_id": ack.device_id,
                "new_state": ack.new_state
            }
            
    except Exception as e:
        print(f"Error acknowledging command: {e}")
        raise HTTPException(status_code=500, detail=str(e))


class RelayStatusReport(BaseModel):
    """Model for ESP32 relay status report."""
    device_id: str
    relay_state: str  # "ON" or "OFF"
    timestamp: int


@app.post("/status")
async def report_relay_status(status: RelayStatusReport):
    """
    ESP32 reports current relay status.
    Called on startup and after each command execution.
    """
    try:
        with engine.begin() as conn:
            # Update relay state
            conn.execute(text("""
                INSERT INTO relay_states (device_id, state, last_updated)
                VALUES (:device_id, :state, NOW())
                ON CONFLICT (device_id)
                DO UPDATE SET state = :state, last_updated = NOW()
            """), {
                "device_id": status.device_id,
                "state": status.relay_state
            })
            
            return {
                "success": True,
                "device_id": status.device_id,
                "state": status.relay_state
            }
            
    except Exception as e:
        print(f"Error reporting status: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/device-status/{device_id}")
async def get_device_status(device_id: str, authorization: Optional[str] = Header(None)):
    """
    Get current relay status for a specific device.
    Used by Sergeant dashboard to show live relay state.
    """
    try:
        verify_token(authorization, ["sergeant", "admin", "coordinator"])
        
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT device_id, state, last_updated
                FROM relay_states
                WHERE device_id = :device_id
            """), {"device_id": device_id}).fetchone()
            
            if result:
                device_id, state, last_updated = result
                age = datetime.now() - last_updated
                is_stale = age.total_seconds() > RELAY_ONLINE_TIMEOUT_SECONDS
                
                return {
                    "device_id": device_id,
                    "state": state,
                    "last_updated": last_updated.isoformat(),
                    "is_online": not is_stale,
                    "age_seconds": int(age.total_seconds())
                }
            else:
                return {
                    "device_id": device_id,
                    "state": "UNKNOWN",
                    "is_online": False,
                    "message": "No status reported yet"
                }
                
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/all-device-status")
async def get_all_device_status(authorization: Optional[str] = Header(None)):
    """
    Get status of all relay devices.
    Used for Sergeant overview dashboard.
    """
    try:
        user = verify_token(authorization, ["sergeant", "admin", "coordinator"])
        
        with engine.connect() as conn:
            if user["role"] == "coordinator":
                dept = (user.get("department") or "").strip()
                if not dept:
                    raise HTTPException(status_code=403, detail="Coordinator department missing in token")

                results = conn.execute(text("""
                    SELECT rs.device_id, rs.state, rs.last_updated
                    FROM relay_states rs
                    JOIN room_relay_mapping m ON UPPER(rs.device_id) = UPPER(m.relay_device_id)
                    LEFT JOIN rooms r ON UPPER(r.room_id) = UPPER(m.room_id)
                    WHERE COALESCE(
                        NULLIF(TRIM(UPPER(r.department)), ''),
                        CASE
                            WHEN UPPER(split_part(m.room_id, '-', 1)) = 'CS' THEN 'CSE'
                            ELSE UPPER(split_part(m.room_id, '-', 1))
                        END
                    ) = UPPER(:department)
                    ORDER BY rs.device_id
                """), {"department": dept}).fetchall()
            else:
                results = conn.execute(text("""
                    SELECT device_id, state, last_updated
                    FROM relay_states
                    ORDER BY device_id
                """)).fetchall()
            
            now = datetime.now()
            devices = []
            
            for row in results:
                device_id, state, last_updated = row
                age = (now - last_updated).total_seconds()
                
                devices.append({
                    "device_id": device_id,
                    "state": state,
                    "last_updated": last_updated.isoformat(),
                    "is_online": age < RELAY_ONLINE_TIMEOUT_SECONDS
                })
            
            online_count = sum(1 for d in devices if d["is_online"])
            
            return {
                "devices": devices,
                "total_devices": len(devices),
                "online_count": online_count,
                "offline_count": len(devices) - online_count
            }
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
