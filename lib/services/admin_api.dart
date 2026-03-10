import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _envBase = String.fromEnvironment('ENERGIA_API_BASE');
final List<String> _candidates = [
  if (_envBase.isNotEmpty) _envBase,
  'http://localhost:5000',
  'http://127.0.0.1:5000',
  'http://10.0.2.2:5000',
  'http://192.168.160.1:5000',
];

String? _lastHealthyBase;
final Map<String, DateTime> _baseCooldownUntil = <String, DateTime>{};
const Duration _baseCooldown = Duration(seconds: 45);
const Duration _requestTimeout = Duration(seconds: 8);

List<String> _orderedCandidates() {
  final now = DateTime.now();
  final active = <String>[];
  final coolingDown = <String>[];

  for (final base in _candidates) {
    final until = _baseCooldownUntil[base];
    if (until != null && now.isBefore(until)) {
      coolingDown.add(base);
    } else {
      active.add(base);
    }
  }

  if (_lastHealthyBase != null) {
    active.remove(_lastHealthyBase);
    active.insert(0, _lastHealthyBase!);
  }

  return [...active, ...coolingDown];
}

void _markBaseHealthy(String base) {
  _lastHealthyBase = base;
  _baseCooldownUntil.remove(base);
}

void _markBaseFailed(String base, Object error) {
  if (error is TimeoutException || error is SocketException || error is http.ClientException) {
    _baseCooldownUntil[base] = DateTime.now().add(_baseCooldown);
  }
}

class AdminApiError implements Exception {
  final String message;
  AdminApiError(this.message);

  @override
  String toString() => 'AdminApiError: $message';
}

Map<String, String> _headers({String? token}) {
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };
  if (token != null && token.isNotEmpty) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

dynamic _safeJsonDecode(String body) {
  if (body.trim().isEmpty) {
    throw AdminApiError('Empty response from server');
  }
  try {
    return jsonDecode(body);
  } catch (e) {
    throw AdminApiError('Invalid JSON response: ${e.toString()}');
  }
}

Future<Map<String, dynamic>> _getJson(String path, {String? token}) async {
  Exception? lastError;
  final candidates = _orderedCandidates();

  for (final base in candidates) {
    final uri = Uri.parse('$base$path');
    try {
      final response = await http
          .get(uri, headers: _headers(token: token))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _markBaseHealthy(base);
        return _safeJsonDecode(response.body) as Map<String, dynamic>;
      }

      String message = 'Request failed (${response.statusCode})';
      try {
        final body = _safeJsonDecode(response.body) as Map<String, dynamic>;
        message = (body['detail'] ?? body['message'] ?? message).toString();
      } catch (_) {
        // Keep fallback message.
      }
      _markBaseFailed(base, AdminApiError(message));
      throw AdminApiError(message);
    } catch (e) {
      if (e is AdminApiError) rethrow;
      _markBaseFailed(base, e);
      lastError = e as Exception;
      continue;
    }
  }

  throw AdminApiError(
    'Backend unreachable. Last error: ${lastError ?? 'unknown'}',
  );
}

Future<Map<String, dynamic>> _putJson(
  String path,
  Map<String, dynamic> payload, {
  String? token,
}) async {
  Exception? lastError;
  final candidates = _orderedCandidates();

  for (final base in candidates) {
    final uri = Uri.parse('$base$path');
    try {
      final response = await http
          .put(
            uri,
            headers: _headers(token: token),
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _markBaseHealthy(base);
        return _safeJsonDecode(response.body) as Map<String, dynamic>;
      }

      String message = 'Request failed (${response.statusCode})';
      try {
        final body = _safeJsonDecode(response.body) as Map<String, dynamic>;
        message = (body['detail'] ?? body['message'] ?? message).toString();
      } catch (_) {
        // Keep fallback message.
      }
      _markBaseFailed(base, AdminApiError(message));
      throw AdminApiError(message);
    } catch (e) {
      if (e is AdminApiError) rethrow;
      _markBaseFailed(base, e);
      lastError = e as Exception;
      continue;
    }
  }

  throw AdminApiError(
    'Backend unreachable. Last error: ${lastError ?? 'unknown'}',
  );
}

Future<Map<String, dynamic>> _postJson(
  String path,
  Map<String, dynamic> payload, {
  String? token,
}) async {
  Exception? lastError;
  final candidates = _orderedCandidates();

  for (final base in candidates) {
    final uri = Uri.parse('$base$path');
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(token: token),
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        _markBaseHealthy(base);
        return _safeJsonDecode(response.body) as Map<String, dynamic>;
      }

      String message = 'Request failed (${response.statusCode})';
      try {
        final body = _safeJsonDecode(response.body) as Map<String, dynamic>;
        message = (body['detail'] ?? body['message'] ?? message).toString();
      } catch (_) {
        // Keep fallback message.
      }
      _markBaseFailed(base, AdminApiError(message));
      throw AdminApiError(message);
    } catch (e) {
      if (e is AdminApiError) rethrow;
      _markBaseFailed(base, e);
      lastError = e as Exception;
      continue;
    }
  }

  throw AdminApiError(
    'Backend unreachable. Last error: ${lastError ?? 'unknown'}',
  );
}

/// Get admin profile information
Future<Map<String, dynamic>> getAdminProfile(String token) async {
  final response = await _getJson('/admin/profile', token: token);
  return Map<String, dynamic>.from(response['data'] ?? <String, dynamic>{});
}

/// Update admin profile (name, email, phone)
Future<Map<String, dynamic>> updateAdminProfile(
  String token, {
  String? name,
  String? email,
  String? phone,
}) async {
  final body = <String, dynamic>{};
  if (name != null && name.isNotEmpty) body['name'] = name;
  if (email != null && email.isNotEmpty) body['email'] = email;
  if (phone != null && phone.isNotEmpty) body['phone'] = phone;

  return _putJson('/admin/profile', body, token: token);
}

/// Change admin password
Future<Map<String, dynamic>> changeAdminPassword(
  String token, {
  required String currentPassword,
  required String newPassword,
}) async {
  return _postJson(
    '/admin/change-password',
    {
      'current_password': currentPassword,
      'new_password': newPassword,
    },
    token: token,
  );
}
