"""
Activity Logging API - tracks all user actions in the system.
Provides endpoints for logging and retrieving activity history.
"""
from datetime import datetime, timedelta
from typing import Optional, List
from fastapi import FastAPI, HTTPException, Depends, Header, Request
from fastapi.responses import JSONResponse
from sqlalchemy import create_engine, Table, Column, Integer, BigInteger, String, DateTime, func, select, desc, text
from sqlalchemy.orm import Session
import jwt
import os
from dotenv import load_dotenv
from functools import lru_cache
import time

load_dotenv()

import config

# Database setup with connection pooling for better performance
DB_URL = config.get_db_url()
engine = create_engine(
    DB_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    pool_recycle=3600
)

app = FastAPI(title="Activity Logging API")

# Activity logs table definition
activity_logs_metadata = {
    "user_id": str,
    "user_name": str,
    "user_role": str,
    "action_type": str,
    "action_description": str,
    "resource_type": str,
    "resource_id": str,
    "department": str,
    "ip_address": str,
    "status": str,
}

JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key")
ALGORITHM = "HS256"

# Simple in-memory cache for recent logs (5 minute TTL)
_logs_cache = {}
_CACHE_TTL = 300  # 5 minutes in seconds


def _extract_user_from_token(token: Optional[str]) -> Optional[dict]:
    """Extract user info from JWT token."""
    if not token:
        return None
    try:
        if token.startswith("Bearer "):
            token = token[7:]
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        return payload
    except Exception:
        return None


def _get_client_ip(request: Request) -> str:
    """Extract client IP from request."""
    if request.client:
        return request.client.host
    return "0.0.0.0"


@app.post("/log")
async def log_activity(
    request: Request,
    user_id: Optional[str] = None,
    user_name: Optional[str] = None,
    user_role: Optional[str] = None,
    action_type: str = None,
    action_description: str = None,
    resource_type: Optional[str] = None,
    resource_id: Optional[str] = None,
    department: Optional[str] = None,
    status: str = "success",
    authorization: Optional[str] = Header(None),
):
    """
    Log a user activity. Can be called with or without authentication.
    
    Parameters:
    - action_type: Required (login, logout, data_submission, report_generation, etc.)
    - action_description: Required (detailed description)
    - user_id: Optional (extracted from token if not provided)
    - user_name: Optional (extracted from token if not provided)
    - user_role: Optional (extracted from token if not provided)
    - resource_type: Optional (sensor, report, etc.)
    - resource_id: Optional
    - department: Optional
    - status: success, failure, warning (default: success)
    """
    try:
        # Extract user from token if not provided
        if not user_id and authorization:
            user_info = _extract_user_from_token(authorization)
            if user_info:
                user_id = user_info.get("sub") or user_info.get("user_id")
                user_name = user_info.get("name") or user_info.get("user_name")
                user_role = user_info.get("role") or user_info.get("user_role")
                department = department or user_info.get("department")

        ip_address = _get_client_ip(request)

        # Insert into database
        with engine.begin() as conn:
            query = text("""
                INSERT INTO activity_logs 
                (user_id, user_name, user_role, action_type, action_description, 
                 resource_type, resource_id, department, ip_address, status, timestamp)
                VALUES 
                (:user_id, :user_name, :user_role, :action_type, :action_description,
                 :resource_type, :resource_id, :department, :ip_address, :status, :timestamp)
            """)
            conn.execute(query, {
                "user_id": user_id,
                "user_name": user_name,
                "user_role": user_role,
                "action_type": action_type,
                "action_description": action_description,
                "resource_type": resource_type,
                "resource_id": resource_id,
                "department": department,
                "ip_address": ip_address,
                "status": status,
                "timestamp": datetime.utcnow(),
            })

        # Clear cache when new log is added
        _logs_cache.clear()

        return {
            "status": "success",
            "message": "Activity logged successfully",
            "timestamp": datetime.utcnow().isoformat(),
        }

    except Exception as e:
        print(f"Error logging activity: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/logs")
