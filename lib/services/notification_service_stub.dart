// ignore_for_file: avoid_print, unused_element
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Stub notification service for unsupported platforms (Windows, Linux, Web)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  bool get isFirebaseSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> initialize() async {
    print('[Notification] Notification service not available on this platform');
  }

  Future<void> requestPermission() async {}

  Future<String?> getToken() async => null;

  void listenForegroundMessages() {}

  void handleNotificationWhenAppOpened() {}

  void _handleNotificationTap(dynamic message) {}

  Future<void> subscribeToTopic(String topic) async {}

  Future<void> unsubscribeFromTopic(String topic) async {}

  Stream<String>? getTokenStream() => null;
}
