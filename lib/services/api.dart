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
Future<void> register(String username, String password, {String role = 'student', String? ktuId, String? name, String? department, String? year}) async {
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
