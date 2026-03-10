# Firebase Push Notifications - Quick Reference

## Quick Start

### 1. Get FCM Token
Run the Flutter app and check logs:
```
[Notification] FCM Token: <your_token_here>
```

### 2. Install Backend Dependencies
```bash
pip install firebase-admin
```

### 3. Add Service Account
Download from Firebase Console > Project Settings > Service Accounts
Save as: `backend/firebase-service-account.json`

### 4. Send Test Notification
```bash
python backend/send_push_notification.py "YOUR_FCM_TOKEN" "Hello" "Test Message"
```

---

## Send Notifications via curl

### Generic Notification
```bash
curl -X POST http://localhost:8000/fcm/send-to-device \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_TOKEN",
    "title": "Hello",
    "body": "Test notification"
  }'
```

### Activity Alert
```bash
curl -X POST http://localhost:8000/fcm/send-activity-alert \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_TOKEN",
    "action_type": "login",
    "user_name": "John Doe",
    "user_role": "admin"
  }'
```

### Sensor Alert
```bash
curl -X POST http://localhost:8000/fcm/send-sensor-alert \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_TOKEN",
    "sensor_name": "ESP32_01",
    "alert_message": "Voltage exceeded"
  }'
```

### Recommendation
```bash
curl -X POST http://localhost:8000/fcm/send-recommendation \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_TOKEN",
    "recommendation_text": "Save energy by 15%"
  }'
```

### Broadcast to All Devices
```bash
curl -X POST http://localhost:8000/fcm/send-to-topic \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "all",
    "title": "Broadcast",
    "body": "Message for everyone"
  }'
```

---

## Notification Types

| Type | Navigation | Use Case |
|------|-----------|----------|
| `activity_alert` | Activity Logs | User actions, login events |
| `sensor_alert` | Sensor Data | Threshold violations |
| `recommendation` | Recommendations | AI suggestions |
| Custom | Custom page | Any other purpose |

---

## Dart Integration

### Get Token
```dart
import 'package:energia/services/notification_service.dart';

final token = await NotificationService().getToken();
```

### Subscribe to Topic
```dart
await NotificationService().subscribeToTopic('all');
```

### Unsubscribe from Topic
```dart
await NotificationService().unsubscribeFromTopic('all');
```

---

## File Structure

```
ENERGIA_APPLICATION/
├── lib/
│   ├── services/
│   │   └── notification_service.dart    ← Main service
│   └── main.dart                         ← Initialization
├── backend/
│   ├── send_push_notification.py        ← Python script
│   ├── fcm_api.py                       ← FastAPI routes
│   ├── firebase-service-account.json    ← Service account (add to .gitignore)
│   └── requirements.txt                 ← Updated with firebase-admin
└── FIREBASE_PUSH_NOTIFICATIONS_GUIDE.md ← Full guide
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No FCM token | Check notification permissions, check app logs |
| Notifications not received | Verify service account file, check device token |
| Background notifications don't work | Ensure `@pragma('vm:entry-point')` decorator |
| iOS notifications don't work | Check APNs certificate in Firebase Console |
| Permission denied errors | Grant notification permission on device |

---

## Next Steps

1. ✅ Notification service implemented
2. ✅ Backend FCM API ready
3. Next: Mount FCM API in `app_main.py`
4. Next: Test with real device
5. Next: Integrate with activity logging system
6. Next: Set up sensor alert thresholds

---

## Useful Links

- [Firebase Console](https://console.firebase.google.com/)
- [FCM Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Plugin](https://pub.dev/packages/firebase_messaging)
