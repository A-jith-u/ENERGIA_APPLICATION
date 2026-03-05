import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';
import 'package:energia/widgets/energy_visualization_widgets.dart';
import 'services/notifier.dart';
import 'package:energia/services/pdf_export.dart';
import 'package:energia/services/csv_export.dart';
import 'role_selection_page.dart'; // For Logout navigation
// Departmental page imports
import 'computer_science_classrooms_page.dart';
import 'Electrical.dart';
import 'Electronics.dart';
import 'mechanical.dart';
import 'Itt.dart';
import 'adminblock.dart';
import 'dart:convert'; // Fixes 'jsonEncode' error
import 'dart:async'; // For Timer
import 'package:http/http.dart' as http; // Fixes 'http' error
import 'services/api.dart' as api; // Import API functions
import 'services/user_counts.dart';
import 'services/user_lists.dart';
import 'services/validators.dart'; // Import validation functions
import 'activity_logs_page.dart'; // Import activity logs page
import 'dart:ui'; // For ImageFilter (glassmorphism effect)
import 'package:energia/widgets/quick_message_sender.dart'; // Quick message sender widget

// --- HELPER WIDGETS ---

class _CampusStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _CampusStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

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
        color:
            isDark
                ? theme.colorScheme.surfaceContainerHighest
                : theme.cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: color),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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
  const _UserStatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

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
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(title, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CampusEnergyPieChart extends StatelessWidget {
  const _CampusEnergyPieChart({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    // Computer Science Department Classrooms/Labs Data
    final csRooms = [
      {
        'name': 'CS Lab 1',
        'usage': 4.2,
        'capacity': 5.0,
        'color': const Color(0xFF2196F3),
      },
      {
        'name': 'CS Lab 2',
        'usage': 3.8,
        'capacity': 5.0,
        'color': const Color(0xFF1976D2),
      },
      {
        'name': 'CS Lab 3',
        'usage': 4.5,
        'capacity': 5.0,
        'color': const Color(0xFF1565C0),
      },
      {
        'name': 'Classroom A',
        'usage': 2.1,
        'capacity': 3.0,
        'color': const Color(0xFF42A5F5),
      },
      {
        'name': 'Classroom B',
        'usage': 1.8,
        'capacity': 3.0,
        'color': const Color(0xFF64B5F6),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? [
                    Colors.grey.shade900.withOpacity(0.5),
                    Colors.grey.shade800.withOpacity(0.3),
                  ]
                  : [
                    Colors.white.withOpacity(0.7),
                    Colors.grey.shade100.withOpacity(0.5),
                  ],
        ),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors:
                    isDark
                        ? [
                          Colors.grey.shade900.withOpacity(0.3),
                          Colors.grey.shade800.withOpacity(0.2),
                        ]
                        : [
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.2),
                        ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.computer,
                        color: Color(0xFF2196F3),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Computer Science Department',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Real-time Energy Consumption',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bar Chart
                Expanded(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 5.5,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.black87,
                          tooltipPadding: const EdgeInsets.all(8),
                          tooltipMargin: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${csRooms[group.x.toInt()]['name']}\n${rod.toY.toStringAsFixed(1)} kW',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < csRooms.length) {
                                final room = csRooms[value.toInt()];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    room['name'] as String,
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 42,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()} kW',
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color:
                                isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(csRooms.length, (index) {
                        final room = csRooms[index];
                        final usage = room['usage'] as double;
                        final capacity = room['capacity'] as double;
                        final percentage = (usage / capacity * 100).round();

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: usage,
                              color: room['color'] as Color,
                              width: 32,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: capacity,
                                color:
                                    isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.05),
                              ),
                              rodStackItems: [],
                            ),
                          ],
                          showingTooltipIndicators: [],
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Current Usage', const Color(0xFF2196F3)),
                    const SizedBox(width: 24),
                    _buildLegendItem(
                      'Capacity',
                      isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// --- MAIN DASHBOARD AND SECTIONS ---

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  // FIX: Explicitly initialize _currentIndex to 0 (a valid index)
  int _currentIndex = 0;

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
      title: '⚡ GECI ENERGIA Control Center',
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
        // --- MODIFIED: Removed the index check, as logout is no longer in the bottom bar ---
        setState(() {
          _currentIndex = index;
        });
        // --- END MODIFIED ---
      },
      bottomNavItems: const [
        // Index 0: Campus Overview
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Campus',
        ),
        // Index 1: User Management
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Users',
        ),
        // --- MODIFIED: LOGOUT ITEM REMOVED ---
      ],
      floatingActionButton: null,
    );
  }

  Widget _buildPage(int index, ColorScheme scheme) {
    switch (index) {
      case 0:
        return _CampusOverviewSection(scheme: scheme);
      case 1:
        return _UsersManagementSection(scheme: scheme);

      default:
        return const SizedBox.shrink();
    }
  }
}

