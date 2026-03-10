import 'package:flutter/material.dart';

class UserPermissionsPage extends StatelessWidget {
  const UserPermissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('User Permissions & Roles'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor: theme.appBarTheme.backgroundColor ?? scheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? scheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Role-Based Access Control',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Comprehensive overview of user roles, permissions, rules, and duties in the ENERGIA system',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Admin Role
              _RoleCard(
                title: 'Administrator',
                icon: Icons.admin_panel_settings,
                color: Colors.red.shade600,
                permissions: const [
                  'Full system access and configuration',
                  'User account management (create, edit, delete)',
                  'Department and building management',
                  'System-wide settings and thresholds',
                  'Access to all reports and analytics',
                  'Activity log monitoring',
                  'Bulk data import/export operations',
                  'Emergency system overrides',
                ],
                rules: const [
                  'Must maintain strict confidentiality of system credentials',
                  'Required to perform regular security audits',
                  'Must document all major system changes',
                  'Responsible for data backup and recovery',
                ],
                duties: const [
                  'Monitor system health and performance',
                  'Respond to critical system alerts',
                  'Manage user access requests',
                  'Generate compliance reports',
                  'Maintain system documentation',
                ],
              ),

              const SizedBox(height: 20),

              // Coordinator Role
              _RoleCard(
                title: 'Department Coordinator',
                icon: Icons.supervisor_account,
                color: Colors.orange.shade600,
                permissions: const [
                  'Department-level oversight and management',
                  'Class representative account management',
                  'Department threshold configuration',
                  'Report generation for assigned department',
                  'Energy consumption monitoring',
                  'Room assignment and mapping',
                  'Activity log access (department scope)',
                ],
                rules: const [
                  'Access limited to assigned department only',
                  'Cannot modify system-wide settings',
                  'Must coordinate with class representatives',
                  'Required to review weekly energy reports',
                ],
                duties: const [
                  'Oversee class representative activities',
                  'Monitor department energy consumption',
                  'Set and enforce department energy goals',
                  'Generate monthly department reports',
                  'Address anomalies and alerts in department',
                  'Coordinate with administration on energy initiatives',
                ],
              ),

              const SizedBox(height: 20),

              // Class Representative Role
              _RoleCard(
                title: 'Class Representative',
                icon: Icons.school,
                color: Colors.blue.shade600,
                permissions: const [
                  'Room-level monitoring and control',
                  'Data submission for assigned classrooms',
                  'Basic energy consumption viewing',
                  'Student energy awareness communication',
                  'Room occupancy reporting',
                  'Anomaly reporting to coordinator',
                ],
                rules: const [
                  'Access limited to assigned rooms only',
                  'Cannot modify threshold settings',
                  'Must submit data within designated timeframes',
                  'Required to report unusual consumption patterns',
                ],
                duties: const [
                  'Daily energy consumption data collection',
                  'Ensure proper equipment usage in classrooms',
                  'Communicate energy policies to students',
                  'Report faulty equipment or sensors',
                  'Participate in department energy meetings',
                  'Promote energy conservation practices',
                ],
              ),

              const SizedBox(height: 20),

              // Sergeant Role
              _RoleCard(
                title: 'Campus Sergeant',
                icon: Icons.security,
                color: Colors.purple.shade600,
                permissions: const [
                  'Campus-wide security and power management',
                  'Real-time relay control (on/off)',
                  'After-hours facility monitoring',
                  'Live sensor and relay status access',
                  'Emergency power shutdown authority',
                  'Anomaly detection and response',
                  'Night shift monitoring dashboard',
                  'Critical alert acknowledgment',
                ],
                rules: const [
                  'Must have physical presence on campus',
                  'Access granted for security purposes only',
                  'Required to log all power control actions',
                  'Must follow escalation protocols for anomalies',
                  'Cannot access user management functions',
                ],
                duties: const [
                  'Monitor live power consumption during shifts',
                  'Respond to after-hours energy alerts',
                  'Control power to unoccupied areas at night',
                  'Patrol and verify equipment status',
                  'Document security and energy incidents',
                  'Coordinate with maintenance for equipment issues',
                  'Ensure compliance with safety protocols',
                ],
              ),

              const SizedBox(height: 32),

              // Summary Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Access Control Summary',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(
                        icon: Icons.lock,
                        label: 'Authentication',
                        value: 'All roles require JWT token-based authentication',
                      ),
                      _SummaryRow(
                        icon: Icons.visibility,
                        label: 'Data Visibility',
                        value: 'Scoped to role level (admin > coordinator > class rep > sergeant)',
                      ),
                      _SummaryRow(
                        icon: Icons.edit,
                        label: 'Modification Rights',
                        value: 'Only admin can modify system configuration',
                      ),
                      _SummaryRow(
                        icon: Icons.warning,
                        label: 'Security',
                        value: 'All actions logged with timestamp, user ID, and IP address',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> permissions;
  final List<String> rules;
  final List<String> duties;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.permissions,
    required this.rules,
    required this.duties,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Permissions Section
                _SectionHeader(
                  icon: Icons.check_circle_outline,
                  title: 'Permissions',
                  color: Colors.green.shade700,
                ),
                const SizedBox(height: 12),
                ...permissions.map((p) => _BulletPoint(text: p)),
                
                const SizedBox(height: 24),
                
                // Rules Section
                _SectionHeader(
                  icon: Icons.rule,
                  title: 'Access Rules',
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 12),
                ...rules.map((r) => _BulletPoint(text: r)),
                
                const SizedBox(height: 24),
                
                // Duties Section
                _SectionHeader(
                  icon: Icons.assignment_outlined,
                  title: 'Core Duties',
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 12),
                ...duties.map((d) => _BulletPoint(text: d)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
