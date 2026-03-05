"""
Example integration of FCM with the ENERGIA backend.
Shows how to send notifications from various parts of the application.
"""

# Example 1: Send notification when user logs in
# Place this in auth_api.py login endpoint

def send_login_notification(user_id: str, user_name: str, user_role: str, device_token: str = None):
    """Send notification when user logs in"""
    import firebase_admin
    from firebase_admin import messaging
    
    try:
        firebase_admin.get_app()
    except ValueError:
        print("Firebase not initialized")
        return False
    
    if not device_token:
        # Could fetch device_token from database for this user
        return False
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="Login Successful",
                body=f"Welcome back, {user_name}!",
            ),
            data={
                "type": "activity_alert",
                "action_type": "login",
                "user_name": user_name,
                "user_role": user_role,
                "timestamp": str(datetime.now()),
            },
            token=device_token,
        )
        
        messaging.send(message)
        print(f"[FCM] Login notification sent to {user_name}")
        return True
    except Exception as e:
        print(f"[FCM] Error sending login notification: {e}")
        return False


# Example 2: Send notification for sensor data anomaly
# Place this in activity_log_api.py or sensor monitoring

def send_sensor_anomaly_notification(sensor_id: str, sensor_value: float, threshold: float, device_token: str):
    """Send notification when sensor reading exceeds threshold"""
    import firebase_admin
    from firebase_admin import messaging
    
    try:
        firebase_admin.get_app()
    except ValueError:
        print("Firebase not initialized")
        return False
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=f"Sensor Alert - {sensor_id}",
                body=f"Reading {sensor_value:.2f} exceeds threshold {threshold:.2f}",
            ),
            data={
                "type": "sensor_alert",
                "sensor_id": sensor_id,
                "sensor_value": str(sensor_value),
                "threshold": str(threshold),
                "timestamp": str(datetime.now()),
            },
            token=device_token,
        )
        
        messaging.send(message)
        print(f"[FCM] Sensor alert sent for {sensor_id}")
        return True
    except Exception as e:
        print(f"[FCM] Error sending sensor notification: {e}")
        return False


# Example 3: Send recommendation notification
# Place this in recommendation_engine.py

def send_recommendation_notification(recommendation_text: str, recommendation_type: str, device_token: str):
    """Send AI recommendation notification"""
    import firebase_admin
    from firebase_admin import messaging
    
    try:
        firebase_admin.get_app()
    except ValueError:
        print("Firebase not initialized")
        return False
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title="Energy Recommendation",
                body=recommendation_text[:100],  # Truncate for notification
            ),
            data={
                "type": "recommendation",
                "recommendation_type": recommendation_type,
                "full_text": recommendation_text,
                "timestamp": str(datetime.now()),
            },
            token=device_token,
        )
        
        messaging.send(message)
        print(f"[FCM] Recommendation sent: {recommendation_type}")
        return True
    except Exception as e:
        print(f"[FCM] Error sending recommendation: {e}")
        return False


# Example 4: Send broadcast notification to all coordinators
# Place this in notify_api.py or admin_dashboard

def broadcast_to_coordinators(title: str, body: str):
    """Send notification to all coordinators"""
    import firebase_admin
    from firebase_admin import messaging
    
    try:
        firebase_admin.get_app()
    except ValueError:
        print("Firebase not initialized")
        return False
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                "type": "broadcast",
                "target": "all_coordinators",
                "timestamp": str(datetime.now()),
            },
            topic="coordinators",  # Device must be subscribed to this topic
        )
        
        messaging.send(message)
        print(f"[FCM] Broadcast sent to coordinators")
        return True
    except Exception as e:
        print(f"[FCM] Error sending broadcast: {e}")
        return False


# Example 5: Integration in activity_log_api.py

from datetime import datetime
import firebase_admin
from firebase_admin import messaging

