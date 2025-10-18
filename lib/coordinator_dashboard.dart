import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';

class CoordinatorDashboardPage extends StatefulWidget {
  const CoordinatorDashboardPage({super.key});

  @override
  State<CoordinatorDashboardPage> createState() => _CoordinatorDashboardPageState();
}

class _CoordinatorDashboardPageState extends State<CoordinatorDashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardScaffold(
      title: '🏢 CS Department ENERGIA',
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
          label: 'Overview',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.room_outlined),
          activeIcon: Icon(Icons.room),
          label: 'Rooms',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
      ],
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.control_point),
              label: const Text('Control Room'),
            )
          : null,
    );
  }

  Widget _buildPage(int index, ColorScheme scheme) {
    switch (index) {
      case 0:
        return _DepartmentOverviewSection(scheme: scheme);
      case 1:
        return _DepartmentRoomsSection(scheme: scheme);
      case 2:
        return _DepartmentAnalyticsSection(scheme: scheme);
      case 3:
        return _DepartmentAlertsSection(scheme: scheme);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DepartmentOverviewSection extends StatelessWidget {
  final ColorScheme scheme;
  const _DepartmentOverviewSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Animated Welcome Message for Coordinator
        TweenAnimationBuilder<Offset>(
          duration: const Duration(milliseconds: 1000),
          tween: Tween(begin: const Offset(-1.0, 0.0), end: const Offset(0.0, 0.0)),
          builder: (context, offset, child) {
            return SlideTransition(
              position: AlwaysStoppedAnimation(offset),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer.withOpacity(0.9),
                      scheme.secondaryContainer.withOpacity(0.7),
                      scheme.primaryContainer.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.primary.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.business_center,
                            size: 40,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, Department Leader! �',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'CS Department Energy Coordinator',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: scheme.onPrimaryContainer.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Orchestrating efficiency across 12 rooms • Leading sustainability',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onPrimaryContainer.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '✨ Your leadership drives campus-wide energy transformation',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        
        // Department Stats
        Text(
          'Department Overview',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: const [
            _DepartmentStatCard(label: 'Total Usage', value: '18.4 kW', icon: Icons.electric_bolt_outlined, color: Colors.green),
            _DepartmentStatCard(label: 'Active Rooms', value: '8 of 12', icon: Icons.room_outlined, color: Colors.blue),
            _DepartmentStatCard(label: 'Alerts', value: '3 Active', icon: Icons.warning_outlined, color: Colors.orange),
            _DepartmentStatCard(label: 'Efficiency', value: '87%', icon: Icons.trending_up_outlined, color: Colors.purple),
          ],
        ),
        const SizedBox(height: 32),
        
        // Energy Budget Tracking
        Text(
          'Energy Budget Tracking',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Monthly Budget: ₹45,000', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text('Used: ₹28,500', style: theme.textTheme.titleMedium?.copyWith(color: Colors.orange.shade600, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.63,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
              ),
              const SizedBox(height: 8),
              Text('63% of budget used • 12 days remaining', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Real-time Chart
        Text(
          'Department Energy Flow (Last 24 Hours)',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: _DepartmentUsageChart()),
        
        const SizedBox(height: 32),
        
        // Optimization Suggestions
        Text(
          'Smart Optimization',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildOptimizationCard(context, 'Schedule AC Auto-off', 'Save 15% by scheduling AC shutdown at 6 PM', Icons.schedule, Colors.green.shade600),
        _buildOptimizationCard(context, 'Lighting Automation', 'Install motion sensors in low-traffic areas', Icons.sensors, Colors.blue.shade600),
      ],
    );
  }

  Widget _buildOptimizationCard(BuildContext context, String title, String description, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text('Apply'),
        ),
      ),
    );
  }
}

class _DepartmentRoomsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _DepartmentRoomsSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Department Rooms Monitor',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time monitoring of all rooms in CS Department',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        // Scheduling Panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.blue.shade600, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Energy Scheduling',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildScheduleButton(context, 'Auto AC Off', '6:00 PM', Icons.ac_unit, Colors.blue.shade600, true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildScheduleButton(context, 'Lights Off', '7:00 PM', Icons.lightbulb_outline, Colors.orange.shade600, false),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildRoomMonitorCard(context, 'CS-404', '2.7 kW', 0.6, Colors.green.shade700, 'Normal'),
        _buildRoomMonitorCard(context, 'CS-Lab 1', '8.2 kW', 0.9, Colors.red.shade600, 'High Usage'),
        _buildRoomMonitorCard(context, 'CS-Lab 2', '6.5 kW', 0.7, Colors.orange.shade600, 'Moderate'),
        _buildRoomMonitorCard(context, 'Server Room', '15.3 kW', 0.8, Colors.purple.shade700, 'Critical System'),
        _buildRoomMonitorCard(context, 'CS-Faculty Room', '1.2 kW', 0.3, Colors.blue.shade700, 'Low Usage'),
        _buildRoomMonitorCard(context, 'CS-Seminar Hall', '0.5 kW', 0.1, Colors.grey.shade500, 'Offline'),
      ],
    );
  }

  Widget _buildScheduleButton(BuildContext context, String action, String time, IconData icon, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? color : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, color: isActive ? color : Colors.grey.shade500, size: 20),
          const SizedBox(height: 4),
          Text(action, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? color : Colors.grey.shade600)),
          Text(time, style: TextStyle(fontSize: 10, color: isActive ? color : Colors.grey.shade500)),
          const SizedBox(height: 4),
          Switch(
            value: isActive,
            onChanged: (value) {},
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomMonitorCard(BuildContext context, String room, String usage, double load, Color statusColor, String status) {
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
                Text(room, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Power: $usage', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text('${(load * 100).toInt()}% Load', style: theme.textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: load,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentAnalyticsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _DepartmentAnalyticsSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Department Analytics',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Comprehensive energy analytics for CS Department',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        _buildAnalyticsCard(context, 'Weekly Report', 'Generate detailed weekly consumption report', Icons.calendar_view_week_outlined),
        _buildAnalyticsCard(context, 'Monthly Trends', 'Analyze monthly usage patterns and trends', Icons.trending_up_outlined),
        _buildAnalyticsCard(context, 'Room Comparison', 'Compare energy usage across all rooms', Icons.compare_arrows_outlined),
        _buildAnalyticsCard(context, 'Peak Hours Analysis', 'Identify peak consumption periods', Icons.schedule_outlined),
        _buildAnalyticsCard(context, 'Cost Analysis', 'Calculate energy costs and savings', Icons.attach_money_outlined),
        _buildAnalyticsCard(context, 'Export Data', 'Export comprehensive department data', Icons.download_outlined),
        
        const SizedBox(height: 24),
        
        // Comparative Analytics
        Text(
          'Department Comparison',
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
              _buildComparisonRow(context, 'CS Department', '18.4 kW', '87%', Colors.blue.shade600, true),
              _buildComparisonRow(context, 'ECE Department', '22.1 kW', '92%', Colors.green.shade600, false),
              _buildComparisonRow(context, 'Mechanical', '31.5 kW', '78%', Colors.red.shade600, false),
              _buildComparisonRow(context, 'Civil Engineering', '15.7 kW', '85%', Colors.orange.shade600, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(BuildContext context, String title, String description, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {},
      ),
    );
  }

  Widget _buildComparisonRow(BuildContext context, String dept, String usage, String efficiency, Color color, bool isCurrent) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isCurrent ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          if (isCurrent) Icon(Icons.star, color: color, size: 20),
          if (isCurrent) const SizedBox(width: 8),
          Expanded(
            child: Text(dept, style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? color : null,
            )),
          ),
          Text(usage, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(efficiency, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DepartmentAlertsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _DepartmentAlertsSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Department Alerts',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'All alerts from CS Department rooms',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        
        _buildAlertCard(context, 'Critical', 'CS-Lab 2: Power surge detected - 12.5 kW', Icons.error_outline, Colors.red.shade600, '15 min ago'),
        _buildAlertCard(context, 'High Usage', 'CS-404: AC running after 6 PM - 5.2 kW', Icons.power_outlined, Colors.orange.shade600, '1 hour ago'),
        _buildAlertCard(context, 'Temperature', 'Server Room: High temperature alert - 28°C', Icons.thermostat_outlined, Colors.blue.shade600, '2 hours ago'),
        _buildAlertCard(context, 'Sensor Issue', 'CS-Seminar: Motion sensor offline', Icons.sensors_off_outlined, Colors.grey.shade500, '4 hours ago'),
        _buildAlertCard(context, 'Maintenance', 'CS-Lab 1: Scheduled maintenance reminder', Icons.build_outlined, Colors.purple.shade600, '1 day ago'),
      ],
    );
  }

  Widget _buildAlertCard(BuildContext context, String type, String message, IconData icon, Color color, String time) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(type, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: color)),
        subtitle: Text(message),
        trailing: Text(time, style: theme.textTheme.bodySmall),
        onTap: () {},
      ),
    );
  }
}

class _DepartmentStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _DepartmentStatCard({required this.label, required this.value, required this.icon, required this.color});

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

class _DepartmentUsageChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 6,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('${value.toInt()}h', style: theme.textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 8.5), FlSpot(2, 6.8), FlSpot(4, 5.4), FlSpot(6, 12.5),
              FlSpot(8, 15.2), FlSpot(10, 18.5), FlSpot(12, 22.8), FlSpot(14, 19.0),
              FlSpot(16, 16.5), FlSpot(18, 14.1), FlSpot(20, 11.2), FlSpot(22, 9.8),
              FlSpot(23.9, 8.7),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.4),
                  theme.colorScheme.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minX: 0,
        maxX: 24,
        minY: 0,
        maxY: 25,
      ),
    );
  }
}