// --- 0. CAMPUS OVERVIEW SECTION ---
class _CampusOverviewSection extends StatefulWidget {
  final ColorScheme scheme;
  const _CampusOverviewSection({required this.scheme});

  @override
  State<_CampusOverviewSection> createState() => _CampusOverviewSectionState();
}

class _CampusOverviewSectionState extends State<_CampusOverviewSection> {
  Map<String, int>? _userCounts;
  bool _isLoading = false; // show immediately, refresh in background

  void _onCountsChanged() {
    setState(() {
      _userCounts = UserCountsStore.instance.counts.value;
    });
  }

  @override
  void initState() {
    super.initState();
    // Subscribe to shared user counts
    UserCountsStore.instance.counts.addListener(_onCountsChanged);
    // Initialize from current store
    _userCounts = UserCountsStore.instance.counts.value;
    // Refresh in background
    _loadUserCounts();
  }

  Future<void> _loadUserCounts() async {
    try {
      final counts = await api.getUserCounts();
      if (mounted) {
        setState(() {
          _userCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Use default values on error
          _userCounts ??= {
            'admins': 0,
            'coordinators': 0,
            'class_representatives': 0,
          };
        });
      }
    }
  }

  @override
  void dispose() {
    UserCountsStore.instance.counts.removeListener(_onCountsChanged);
    super.dispose();
  }

  void _refreshCounts() {
    _loadUserCounts();
  }

