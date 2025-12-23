import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
// NOTE: Assume these files are created in your project root
import 'role_selection_page.dart';
import 'graph_adm.dart';
import 'anomaly_adm.dart';
class Dash extends StatefulWidget {
  const Dash({super.key});

  @override
  State<Dash> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<Dash> {
  int _index = 0;

  void _handleTabSelection(int newIndex) {
    if (newIndex == 2) { // Index 2 is now reserved for Logout
      _performLogout();
    } else {
      setState(() {
        _index = newIndex;
      });
    }
  }

  /*void _performLogout() {
    // Navigate specifically to the student login page and clear the navigation stack.
    // Assuming the route name for student_login.dart is '/student_login'.
    Navigator.of(context).pushNamedAndRemoveUntil('/student_login', (Route<dynamic> route) => false);
  }*/
void _performLogout() {
    // CORRECTED NAVIGATION: Navigate to RoleSelectionPage and clear stack.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
      (Route<dynamic> route) => false,
    );
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPage(_index, colorScheme),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _handleTabSelection, // Use the new handler
        items: const [
          // Index 0: Analysis (Was Index 1)
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          // Index 1: Alerts (Was Index 2)
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          // Index 2: Logout (Was Index 3)
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            activeIcon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, ColorScheme scheme) {
    switch (index) {
      case 0:
        return _ReportsSection(scheme: scheme); // Now Analysis
      case 1:
        return _AlertsSection(scheme: scheme); // Now Alerts
      case 2:
        // Logout case (unreachable page view)
        return const Center(child: Text("Logging out..."));
      default:
        return const SizedBox.shrink();
    }
  }
}

// --- Alerts Section ---

class _AlertsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _AlertsSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Recent Alerts',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Notifications about unusual energy usage in your assigned classroom.',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        // Scoped alerts to CR's location (CS-201)
        _buildAlertCard(context, 'High Usage Alert', ' AC running after 6 PM. Usage: 5.2 kW.', Icons.power_outlined, Colors.red.shade400, '2h ago'),
        _buildAlertCard(context, 'Anomaly Detected', ' Projector left on overnight (Occupancy Mismatch).', Icons.lightbulb_outline, Colors.amber.shade600, '1d ago'),
        _buildAlertCard(context, 'Sensor Offline', ' PIR Sensor is not responding.', Icons.sensors_off_outlined, Colors.grey.shade500, '3d ago'),
      ],
    );
  }

  Widget _buildAlertCard(BuildContext context, String title, String subtitle, IconData icon, Color color, String time) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: color)),
        subtitle: Text(subtitle),
        trailing: Text(time, style: theme.textTheme.bodySmall),
        onTap: () {
          // Placeholder for alert details
        },
      ),
    );
  }
}

// --- Reports Section (Analysis/Graphs) ---

class _ReportsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _ReportsSection({required this.scheme});

  // Define the target dark color for the header
  static const _headerColor = Color(0xFF1B2A3B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Consumption Analysis',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'View detailed consumption graphs and anomaly reports.',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        // Monthly Consumption Graph (Interactive View)
        _buildGraphTile(
          context,
          'Monthly Consumption Trend',
          'View total energy usage over the last 30 days.',
          Icons.calendar_month_outlined,
          // --- MODIFIED: Reverted to original color for tile styling ---
          Colors.blue.shade600, 
          // --- END MODIFIED ---
          'Monthly',
        ),
        // Daily Consumption Graph (Interactive View)
        _buildGraphTile(
          context,
          'Daily Usage Profile',
          'View hourly consumption breakdown for today.',
          Icons.today_outlined,
          // --- MODIFIED: Reverted to original color for tile styling ---
          Colors.green.shade600,
          // --- END MODIFIED ---
          'Daily',
        ),
        // Anomaly Report Viewer (Navigates to Anomaly Page)
        _buildAnomalyReportTile(
          context,
          'Detailed Anomaly Report',
          'List of all triggered alerts and exceptions.',
          Icons.warning_amber_rounded,
          Colors.amber.shade700,
        ),
      ],
    );
  }

  Widget _buildGraphTile(BuildContext context, String title, String subtitle, IconData icon, Color color, String type) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      // Uses the passed color for shadow
      shadowColor: color.withOpacity(0.1), 
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to new page for graph visualization
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Analysis(
                title: '$type Consumption Graph',
                type: type,
                // Pass the fixed dark color for the AppBar header (0xFF1B2A3B)
                color: _headerColor, 
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Uses the passed color for the icon background
                  color: color.withOpacity(0.15), 
                  borderRadius: BorderRadius.circular(10),
                ),
                // Uses the passed color for the icon itself
                child: Icon(icon, color: color, size: 30), 
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.show_chart_outlined, size: 24, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnomalyReportTile(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to new page for anomaly list visualization
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const Anomaly(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // CR cannot download, so we use a view icon
              const Icon(Icons.visibility_outlined, size: 24, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}


// --- Helper Classes ---

class _EnergyUsageChart extends StatelessWidget {
  final bool isDark;
  const _EnergyUsageChart({required this.isDark});

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
              FlSpot(0, 1.5), FlSpot(2, 1.8), FlSpot(4, 1.4), FlSpot(6, 2.5),
              FlSpot(8, 2.2), FlSpot(10, 3.5), FlSpot(12, 3.8), FlSpot(14, 3.0),
              FlSpot(16, 2.5), FlSpot(18, 4.1), FlSpot(20, 3.2), FlSpot(22, 2.8),
              FlSpot(23.9, 2.7),
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
        maxY: 5,
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String tip;
  final IconData icon;
  const _TipCard({required this.tip, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Text(tip)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: 160,
      height: 140, // Increased height to prevent overflow
      child: Card(
        elevation: 2,
        shadowColor: Colors.transparent,
        color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced padding slightly
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 24, color: color), // Reduced icon size slightly
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}