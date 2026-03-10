"""
Firebase Cloud Messaging (FCM) API endpoints for sending push notifications.
Add these routes to your FastAPI app_main.py
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from pydantic import BaseModel
from typing import Optional, List
import firebase_admin
from firebase_admin import credentials, messaging
import os
import sys
import importlib
from datetime import datetime
import json

# File to persist recent broadcast notifications for client retrieval (simple dev store)
NOTIFICATIONS_STORE = os.path.join(os.path.dirname(__file__), "notifications.json")

def _load(name: str):
    """Import backend modules whether run as package or as a bare module."""
    if __package__:
        return importlib.import_module(f".{name}", __package__)
    sys.path.append(os.path.dirname(__file__))
    return importlib.import_module(name)

# Initialize Firebase Admin
try:
    firebase_admin.get_app()
except ValueError:
    service_account_path = os.path.join(
        os.path.dirname(__file__), 
        "firebase-service-account.json"
    )
    if os.path.exists(service_account_path):
        try:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            print("[FCM API] Firebase initialized from service account")
        except Exception as e:
            print(f"[FCM API] Warning: Firebase initialization failed: {e}")
            print("[FCM API] Continuing without Firebase - push notifications will be logged but not sent")
    else:
        print(f"[FCM API] firebase-service-account.json not found - continuing without Firebase")
        print(f"[FCM API] To enable FCM, add your Firebase credentials at: {service_account_path}")


app = FastAPI(title="Firebase Cloud Messaging API")

# ============================================================================
# Pydantic Models
# ============================================================================

class NotificationPayload(BaseModel):
    """Payload for sending notifications"""
    title: str
    body: str
    data: Optional[dict] = None
    image_url: Optional[str] = None
    sound: Optional[str] = "default"


class SendToDeviceRequest(NotificationPayload):
    """Request to send notification to a specific device"""
    device_token: str


class SendToTopicRequest(NotificationPayload):
    """Request to send notification to all devices in a topic"""
    topic: str


class SendToAllRequest(NotificationPayload):
    """Request to send notification to all devices"""
    pass


class ActivityAlertRequest(BaseModel):
    """Request to send activity alert"""
    device_token: str
    action_type: str
    user_name: str
    user_role: Optional[str] = None


class SensorAlertRequest(BaseModel):
    """Request to send sensor alert"""
    device_token: str
    sensor_name: str
    alert_message: str
    sensor_value: Optional[float] = None
    threshold: Optional[float] = None


class RecommendationRequest(BaseModel):
    """Request to send AI recommendation"""
    device_token: str
    recommendation_text: str
    recommendation_type: Optional[str] = None


class SubscribeToTopicRequest(BaseModel):
    """Request to subscribe device to topic"""
    device_token: str
    topic: str


class UnsubscribeFromTopicRequest(BaseModel):
    """Request to unsubscribe device from topic"""
    device_token: str
    topic: str


class ReplyToNotificationRequest(BaseModel):
    """Request to post a reply to a notification"""
    notification_id: int
    user_id: str
    user_name: str
    body: str


# ============================================================================
# Helper Functions
# ============================================================================

def _send_message(message: messaging.Message) -> str:
    """Send a message and return the response"""
    try:
        response = messaging.send(message)
        print(f"[FCM API] Message sent successfully: {response}")
        return response
    except Exception as e:
        print(f"[FCM API] Error sending message: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def _is_firebase_initialized() -> bool:
    """Check if Firebase is initialized"""
    try:
        firebase_admin.get_app()
        return True
    except ValueError:
        return False


# ============================================================================
# Notification Endpoints
# ============================================================================

@app.get("/status")
async def get_status():
    """Check if Firebase Cloud Messaging is available"""
    return {
        "status": "available" if _is_firebase_initialized() else "not_initialized",
        "timestamp": datetime.now().isoformat()
    }


@app.post("/send-to-device")
async def send_notification_to_device(request: SendToDeviceRequest):
    """Send notification to a specific device"""
    if not _is_firebase_initialized():
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=request.title,
                body=request.body,
            ),
            data=request.data or {},
            token=request.device_token,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound=request.sound,
                    image=request.image_url,
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        sound=request.sound,
                        mutable_content=True,
                    ),
                ),
            ),
        )
        
        response = _send_message(message)
        return {
            "status": "sent",
            "message_id": response,
            "device_token": request.device_token,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send-to-topic")
async def send_notification_to_topic(request: SendToTopicRequest):
    """Send notification to all devices subscribed to a topic"""
    if not _is_firebase_initialized():
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=request.title,
                body=request.body,
            ),
            data=request.data or {},
            topic=request.topic,
        )
        
        response = _send_message(message)
        return {
            "status": "sent",
            "message_id": response,
            "topic": request.topic,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send-to-all")
async def send_notification_to_all(request: SendToAllRequest):
    """Send notification to all devices (via 'all' topic)"""
    # Persist the notification for retrieval by clients (so they can see admin broadcasts)
    # Build notification payload
    notif = {
        "title": request.title,
        "body": request.body,
        "data": request.data or {},
        "timestamp": datetime.now().isoformat(),
    }
    # First, try to persist into DB if available
    try:
        # Import backend DB init module which exposes `engine` and `notifications_table`
        import db_init
        if hasattr(db_init, "notifications_table") and hasattr(db_init, "engine"):
            try:
                with db_init.engine.begin() as conn:
                    conn.execute(
                        db_init.notifications_table.insert().values(
                            title=request.title,
                            body=request.body,
                            data=json.dumps(request.data or {}),
                        )
                    )
            except Exception as e:
                print(f"[FCM API] Warning: DB insert failed: {e}")
        else:
            print("[FCM API] DB notifications table or engine not available; falling back to JSON store")
    except Exception as e:
        print(f"[FCM API] Warning: could not access DB module: {e}")

    # Always keep a lightweight JSON fallback store for quick retrieval
    try:
        existing = []
        if os.path.exists(NOTIFICATIONS_STORE):
            try:
                with open(NOTIFICATIONS_STORE, "r", encoding="utf-8") as f:
                    existing = json.load(f)
            except Exception:
                existing = []
        existing.append(notif)
        existing = existing[-100:]
        with open(NOTIFICATIONS_STORE, "w", encoding="utf-8") as f:
            json.dump(existing, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[FCM API] Warning: failed to persist notification to JSON store: {e}")

    if not _is_firebase_initialized():
        print(f"[FCM API] DEV MODE: Notification logged (not sent): title='{request.title}', body='{request.body}'")
        return {
            "status": "logged",
            "message_id": "dev-mode",
            "topic": "all",
            "note": "Firebase not initialized - message logged for development"
        }
    
    return await send_notification_to_topic(
        SendToTopicRequest(
            title=request.title,
            body=request.body,
            data=request.data,
            image_url=request.image_url,
            sound=request.sound,
            topic="all"
        )
    )


@app.get("/recent")
async def get_recent_notifications(limit: int = 20):
    """Return recent broadcast notifications stored on the server."""
    try:
        if not os.path.exists(NOTIFICATIONS_STORE):
            return {"notifications": []}
        with open(NOTIFICATIONS_STORE, "r", encoding="utf-8") as f:
            data = json.load(f)
        # Return latest `limit` items
        return {"notifications": data[-limit:][::-1]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send-activity-alert")
async def send_activity_alert(request: ActivityAlertRequest):
    """Send activity alert notification"""
    if not _is_firebase_initialized():
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    
    data = {
        "type": "activity_alert",
        "target": "activity_logs",
        "action_type": request.action_type,
        "user_name": request.user_name,
        "user_role": request.user_role or "unknown",
        "timestamp": datetime.now().isoformat(),
    }
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="Activity Alert",
                body=f"{request.user_name} performed: {request.action_type}",
            ),
            data=data,
            token=request.device_token,
        )
        
        response = _send_message(message)
        return {
            "status": "sent",
            "message_id": response,
            "type": "activity_alert",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send-sensor-alert")
async def send_sensor_alert(request: SensorAlertRequest):
    """Send sensor alert notification"""
    if not _is_firebase_initialized():
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    
    data = {
        "type": "sensor_alert",
        "target": "sensor_data",
        "sensor_name": request.sensor_name,
        "sensor_value": str(request.sensor_value) if request.sensor_value else None,
        "threshold": str(request.threshold) if request.threshold else None,
        "timestamp": datetime.now().isoformat(),
    }
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="Sensor Alert",
                body=request.alert_message,
            ),
            data=data,
            token=request.device_token,
        )
        
        response = _send_message(message)
        return {
            "status": "sent",
            "message_id": response,
            "type": "sensor_alert",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send-recommendation")
async def send_recommendation(request: RecommendationRequest):
    """Send AI recommendation notification"""
    if not _is_firebase_initialized():
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    
    data = {
        "type": "recommendation",
        "target": "recommendations",
        "recommendation_type": request.recommendation_type or "general",
        "timestamp": datetime.now().isoformat(),
    }
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="AI Recommendation",
                body=request.recommendation_text,
            ),
            data=data,
            token=request.device_token,
        )
        
        response = _send_message(message)
        return {
            "status": "sent",
            "message_id": response,
            "type": "recommendation",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/subscribe-to-topic")
async def subscribe_device_to_topic(request: SubscribeToTopicRequest):
    """Subscribe a device to a topic"""
    if not _is_firebase_initialized():
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    
    try:
        response = messaging.make_topic_management_message(
            tokens=[request.device_token],
            topic=request.topic,
            operation="subscribe"
        )
        return {
            "status": "subscribed",
            "device_token": request.device_token,
            "topic": request.topic,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/unsubscribe-from-topic")
async def unsubscribe_device_from_topic(request: UnsubscribeFromTopicRequest):
    """Unsubscribe a device from a topic"""
    if not _is_firebase_initialized():
        raise HTTPException(status_code=503, detail="Firebase not initialized")
    
    try:
        response = messaging.make_topic_management_message(
            tokens=[request.device_token],
            topic=request.topic,
            operation="unsubscribe"
        )
        return {
            "status": "unsubscribed",
            "device_token": request.device_token,
            "topic": request.topic,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/reply")
async def post_reply_to_notification(request: ReplyToNotificationRequest):
    """Post a reply to a notification (persists reply and broadcasts to all users)"""
    # Persist the reply to DB
    try:
        import db_init
        if hasattr(db_init, "notification_replies_table") and hasattr(db_init, "engine"):
            try:
                with db_init.engine.begin() as conn:
                    conn.execute(
                        db_init.notification_replies_table.insert().values(
                            notification_id=request.notification_id,
                            user_id=request.user_id,
                            user_name=request.user_name,
                            body=request.body,
                        )
                    )
            except Exception as e:
                print(f"[FCM API] Warning: DB insert for reply failed: {e}")
        else:
            print("[FCM API] DB notification_replies table or engine not available")
    except Exception as e:
        print(f"[FCM API] Warning: could not access DB module for reply: {e}")

    # Broadcast the reply as a notification to all users
    reply_notification = {
        "title": f"New Reply from {request.user_name}",
        "body": request.body,
        "data": {
            "type": "reply",
            "original_notification_id": str(request.notification_id),
            "user_name": request.user_name,
        },
        "timestamp": datetime.now().isoformat(),
    }
    
    # Persist reply to JSON store
    try:
        existing = []
        if os.path.exists(NOTIFICATIONS_STORE):
            try:
                with open(NOTIFICATIONS_STORE, "r", encoding="utf-8") as f:
                    existing = json.load(f)
            except Exception:
                existing = []
        existing.append(reply_notification)
        existing = existing[-100:]
        with open(NOTIFICATIONS_STORE, "w", encoding="utf-8") as f:
            json.dump(existing, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[FCM API] Warning: failed to persist reply to JSON store: {e}")

    if not _is_firebase_initialized():
        print(f"[FCM API] DEV MODE: Reply logged (not sent): from '{request.user_name}': '{request.body}'")
        return {
            "status": "logged",
            "reply_id": "dev-mode",
            "note": "Firebase not initialized - reply logged for development"
        }
    
    # Send via FCM to 'all' topic
    return await send_notification_to_topic(
        SendToTopicRequest(
            title=reply_notification["title"],
            body=reply_notification["body"],
            data=reply_notification["data"],
            topic="all"
        )
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
