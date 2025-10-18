import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardScaffold(
      title: 'CR Dashboard',
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPage(_index, colorScheme),
      ),
      currentIndex: _index,
      onBottomNavTapped: (i) => setState(() => _index = i),
      bottomNavItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart_outlined),
          activeIcon: Icon(Icons.show_chart),
          label: 'Live',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Reports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
      ],
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.filter_list),
              label: const Text('Filter Rooms'),
            )
          : null,
    );
  }

  Widget _buildPage(int index, ColorScheme scheme) {
    switch (index) {
      case 0:
        return _OverviewSection(scheme: scheme);
      case 1:
        return _LiveUsageSection(scheme: scheme);
      case 2:
        return _ReportsSection(scheme: scheme);
      case 3:
        return _AlertsSection(scheme: scheme);
      default:
        return const SizedBox.shrink();
    }
  }
}

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
          'Notifications about unusual energy usage.',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildAlertCard(context, 'High Usage Alert', 'CS-404: AC running after 6 PM. Usage: 5.2 kW.', Icons.power_outlined, Colors.red.shade400, '2h ago'),
        _buildAlertCard(context, 'Anomaly Detected', 'Library: Projector left on overnight. Potential waste: 8 kWh.', Icons.lightbulb_outline, Colors.amber.shade600, '1d ago'),
        _buildAlertCard(context, 'Sensor Offline', 'E-Lab: Sensor E-301 is not responding.', Icons.sensors_off_outlined, Colors.grey.shade500, '3d ago'),
        _buildAlertCard(context, 'Low Usage Warning', 'Admin Block: Unusually low consumption. Possible power outage.', Icons.power_off_outlined, Colors.blue.shade400, '4d ago'),
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

class _ReportsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _ReportsSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Generate Reports',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Analyze historical data and trends.',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildReportOption(context, 'Daily Summary', 'View detailed hourly breakdown for any day.', Icons.today_outlined),
        _buildReportOption(context, 'Weekly Trends', 'Compare consumption across weeks.', Icons.calendar_view_week_outlined),
        _buildReportOption(context, 'Monthly Analysis', 'Get insights on monthly usage patterns.', Icons.calendar_month_outlined),
        _buildReportOption(context, 'Custom Range', 'Select a specific date range for analysis.', Icons.date_range_outlined),
        _buildReportOption(context, 'Anomaly Report', 'List all flagged unusual activities.', Icons.warning_amber_rounded),
        _buildReportOption(context, 'Export to PDF', 'Download a comprehensive report document.', Icons.picture_as_pdf_outlined),
      ],
    );
  }

  Widget _buildReportOption(BuildContext context, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          // Placeholder for report generation logic
        },
      ),
    );
  }
}

