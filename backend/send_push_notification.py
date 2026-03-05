"""
Send Firebase Cloud Messaging (FCM) push notifications to Flutter app.
Requires Firebase Admin SDK.

Install with: pip install firebase-admin
"""

import firebase_admin
from firebase_admin import credentials, messaging
import os
import sys
from datetime import datetime


def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    try:
        # Check if Firebase is already initialized
        firebase_admin.get_app()
        print("[FCM] Firebase already initialized")
    except ValueError:
        # Firebase not initialized, initialize it
        # Download the service account key from Firebase Console
        # 1. Go to Firebase Console > Project Settings > Service Accounts
        # 2. Click "Generate New Private Key"
        # 3. Save as "firebase-service-account.json" in the backend folder
        
        service_account_path = os.path.join(
            os.path.dirname(__file__), 
            "firebase-service-account.json"
        )
        
        if not os.path.exists(service_account_path):
            print("[FCM] ERROR: firebase-service-account.json not found!")
            print(f"[FCM] Expected path: {service_account_path}")
            print("[FCM] Steps to fix:")
            print("1. Go to Firebase Console > Project Settings > Service Accounts")
            print("2. Click 'Generate New Private Key'")
            print("3. Save the JSON file as 'firebase-service-account.json' in backend folder")
            return False
        
        try:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
            print("[FCM] Firebase initialized successfully")
            return True
        except Exception as e:
            print(f"[FCM] Error initializing Firebase: {e}")
            return False


def send_notification_to_device(device_token, title, body, data=None):
    """Send notification to a specific device"""
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=device_token,
        )
        
        response = messaging.send(message)
        print(f"[FCM] Successfully sent message to device: {response}")
        return True
    except Exception as e:
        print(f"[FCM] Error sending message to device: {e}")
        return False


def send_notification_to_topic(topic, title, body, data=None):
    """Send notification to all devices subscribed to a topic"""
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            topic=topic,
        )
        
        response = messaging.send(message)
        print(f"[FCM] Successfully sent message to topic '{topic}': {response}")
        return True
    except Exception as e:
        print(f"[FCM] Error sending message to topic: {e}")
        return False


def send_notification_to_all(title, body, data=None):
    """Send notification to all devices (using 'all' topic)"""
    return send_notification_to_topic("all", title, body, data)


def send_activity_alert(device_token, action_type, user_name):
    """Send activity alert notification"""
    data = {
        "type": "activity_alert",
        "target": "activity_logs",
        "timestamp": datetime.now().isoformat(),
    }
    
    return send_notification_to_device(
        device_token,
        title="Activity Alert",
        body=f"{user_name} performed: {action_type}",
        data=data
    )


def send_sensor_alert(device_token, sensor_name, alert_message):
    """Send sensor alert notification"""
    data = {
        "type": "sensor_alert",
        "target": "sensor_data",
        "sensor": sensor_name,
        "timestamp": datetime.now().isoformat(),
    }
    
    return send_notification_to_device(
        device_token,
        title="Sensor Alert",
        body=alert_message,
        data=data
    )


def send_recommendation(device_token, recommendation_text):
    """Send AI recommendation notification"""
    data = {
        "type": "recommendation",
        "target": "recommendations",
        "timestamp": datetime.now().isoformat(),
    }
    
    return send_notification_to_device(
        device_token,
        title="AI Recommendation",
        body=recommendation_text,
        data=data
    )


def send_system_notification(device_token, title, body, notification_type="system"):
    """Send generic system notification"""
    data = {
        "type": notification_type,
        "timestamp": datetime.now().isoformat(),
    }
    
    return send_notification_to_device(device_token, title, body, data)


# Example usage
if __name__ == "__main__":
    # Initialize Firebase
    if not initialize_firebase():
        sys.exit(1)
    
    # Example 1: Send to a specific device
    # Replace with actual device token from app logs
    sample_token = "YOUR_DEVICE_TOKEN_HERE"
    
    if len(sys.argv) > 1:
        device_token = sys.argv[1]
    else:
        print("[FCM] Usage: python send_push_notification.py <device_token>")
        print("[FCM] Or: python send_push_notification.py <device_token> <title> <body>")
        print("\n[FCM] Example with sample token (will fail without valid token):")
        device_token = sample_token
    
    if len(sys.argv) > 3:
        title = sys.argv[2]
        body = sys.argv[3]
    else:
        title = "Test Notification"
        body = "This is a test push notification from ENERGIA backend"
    
    # Send different types of notifications
    print("\n" + "="*50)
    print("[FCM] Sending notifications...")
    print("="*50)
    
    # Generic notification
    send_system_notification(device_token, title, body)
    
    # Activity alert
    # send_activity_alert(device_token, "data_submission", "Admin User")
    
    # Sensor alert
    # send_sensor_alert(device_token, "ESP32_Sensor_01", "Voltage exceeded threshold")
    
    # AI recommendation
    # send_recommendation(device_token, "Reduce energy consumption by 15% to save costs")
    
    # Send to topic
    # send_notification_to_topic("all", "Broadcast Notification", "This goes to all devices in 'all' topic")
    
    print("\n[FCM] Done!")