  // Helper to build the Department Status Tiles
  Widget _buildDepartmentStatusTile(
    BuildContext context,
    String dept,
    String usage,
    String efficiency,
    Color color,
    String status, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.business_rounded, color: color, size: 28),
        title: Text(
          dept,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text('Usage: $usage • Efficiency: $efficiency'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalUsers = _userCounts?['total_users'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Admin Welcome Card
        _AdminWelcomeCard(scheme: widget.scheme),
        const SizedBox(height: 24),

        // Campus-wide Key Stats
        Text(
          'Campus Energy Overview',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            const _CampusStatCard(
              label: 'Total Usage',
              value: '247.8 kW',
              icon: Icons.electric_bolt_outlined,
              color: Colors.red,
            ),
            _isLoading
                ? const SizedBox(
                  width: 160,
                  height: 120,
                  child: Card(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
                : _CampusStatCard(
                  label: 'Active Users',
                  value: '$totalUsers',
                  icon: Icons.people_outlined,
                  color: Colors.blue,
                ),
            const _CampusStatCard(
              label: 'Buildings',
              value: '12 Online',
              icon: Icons.business_outlined,
              color: Colors.purple,
            ),
            const _CampusStatCard(
              label: 'Efficiency',
              value: '94.2%',
              icon: Icons.eco_outlined,
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Campus Energy Distribution (Pie Chart is essential for high-level visualization)
        Text(
          'Energy Distribution by Department',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 300, child: _CampusEnergyPieChart()),

        const SizedBox(height: 32),

        // Department Status - Computer Science Only
        Text(
          'Department Status',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Computer Science Department (Primary Focus)
        _buildDepartmentStatusTile(
          context,
          'Computer Science',
          '18.4 kW',
          '87%',
          Colors.green.shade600,
          'Optimal',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ComputerScienceClassroomsPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        // Quick Message Sender Widget
        const QuickMessageSender(),

        const SizedBox(height: 32),

        // Quick Links (Admin specific actions)
        Text(
          'Admin Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          'Generate Monthly Report',
          'Create campus-wide consumption report.',
          Icons.picture_as_pdf,
        ), //
        _buildActionCard(
          context,
          'Manage Thresholds',
          'Adjust campus-level anomaly limits.',
          Icons.tune,
        ), //
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {},
      ),
    );
  }
}

class _AdminWelcomeCard extends StatelessWidget {
  final ColorScheme scheme;
  const _AdminWelcomeCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
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
                border: Border.all(
                  color: scheme.primary.withOpacity(0.3),
                  width: 1,
                ),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary,
                          scheme.primary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 32,
                      color: Colors.white,
                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.shade400,
                                Colors.orange.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            '🏆 Master of Campus Energy',
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
    );
  }
}

// --- 1. USERS MANAGEMENT SECTION ---
class _UsersManagementSection extends StatefulWidget {
  final ColorScheme scheme;
  const _UsersManagementSection({required this.scheme});

  @override
  State<_UsersManagementSection> createState() =>
      _UsersManagementSectionState();
}

class _UsersManagementSectionState extends State<_UsersManagementSection> {
  Map<String, int>? _userCounts;
  bool _isLoading = false;

  void _onCountsChanged() {
    setState(() {
      _userCounts = UserCountsStore.instance.counts.value;
    });
  }

  @override
  void initState() {
    super.initState();
    UserCountsStore.instance.counts.addListener(_onCountsChanged);
    _userCounts = UserCountsStore.instance.counts.value;
    _loadUserCounts();
  }

  Future<void> _loadUserCounts() async {
    try {
      final counts = await api.getUserCounts();
      if (mounted) {
        setState(() {
          _userCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    UserCountsStore.instance.counts.removeListener(_onCountsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalUsers = _userCounts?['total_users'] ?? 0;
    final coordinatorCount = _userCounts?['coordinators'] ?? 0;
    final classRepCount = _userCounts?['class_representatives'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'User Management',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage all ENERGIA system users',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child:
                  _isLoading
                      ? const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                      : _UserStatsCard(
                        title: 'Total Users',
                        value: '$totalUsers',
                        icon: Icons.people_outlined,
                        color: Colors.blue.shade600,
                      ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _UserStatsCard(
                title: 'Active Now',
                value: '$totalUsers',
                icon: Icons.online_prediction_outlined,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Tappable User Type Cards with navigation (hide Administrators & Students as requested)
        _buildUserTypeCard(
          context,
          'Coordinators',
          _isLoading ? 'Loading...' : '$coordinatorCount Users',
          Icons.supervisor_account_outlined,
          Colors.orange.shade600,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CoordinatorsPage()));
          },
        ),
        _buildUserTypeCard(
          context,
          'Class Representatives',
          _isLoading ? 'Loading...' : '$classRepCount Users',
          Icons.school_outlined,
          Colors.blue.shade600,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ClassRepresentativesPage(),
              ),
            );
          },
        ),

        // (Students card removed)
        const SizedBox(height: 24),

        // Quick Actions
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        _buildActionCard(
          context,
          'Add New User',
          'Register a new system user',
          Icons.person_add_outlined,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddUserPage()));
          },
        ),
        _buildActionCard(
          context,
          'Bulk Import',
          'Export all users to CSV file',
          Icons.download_outlined,
          onTap: () => _exportAllUsersCSV(context),
        ),
        _buildActionCard(
          context,
          'User Permissions',
          'Manage access controls',
          Icons.security_outlined,
        ),
        _buildActionCard(
          context,
          'Activity Logs',
          'View user activity history',
          Icons.history_outlined,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ActivityLogsPage()));
          },
        ),

        const SizedBox(height: 24),

        // Real-time User Activity
        Text(
          'Live User Activity',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        _ActivityLogWidget(),
      ],
    );
  }

  Widget _buildUserActivity(
    BuildContext context,
    String user,
    String action,
    IconData icon,
    Color color,
    String time,
  ) {
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
                Text(
                  user,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(action, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  void _exportAllUsersCSV(BuildContext context) async {
    try {
      // Get all coordinators and class representatives data from backend
      final coordinators = await api.getCoordinators();
      final classReps = await api.getClassRepresentatives();

      // Convert to the format expected by CSV export
      final coordsForCsv =
          coordinators
              .map(
                (c) => {
                  'name': c['name']?.toString() ?? '',
                  'ktuid': c['username']?.toString() ?? '',
                  'department': c['department']?.toString() ?? '',
                },
              )
              .toList();

      final repsForCsv =
          classReps
              .map(
                (r) => {
                  'name': r['name']?.toString() ?? '',
                  'ktuid': r['ktu_id']?.toString() ?? '',
                  'department': r['department']?.toString() ?? '',
                  'room':
                      r['email']?.toString() ??
                      '', // Using email instead of room
                  'year': r['year']?.toString() ?? '',
                  'gender': 'N/A', // Not available in backend
                },
              )
              .toList();

      // Export to CSV
      final filePath = await exportUsersCSV(
        coordinators: coordsForCsv,
        classReps: repsForCsv,
      );

      if (context.mounted) {
        final msg =
            filePath != null
                ? 'CSV exported to: $filePath'
                : 'CSV export initiated';
        AppNotifier.showInfo(context, msg);
      }
    } catch (e) {
      if (context.mounted) {
        AppNotifier.showError(context, 'Failed to export users: $e');
      }
    }
  }

  Widget _buildUserTypeCard(
    BuildContext context,
    String type,
    String count,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          type,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(count),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String description,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary, size: 32),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap ?? () {},
      ),
    );
  }
}

