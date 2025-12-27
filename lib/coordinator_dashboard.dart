import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';

// Assuming Analysis is in graph_adm.dart and Anomaly is in anomaly_adm.dart
import 'graph_adm.dart'; 
import 'anomaly_adm.dart'; 
import 'services/notifier.dart'; // Added import for notifier
// --- MODIFIED: ADDED IMPORT FOR ROLE SELECTION PAGE ---
import 'role_selection_page.dart';
// --- END MODIFIED ---


class CoordinatorDashboardPage extends StatefulWidget {
  const CoordinatorDashboardPage({super.key});

  @override
  State<CoordinatorDashboardPage> createState() => _CoordinatorDashboardPageState();
}

class _CoordinatorDashboardPageState extends State<CoordinatorDashboardPage> {
  int _currentIndex = 0;

  // Placeholder navigation targets (assuming imports would be here)
  void _performLogout() {
    // Navigate to RoleSelectionPage and clear stack.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardScaffold(
      title: '🏢 CS Department ENERGIA',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: _performLogout,
        ),
      ],
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPage(_currentIndex, colorScheme),
      ),
      currentIndex: _currentIndex,
      onBottomNavTapped: (index) {
        if (index == 4) { // Assuming a 5th item (Logout) might be added
           _performLogout();
        } else {
           setState(() {
             _currentIndex = index;
           });
        }
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
                                'Welcome, Department Leader! 👋',
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
        
        // Real-time Chart
        Text(
          'Department Energy Flow (Last 24 Hours)',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: _DepartmentUsageChart()),
        
        const SizedBox(height: 32),
        
        // Optimization Suggestions
        
        const SizedBox(height: 12),
        //_buildOptimizationCard(context, 'Adjust AC Schedules', 'CS-Lab 1 has 20% avoidable peak usage after 5 PM.', Icons.ac_unit, Colors.red.shade600),
        //_buildOptimizationCard(context, 'Motion Sensor Audit', 'CS-Seminar Hall motion sensor reporting low usage despite being marked active.', Icons.sensors, Colors.orange.shade600),
        
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
  
  // MODIFIED: Sample data adjusted for requested percentages (15, 25, 10, 13, 15, 22)
  // Total Usage maintained around 34.5 kW
  final List<Map<String, dynamic>> _roomData = const [
    {'room': 'CS-404', 'usage_kw': 5.2, 'load': 0.6, 'status': 'Normal', 'color': Colors.green}, // ~15.1%
    {'room': 'CS-Lab 1', 'usage_kw': 8.6, 'load': 0.9, 'status': 'High Usage', 'color': Colors.red}, // ~24.9%
    {'room': 'CS-Lab 2', 'usage_kw': 3.4, 'load': 0.7, 'status': 'Moderate', 'color': Colors.orange}, // ~9.9%
    {'room': 'Server Room', 'usage_kw': 4.5, 'load': 0.8, 'status': 'Critical System', 'color': Colors.purple}, // ~13.0%
    {'room': 'CS-Faculty Room', 'usage_kw': 5.2, 'load': 0.3, 'status': 'Low Usage', 'color': Colors.blue}, // ~15.1%
    {'room': 'CS-Seminar Hall', 'usage_kw': 7.6, 'load': 0.5, 'status': 'Offline', 'color': Colors.grey}, // ~22.0%
  ];

  // Refactored helper function for a more compact, ListTile-like appearance
  Widget _buildRoomMonitorCard(BuildContext context, String room, String usage, double load, Color statusColor, String status) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 8), // Reduced margin for compactness
      child: InkWell(
        onTap: () {
          // Placeholder: Navigate to detailed room control/analytics page
          // Provide consistent in-app feedback
          // ignore: use_build_context_synchronously
          AppNotifier.showInfo(context, 'Opening Control Panel for $room');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Tighter vertical padding (8.0 instead of 12.0)
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Icon
              Icon(Icons.room_outlined, color: statusColor, size: 24), // Smaller icon
              const SizedBox(width: 16),
              
              // 2. Name and Usage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room, 
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16) // Slightly smaller font
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 4, // Thinner progress bar
                      child: LinearProgressIndicator( 
                        value: load,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 3. Status/Load Value
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    usage, 
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  Text(
                    status, 
                    style: theme.textTheme.bodySmall?.copyWith(color: statusColor, fontSize: 10) // Smaller status text
                  ),
                ],
              ),
              // Arrow Icon REMOVED here
            ],
          ),
        ),
      ),
    );
  }
  

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
        
        // Rooms List using the new compact card layout
        ..._roomData.map((data) {
          return _buildRoomMonitorCard(
            context, 
            data['room'] as String, 
            '${(data['usage_kw'] as double).toStringAsFixed(1)} kW', 
            data['load'] as double, 
            data['color'] as Color, 
            data['status'] as String
          );
        }).toList(),

        const SizedBox(height: 32),
        
        // NEW: Aggregate Rooms Usage Pie Chart
        Text(
          'Energy Distribution Among Rooms',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: _DepartmentRoomsDistributionChart(roomData: _roomData),
        ),
        
      ],
    );
  }

}

class _DepartmentRoomsDistributionChart extends StatelessWidget {
  final List<Map<String, dynamic>> roomData;

  const _DepartmentRoomsDistributionChart({required this.roomData});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate total usage
    final totalUsage = roomData.fold<double>(0, (sum, room) => sum + (room['usage_kw'] as double));