class _LiveUsageSection extends StatelessWidget {
  final ColorScheme scheme;
  const _LiveUsageSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Live Consumption',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Real-time power usage across campus facilities.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        // Device Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device Controls - CS-404', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDeviceControl(context, 'Lights', Icons.lightbulb_outline, true, Colors.amber.shade600),
                  _buildDeviceControl(context, 'AC', Icons.ac_unit, true, Colors.blue.shade600),
                  _buildDeviceControl(context, 'Projector', Icons.video_call, false, Colors.grey.shade500),
                  _buildDeviceControl(context, 'Fan', Icons.mode_fan_off, false, Colors.green.shade600),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildRoomCard(context, 'CS-404 (Your Class)', '2.7 kW', 0.8, Colors.green.shade700),
        _buildRoomCard(context, 'Library Reading Hall', '12.1 kW', 0.9, Colors.red.shade600),
        _buildRoomCard(context, 'Electronics Lab', '5.8 kW', 0.6, Colors.orange.shade700),
        _buildRoomCard(context, 'Seminar Hall', '0.2 kW', 0.1, Colors.grey.shade500),
        _buildRoomCard(context, 'Principal\'s Office', '1.5 kW', 0.4, Colors.blue.shade700),
        _buildRoomCard(context, 'Server Room', '25.3 kW', 1.0, Colors.purple.shade700),
      ],
    );
  }

  Widget _buildDeviceControl(BuildContext context, String device, IconData icon, bool isOn, Color color) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isOn ? color.withOpacity(0.2) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: isOn ? color : Colors.grey.shade300),
          ),
          child: IconButton(
            onPressed: () {},
            icon: Icon(icon, color: isOn ? color : Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 4),
        Text(device, style: TextStyle(fontSize: 12, color: isOn ? color : Colors.grey.shade500)),
        Text(isOn ? 'ON' : 'OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOn ? color : Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildRoomCard(BuildContext context, String title, String usage, double load, Color indicatorColor) {
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
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(usage, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: indicatorColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: load,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(load * 100).toInt()}% Load', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final ColorScheme scheme;
  const _OverviewSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Animated Welcome Card for CR
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer.withOpacity(0.8),
                        theme.colorScheme.primaryContainer.withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, Energy Guardian! 🛡️',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Managing CS-404 • JC Bose Block',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your classroom energy stewardship makes a difference!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
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
        Wrap(
          spacing: 18,
          runSpacing: 18,
          alignment: WrapAlignment.center,
          children: const [
            _StatCard(label: 'CS-404 Live', value: '4.2 kW', icon: Icons.flash_on, color: Colors.orange),
            _StatCard(label: 'Today\'s Peak', value: '6.8 kW', icon: Icons.trending_up_outlined, color: Colors.red),
            _StatCard(label: 'Efficiency', value: '87%', icon: Icons.eco, color: Colors.green),
            _StatCard(label: 'Daily Goal', value: '28.7/30 kWh', icon: Icons.track_changes, color: Colors.blue),
          ],
        ),
        const SizedBox(height: 32),
        
        // Building & Classroom Rankings
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.secondaryContainer.withOpacity(0.8),
                theme.colorScheme.secondaryContainer.withOpacity(0.4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.leaderboard,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Energy Efficiency Rankings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Building & Classroom Performance',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Building-wise Ranking
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.indigo.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'JC Bose Block Performance',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#1/4 Blocks',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Most efficient block campus-wide • 89.2% avg efficiency',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Classroom-wise Ranking within Building
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade100, Colors.orange.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.class_, color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'CS-404 Position in JC Bose Block',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade400,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '#2',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'out of 12 classrooms in block',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '87% efficiency • Only 0.8 kWh behind #1 (CS-401)',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.trending_up,
                          color: Colors.green,
                          size: 24,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Top Performers in Building
              Text(
                'Top 3 Classrooms in JC Bose Block',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              ..._buildBuildingRankingList(theme),
              
              const SizedBox(height: 16),
              
              // Building Goal & Achievements
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade50, Colors.indigo.shade50],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.purple.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Building Challenge 🎯',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Beat CS-401 to become #1!',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Save just 0.8 kWh more today to take the lead',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Recent Achievements �',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildAchievementBadge('🥈', 'Silver Medal', '#2 in JC Bose Block'),
                        _buildAchievementBadge('⚡', 'Peak Optimizer', 'Reduced peak by 12%'),
                        _buildAchievementBadge('📈', 'Trending Up', '3-day efficiency streak'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Recent Alerts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...List.generate(3, (i) => _activityTile(i)),
        const SizedBox(height: 32),
        Text('24-Hour Usage (kW)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SizedBox(height: 200, child: _EnergyUsageChart(isDark: isDark)),
        const SizedBox(height: 32),
        Text('Energy Saving Tips', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const _TipCard(
          tip: 'Turn off lights and projectors in empty classrooms to save up to 20% on lighting energy.',
          icon: Icons.lightbulb_outline,
        ),
        const _TipCard(
          tip: 'Set ACs to an optimal temperature (24-26°C). Every degree lower can increase costs by 6-8%.',
          icon: Icons.ac_unit_outlined,
        ),
        const SizedBox(height: 32),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildQuickAction(context, 'Report Issue', Icons.report_problem_outlined, Colors.red.shade600),
            _buildQuickAction(context, 'Submit Reading', Icons.assessment_outlined, Colors.blue.shade600),
            _buildQuickAction(context, 'Request Maintenance', Icons.build_outlined, Colors.orange.shade600),
            _buildQuickAction(context, 'Energy Goal', Icons.track_changes_outlined, Colors.green.shade600),
          ],
        ),
      ],
    );
  }

  static Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  static Widget _activityTile(int i) {
    final titles = [
      'High Usage Detected: AC running after 6 PM',
      'Anomaly: Projector left on overnight',
      'Sensor Offline: Room 302, West Wing',
    ];
    final icons = [
      Icons.power_outlined,
      Icons.lightbulb_outline,
      Icons.sensors_off_outlined,
    ];
    final colors = [
      Colors.red.shade400,
      Colors.amber.shade600,
      Colors.grey.shade500,
    ];
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      child: ListTile(
        leading: Icon(icons[i], color: colors[i]),
        title: Text(titles[i]),
        subtitle: const Text('About 2 hours ago'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }

  static List<Widget> _buildBuildingRankingList(ThemeData theme) {
    final rankings = [
      {'room': 'CS-401', 'efficiency': '87.8%', 'usage': '29.2 kWh', 'rank': '#1', 'color': Colors.amber, 'trend': '↗️'},
      {'room': 'CS-404', 'efficiency': '87.0%', 'usage': '28.7 kWh', 'rank': '#2', 'color': Colors.orange, 'trend': '↗️'},
      {'room': 'CS-403', 'efficiency': '85.4%', 'usage': '31.5 kWh', 'rank': '#3', 'color': Colors.brown, 'trend': '↘️'},
    ];

    return rankings.map((data) {
      final isCurrentRoom = data['room'] == 'CS-404';
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentRoom 
              ? Colors.amber.withOpacity(0.15) 
              : theme.colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentRoom 
                ? Colors.amber.withOpacity(0.4) 
                : theme.colorScheme.outline.withOpacity(0.2),
            width: isCurrentRoom ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: data['color'] as Color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                data['rank'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        data['room'] as String,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isCurrentRoom ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      if (isCurrentRoom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${data['efficiency']} • ${data['usage']}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              data['trend'] as String,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }).toList();
  }

  static Widget _buildAchievementBadge(String emoji, String title, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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


