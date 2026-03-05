// Simple API client for ENERGIA backend
// - Uses the host loopback address for Android emulator (10.0.2.2)
// - Exposes `login` and `register` helpers returning JWT token on success

import 'dart:convert';
import 'user_counts.dart';
import 'package:http/http.dart' as http;
import 'user_lists.dart';

/// Base URL for backend API. When running the server on the development
/// machine and testing on Android emulator use 10.0.2.2 to reach host.
/// Candidate backends to try when connecting from different environments.
/// - `10.0.2.2` is the Android emulator host loopback.
/// - `localhost` / `127.0.0.1` are used when running on desktop or when emulator networking
///   resolves the host.
const String _envBase = String.fromEnvironment('ENERGIA_API_BASE');
final List<String> _candidates = [
  if (_envBase.isNotEmpty) _envBase,
  'http://10.0.2.2:5000',
  'http://192.168.160.1:5000', // Host machine IP for Android emulator
  'http://localhost:5000',
  'http://127.0.0.1:5000',
];

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => 'ApiError: $message';
}

/// Login with username/password. Returns access token string on success.
Future<String> login(String username, String password, {String? department}) async {
  // Try candidate bases until one responds successfully.
  Exception? lastError;
  print('[API] Attempting login for user: $username');
  print('[API] Trying candidates: $_candidates');
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/login');
    print('[API] Trying: $uri');
    try {
      final requestBody = {'username': username, 'password': password};
      if (department != null) {
        requestBody['department'] = department;
      }
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody))
          .timeout(Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Login successful!');
        return data['access_token'] as String;
      }
      
      // Handle specific credential errors (400, 401)
      if (resp.statusCode == 400 || resp.statusCode == 401) {
        try {
          final errorData = jsonDecode(resp.body) as Map<String, dynamic>;
          final detail = errorData['detail'] as String?;
          print('[API] Login credential error: $detail');
          throw ApiError(detail ?? 'Invalid credentials');
        } catch (e) {
          if (e is ApiError) rethrow;
          print('[API] Could not parse error response');
          throw ApiError('Invalid credentials');
        }
      }
      
      // Handle system errors (5xx)
      if (resp.statusCode >= 500) {
        print('[API] Backend system error: ${resp.statusCode}');
        throw ApiError('Something went wrong');
      }
      
      // Other errors
      throw ApiError('Login failed');
    } catch (e) {
      if (e is ApiError) {
        print('[API] Error with $base: ${e.message}');
        rethrow; // Re-throw ApiError to show specific message
      }
      print('[API] Connection error with $base: $e');
      lastError = e as Exception;
      // try next candidate
      continue;
    }
  }
  print('[API] All candidates failed. Last error: $lastError');
  throw ApiError('Backend unreachable. Please check your connection or contact support.');
}