    // 2. Create PieChartSections
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];
    
    // MODIFIED RADIUS to make slices look larger and give labels more room
    const double sliceRadius = 100; 
    
    roomData.asMap().forEach((index, room) {
      final usage = room['usage_kw'] as double;
      final name = room['room'] as String;
      final color = room['color'] as Color;
      final percentage = totalUsage > 0 ? (usage / totalUsage) * 100 : 0.0;
      
      if (usage > 0) {
        sections.add(
          PieChartSectionData(
            value: usage,
            color: color,
            // Only show title if percentage is greater than or equal to 6%
            title: percentage >= 6.0 ? '${percentage.toStringAsFixed(0)}%' : '',
            showTitle: percentage >= 6.0,
            radius: sliceRadius,
            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      }
      
      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: color),
              const SizedBox(width: 8),
              Text(
                '$name (${usage.toStringAsFixed(1)} kW)',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    });

    if (totalUsage == 0) {
       sections.add(
          PieChartSectionData(
            value: 1.0,
            color: Colors.grey.shade300,
            title: '0%',
            radius: sliceRadius,
            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pie Chart
        SizedBox(
          width: 200, // Increased width to accommodate larger radius
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 3,
              centerSpaceRadius: 0,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Total Live Usage: ${totalUsage.toStringAsFixed(1)} kW',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Use Expanded/Wrap if the legend is too long, but simple column works for this data size
              ...legendItems,
            ],
          ),
        ),
      ],
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
        
        _buildAnalyticsCard(
          context, 
          'Daily Trends', 
          'Analyze hourly usage patterns and trends.', 
          Icons.timeline_outlined, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Analysis(title: 'Daily Consumption Trend', type: 'Daily', color: const Color(0xFF1B2A3B)))),
          showArrow: true,
        ),
        _buildAnalyticsCard(
          context, 
          'Monthly Trends', 
          'Analyze long-term monthly usage patterns.', 
          Icons.bar_chart_outlined, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Analysis(title: 'Monthly Consumption Trend', type: 'Monthly',color: const Color(0xFF1B2A3B)))),
          showArrow: true,
        ),
       _buildAnalyticsCard(
          context, 
          'Peak Hours Analysis', 
          'Identify and optimize daily peak consumption periods.', 
          Icons.schedule_outlined,
          // MODIFIED: Links to the new Ranked Metrics Table
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PeakHoursMetricsTable())),
          showArrow: true,
        ),
        /*_buildAnalyticsCard(
          context, 
          'Anomaly Alerts', 
          'View all critical and high-priority system alerts.', 
          Icons.notifications_active_outlined, 
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Anomaly())),
          showArrow: true,
        ),*/
        _buildAnalyticsCard(
          context, 
          'Usage Report', 
          'Export comprehensive department data for auditing.', 
          Icons.download_for_offline_outlined, 
          () => AppNotifier.showInfo(context, 'Preparing detailed report for download...'),
          showArrow: false, // ARROW REMOVED
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  // Modified helper function to accept VoidCallback for navigation
  Widget _buildAnalyticsCard(BuildContext context, String title, String description, IconData icon, VoidCallback onTap, {bool showArrow = true}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        // Conditional trailing widget
        trailing: showArrow ? const Icon(Icons.arrow_forward_ios_rounded, size: 16) : null,
        onTap: onTap, // Uses the navigation callback
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

// --- NEW WIDGET: Ranked Metrics Table ---

class PeakHoursMetricsTable extends StatelessWidget {
  const PeakHoursMetricsTable({super.key});

  final List<Map<String, String>> peakData = const [
    {'rank': '1st', 'time': '1:00 PM - 2:00 PM', 'usage': '22.8 kW', 'load': 'High'},
    {'rank': '2nd', 'time': '10:00 AM - 11:00 AM', 'usage': '18.5 kW', 'load': 'High'},
    {'rank': '3rd', 'time': '6:00 PM - 7:00 PM', 'usage': '14.1 kW', 'load': 'Moderate'},
    {'rank': '4th', 'time': '12:00 PM - 1:00 PM', 'usage': '12.5 kW', 'load': 'Moderate'},
  ];

  Color _getRankColor(int index) {
    if (index == 0) return Colors.red.shade600;
    if (index == 1) return Colors.orange.shade600;
    if (index == 2) return Colors.yellow.shade600;
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peak Hours Analysis'),
        backgroundColor: const Color(0xFF1B2A3B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Top Daily Energy Usage Periods',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'These time slots represent the highest average power demand in the department. Optimization focus areas are highlighted.',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Ranked List Cards
          ...peakData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final color = _getRankColor(index);
            
            return Card(
              elevation: 4,
              shadowColor: color.withOpacity(0.1),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  child: Text(data['rank']!, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
                ),
                title: Text(
                  data['time']!, 
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                ),
                subtitle: Text(
                  'Average Usage: ${data['usage']!}',
                  style: theme.textTheme.bodyLarge,
                ),
                trailing: Chip(
                  label: Text(data['load']!),
                  backgroundColor: color.withOpacity(0.2),
                  labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  AppNotifier.showInfo(context, 'Focusing optimization for ${data['time']}');
                },
              ),
            );
          }).toList(),
          
          const SizedBox(height: 40),
          
          Text(
            'Recommendation',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'The primary peak between 1:00 PM and 2:00 PM suggests a need to verify AC scheduling and lighting control during the lunch period.',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

// --- Helper Classes (Replaced/Kept for integrity) ---

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