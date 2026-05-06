// ignore_for_file: deprecated_member_use, file_names
import 'package:flutter/material.dart';
import 'package:energia/models/user_role_model.dart';

/// Service to manage department-specific customization and configurations
class DepartmentCustomizationService {
  static final DepartmentCustomizationService _instance =
      DepartmentCustomizationService._internal();

  factory DepartmentCustomizationService() {
    return _instance;
  }

  DepartmentCustomizationService._internal();

  /// Get theme data specific to a department
  ThemeData getDepartmentTheme(Department department) {
    final primaryColor =
        departmentColors[department] ?? const Color(0xFF005BBB);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }

  /// Get dashboard features available for a specific role
  List<DashboardFeature> getDashboardFeatures(
    UserRole role,
    Department department,
  ) {
    final features = <DashboardFeature>[];

    // Common features for all coordinators
    if (role == UserRole.technicalCoordinator ||
        role == UserRole.admin ||
        role == UserRole.superAdmin) {
      features.addAll([
        DashboardFeature(
          id: 'overview',
          title: 'Energy Overview',
          description: 'Real-time energy consumption overview',
          icon: Icons.dashboard,
          route: '/coordinator_dashboard',
          order: 1,
        ),
        DashboardFeature(
          id: 'live_data',
          title: 'Live Data',
          description: 'Real-time sensor data from devices',
          icon: Icons.show_chart,
          route: '/live_data',
          order: 2,
        ),
        DashboardFeature(
          id: 'analytics',
          title: 'Analytics',
          description: 'Energy consumption trends and analysis',
          icon: Icons.trending_up,
          route: '/prediction_page',
          order: 3,
        ),
      ]);
    }

    // Admin-exclusive features
    if (role == UserRole.admin || role == UserRole.superAdmin) {
      features.addAll([
        DashboardFeature(
          id: 'threshold_management',
          title: 'Threshold Management',
          description: 'Set energy consumption thresholds',
          icon: Icons.settings,
          route: '/threshold_search',
          order: 4,
        ),
        DashboardFeature(
          id: 'room_management',
          title: 'Room Management',
          description: 'Configure rooms and sensors',
          icon: Icons.meeting_room,
          route: '/room_management',
          order: 5,
        ),
      ]);
    }

    // Super admin features
    if (role == UserRole.superAdmin) {
      features.add(
        DashboardFeature(
          id: 'user_management',
          title: 'User Management',
          description: 'Manage all users across departments',
          icon: Icons.people,
          route: '/user_management',
          order: 6,
        ),
      );
    }

    // Class representative features
    if (role == UserRole.classRepresentative) {
      features.addAll([
        DashboardFeature(
          id: 'classroom_overview',
          title: 'Classroom Overview',
          description: 'Your classroom energy status',
          icon: Icons.class_,
          route: '/classroom_dashboard',
          order: 1,
        ),
        DashboardFeature(
          id: 'daily_report',
          title: 'Daily Report',
          description: 'Daily energy consumption report',
          icon: Icons.article,
          route: '/daily_report',
          order: 2,
        ),
        DashboardFeature(
          id: 'trends',
          title: 'Trends',
          description: 'Weekly and monthly trends',
          icon: Icons.show_chart,
          route: '/trends',
          order: 3,
        ),
      ]);
    }

    // Department-specific customizations
    features.addAll(_getDepartmentSpecificFeatures(role, department));

    return features..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Get department-specific menu items
  List<DepartmentMenuItem> getDepartmentMenuItems(
    Department department,
    UserRole role,
  ) {
    final items = <DepartmentMenuItem>[
      DepartmentMenuItem(
        id: 'dept_overview',
        title: '${departmentNames[department]} Overview',
        icon: Icons.domain,
        route: '/department_overview',
        color: departmentColors[department] ?? Colors.blue,
      ),
    ];

    // Add department-specific items
    switch (department) {
      case Department.computerScience:
        items.addAll([
          DepartmentMenuItem(
            id: 'lab_monitoring',
            title: 'Lab Monitoring',
            icon: Icons.computer,
            route: '/cs_lab_monitoring',
            color: departmentColors[department]!,
          ),
          DepartmentMenuItem(
            id: 'server_room',
            title: 'Server Room',
            icon: Icons.dns,
            route: '/server_room_monitoring',
            color: departmentColors[department]!,
          ),
        ]);
        break;
      case Department.electrical:
        items.addAll([
          DepartmentMenuItem(
            id: 'distribution_monitoring',
            title: 'Distribution Monitoring',
            icon: Icons.electric_bolt,
            route: '/electrical_distribution',
            color: departmentColors[department]!,
          ),
          DepartmentMenuItem(
            id: 'power_quality',
            title: 'Power Quality',
            icon: Icons.assessment,
            route: '/power_quality',
            color: departmentColors[department]!,
          ),
        ]);
        break;
      case Department.electronics:
        items.addAll([
          DepartmentMenuItem(
            id: 'device_monitoring',
            title: 'Device Monitoring',
            icon: Icons.devices,
            route: '/device_monitoring',
            color: departmentColors[department]!,
          ),
        ]);
        break;
      case Department.mechanical:
        items.addAll([
          DepartmentMenuItem(
            id: 'hvac_monitoring',
            title: 'HVAC Monitoring',
            icon: Icons.air,
            route: '/hvac_monitoring',
            color: departmentColors[department]!,
          ),
        ]);
        break;
      case Department.itt:
      case Department.civilEngineering:
      case Department.admin:
        // Default items
        break;
    }

    return items;
  }

  /// Get customized metrics to display for a role
  List<MetricCard> getMetricsForRole(UserRole role, Department department) {
    final metrics = <MetricCard>[];

    // Common metrics
    metrics.add(
      MetricCard(
        id: 'total_consumption',
        title: 'Total Consumption',
        unit: 'kWh',
        icon: Icons.bolt,
        displayPriority: 1,
      ),
    );

    // Role-specific metrics
    if (role == UserRole.technicalCoordinator ||
        role == UserRole.admin ||
        role == UserRole.superAdmin) {
      metrics.addAll([
        MetricCard(
          id: 'peak_load',
          title: 'Peak Load',
          unit: 'kW',
          icon: Icons.trending_up,
          displayPriority: 2,
        ),
        MetricCard(
          id: 'avg_load',
          title: 'Average Load',
          unit: 'kW',
          icon: Icons.show_chart,
          displayPriority: 3,
        ),
      ]);
    }

    // Department-specific metrics
    switch (department) {
      case Department.computerScience:
        metrics.add(
          MetricCard(
            id: 'cooling_efficiency',
            title: 'Cooling Efficiency',
            unit: '%',
            icon: Icons.ac_unit,
            displayPriority: 4,
          ),
        );
        break;
      case Department.electrical:
        metrics.add(
          MetricCard(
            id: 'power_factor',
            title: 'Power Factor',
            unit: 'PF',
            icon: Icons.electric_bolt,
            displayPriority: 4,
          ),
        );
        break;
      case Department.mechanical:
        metrics.add(
          MetricCard(
            id: 'efficiency_rating',
            title: 'Efficiency Rating',
            unit: '%',
            icon: Icons.settings,
            displayPriority: 4,
          ),
        );
        break;
      default:
        break;
    }

    return metrics
      ..sort((a, b) => a.displayPriority.compareTo(b.displayPriority));
  }

  /// Get department-specific color scheme for charts
  Map<String, Color> getDepartmentChartColors(Department department) {
    final baseColor = departmentColors[department] ?? const Color(0xFF005BBB);

    return {
      'primary': baseColor,
      'secondary': baseColor.withOpacity(0.7),
      'accent': baseColor.withOpacity(0.5),
      'background': baseColor.withOpacity(0.1),
    };
  }

  /// Check if role can access department-specific features
  bool canAccessDepartmentFeatures(
    UserRole role,
    Department userDept,
    Department targetDept,
  ) {
    // Super admin can access all
    if (role == UserRole.superAdmin) return true;

    // Admin can access their department only
    if (role == UserRole.admin) return userDept == targetDept;

    // Coordinators can access their department only
    if (role == UserRole.technicalCoordinator) return userDept == targetDept;

    // Class representatives can access their department only
    if (role == UserRole.classRepresentative) return userDept == targetDept;

    return false;
  }

  /// Get list of accessible rooms by department
  List<String> getAccessibleRoomsByDepartment(Department department) {
    final roomsByDept = {
      Department.computerScience: [
        'CSL-101',
        'CSL-102',
        'CSL-103',
        'CS-Lab-1',
        'CS-Lab-2',
        'Server-Room',
      ],
      Department.electrical: ['ELE-101', 'ELE-102', 'ELE-Lab-1', 'Power-Room'],
      Department.electronics: ['ECE-101', 'ECE-102', 'ECE-Lab-1'],
      Department.mechanical: ['MECH-101', 'MECH-102', 'MECH-Lab-1', 'Workshop'],
      Department.itt: ['ITT-101', 'ITT-102'],
      Department.civilEngineering: ['CIVIL-101', 'CIVIL-102'],
      Department.admin: [],
    };

    return (roomsByDept[department])?.cast<String>() ?? [];
  }

  List<DashboardFeature> _getDepartmentSpecificFeatures(
    UserRole role,
    Department department,
  ) {
    final features = <DashboardFeature>[];

    if (role == UserRole.technicalCoordinator ||
        role == UserRole.admin ||
        role == UserRole.superAdmin) {
      switch (department) {
        case Department.computerScience:
          features.addAll([
            DashboardFeature(
              id: 'lab_equipment',
              title: 'Lab Equipment',
              description: 'Monitor lab equipment energy usage',
              icon: Icons.computer,
              route: '/lab_equipment',
              order: 7,
            ),
          ]);
          break;
        case Department.electrical:
          features.addAll([
            DashboardFeature(
              id: 'power_distribution',
              title: 'Power Distribution',
              description: 'Monitor power distribution systems',
              icon: Icons.electric_bolt,
              route: '/power_distribution',
              order: 7,
            ),
          ]);
          break;
        case Department.mechanical:
          features.addAll([
            DashboardFeature(
              id: 'hvac_systems',
              title: 'HVAC Systems',
              description: 'Monitor heating and cooling systems',
              icon: Icons.air,
              route: '/hvac_systems',
              order: 7,
            ),
          ]);
          break;
        default:
          break;
      }
    }

    return features;
  }
}

/// Model for dashboard features
class DashboardFeature {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final int order;

  DashboardFeature({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.order,
  });
}

/// Model for department menu items
class DepartmentMenuItem {
  final String id;
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  DepartmentMenuItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
  });
}

/// Model for metric cards
class MetricCard {
  final String id;
  final String title;
  final String unit;
  final IconData icon;
  final int displayPriority;

  MetricCard({
    required this.id,
    required this.title,
    required this.unit,
    required this.icon,
    required this.displayPriority,
  });
}
