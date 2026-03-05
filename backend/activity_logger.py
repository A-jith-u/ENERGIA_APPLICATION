"""
Activity logging utility to be used across all API modules.
"""
import asyncio
import json
import os
import sys
import importlib
from typing import Optional
from datetime import datetime
from sqlalchemy import text, create_engine

def _load_cfg():
    """Load config module handling both package and script execution."""
    if __package__:
        from . import config
        return config
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        return importlib.import_module("config")

cfg = _load_cfg()
DB_URL = cfg.get_db_url()
engine = create_engine(DB_URL)


def log_activity(
    user_id: Optional[str] = None,
    user_name: Optional[str] = None,
    user_role: Optional[str] = None,
    action_type: str = None,
    action_description: str = None,
    resource_type: Optional[str] = None,
    resource_id: Optional[str] = None,
    department: Optional[str] = None,
    ip_address: str = "0.0.0.0",
    status: str = "success",
):
    """
    Log an activity to the database synchronously.
    
    Parameters:
    - user_id: ID or username of the user performing action
    - user_name: Full name of the user
    - user_role: Role of user (admin, coordinator, student)
    - action_type: Type of action (login, logout, data_submission, etc.)
    - action_description: Detailed description of the action
    - resource_type: Type of resource affected (sensor, report, etc.)
    - resource_id: ID of the affected resource
    - department: Department involved
    - ip_address: IP address of the request
    - status: success, failure, or warning
    """
    try:
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
    except Exception as e:
        print(f"Error logging activity: {str(e)}")
        # Don't raise, just log the error to console


def log_activity_async(
    user_id: Optional[str] = None,
    user_name: Optional[str] = None,
    user_role: Optional[str] = None,
    action_type: str = None,
    action_description: str = None,
    resource_type: Optional[str] = None,
    resource_id: Optional[str] = None,
    department: Optional[str] = None,
    ip_address: str = "0.0.0.0",
    status: str = "success",
):
    """
    Async wrapper for logging activities without blocking the response.
    """
    try:
        # Run the blocking operation in a thread pool
        asyncio.create_task(_async_log_wrapper(
            user_id, user_name, user_role, action_type, action_description,
            resource_type, resource_id, department, ip_address, status
        ))
    except Exception as e:
        print(f"Error scheduling activity log: {str(e)}")


async def _async_log_wrapper(
    user_id, user_name, user_role, action_type, action_description,
    resource_type, resource_id, department, ip_address, status
):
    """Wrapper to run blocking log operation in async context."""
    log_activity(
        user_id=user_id,
        user_name=user_name,
        user_role=user_role,
        action_type=action_type,
        action_description=action_description,
        resource_type=resource_type,
        resource_id=resource_id,
        department=department,
        ip_address=ip_address,
        status=status,
    )
