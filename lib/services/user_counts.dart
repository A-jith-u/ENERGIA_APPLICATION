import 'package:flutter/foundation.dart';

class UserCountsStore {
  static final UserCountsStore instance = UserCountsStore._();
  UserCountsStore._();

  // keys: total_users, coordinators, class_representatives
  final ValueNotifier<Map<String, int>> counts = ValueNotifier<Map<String, int>>({
    'total_users': 0,
    'coordinators': 0,
    'class_representatives': 0,
  });

  void setCounts(Map<String, int> newCounts) {
    counts.value = {
      'total_users': newCounts['total_users'] ?? counts.value['total_users'] ?? 0,
      'coordinators': newCounts['coordinators'] ?? counts.value['coordinators'] ?? 0,
      'class_representatives': newCounts['class_representatives'] ?? counts.value['class_representatives'] ?? 0,
    };
  }

  void decrement(String roleKey) {
    final current = Map<String, int>.from(counts.value);
    if (current.containsKey(roleKey) && current[roleKey]! > 0) {
      current[roleKey] = current[roleKey]! - 1;
    }
    if (current['total_users'] != null && current['total_users']! > 0) {
      current['total_users'] = current['total_users']! - 1;
    }
    counts.value = current;
  }

  void increment(String roleKey) {
    final current = Map<String, int>.from(counts.value);
    if (current.containsKey(roleKey)) {
      current[roleKey] = (current[roleKey] ?? 0) + 1;
    }
    current['total_users'] = (current['total_users'] ?? 0) + 1;
    counts.value = current;
  }
}