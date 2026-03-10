# Firebase Push Notifications in Flutter - Complete Setup Guide

## Overview
This guide walks through setting up Firebase Cloud Messaging (FCM) for push notifications in the ENERGIA Flutter app.

## Prerequisites
- Firebase project created
- Flutter app with Firebase initialized (already done in your project)
- Firebase Admin SDK (for backend)

---

## Part 1: Flutter App Setup

### 1.1 Dependencies Already Added
The required packages are already in `pubspec.yaml`:
```yaml
firebase_core: ^2.24.2
firebase_messaging: ^14.7.10
```

If needed, run:
```bash
flutter pub get
```

### 1.2 Firebase Initialization
Already configured in `lib/main.dart`:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

// Initialize notification service
await NotificationService().initialize();
```

### 1.3 Notification Service Features
Located in `lib/services/notification_service.dart`:
- Request notification permissions
- Get FCM device token
- Listen to foreground messages
- Handle background messages
- Handle notification taps when app is in background/terminated
- Subscribe/unsubscribe from topics
- Handle different notification types (activity, sensor, recommendations)

---

## Part 2: Android Configuration

### 2.1 AndroidManifest.xml
Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <!-- Notification permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <application ...>
        <!-- Firebase Cloud Messaging Service -->
        <service
            android:name=".firebase.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
    </application>
</manifest>
```

### 2.2 Build Gradle
Update `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

Update `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
    implementation 'com.google.firebase:firebase-messaging'
}
```

### 2.3 MainActivity.kt
Ensure `android/app/src/main/kotlin/com/example/energia/MainActivity.kt` extends FlutterFragmentActivity (or similar):

```kotlin
package com.example.energia

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
}
```

---

## Part 3: iOS Configuration

### 3.1 Capabilities
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the "Runner" project > "Runner" target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"

### 3.2 Podfile
Ensure `ios/Podfile` has proper configuration. Usually auto-configured by Firebase:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
  end
end
```

### 3.3 Runner Project
Make sure `ios/Runner/GeneratedPluginRegistrant.m` includes Firebase plugins (auto-generated).

---

## Part 4: Get FCM Device Token

### 4.1 Running the App
Once you run the Flutter app:
```bash
flutter run
```

The notification service will:
1. Request permissions automatically
2. Retrieve the FCM token (check console logs)
3. Print: `[Notification] FCM Token: YOUR_TOKEN_HERE`

### 4.2 Retrieving the Token Programmatically
```dart
import 'package:energia/services/notification_service.dart';

final notificationService = NotificationService();
String? token = await notificationService.getToken();
print('FCM Token: $token');
```

---

## Part 5: Backend Setup

### 5.1 Install Firebase Admin SDK
```bash
cd backend
pip install firebase-admin
```

### 5.2 Get Firebase Service Account Key
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings > Service Accounts
4. Click "Generate New Private Key"
5. Save the JSON file as `backend/firebase-service-account.json`

### 5.3 Mount FCM API (Optional)
In `backend/app_main.py`, add:
```python
fcm_api = _load("fcm_api")
app.mount("/fcm", fcm_api.app)
```

Then restart the backend server:
```bash
python backend/start_server.py
```

---

## Part 6: Sending Notifications

### 6.1 Using Python Script
```bash
# Send to a specific device
python backend/send_push_notification.py "YOUR_FCM_TOKEN" "Title" "Body"

# Example
python backend/send_push_notification.py "abc123xyz..." "Test Alert" "This is a test"
```

### 6.2 Using FastAPI Endpoint

#### Send to Device
```bash
curl -X POST http://localhost:8000/fcm/send-to-device \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_FCM_TOKEN",
    "title": "Test Notification",
    "body": "Hello from ENERGIA!",
    "data": {"type": "test"}
  }'
```

#### Send to Topic
```bash
curl -X POST http://localhost:8000/fcm/send-to-topic \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "all",
    "title": "Broadcast",
    "body": "Message to all devices"
  }'
```

#### Send Activity Alert
```bash
curl -X POST http://localhost:8000/fcm/send-activity-alert \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_FCM_TOKEN",
    "action_type": "data_submission",
    "user_name": "John Doe",
    "user_role": "student"
  }'
```

