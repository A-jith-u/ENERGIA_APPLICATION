// ignore_for_file: avoid_print, unused_element
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Check if Firebase is supported on this platform
  bool get isFirebaseSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> initialize() async {
    // Skip Firebase on unsupported platforms (Windows, Linux, Web)
    if (!isFirebaseSupported) {
      print(
        '[Notification] Firebase Cloud Messaging not supported on this platform',
      );
      return;
    }

    try {
      await _initializeFirebase();
    } catch (e) {
      print('[Notification] Error initializing Firebase: $e');
    }
  }

  /// Initialize Firebase - only called on Android/iOS
  Future<void> _initializeFirebase() async {
    // This code path only executes on Android/iOS
    // Firebase initialization would happen here
    print('[Notification] Firebase initialization setup complete');
  }

  /// Request notification permissions
  Future<void> requestPermission() async {
    if (!isFirebaseSupported) {
      print('[Notification] Permissions not available on this platform');
      return;
    }
    print('[Notification] Permission request would happen here on Android/iOS');
  }

  /// Get FCM device token
  Future<String?> getToken() async {
    if (!isFirebaseSupported) return null;
    print('[Notification] Token retrieval would happen here on Android/iOS');
    return null;
  }

  /// Listen to foreground messages (app in foreground)
  void listenForegroundMessages() {
    if (!isFirebaseSupported) return;
    print('[Notification] Foreground message listener setup on Android/iOS');
  }

  /// Handle notification when app is opened from terminated state
  void handleNotificationWhenAppOpened() {
    if (!isFirebaseSupported) return;
    print(
      '[Notification] Background/terminated notification handler on Android/iOS',
    );
  }

  /// Handle notification tap and navigate
  void _handleNotificationTap(dynamic message) {
    if (!isFirebaseSupported) return;
    print('[Notification] Notification tap handler on Android/iOS');
  }

  /// Subscribe to topic (e.g., for group notifications)
  Future<void> subscribeToTopic(String topic) async {
    if (!isFirebaseSupported) return;
    print('[Notification] Topic subscription for "$topic" on Android/iOS');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!isFirebaseSupported) return;
    print('[Notification] Topic unsubscription for "$topic" on Android/iOS');
  }

  /// Quick admin helper: send a push notification to all users via backend.
  /// Returns true on success, false on error.
  Future<bool> quickSendToAll({
    required String title,
    required String body,
  }) async {
    try {
      await _sendPushToAll(title: title, body: body);
      print('[Notification] Quick send succeeded');
      return true;
    } catch (e) {
      print('[Notification] Quick send failed: $e');
      return false;
    }
  }

  Future<void> _sendPushToAll({
    required String title,
    required String body,
  }) async {
    const candidates = <String>[
      'http://localhost:5000',
      'http://127.0.0.1:5000',
      'http://10.0.2.2:5000',
      'http://192.168.160.1:5000',
    ];

    Object? lastError;
    for (final base in candidates) {
      final uri = Uri.parse('$base/fcm/send-to-all');
      try {
        final resp = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'title': title,
                'body': body,
                'data': <String, dynamic>{},
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          return;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Push broadcast failed. Last error: $lastError');
  }
}
