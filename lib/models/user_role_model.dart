import 'package:flutter/material.dart';

// Define all possible user roles
enum UserRole {
  student,
  classRepresentative,
  technicalCoordinator,
  admin,
  superAdmin,
}

// Define all departments
enum Department {
  computerScience,
  electrical,
  electronics,
  mechanical,
  itt,
  civilEngineering,
  admin,
}

// Department to display name mapping
const Map<Department, String> departmentNames = {
  Department.computerScience: 'Computer Science',
  Department.electrical: 'Electrical',
  Department.electronics: 'Electronics',
  Department.mechanical: 'Mechanical',
  Department.itt: 'ITT',
  Department.civilEngineering: 'Civil Engineering',
  Department.admin: 'Administration',
};

// Department to color mapping for UI consistency
const Map<Department, Color> departmentColors = {
  Department.computerScience: Color(0xFF2196F3), // Blue
  Department.electrical: Color(0xFFFF9800), // Orange
  Department.electronics: Color(0xFFF44336), // Red
  Department.mechanical: Color(0xFF4CAF50), // Green
  Department.itt: Color(0xFF9C27B0), // Purple
  Department.civilEngineering: Color(0xFF795548), // Brown
  Department.admin: Color(0xFF607D8B), // Blue Grey
};

// Department to icon mapping
const Map<Department, IconData> departmentIcons = {
  Department.computerScience: Icons.computer,
  Department.electrical: Icons.electric_bolt,
  Department.electronics: Icons.devices,
  Department.mechanical: Icons.settings,
  Department.itt: Icons.info_outline,
  Department.civilEngineering: Icons.apartment,
  Department.admin: Icons.admin_panel_settings,
};

/// Enhanced user model with department and role-based customization
class EnhancedUser {
  final String id;
  final String username;
  final String email;
  final String name;
  final UserRole role;
  final Department department;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool isActive;
  
  // Additional fields for coordinators
  final String? coordinatorId;
  
  // Additional fields for class representatives
  final String? ktuId;
  final String? classYear;
  final String? section;

  EnhancedUser({
    required this.id,
    required this.username,
    required this.email,
    required this.name,
    required this.role,
    required this.department,
    required this.createdAt,
    this.lastLogin,
    this.isActive = true,
    this.coordinatorId,
    this.ktuId,
    this.classYear,
    this.section,
  });

  /// Get user's display title based on role and department
  String getDisplayTitle() {
    switch (role) {
      case UserRole.classRepresentative:
        return 'Class Representative - ${departmentNames[department]!}';
      case UserRole.technicalCoordinator:
        return 'Technical Coordinator - ${departmentNames[department]!}';
      case UserRole.admin:
        return 'Department Admin - ${departmentNames[department]!}';
      case UserRole.superAdmin:
        return 'System Administrator';
      case UserRole.student:
        return 'Student';
    }
  }

  /// Check if user can access a specific feature
  bool canAccessFeature(String featureName) {
    switch (role) {
      case UserRole.classRepresentative:
        return ['view_classroom_data', 'view_trends', 'generate_reports']
            .contains(featureName);
      case UserRole.technicalCoordinator:
        return [
          'view_all_data',
          'manage_thresholds',
          'view_trends',
          'generate_reports',
          'manage_rooms',
          'export_data'
        ].contains(featureName);
      case UserRole.admin:
        return [
          'view_all_data',
          'manage_users',
          'manage_thresholds',
          'view_trends',
          'generate_reports',
          'manage_rooms',
          'export_data',
          'system_settings'
        ].contains(featureName);
      case UserRole.superAdmin:
        return true; // Full access
      case UserRole.student:
        return ['view_classroom_data'].contains(featureName);
    }
  }

  /// Get list of rooms user can access based on role and department
  List<String> getAccessibleRooms(List<String> allRooms) {
    switch (role) {
      case UserRole.classRepresentative:
      case UserRole.technicalCoordinator:
      case UserRole.admin:
        // Filter rooms by department
        return allRooms
            .where((room) => room.toLowerCase().contains(department.name.toLowerCase()))
            .toList();
      case UserRole.student:
        // Students can see only their assigned classroom
        return [];
      case UserRole.superAdmin:
        return allRooms;
    }
  }

  /// Convert to JSON for API communication
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'name': name,
      'role': role.toString().split('.').last,
      'department': department.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'is_active': isActive,
      'coordinator_id': coordinatorId,
      'ktu_id': ktuId,
      'class_year': classYear,
      'section': section,
    };
  }

  /// Create from JSON
  factory EnhancedUser.fromJson(Map<String, dynamic> json) {
    return EnhancedUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.student,
      ),
      department: Department.values.firstWhere(
        (d) => d.toString() == 'Department.${json['department']}',
        orElse: () => Department.admin,
      ),
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      lastLogin: json['last_login'] != null ? DateTime.parse(json['last_login']) : null,
      isActive: json['is_active'] ?? true,
      coordinatorId: json['coordinator_id'],
      ktuId: json['ktu_id'],
      classYear: json['class_year'],
      section: json['section'],
    );
  }

  @override
  String toString() => 'EnhancedUser($id, $username, ${role.name}, ${department.name})';
}