// --- USER MANAGEMENT DETAIL PAGES (Added from snippet) ---

class CoordinatorsPage extends StatefulWidget {
  const CoordinatorsPage({super.key});

  @override
  State<CoordinatorsPage> createState() => _CoordinatorsPageState();
}

class _CoordinatorsPageState extends State<CoordinatorsPage> {
  List<Map<String, dynamic>> _allCoordinators = [];
  bool _isLoading = false;
  String? _errorMessage;

  final _searchController = TextEditingController();
  String _selectedDepartment = 'All Departments';
  List<Map<String, dynamic>> _filteredCoordinators = [];

  @override
  void initState() {
    super.initState();
    // Subscribe to shared coordinators list
    UserListsStore.instance.coordinators.addListener(_onCoordinatorsChanged);
    // Initialize from cached store for instant display
    _allCoordinators = List<Map<String, dynamic>>.from(
      UserListsStore.instance.coordinators.value,
    );
    _filteredCoordinators = List.from(_allCoordinators);
    // Refresh in background
    _loadCoordinators();
  }

  void _onCoordinatorsChanged() {
    setState(() {
      _allCoordinators = List<Map<String, dynamic>>.from(
        UserListsStore.instance.coordinators.value,
      );
      _filteredCoordinators = List.from(_allCoordinators);
    });
  }