/// Register a new user
Future<void> register(String username, String password, {String role = 'student', String? ktuId, String? name, String? department, String? year, String? email}) async {
  Exception? lastError;
  for (final base in _candidates) {
    final uri = Uri.parse('$base/register');
    try {
      final body = <String, dynamic>{
        'username': username,
        'password': password,
        'role': role,
      };
      if (ktuId != null) body['ktu_id'] = ktuId;
      if (name != null) body['name'] = name;
      if (department != null) body['department'] = department;
      if (year != null) body['year'] = year;
      if (email != null) body['email'] = email;
      
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));
      if (resp.statusCode == 200) return;
      throw ApiError('Register failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      lastError = e as Exception;
      continue;
    }
  }
  throw ApiError('Register failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

/// Send an email notification (alert/update) to one or more recipients.
/// [type] should be 'alert' or 'update'.
Future<void> sendNotification({
  required String type,
  required String subject,
  required String body,
  required List<String> recipients,
}) async {
  if (type != 'alert' && type != 'update') {
    throw ApiError('Unsupported notification type: $type');
  }

  Exception? lastError;
  for (final base in _candidates) {
    final uri = Uri.parse('$base/notify/$type');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'subject': subject,
          'body': body,
          'recipients': recipients,
        }),
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) return;
      throw ApiError('Notification failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      lastError = e as Exception;
      continue;
    }
  }

  throw ApiError('Notification failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

Future<void> requestPasswordReset(String username) async {
  Exception? lastError;
  for (final base in _candidates) {
    final uri = Uri.parse('$base/request-password-reset');
    try {
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'username': username}))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) return;
      throw ApiError('Reset request failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      lastError = e as Exception;
      continue;
    }
  }
  throw ApiError('Reset request failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

Future<void> confirmPasswordReset(String username, String otp, String newPassword) async {
  Exception? lastError;
  for (final base in _candidates) {
    final uri = Uri.parse('$base/confirm-password-reset');
    try {
      final resp = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': username,
                'otp': otp,
                'new_password': newPassword,
              }))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) return;
      throw ApiError('Reset confirm failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      lastError = e as Exception;
      continue;
    }
  }
  throw ApiError('Reset confirm failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

/// Fetch all coordinators from the backend
Future<List<Map<String, dynamic>>> getCoordinators() async {
  Exception? lastError;
  print('[API] Fetching coordinators');
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/users/coordinators');
    print('[API] Trying: $uri');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Fetched ${data['total']} coordinators');
        final list = List<Map<String, dynamic>>.from(data['coordinators']);
        UserListsStore.instance.setCoordinators(list);
        return list;
      }
      throw ApiError('Get coordinators failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('[API] Error with $base: $e');
      lastError = e as Exception;
      continue;
    }
  }
  print('[API] All candidates failed. Last error: $lastError');
  throw ApiError('Get coordinators failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

/// Fetch all class representatives from the backend
Future<List<Map<String, dynamic>>> getClassRepresentatives() async {
  Exception? lastError;
  print('[API] Fetching class representatives');
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/users/class-representatives');
    print('[API] Trying: $uri');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Fetched ${data['total']} class representatives');
        final list = List<Map<String, dynamic>>.from(data['class_representatives']);
        UserListsStore.instance.setClassRepresentatives(list);
        return list;
      }
      throw ApiError('Get class representatives failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('[API] Error with $base: $e');
      lastError = e as Exception;
      continue;
    }
  }
  print('[API] All candidates failed. Last error: $lastError');
  throw ApiError('Get class representatives failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

/// Fetch user counts from the backend
Future<Map<String, int>> getUserCounts() async {
  Exception? lastError;
  print('[API] Fetching user counts');
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/users/counts');
    print('[API] Trying: $uri');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Fetched user counts: ${data}');
        final result = {
          'total_users': data['total_users'] as int,
          'coordinators': data['coordinators'] as int,
          'class_representatives': data['class_representatives'] as int,
        };
        // Update shared store so UI can react instantly
        UserCountsStore.instance.setCounts(result);
        return result;
      }
      throw ApiError('Get user counts failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('[API] Error with $base: $e');
      lastError = e as Exception;
      continue;
    }
  }
  print('[API] All candidates failed. Last error: $lastError');
  throw ApiError('Get user counts failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

/// Fetch campus overview metrics: total usage, active/total rooms, efficiency, inactive rooms
Future<Map<String, dynamic>> getCampusOverview({int activeWindowMinutes = 5, int usageWindowHours = 24}) async {
  Exception? lastError;
  print('[API] Fetching campus overview');

  for (final base in _candidates) {
    final uri = Uri.parse('$base/dashboard/overview?active_window_minutes=$activeWindowMinutes&usage_window_hours=$usageWindowHours');
    print('[API] Trying: $uri');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Overview: $data');
        return data;
      }
      throw ApiError('Get campus overview failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('[API] Error with $base: $e');
      lastError = e as Exception;
      continue;
    }
  }
  print('[API] All candidates failed. Last error: $lastError');
  throw ApiError('Get campus overview failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

/// Delete a user (coordinator or class representative) by username
Future<void> deleteUser(String username) async {
  Exception? lastError;
  print('[API] Deleting user: $username');
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/users/$username');
    print('[API] Trying DELETE: $uri');
    try {
      final resp = await http.delete(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        print('[API] User deleted successfully');
        return;
      }
      if (resp.statusCode == 404) {
        throw ApiError('User not found or cannot be deleted');
      }
      throw ApiError('Delete user failed (${base}): ${resp.statusCode} ${resp.body}');
    } catch (e) {
      print('[API] Error with $base: $e');
      lastError = e as Exception;
      if (e is ApiError) rethrow;
      continue;
    }
  }
  print('[API] All candidates failed. Last error: $lastError');
  throw ApiError('Delete user failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}
/// Get activity logs from the backend
Future<List<Map<String, dynamic>>> getActivityLogs({int limit = 10, int days = 1}) async {
  Exception? lastError;
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/activity/logs?limit=$limit&days=$days');
    try {
      print('[API] Fetching activity logs from: $uri');
      final resp = await http.get(uri).timeout(Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final logs = List<Map<String, dynamic>>.from(data['data'] ?? []);
        return logs;
      }
      print('[API] Activity logs from $base: ${resp.statusCode}');
      lastError = ApiError('HTTP ${resp.statusCode}');
      continue;
    } catch (e) {
      print('[API] Error fetching activity logs from $base: $e');
      lastError = e as Exception;
      continue;
    }
  }
  print('[API] Failed to get activity logs. Last error: $lastError');
  return [];
}