#### Send Sensor Alert
```bash
curl -X POST http://localhost:8000/fcm/send-sensor-alert \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_FCM_TOKEN",
    "sensor_name": "ESP32_01",
    "alert_message": "Voltage exceeded threshold",
    "sensor_value": 245.5,
    "threshold": 240.0
  }'
```

#### Send Recommendation
```bash
curl -X POST http://localhost:8000/fcm/send-recommendation \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "YOUR_FCM_TOKEN",
    "recommendation_text": "Reduce energy usage by 15% during peak hours",
    "recommendation_type": "efficiency"
  }'
```

### 6.3 Using Dart Code
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendTestNotification(String deviceToken) async {
  final uri = Uri.parse('http://localhost:8000/fcm/send-to-device');
  
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'device_token': deviceToken,
      'title': 'Test from App',
      'body': 'Notification sent from Flutter',
      'data': {'type': 'test'},
    }),
  );
  
  if (response.statusCode == 200) {
    print('Notification sent successfully');
  } else {
    print('Error: ${response.statusCode}');
  }
}
```

---

## Part 7: Notification Types Supported

The app handles these notification types:

### Activity Alert
- **Type**: `activity_alert`
- **Example**: User login, data submission, etc.
- **Handler**: Navigates to activity logs page

### Sensor Alert
- **Type**: `sensor_alert`
- **Example**: Voltage threshold exceeded, abnormal reading
- **Handler**: Navigates to sensor data page

### Recommendation
- **Type**: `recommendation`
- **Example**: Energy saving suggestions from AI
- **Handler**: Navigates to recommendations page

### Custom Types
You can add more types by modifying `_handleNotificationTap()` in `notification_service.dart`

---

## Part 8: Testing

### 8.1 Foreground Notification Test
1. Open the app
2. Send a notification using any method above
3. The notification will appear while app is open
4. Check console logs for received data

### 8.2 Background Notification Test
1. Open the app
2. Press home button (keep app in background)
3. Send a notification
4. Notification will appear in system tray
5. Tap notification to open app and handle it

### 8.3 Terminated State Test
1. Close the app completely
2. Send a notification
3. Notification will appear in system tray
4. Tap notification to open app
5. App will navigate based on notification type

---

## Part 9: Troubleshooting

### Issue: FCM Token Not Showing
**Solution**:
1. Ensure permissions are granted
2. Check logcat: `flutter logs`
3. Look for: `[Notification] FCM Token:`

### Issue: Notifications Not Received
**Solutions**:
1. Check service account JSON file exists
2. Verify Firebase project is correct
3. Check device token is valid
4. Ensure app is installed properly

### Issue: Background Handler Not Working
**Solution**:
1. Add `@pragma('vm:entry-point')` to background handler
2. Ensure handler is at top-level
3. Check background execution is enabled on device

### Issue: iOS Certificates
**Solution**:
1. Ensure APNs certificate is uploaded to Firebase
2. Re-run `flutter clean` and rebuild
3. Check iOS provisioning profile

---

## Part 10: Production Checklist

- [ ] Service account JSON file is secure (add to .gitignore)
- [ ] Error handling implemented
- [ ] User consent for notifications obtained
- [ ] Notification frequency is reasonable
- [ ] Test on actual devices (Android & iOS)
- [ ] Add analytics tracking for notifications
- [ ] Document notification types for backend team
- [ ] Set up notification scheduling if needed

---

## File References

**Flutter Files:**
- `lib/services/notification_service.dart` - Main notification service
- `lib/main.dart` - App initialization
- `lib/firebase_options.dart` - Firebase config (auto-generated)

**Backend Files:**
- `backend/send_push_notification.py` - Python script to send notifications
- `backend/fcm_api.py` - FastAPI endpoints for FCM
- `backend/firebase-service-account.json` - Service account credentials (add to .gitignore)

**Android Files:**
- `android/app/src/main/AndroidManifest.xml` - Permissions and services
- `android/app/build.gradle` - Dependencies
- `android/build.gradle` - Google Services plugin

**iOS Files:**
- `ios/Runner.xcworkspace` - Project workspace
- `ios/Podfile` - CocoaPods dependencies

---

## Additional Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview/)
- [Firebase Admin SDK (Python)](https://firebase.google.com/docs/admin/setup)
- [Android Notifications](https://developer.android.com/guide/topics/ui/notifiers/notifications)
- [iOS Push Notifications](https://developer.apple.com/documentation/usernotifications)