  Future<void> _loadCoordinators() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      await api.getCoordinators();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load coordinators: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    UserListsStore.instance.coordinators.removeListener(_onCoordinatorsChanged);
    super.dispose();
  }

  void _filterData() {
    setState(() {
      _filteredCoordinators =
          _allCoordinators.where((coord) {
            final name = coord['name']?.toString().toLowerCase() ?? '';
            final username = coord['username']?.toString().toLowerCase() ?? '';
            final searchLower = _searchController.text.toLowerCase();

            final matchesSearch =
                _searchController.text.isEmpty ||
                name.contains(searchLower) ||
                username.contains(searchLower);

            final matchesDepartment =
                _selectedDepartment == 'All Departments' ||
                coord['department'] == _selectedDepartment;

            return matchesSearch && matchesDepartment;
          }).toList();
    });
  }

  void _exportData() {
    final headers = ['Name', 'Username', 'Department'];
    final rows =
        _filteredCoordinators
            .map(
              (c) => [
                c['name']?.toString() ?? '',
                c['username']?.toString() ?? '',
                c['department']?.toString() ?? '',
              ],
            )
            .toList();

    exportTablePdfAutoSave(
      'Department Coordinators',
      headers,
      rows,
      subtitle:
          'Exported ${_filteredCoordinators.length} coordinators · ${DateTime.now()}',
    ).then((savedPath) {
      final msg =
          savedPath != null
              ? 'Saved PDF to: $savedPath'
              : 'PDF ready – choose location in Save/Share';
      AppNotifier.showInfo(context, msg);
    });
  }

  void _confirmDeleteUser(String username, String name) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User'),
            content: Text(
              'Are you sure you want to delete $name ($username)?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _deleteUser(username);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteUser(String username) async {
    try {
      // Optimistic update: remove from list immediately
      final indexToRemove = _allCoordinators.indexWhere(
        (c) => c['username'] == username,
      );
      if (indexToRemove != -1) {
        final removedUser = _allCoordinators[indexToRemove];
        setState(() {
          _allCoordinators.removeAt(indexToRemove);
          _filterData(); // Update filtered list
        });
        // Reflect change in global user counts immediately
        UserCountsStore.instance.decrement('coordinators');
        AppNotifier.showSuccess(context, 'User deleted successfully');

        // Call API in background
        try {
          await api.deleteUser(username);
        } catch (e) {
          // If delete fails, add user back
          if (mounted) {
            setState(() {
              _allCoordinators.insert(indexToRemove, removedUser);
              _filterData();
            });
            // Revert global counts
            UserCountsStore.instance.increment('coordinators');
            AppNotifier.showError(context, 'Failed to delete user: $e');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Failed to delete user: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinators'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCoordinators,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surfaceContainerLowest,
              scheme.surfaceContainerHigh,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadCoordinators,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Card(
                              elevation: 0,
                              color: scheme.primaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.supervisor_account,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Department Coordinators',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      scheme.onPrimaryContainer,
                                                ),
                                          ),
                                          Text(
                                            'Manage and review coordinator roster',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: scheme
                                                      .onPrimaryContainer
                                                      .withOpacity(0.85),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quick actions
                                    FilledButton.icon(
                                      onPressed: _exportData,
                                      icon: const Icon(Icons.file_download),
                                      label: const Text('Export'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: const Text(
                                                  'Filter Options',
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    DropdownButtonFormField<
                                                      String
                                                    >(
                                                      value:
                                                          _selectedDepartment,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Department',
                                                            border:
                                                                OutlineInputBorder(),
                                                          ),
                                                      items: const [
                                                        DropdownMenuItem(
                                                          value:
                                                              'All Departments',
                                                          child: Text(
                                                            'All Departments',
                                                          ),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'CSE',
                                                          child: Text('CSE'),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'ECE',
                                                          child: Text('ECE'),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'ME',
                                                          child: Text('ME'),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'CE',
                                                          child: Text('CE'),
                                                        ),
                                                        DropdownMenuItem(
                                                          value: 'AD',
                                                          child: Text('AD'),
                                                        ),
                                                      ],
                                                      onChanged: (value) {
                                                        if (value != null) {
                                                          setState(() {
                                                            _selectedDepartment =
                                                                value;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _selectedDepartment =
                                                            'All Departments';
                                                      });
                                                      _filterData();
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text('Clear'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () {
                                                      _filterData();
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text('Apply'),
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
                                      icon: const Icon(Icons.filter_alt),
                                      label: Text(
                                        _selectedDepartment == 'All Departments'
                                            ? 'Filter'
                                            : 'Filtered',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Content Card with centered table
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Search bar
                                    TextField(
                                      controller: _searchController,
                                      onChanged: (_) => _filterData(),
                                      decoration: const InputDecoration(
                                        hintText: 'Search by name or username',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Table
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: [
                                          DataColumn(
                                            label: Text(
                                              'Name',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Username',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Department',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Actions',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                        ],
                                        rows:
                                            _filteredCoordinators.map((c) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      c['name']?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      c['username']
                                                              ?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      c['department']
                                                              ?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                      ),
                                                      tooltip: 'Delete user',
                                                      onPressed:
                                                          () => _confirmDeleteUser(
                                                            c['username']
                                                                    ?.toString() ??
                                                                '',
                                                            c['name']
                                                                    ?.toString() ??
                                                                'User',
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            // Footer stats
                            Row(
                              children: [
                                Expanded(
                                  child: _UserStatsCard(
                                    title: 'Total Coordinators',
                                    value: '${_filteredCoordinators.length}',
                                    icon: Icons.people,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _UserStatsCard(
                                    title: 'Showing',
                                    value:
                                        '${_filteredCoordinators.length}/${_allCoordinators.length}',
                                    icon: Icons.filter_list,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClassRepresentativesPage extends StatefulWidget {
  const ClassRepresentativesPage({super.key});

  @override
  State<ClassRepresentativesPage> createState() =>
      _ClassRepresentativesPageState();
}

class _ClassRepresentativesPageState extends State<ClassRepresentativesPage> {
  List<Map<String, dynamic>> _allReps = [];
  bool _isLoading = false;
  String? _errorMessage;

  final _searchController = TextEditingController();
  String _selectedDepartment = 'All Departments';
  List<Map<String, dynamic>> _filteredReps = [];
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    // Subscribe to shared reps list
    UserListsStore.instance.classReps.addListener(_onRepsChanged);
    // Initialize from cached store for instant display
    _allReps = List<Map<String, dynamic>>.from(
      UserListsStore.instance.classReps.value,
    );
    _filteredReps = List.from(_allReps);
    // Refresh in background
    _loadClassRepresentatives();
  }

  void _onRepsChanged() {
    setState(() {
      _allReps = List<Map<String, dynamic>>.from(
        UserListsStore.instance.classReps.value,
      );
      _filteredReps = List.from(_allReps);
      _sortData();
    });
  }

  Future<void> _loadClassRepresentatives() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });

    try {
      await api.getClassRepresentatives();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load class representatives: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    UserListsStore.instance.classReps.removeListener(_onRepsChanged);
    super.dispose();
  }

  void _filterData() {
    setState(() {
      _filteredReps =
          _allReps.where((rep) {
            final name = rep['name']?.toString().toLowerCase() ?? '';
            final ktuId = rep['ktu_id']?.toString().toLowerCase() ?? '';
            final email = rep['email']?.toString().toLowerCase() ?? '';
            final searchLower = _searchController.text.toLowerCase();

            final matchesSearch =
                _searchController.text.isEmpty ||
                name.contains(searchLower) ||
                ktuId.contains(searchLower) ||
                email.contains(searchLower);

            final matchesDepartment =
                _selectedDepartment == 'All Departments' ||
                rep['department'] == _selectedDepartment;

            return matchesSearch && matchesDepartment;
          }).toList();
      _sortData();
    });
  }

  void _sortData() {
    _filteredReps.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = (a['name']?.toString() ?? '').compareTo(
            b['name']?.toString() ?? '',
          );
          break;
        case 'ktuid':
          comparison = (a['ktu_id']?.toString() ?? '').compareTo(
            b['ktu_id']?.toString() ?? '',
          );
          break;
        case 'department':
          comparison = (a['department']?.toString() ?? '').compareTo(
            b['department']?.toString() ?? '',
          );
          break;
        case 'year':
          final yearA = int.tryParse(a['year']?.toString() ?? '0') ?? 0;
          final yearB = int.tryParse(b['year']?.toString() ?? '0') ?? 0;
          comparison = yearA.compareTo(yearB);
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _exportData() {
    final headers = ['Name', 'KTU ID', 'Department', 'Email', 'Year'];
    final rows =
        _filteredReps
            .map(
              (r) => [
                r['name']?.toString() ?? '',
                r['ktu_id']?.toString() ?? '',
                r['department']?.toString() ?? '',
                r['email']?.toString() ?? '',
                r['year']?.toString() ?? '',
              ],
            )
            .toList();

    exportTablePdfAutoSave(
      'Class Representatives',
      headers,
      rows,
      subtitle: 'Exported ${_filteredReps.length} reps · ${DateTime.now()}',
    ).then((savedPath) {
      final msg =
          savedPath != null
              ? 'Saved PDF to: $savedPath'
              : 'PDF ready – choose location in Save/Share';
      AppNotifier.showInfo(context, msg);
    });
  }

  void _confirmDeleteUser(String username, String name) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User'),
            content: Text(
              'Are you sure you want to delete $name ($username)?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _deleteUser(username);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteUser(String username) async {
    try {
      // Optimistic update: remove from list immediately
      final indexToRemove = _allReps.indexWhere(
        (r) => r['username'] == username || r['ktu_id'] == username,
      );
      if (indexToRemove != -1) {
        final removedUser = _allReps[indexToRemove];
        setState(() {
          _allReps.removeAt(indexToRemove);
          _filterData(); // Update filtered list
        });
        // Reflect change in global user counts immediately
        UserCountsStore.instance.decrement('class_representatives');
        AppNotifier.showSuccess(context, 'User deleted successfully');

        // Call API in background
        try {
          await api.deleteUser(username);
        } catch (e) {
          // If delete fails, add user back
          if (mounted) {
            setState(() {
              _allReps.insert(indexToRemove, removedUser);
              _filterData();
            });
            // Revert global counts
            UserCountsStore.instance.increment('class_representatives');
            AppNotifier.showError(context, 'Failed to delete user: $e');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Failed to delete user: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Representatives'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClassRepresentatives,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surfaceContainerLowest,
              scheme.surfaceContainerHigh,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadClassRepresentatives,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                      : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Card(
                              elevation: 0,
                              color: scheme.secondaryContainer,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.school,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Class Representatives Directory',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      scheme
                                                          .onSecondaryContainer,
                                                ),
                                          ),
                                          Text(
                                            'Browse class reps by department and year',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: scheme
                                                      .onSecondaryContainer
                                                      .withOpacity(0.85),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FilledButton.icon(
                                      onPressed: _exportData,
                                      icon: const Icon(Icons.file_download),
                                      label: const Text('Export'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: const Text(
                                                  'Sort Options',
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    RadioListTile<String>(
                                                      title: const Text('Name'),
                                                      value: 'name',
                                                      groupValue: _sortBy,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _sortBy = value!;
                                                        });
                                                      },
                                                    ),
                                                    RadioListTile<String>(
                                                      title: const Text(
                                                        'KTU ID',
                                                      ),
                                                      value: 'ktuid',
                                                      groupValue: _sortBy,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _sortBy = value!;
                                                        });
                                                      },
                                                    ),
                                                    RadioListTile<String>(
                                                      title: const Text(
                                                        'Department',
                                                      ),
                                                      value: 'department',
                                                      groupValue: _sortBy,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _sortBy = value!;
                                                        });
                                                      },
                                                    ),
                                                    RadioListTile<String>(
                                                      title: const Text('Year'),
                                                      value: 'year',
                                                      groupValue: _sortBy,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _sortBy = value!;
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SwitchListTile(
                                                      title: const Text(
                                                        'Ascending',
                                                      ),
                                                      value: _sortAscending,
                                                      onChanged: (value) {
                                                        setState(() {
                                                          _sortAscending =
                                                              value;
                                                        });
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  FilledButton(
                                                    onPressed: () {
                                                      _filterData();
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text('Apply'),
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
                                      icon: const Icon(Icons.sort),
                                      label: const Text('Sort'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Content Card with centered table
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Toolbar
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: (_) => _filterData(),
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Search by name, KTU ID, or email',
                                              prefixIcon: Icon(Icons.search),
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        DropdownButton<String>(
                                          value: _selectedDepartment,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'All Departments',
                                              child: Text('All Departments'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'CSE',
                                              child: Text('CSE'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'ECE',
                                              child: Text('ECE'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'ME',
                                              child: Text('ME'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'CE',
                                              child: Text('CE'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'AD',
                                              child: Text('AD'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _selectedDepartment = value;
                                              });
                                              _filterData();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Table
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: [
                                          DataColumn(
                                            label: Text(
                                              'Name',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'KTU ID',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Department',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Email',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Year',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Actions',
                                              style:
                                                  theme.textTheme.titleMedium,
                                            ),
                                          ),
                                        ],
                                        rows:
                                            _filteredReps.map((r) {
                                              return DataRow(
                                                cells: [
                                                  DataCell(
                                                    Text(
                                                      r['name']?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      r['ktu_id']?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      r['department']
                                                              ?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      r['email']?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Text(
                                                      r['year']?.toString() ??
                                                          'N/A',
                                                    ),
                                                  ),
                                                  DataCell(
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                      ),
                                                      tooltip: 'Delete user',
                                                      onPressed:
                                                          () => _confirmDeleteUser(
                                                            r['username']
                                                                    ?.toString() ??
                                                                '',
                                                            r['name']
                                                                    ?.toString() ??
                                                                'User',
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            // Footer stats
                            Row(
                              children: [
                                Expanded(
                                  child: _UserStatsCard(
                                    title: 'Total Representatives',
                                    value: '${_filteredReps.length}',
                                    icon: Icons.groups,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _UserStatsCard(
                                    title: 'Showing',
                                    value:
                                        '${_filteredReps.length}/${_allReps.length}',
                                    icon: Icons.filter_list,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _admissionCtl = TextEditingController();

  String _role = 'Class Representative';
  String _department = 'CSE';
  String _year = '2';
  String _semester = 'S3';
  String _classGroup = 'CSE - A';

  static const roles = ['Class Representative', 'Coordinator'];
  static const departments = ['CSE', 'ECE', 'ME', 'CE', 'AD'];

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _admissionCtl.dispose();
    super.dispose();
  }

  /*void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final user = {
      'name': _nameCtl.text.trim(),
      'email': _emailCtl.text.trim(),
      'phone': _phoneCtl.text.trim(),
      'role': _role,
      if (_role == 'Class Representative') ...{
        'department': _department,
        'year': _year,
        'semester': _semester,
        'class': _classGroup,
        'admissionNo': _admissionCtl.text.trim(),
      },
    };

    // TODO: wire this to backend / persistence. For now show confirmation and return user data.
    AppNotifier.showSuccess(context, 'Created ${user['role']}: ${user['name']}');
    Navigator.of(context).pop(user);
  }*/
  // Inside _AddUserPageState in admin_dashboard.dart
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Show loading dialog
    showDialog(
      context: context,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Call your new invite API
      /*final response = await http.post(
  Uri.parse('http://localhost:8000/auth/admin/invite-user'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'username': _emailCtl.text.trim(), // Backend expects 'username'
    'role': _role.toLowerCase(),
    'department': _department,
    'ktu_id': _admissionCtl.text.trim(),
    'year': _year,
    // No password sent here; backend generates the OTP
  }),
);*/
      // Inside _submit() in admin_dashboard.dart
      final response = await http.post(
        Uri.parse('http://localhost:8000/auth/admin/invite-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _emailCtl.text.trim(),
          'name': _nameCtl.text.trim(), // Include the Name
          'role': _role.toLowerCase(),
          // Department required for both coordinator and class rep
          'department': _department,
          // Class rep–specific fields
          if (_role == 'Class Representative') ...{
            'ktu_id': _admissionCtl.text.trim(),
            'year': _year,
          },
        }),
      );

      Navigator.pop(context); // Close loading
      if (response.statusCode == 200) {
        AppNotifier.showSuccess(context, 'Invitation email sent!');
        Navigator.pop(context);
      }
    } catch (e) {
      Navigator.pop(context);
      // Handle error...
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New User'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Rahul Krishnan',
                    ),
                    validator: validateFullName,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'rahul.krishnan@geci.ac.in',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '9876543210',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: validatePhone,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items:
                        roles
                            .map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _role = v!),
                  ),

                  // Extra fields shown when role requires academic context
                  if (_role == 'Class Representative' ||
                      _role == 'Coordinator') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _department,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                      items:
                          departments
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _department = v!),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Class Rep–specific details
                  if (_role == 'Class Representative') ...[
                    DropdownButtonFormField<String>(
                      value: _year,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items:
                          ['1', '2', '3', '4']
                              .map(
                                (y) => DropdownMenuItem(
                                  value: y,
                                  child: Text('$y'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _semester,
                      decoration: const InputDecoration(
                        labelText: 'Semester',
                        hintText: 'S3',
                      ),
                      onChanged: (v) => _semester = v,
                      validator:
                          (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _classGroup,
                      decoration: const InputDecoration(
                        labelText: 'Class',
                        hintText: 'CSE - A',
                      ),
                      onChanged: (v) => _classGroup = v,
                      validator:
                          (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _admissionCtl,
                      decoration: const InputDecoration(
                        labelText: 'Ktu Id',
                        hintText: 'IDK22CS017',
                      ),
                      validator: validateKtuIdWithExamples,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Create User'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Activity Log Widget - fetches and displays real activity logs from backend
class _ActivityLogWidget extends StatefulWidget {
  const _ActivityLogWidget({super.key});

  @override
  State<_ActivityLogWidget> createState() => __ActivityLogWidgetState();
}

class __ActivityLogWidgetState extends State<_ActivityLogWidget> {
  late Future<List<Map<String, dynamic>>> _activityLogsFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _activityLogsFuture = _fetchActivityLogs();
    // Refresh logs every 30 seconds (reduced from 10 to avoid timeout issues)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _activityLogsFuture = _fetchActivityLogs();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchActivityLogs() async {
    try {
      final logs = await api.getActivityLogs(limit: 10, days: 1);
      return logs;
    } catch (e) {
      print('Error fetching activity logs: $e');
      return [];
    }
  }

  String _getTimeAgo(String timestamp) {
    try {
      final logTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(logTime);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'unknown';
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'data_submission':
        return Icons.assignment_turned_in;
      case 'report_generation':
        return Icons.assessment;
      case 'alert':
        return Icons.warning;
      case 'warning':
        return Icons.info;
      default:
        return Icons.history;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green.shade600;
      case 'failure':
        return Colors.red.shade600;
      case 'warning':
        return Colors.orange.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _activityLogsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loading activity logs...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error loading activity logs',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.history, color: Colors.grey.shade400, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No activity logs found',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: List.generate(logs.length, (index) {
              final log = logs[index];
              final userName = log['user_name'] ?? 'Unknown User';
              final action = log['action_description'] ?? 'Unknown action';
              final timestamp = log['timestamp'] ?? '';
              final actionType = log['action_type'] ?? 'activity';
              final status = log['status'] ?? 'success';

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < logs.length - 1 ? 12 : 0,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getActionIcon(actionType),
                        color: _getStatusColor(status),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            action,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeAgo(timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
