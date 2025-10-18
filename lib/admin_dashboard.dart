import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardScaffold(
      title: '⚡ GECI ENERGIA Control Center',
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPage(_currentIndex, colorScheme),
      ),
      currentIndex: _currentIndex,
      onBottomNavTapped: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      bottomNavItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Campus',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Users',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.health_and_safety_outlined),
          activeIcon: Icon(Icons.health_and_safety),
          label: 'System',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Control',
        ),
      ],
      floatingActionButton: _currentIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency Stop'),
              backgroundColor: Colors.red.shade600,
            )
          : null,
    );
  }

  Widget _buildPage(int index, ColorScheme scheme) {
    switch (index) {
      case 0:
        return _CampusOverviewSection(scheme: scheme);
      case 1:
        return _UsersManagementSection(scheme: scheme);
      case 2:
        return _SystemHealthSection(scheme: scheme);
      case 3:
        return _CampusControlSection(scheme: scheme);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _CampusOverviewSection extends StatelessWidget {
  final ColorScheme scheme;
  const _CampusOverviewSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Supreme Admin Welcome with Bounce Animation
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1200),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0), // Clamp opacity to valid range
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.primaryContainer.withOpacity(0.9),
                        scheme.primaryContainer.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.primary.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade400,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.star, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Welcome, System Administrator! ⚙️',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'GECI ENERGIA Control Center',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onPrimaryContainer.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amber.shade400, Colors.orange.shade400],
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                '🏆 Master of Campus Energy • 247.8 kW',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        
        // Campus-wide Stats
        Text(
          'Campus Energy Overview',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: const [
            _CampusStatCard(label: 'Total Usage', value: '247.8 kW', icon: Icons.electric_bolt_outlined, color: Colors.green),
            _CampusStatCard(label: 'Active Users', value: '1,247', icon: Icons.people_outlined, color: Colors.blue),
            _CampusStatCard(label: 'Buildings', value: '12 Online', icon: Icons.business_outlined, color: Colors.purple),
            _CampusStatCard(label: 'Efficiency', value: '94.2%', icon: Icons.eco_outlined, color: Colors.orange),
          ],
        ),
        const SizedBox(height: 32),
        
        // Campus Energy Distribution
        Text(
          'Energy Distribution by Department',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: _CampusEnergyPieChart()),
        
        const SizedBox(height: 32),
        
        // Department Status
        Text(
          'Department Status',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildDepartmentStatus(context, 'Computer Science', '18.4 kW', '87%', Colors.green.shade600, 'Optimal'),
        _buildDepartmentStatus(context, 'Electronics & Comm.', '22.1 kW', '92%', Colors.blue.shade600, 'Excellent'),
        _buildDepartmentStatus(context, 'Mechanical', '31.5 kW', '78%', Colors.orange.shade600, 'Moderate'),
        _buildDepartmentStatus(context, 'Civil Engineering', '15.7 kW', '85%', Colors.purple.shade600, 'Good'),
        _buildDepartmentStatus(context, 'Administrative', '8.2 kW', '95%', Colors.cyan.shade600, 'Excellent'),
        
        const SizedBox(height: 32),
        
        // Real-time Campus Map
        Text(
          'Campus Energy Map',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBuildingIndicator(context, 'CS Block', '18.4kW', Colors.green.shade600, 0.7),
                  _buildBuildingIndicator(context, 'ECE Block', '22.1kW', Colors.blue.shade600, 0.8),
                  _buildBuildingIndicator(context, 'Mech Block', '31.5kW', Colors.orange.shade600, 0.9),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBuildingIndicator(context, 'Library', '12.3kW', Colors.purple.shade600, 0.6),
                  _buildBuildingIndicator(context, 'Admin', '8.2kW', Colors.cyan.shade600, 0.4),
                  _buildBuildingIndicator(context, 'Hostels', '45.7kW', Colors.red.shade600, 1.0),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Carbon Footprint
        Text(
          'Sustainability Metrics',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SustainabilityCard(
                title: 'CO₂ Saved Today',
                value: '2.3 tons',
                icon: Icons.eco,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SustainabilityCard(
                title: 'Trees Equivalent',
                value: '104 trees',
                icon: Icons.forest,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBuildingIndicator(BuildContext context, String name, String usage, Color color, double intensity) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(intensity * 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(Icons.business, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(usage, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  Widget _buildDepartmentStatus(BuildContext context, String dept, String usage, String efficiency, Color color, String status) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.business_rounded, color: color, size: 28),
        title: Text(dept, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text('Usage: $usage • Efficiency: $efficiency'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        onTap: () {},
      ),
    );
  }
}

class _UsersManagementSection extends StatelessWidget {
  final ColorScheme scheme;
  const _UsersManagementSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'User Management',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage all ENERGIA system users',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: _UserStatsCard(
                title: 'Total Users',
                value: '1,247',
                icon: Icons.people_outlined,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _UserStatsCard(
                title: 'Active Now',
                value: '342',
                icon: Icons.online_prediction_outlined,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        _buildUserTypeCard(context, 'Administrators', '8 Users', Icons.admin_panel_settings_outlined, Colors.red.shade600),
        _buildUserTypeCard(context, 'Coordinators', '24 Users', Icons.supervisor_account_outlined, Colors.orange.shade600),
        _buildUserTypeCard(context, 'Class Representatives', '156 Users', Icons.school_outlined, Colors.blue.shade600),
        _buildUserTypeCard(context, 'Students', '1,059 Users', Icons.person_outline, Colors.green.shade600),
        
        const SizedBox(height: 24),
        
        // Quick Actions
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        _buildActionCard(context, 'Add New User', 'Register a new system user', Icons.person_add_outlined),
        _buildActionCard(context, 'Bulk Import', 'Import users from CSV file', Icons.upload_file_outlined),
        _buildActionCard(context, 'User Permissions', 'Manage access controls', Icons.security_outlined),
        _buildActionCard(context, 'Activity Logs', 'View user activity history', Icons.history_outlined),
        
        const SizedBox(height: 24),
        
        // Real-time User Activity
        Text(
          'Live User Activity',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _buildUserActivity(context, 'Rahul Kumar (CS-404)', 'Submitted energy reading', Icons.assignment_turned_in, Colors.green.shade600, '2 min ago'),
              _buildUserActivity(context, 'Dr. Priya (CS Coord)', 'Generated weekly report', Icons.analytics, Colors.blue.shade600, '15 min ago'),
              _buildUserActivity(context, 'Arjun S (ECE-302)', 'Reported AC malfunction', Icons.report_problem, Colors.orange.shade600, '1 hour ago'),
              _buildUserActivity(context, 'System Auto', 'Scheduled maintenance alert', Icons.schedule, Colors.purple.shade600, '2 hours ago'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserActivity(BuildContext context, String user, String action, IconData icon, Color color, String time) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(action, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(time, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildUserTypeCard(BuildContext context, String type, String count, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(type, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(count),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {},
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String description, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {},
      ),
    );
  }
}

class _SystemHealthSection extends StatelessWidget {
  final ColorScheme scheme;
  const _SystemHealthSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'System Health Monitor',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time system performance and health metrics',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        // System Status Cards
        Row(
          children: [
            Expanded(
              child: _SystemHealthCard(
                title: 'Uptime',
                value: '99.8%',
                icon: Icons.timeline_outlined,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SystemHealthCard(
                title: 'Response',
                value: '24ms',
                icon: Icons.speed_outlined,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        _buildHealthMetric(context, 'Database Performance', 95, Colors.green.shade600, 'Excellent'),
        _buildHealthMetric(context, 'API Response Time', 88, Colors.blue.shade600, 'Good'),
        _buildHealthMetric(context, 'Sensor Network', 92, Colors.orange.shade600, 'Stable'),
        _buildHealthMetric(context, 'Data Processing', 97, Colors.purple.shade600, 'Optimal'),
        
        const SizedBox(height: 32),
        
        Text(
          'System Alerts',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        _buildSystemAlert(context, 'Info', 'Daily backup completed successfully', Icons.info_outline, Colors.blue.shade600, '2h ago'),
        _buildSystemAlert(context, 'Warning', 'High memory usage on Server-02', Icons.warning_outlined, Colors.orange.shade600, '4h ago'),
        _buildSystemAlert(context, 'Success', 'Security patch applied successfully', Icons.check_circle_outline, Colors.green.shade600, '1d ago'),
        
        const SizedBox(height: 32),
        
        // System Diagnostics
        Text(
          'System Diagnostics',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        _buildDiagnosticCard(context, 'Network Latency', '24ms', 'Excellent', Colors.green.shade600, Icons.network_check),
        _buildDiagnosticCard(context, 'Data Throughput', '2.4 GB/h', 'Normal', Colors.blue.shade600, Icons.data_usage),
        _buildDiagnosticCard(context, 'Error Rate', '0.02%', 'Minimal', Colors.green.shade600, Icons.error_outline),
        _buildDiagnosticCard(context, 'Active Sessions', '342 users', 'Stable', Colors.orange.shade600, Icons.people),
        
        const SizedBox(height: 24),
        
        // Quick Maintenance Actions
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Sync Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.backup, size: 20),
                label: const Text('Backup Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosticCard(BuildContext context, String metric, String value, String status, Color color, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 24),
        title: Text(metric, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(status),
        trailing: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildHealthMetric(BuildContext context, String metric, int percentage, Color color, String status) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(metric, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text('$percentage%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemAlert(BuildContext context, String type, String message, IconData icon, Color color, String time) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(type, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: color)),
        subtitle: Text(message),
        trailing: Text(time, style: theme.textTheme.bodySmall),
        onTap: () {},
      ),
    );
  }
}

class _CampusControlSection extends StatelessWidget {
  final ColorScheme scheme;
  const _CampusControlSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Campus Control Center',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Master controls for entire campus energy system',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        // Emergency Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emergency, color: Colors.red.shade600, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Emergency Controls',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildEmergencyButton(context, 'Emergency Shutdown', 'Cut power to all non-critical systems', Icons.power_off, Colors.red.shade600),
              _buildEmergencyButton(context, 'Fire Safety Mode', 'Activate emergency lighting only', Icons.local_fire_department, Colors.orange.shade600),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Building Controls
        Text(
          'Building Controls',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        _buildBuildingControl(context, 'Academic Block A', 'Main CS & ECE Building', Icons.school, true),
        _buildBuildingControl(context, 'Academic Block B', 'Mechanical & Civil Building', Icons.construction, true),
        _buildBuildingControl(context, 'Laboratory Complex', 'All Engineering Labs', Icons.science, false),
        _buildBuildingControl(context, 'Administrative Block', 'Offices & Meeting Rooms', Icons.business, true),
        _buildBuildingControl(context, 'Library & Auditorium', 'Central Facilities', Icons.library_books, true),
        
        const SizedBox(height: 24),
        
        // System Settings
        Text(
          'System Configuration',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        _buildConfigCard(context, 'Energy Thresholds', 'Set campus-wide energy limits', Icons.tune),
        _buildConfigCard(context, 'Alert Settings', 'Configure system notifications', Icons.notifications_active),
        _buildConfigCard(context, 'Backup Systems', 'Manage backup power systems', Icons.battery_charging_full),
        _buildConfigCard(context, 'Maintenance Mode', 'Schedule system maintenance', Icons.build_circle),
        
        const SizedBox(height: 24),
        
        // Automation Rules
        Text(
          'Smart Automation',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.smart_toy, color: Colors.green.shade600, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'AI-Powered Energy Optimization',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildAutomationRule(context, 'Auto AC Scheduling', 'Automatically adjust AC based on occupancy', true, Colors.blue.shade600),
              _buildAutomationRule(context, 'Smart Lighting', 'Motion-based lighting control', true, Colors.orange.shade600),
              _buildAutomationRule(context, 'Peak Hour Management', 'Reduce non-essential loads during peak hours', false, Colors.red.shade600),
              _buildAutomationRule(context, 'Weekend Power-down', 'Auto shutdown non-critical systems on weekends', true, Colors.purple.shade600),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // AI-Powered Predictive Analytics
        Text(
          '🤖 AI-Powered Insights',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade50, Colors.blue.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepPurple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome, color: Colors.deepPurple.shade600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Hour Prediction',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '⚡ Expected surge in CS Block at 2:30 PM',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text('94.2% Accurate'),
                    backgroundColor: Colors.green.shade100,
                    labelStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PredictionCard(
                      title: 'Tomorrow Peak',
                      prediction: '185.3 kW',
                      time: '2:15 PM',
                      confidence: '96%',
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PredictionCard(
                      title: 'Weekly Trend',
                      prediction: '↗️ +12%',
                      time: 'Next Week',
                      confidence: '89%',
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Real-time Carbon Footprint & Weather Correlation
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.teal.shade50],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco, color: Colors.green.shade600, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '🌍 Carbon Impact',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '2.3 tons CO₂',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text('Saved Today', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.73,
                      backgroundColor: Colors.green.shade100,
                      valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Equivalent to 104 trees planted 🌳',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.green.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade50, Colors.yellow.shade50],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wb_sunny, color: Colors.orange.shade600, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '🌤️ Weather Impact',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '28°C',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+15% AC Load',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text('Current Temp', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Peak hours: 1-4 PM (32°C expected)',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Smart Device Health Monitoring
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan.shade50, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyan.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.health_and_safety, color: Colors.cyan.shade600, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '⚕️ Device Health Monitor',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'All Systems Optimal',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DeviceHealthCard(
                      deviceName: 'AC Units',
                      health: 98,
                      status: 'Excellent',
                      color: Colors.green,
                      icon: Icons.ac_unit,
                      count: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DeviceHealthCard(
                      deviceName: 'Lighting',
                      health: 85,
                      status: 'Good',
                      color: Colors.orange,
                      icon: Icons.lightbulb,
                      count: 156,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DeviceHealthCard(
                      deviceName: 'Sensors',
                      health: 92,
                      status: 'Very Good',
                      color: Colors.blue,
                      icon: Icons.sensors,
                      count: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Advanced Analytics
        Text(
          'Advanced Analytics',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _AnalyticsCard(
                title: 'ML Predictions',
                value: '94.2%',
                subtitle: 'Accuracy',
                icon: Icons.psychology,
                color: Colors.purple.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnalyticsCard(
                title: 'Cost Savings',
                value: '₹1.2L',
                subtitle: 'This Month',
                icon: Icons.savings,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutomationRule(BuildContext context, String title, String description, bool isActive, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? color : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isActive ? color : Colors.grey.shade600)),
                Text(description, style: TextStyle(fontSize: 12, color: isActive ? color.withOpacity(0.8) : Colors.grey.shade500)),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (value) {},
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyButton(BuildContext context, String title, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: () {
          // Emergency action
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(description, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingControl(BuildContext context, String name, String description, IconData icon, bool isOnline) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: isOnline ? Colors.green.shade600 : Colors.grey.shade500, size: 32),
        title: Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: Switch(
          value: isOnline,
          onChanged: (value) {
            // Toggle building power
          },
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context, String title, String description, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {},
      ),
    );
  }
}

class _CampusStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _CampusStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: 160,
      height: 120,
      child: Card(
        elevation: 2,
        shadowColor: Colors.transparent,
        color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: color),
              const Spacer(),
              Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _UserStatsCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(title, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SystemHealthCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(title, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SustainabilityCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SustainabilityCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(title, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _AnalyticsCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CampusEnergyPieChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(value: 30, color: Colors.blue.shade600, title: 'CS\n30%', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: 25, color: Colors.green.shade600, title: 'ECE\n25%', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: 20, color: Colors.orange.shade600, title: 'Mech\n20%', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: 15, color: Colors.purple.shade600, title: 'Civil\n15%', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          PieChartSectionData(value: 10, color: Colors.cyan.shade600, title: 'Admin\n10%', radius: 50, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final String title;
  final String prediction;
  final String time;
  final String confidence;
  final Color color;

  const _PredictionCard({
    required this.title,
    required this.prediction,
    required this.time,
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prediction,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              confidence + ' confidence',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceHealthCard extends StatelessWidget {
  final String deviceName;
  final int health;
  final String status;
  final Color color;
  final IconData icon;
  final int count;

  const _DeviceHealthCard({
    required this.deviceName,
    required this.health,
    required this.status,
    required this.color,
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deviceName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$health%',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: health / 100,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          const SizedBox(height: 8),
          Text(
            '$count devices',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