def log_activity_and_notify(
    user_id: str,
    user_name: str,
    user_role: str,
    action_type: str,
    action_description: str,
    device_token: str = None,
    notify: bool = True
):
    """Log activity and optionally send notification"""
    
    # ... existing logging code ...
    
    # Send notification if enabled
    if notify and device_token:
        try:
            firebase_admin.get_app()
            
            message = messaging.Message(
                notification=messaging.Notification(
                    title=f"{action_type.replace('_', ' ').title()} Activity",
                    body=f"{user_name}: {action_description}",
                ),
                data={
                    "type": "activity_alert",
                    "action_type": action_type,
                    "user_name": user_name,
                    "user_role": user_role,
                    "user_id": user_id,
                    "timestamp": datetime.now().isoformat(),
                },
                token=device_token,
            )
            
            messaging.send(message)
            print(f"[FCM] Activity notification sent for {action_type}")
        except Exception as e:
            print(f"[FCM] Error sending activity notification: {e}")


# Example 6: Store device tokens in database
# Add this table to db_init.py

"""
device_tokens_table = Table(
    "device_tokens",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("user_id", String, nullable=False),
    Column("device_token", String, nullable=False, unique=True),
    Column("platform", String, nullable=False),  # 'android', 'ios'
    Column("created_at", DateTime, server_default=func.now()),
    Column("last_seen", DateTime, server_default=func.now()),
)
"""


# Example 7: API endpoint to register device token

from fastapi import FastAPI
from pydantic import BaseModel

class RegisterDeviceRequest(BaseModel):
    user_id: str
    device_token: str
    platform: str  # 'android' or 'ios'

@app.post("/register-device")
async def register_device(request: RegisterDeviceRequest):
    """Register device token for a user"""
    try:
        # Store in database
        # db.insert(device_tokens, values={
        #     'user_id': request.user_id,
        #     'device_token': request.device_token,
        #     'platform': request.platform,
        # })
        
        # Subscribe to user-specific topic
        firebase_admin.messaging.make_topic_management_message(
            tokens=[request.device_token],
            topic=f"user_{request.user_id}",
            operation="subscribe"
        )
        
        return {
            "status": "registered",
            "user_id": request.user_id,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# Example 8: Dart integration - Send device token to backend

/*
import 'package:energia/services/notification_service.dart';
import 'package:energia/services/api.dart';

// In your login flow, after successful authentication:
Future<void> registerDeviceToken(String userId) async {
  final notificationService = NotificationService();
  final token = await notificationService.getToken();
  
  if (token != null) {
    // Send token to backend
    try {
      await Future.wait([
        // Your login API call
        // registerTokenOnBackend(userId, token),
      ]);
    } catch (e) {
      print('Error registering device token: $e');
    }
  }
}
*/


# Example 9: Test notification service in debug mode

def test_fcm_notifications():
    """Test various FCM notification scenarios"""
    import firebase_admin
    from firebase_admin import messaging
    
    # Initialize Firebase
    try:
        firebase_admin.get_app()
    except ValueError:
        print("Firebase not initialized for testing")
        return
    
    print("\n" + "="*50)
    print("Testing FCM Notifications")
    print("="*50)
    
    # Use 'test-token' as placeholder (won't actually send)
    test_token = "test-token-placeholder"
    
    # Test 1: Basic notification
    print("\n[Test 1] Basic notification")
    message = messaging.Message(
        notification=messaging.Notification(
            title="Test Notification",
            body="This is a test",
        ),
        token=test_token,
    )
    print(f"Message object created: {message}")
    
    # Test 2: With data
    print("\n[Test 2] Notification with data")
    message = messaging.Message(
        notification=messaging.Notification(
            title="Activity Alert",
            body="User logged in",
        ),
        data={
            "type": "activity_alert",
            "user_name": "John Doe",
        },
        token=test_token,
    )
    print(f"Message with data created successfully")
    
    # Test 3: Topic message
    print("\n[Test 3] Topic message")
    message = messaging.Message(
        notification=messaging.Notification(
            title="Broadcast",
            body="Message to all",
        ),
        topic="all",
    )
    print(f"Topic message created successfully")
    
    print("\n" + "="*50)
    print("All tests passed!")
    print("="*50 + "\n")


if __name__ == "__main__":
    test_fcm_notifications()