async def get_activity_logs(
    limit: int = 10,
    offset: int = 0,
    action_type: Optional[str] = None,
    user_id: Optional[str] = None,
    user_role: Optional[str] = None,
    status: Optional[str] = None,
    days: int = 1,
):
    """
    Retrieve activity logs with optional filtering.
    
    Parameters:
    - limit: Number of logs to return (default: 10 for fastest response, max 50)
    - offset: Pagination offset (default: 0)
    - action_type: Filter by action type
    - user_id: Filter by user
    - user_role: Filter by user role (admin, coordinator, student)
    - status: Filter by status (success, failure, warning)
    - days: Only retrieve logs from last N days (default: 1 for faster queries)
    """
    try:
        # Cap limit to prevent slow queries
        limit = min(limit, 50)
        
        # Generate cache key
        cache_key = f"logs_{limit}_{offset}_{action_type}_{user_id}_{user_role}_{status}_{days}"
        
        # Check cache
        if cache_key in _logs_cache:
            cached_data, cached_time = _logs_cache[cache_key]
            if time.time() - cached_time < _CACHE_TTL:
                return cached_data
        
        cutoff_date = datetime.utcnow() - timedelta(days=days)

        # Build dynamic query with proper parameterization
        where_clauses = ["timestamp >= :cutoff_date"]
        params = {"cutoff_date": cutoff_date}

        if action_type:
            where_clauses.append("action_type = :action_type")
            params["action_type"] = action_type

        if user_id:
            where_clauses.append("user_id = :user_id")
            params["user_id"] = user_id

        if user_role:
            where_clauses.append("user_role = :user_role")
            params["user_role"] = user_role

        if status:
            where_clauses.append("status = :status")
            params["status"] = status

        where_clause = " AND ".join(where_clauses)

        query = text(f"""
            SELECT 
                id, user_id, user_name, user_role, action_type, action_description,
                resource_type, resource_id, department, ip_address, status, timestamp
            FROM activity_logs
            WHERE {where_clause}
            ORDER BY timestamp DESC
            LIMIT :limit OFFSET :offset
        """)

        params["limit"] = limit
        params["offset"] = offset

        with engine.connect() as conn:
            result = conn.execute(query, params)
            rows = result.fetchall()

        # Only count if we need total (can be expensive with large datasets)
        total_count = len(rows)
        if len(rows) >= limit:
            # Get estimated total for pagination only if needed
            count_query = text(f"""
                SELECT COUNT(*) FROM activity_logs
                WHERE {where_clause}
            """)
            try:
                with engine.connect() as conn:
                    count_result = conn.execute(count_query, params)
                    total_count = count_result.scalar()
            except:
                pass  # Use rows count if count fails

        logs = []
        for row in rows:
            logs.append({
                "id": row[0],
                "user_id": row[1],
                "user_name": row[2],
                "user_role": row[3],
                "action_type": row[4],
                "action_description": row[5],
                "resource_type": row[6],
                "resource_id": row[7],
                "department": row[8],
                "ip_address": row[9],
                "status": row[10],
                "timestamp": row[11].isoformat() if row[11] else None,
            })

        result = {
            "status": "success",
            "data": logs,
            "pagination": {
                "limit": limit,
                "offset": offset,
                "total": total_count,
            },
        }
        
        # Cache the result
        _logs_cache[cache_key] = (result, time.time())
        
        # Keep cache size manageable (max 100 entries)
        if len(_logs_cache) > 100:
            oldest_key = min(_logs_cache.keys(), key=lambda k: _logs_cache[k][1])
            del _logs_cache[oldest_key]
        
        return result

    except Exception as e:
        print(f"Error retrieving activity logs: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/logs/summary")
async def get_activity_summary(days: int = 7):
    """
    Get a summary of activities over the last N days.
    Returns counts by action type, user role, and status.
    """
    try:
        cutoff_date = datetime.utcnow() - timedelta(days=days)

        with engine.connect() as conn:
            # Count by action type
            action_query = text("""
                SELECT action_type, COUNT(*) as count
                FROM activity_logs
                WHERE timestamp >= :cutoff_date
                GROUP BY action_type
                ORDER BY count DESC
            """)
            action_result = conn.execute(action_query, {"cutoff_date": cutoff_date})
            action_counts = dict(action_result.fetchall())

            # Count by role
            role_query = text("""
                SELECT user_role, COUNT(*) as count
                FROM activity_logs
                WHERE timestamp >= :cutoff_date
                GROUP BY user_role
                ORDER BY count DESC
            """)
            role_result = conn.execute(role_query, {"cutoff_date": cutoff_date})
            role_counts = dict(role_result.fetchall())

            # Count by status
            status_query = text("""
                SELECT status, COUNT(*) as count
                FROM activity_logs
                WHERE timestamp >= :cutoff_date
                GROUP BY status
                ORDER BY count DESC
            """)
            status_result = conn.execute(status_query, {"cutoff_date": cutoff_date})
            status_counts = dict(status_result.fetchall())

            # Total activities
            total_query = text("""
                SELECT COUNT(*) FROM activity_logs
                WHERE timestamp >= :cutoff_date
            """)
            total = conn.execute(total_query, {"cutoff_date": cutoff_date}).scalar()

        return {
            "status": "success",
            "summary": {
                "total_activities": total,
                "by_action_type": action_counts,
                "by_user_role": role_counts,
                "by_status": status_counts,
                "period_days": days,
            },
        }

    except Exception as e:
        print(f"Error getting activity summary: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/logs/user/{user_id}")
async def get_user_activity(user_id: str, limit: int = 20, days: int = 30):
    """
    Get activity logs for a specific user.
    """
    try:
        cutoff_date = datetime.utcnow() - timedelta(days=days)

        query = text("""
            SELECT 
                id, user_id, user_name, user_role, action_type, action_description,
                resource_type, resource_id, department, status, timestamp
            FROM activity_logs
            WHERE user_id = :user_id AND timestamp >= :cutoff_date
            ORDER BY timestamp DESC
            LIMIT :limit
        """)

        with engine.connect() as conn:
            result = conn.execute(query, {
                "user_id": user_id,
                "cutoff_date": cutoff_date,
                "limit": limit,
            })
            rows = result.fetchall()

        logs = []
        for row in rows:
            logs.append({
                "id": row[0],
                "user_id": row[1],
                "user_name": row[2],
                "user_role": row[3],
                "action_type": row[4],
                "action_description": row[5],
                "resource_type": row[6],
                "resource_id": row[7],
                "department": row[8],
                "status": row[9],
                "timestamp": row[10].isoformat() if row[10] else None,
            })

        return {
            "status": "success",
            "user_id": user_id,
            "logs": logs,
            "count": len(logs),
        }

    except Exception as e:
        print(f"Error retrieving user activity: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/logs/{log_id}")
async def delete_activity_log(log_id: int):
    """
    Delete a specific activity log entry (admin only).
    """
    try:
        with engine.begin() as conn:
            query = text("DELETE FROM activity_logs WHERE id = :log_id")
            result = conn.execute(query, {"log_id": log_id})

            if result.rowcount == 0:
                raise HTTPException(status_code=404, detail="Log entry not found")

        return {
            "status": "success",
            "message": "Activity log deleted successfully",
        }

    except Exception as e:
        print(f"Error deleting activity log: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/ping")
async def ping():
    """Health check endpoint."""
    return {"status": "pong", "service": "activity_logging"}
