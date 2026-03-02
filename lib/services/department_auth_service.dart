import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:energia/models/user_role_model.dart';

/// Authentication service with department-based role support
class DepartmentAuthService {
  static final DepartmentAuthService _instance = DepartmentAuthService._internal();

  factory DepartmentAuthService() {
    return _instance;
  }

  DepartmentAuthService._internal();

  // Try multiple base URLs in order of preference
  static const List<String> _baseUrls = [
    'http://192.168.160.1:5000',
    'http://10.93.17.69:5000',
    'http://10.0.2.2:5000', // Android emulator
    'http://localhost:5000',
    'http://127.0.0.1:5000',
  ];
  
  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';
  static const String _deptKey = 'user_department';
  static const String _roleKey = 'user_role';

  late SharedPreferences _prefs;
  EnhancedUser? _currentUser;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get current user
  EnhancedUser? get currentUser => _currentUser;

  /// Get current user's department
  Department? get currentDepartment => _currentUser?.department;

  /// Check if user is logged in
  bool get isLoggedIn => _currentUser != null;

  /// Login coordinator with department
  Future<LoginResult> loginCoordinator({
    required String coordinatorId,
    required String password,
    String? department,
  }) async {
    // Try each base URL until one works
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/coordinator/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': coordinatorId,
            'coordinator_id': coordinatorId,
            'password': password,
            if (department != null && department.isNotEmpty) 'department': department,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final user = EnhancedUser(
            id: data['id'].toString(),
            username: data['coordinator_id'],
            email: data['email'],
            name: data['name'],
            role: UserRole.technicalCoordinator,
            department: _parseDepartment(data['department']),
            createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
            lastLogin: DateTime.now(),
            coordinatorId: data['coordinator_id'],
          );

          await _saveUser(user, data['token']);
          _currentUser = user;

          return LoginResult.success(user);
        } else if (response.statusCode == 401) {
          return LoginResult.error('Invalid credentials');
        } else {
          return LoginResult.error('Login failed: ${response.statusCode}');
        }
      } catch (e) {
        // Try next URL
        continue;
      }
    }
    
    return LoginResult.error('Cannot connect to server. Please check if backend is running.');
  }

  /// Login class representative with department
  Future<LoginResult> loginClassRepresentative({
    required String username,
    required String password,
  }) async {
    // Try each base URL until one works
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/student/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final user = EnhancedUser(
            id: data['id'].toString(),
            username: data['username'],
            email: data['email'],
            name: data['name'],
            role: UserRole.classRepresentative,
            department: _parseDepartment(data['department']),
            createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
            lastLogin: DateTime.now(),
            ktuId: data['ktu_id'],
            classYear: data['year'],
            section: data['section'],
          );

          await _saveUser(user, data['token']);
          _currentUser = user;

          return LoginResult.success(user);
        } else if (response.statusCode == 401) {
          return LoginResult.error('Invalid credentials');
        } else {
          return LoginResult.error('Login failed: ${response.statusCode}');
        }
      } catch (e) {
        // Try next URL
        continue;
      }
    }
    
    return LoginResult.error('Cannot connect to server. Please check if backend is running.');
  }

  /// Login admin with department
  Future<LoginResult> loginAdmin({
    required String username,
    required String password,
  }) async {
    // Try each base URL until one works
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final isSuperAdmin = data['is_superadmin'] ?? false;

          final user = EnhancedUser(
            id: data['id'].toString(),
            username: data['username'],
            email: data['email'],
            name: data['name'],
            role: isSuperAdmin ? UserRole.superAdmin : UserRole.admin,
            department: _parseDepartment(data['department']),
            createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
            lastLogin: DateTime.now(),
          );

          await _saveUser(user, data['token']);
          _currentUser = user;

          return LoginResult.success(user);
        } else if (response.statusCode == 401) {
          return LoginResult.error('Invalid credentials');
        } else {
          return LoginResult.error('Login failed: ${response.statusCode}');
        }
      } catch (e) {
        // Try next URL
        continue;
      }
    }
    
    return LoginResult.error('Cannot connect to server. Please check if backend is running.');
  }

  /// Restore session if user was previously logged in
  Future<bool> restoreSession() async {
    try {
      final userJson = _prefs.getString(_userKey);
      if (userJson == null) return false;

      final userData = jsonDecode(userJson);
      _currentUser = EnhancedUser.fromJson(userData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _currentUser = null;
    await _prefs.remove(_userKey);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_deptKey);
    await _prefs.remove(_roleKey);
  }

  /// Refresh user data from server
  Future<bool> refreshUserData() async {
    if (_currentUser == null) return false;

    final token = _prefs.getString(_tokenKey);
    if (token == null) return false;

    // Try each base URL until one works
    for (final baseUrl in _baseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/user/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _currentUser = EnhancedUser.fromJson(data);
          await _prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
          return true;
        }
      } catch (e) {
        // Try next URL
        continue;
      }
    }

    return false;
  }

  /// Check if current user has access to a specific feature
  bool canAccessFeature(String featureName) {
    if (_currentUser == null) return false;
    return _currentUser!.canAccessFeature(featureName);
  }

  /// Check if current user can access a specific room
  bool canAccessRoom(String roomId) {
    if (_currentUser == null) return false;

    final accessibleRooms = _currentUser!.getAccessibleRooms(_getAllRooms());
    return accessibleRooms.contains(roomId);
  }

  /// Get all rooms user can access
  List<String> getAccessibleRooms() {
    if (_currentUser == null) return [];
    return _currentUser!.getAccessibleRooms(_getAllRooms());
  }

  // Private helper methods

  Future<void> _saveUser(EnhancedUser user, String token) async {
    // Ensure prefs is initialized
    _prefs = await SharedPreferences.getInstance();
    
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_deptKey, user.department.name);
    await _prefs.setString(_roleKey, user.role.name);
  }

  Department _parseDepartment(String deptStr) {
    try {
      return Department.values.firstWhere(
        (d) => d.name == deptStr.toLowerCase(),
      );
    } catch (e) {
      return Department.admin;
    }
  }

  List<String> _getAllRooms() {
    // This would be fetched from your backend
    return [
      'CSL-101', 'CSL-102', 'CSL-103', 'CS-Lab-1', 'CS-Lab-2', 'Server-Room',
      'ELE-101', 'ELE-102', 'ELE-Lab-1', 'Power-Room',
      'ECE-101', 'ECE-102', 'ECE-Lab-1',
      'MECH-101', 'MECH-102', 'MECH-Lab-1', 'Workshop',
      'ITT-101', 'ITT-102',
      'CIVIL-101', 'CIVIL-102',
    ];
  }
}

/// Result object for login operations
class LoginResult {
  final bool success;
  final String? message;
  final EnhancedUser? user;

  LoginResult({
    required this.success,
    this.message,
    this.user,
  });

  factory LoginResult.success(EnhancedUser user) {
    return LoginResult(
      success: true,
      user: user,
    );
  }

  factory LoginResult.error(String message) {
    return LoginResult(
      success: false,
      message: message,
    );
  }
}
