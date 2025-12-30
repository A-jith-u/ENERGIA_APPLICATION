// Simple API client for ENERGIA backend
// - Uses the host loopback address for Android emulator (10.0.2.2)
// - Exposes `login` and `register` helpers returning JWT token on success

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base URL for backend API. When running the server on the development
/// machine and testing on Android emulator use 10.0.2.2 to reach host.
/// Candidate backends to try when connecting from different environments.
/// - `10.0.2.2` is the Android emulator host loopback.
/// - `localhost` / `127.0.0.1` are used when running on desktop or when emulator networking
///   resolves the host.
const String _envBase = String.fromEnvironment('ENERGIA_API_BASE');
final List<String> _candidates = [
  if (_envBase.isNotEmpty) _envBase,
  'http://10.0.2.2:8000',
  'http://localhost:8000',
  'http://127.0.0.1:8000',
];

class ApiError implements Exception {
  final String message;
  ApiError(this.message);
  @override
  String toString() => 'ApiError: $message';
}

/// Login with username/password. Returns access token string on success.
Future<String> login(String username, String password) async {
  // Try candidate bases until one responds successfully.
  Exception? lastError;
  print('[API] Attempting login for user: $username');
  print('[API] Trying candidates: $_candidates');
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/auth/login');
    print('[API] Trying: $uri');
    try {
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}))
          .timeout(Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Login successful!');
        return data['access_token'] as String;
      }
      // server reachable but returned error — surface body when present
      final body = resp.body.isNotEmpty ? resp.body : resp.statusCode.toString();
      print('[API] Login failed: ${resp.statusCode} $body');
      throw ApiError('Login failed (${base}): ${resp.statusCode} $body');
    } catch (e) {
      print('[API] Error with $base: $e');
      lastError = e as Exception;
      // try next candidate
      continue;
    }
  }
  print('[API] All candidates failed. Last error: $lastError');
  throw ApiError('Login failed, no backend reachable. Last error: ${lastError ?? 'unknown'}');
}

/// Register a new user
Future<void> register(String username, String password, {String role = 'student', String? ktuId, String? name, String? department, String? year, String? email}) async {
  Exception? lastError;
  for (final base in _candidates) {
    final uri = Uri.parse('$base/auth/register');
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
    final uri = Uri.parse('$base/auth/request-password-reset');
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
    final uri = Uri.parse('$base/auth/confirm-password-reset');
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
    final uri = Uri.parse('$base/auth/users/coordinators');
    print('[API] Trying: $uri');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Fetched ${data['total']} coordinators');
        return List<Map<String, dynamic>>.from(data['coordinators']);
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
    final uri = Uri.parse('$base/auth/users/class-representatives');
    print('[API] Trying: $uri');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Fetched ${data['total']} class representatives');
        return List<Map<String, dynamic>>.from(data['class_representatives']);
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
    final uri = Uri.parse('$base/auth/users/counts');
    print('[API] Trying: $uri');
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      print('[API] Response from $base: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        print('[API] Fetched user counts: ${data}');
        return {
          'total_users': data['total_users'] as int,
          'coordinators': data['coordinators'] as int,
          'class_representatives': data['class_representatives'] as int,
          'admins': data['admins'] as int,
        };
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

/// Delete a user (coordinator or class representative) by username
Future<void> deleteUser(String username) async {
  Exception? lastError;
  print('[API] Deleting user: $username');
  
  for (final base in _candidates) {
    final uri = Uri.parse('$base/auth/users/$username');
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
