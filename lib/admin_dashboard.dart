// ignore_for_file: deprecated_member_use, file_names, curly_braces_in_flow_control_structures, unused_element, unused_field, unused_local_variable, unused_element_parameter, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';
import 'package:intl/intl.dart'; // For DateFormat
import 'services/notifier.dart';
import 'package:energia/services/pdf_export.dart';
import 'package:energia/services/csv_export.dart';
import 'role_selection_page.dart'; // For Logout navigation
// Departmental page imports
import 'computer_science_classrooms_page.dart';
import 'dart:convert'; // Fixes 'jsonEncode' error
import 'dart:async'; // For Timer
import 'package:http/http.dart' as http; // Fixes 'http' error
import 'services/api.dart' as api; // Import API functions
import 'package:shared_preferences/shared_preferences.dart';
import 'services/user_counts.dart';
import 'services/user_lists.dart';
import 'services/validators.dart'; // Import validation functions
import 'activity_logs_page.dart'; // Import activity logs page
import 'monthly_report_page.dart'; // Import monthly report page
import 'dart:ui'; // For ImageFilter (glassmorphism effect)
import 'sergeant_list_page.dart'; // Import sergeant list page
import 'coordinator_list_page.dart'; // Import coordinator list page
import 'class_representatives_list_page.dart'; // Import class representatives list page
import 'user_permissions_page.dart'; // Import user permissions page
import 'admin_profile_page.dart'; // Import admin profile page
import 'services/admin_api.dart'; // Import admin API functions

// --- HELPER WIDGETS ---

class _CampusStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _CampusStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: 160,
      height: 120,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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

  Future<void> _openProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        if (mounted) {
          AppNotifier.showError(context, 'Authentication token not found');
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      final profile = await getAdminProfile(token);

      if (!mounted) return;
      // Close loading indicator
      Navigator.pop(context);

      // Navigate to profile page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminProfilePage(profile: profile, token: token),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Close loading indicator if still showing
      Navigator.pop(context);
      AppNotifier.showError(context, 'Failed to load profile: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardScaffold(
      title: '⚡ GECI ENERGIA Control Center',
      actions: [
        IconButton(
          icon: const Icon(Icons.account_circle),
          tooltip: 'Profile',
          onPressed: _openProfile,
        ),
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
  bool _isLoading = false; // user counts
  bool _isOverviewLoading = true;
  Timer? _refreshTimer;

  double? _totalUsageKwh;
  int _activeRooms = 0;
  int _totalRooms = 0;
  double? _efficiencyPercent;
  List<String> _inactiveRooms = const [];

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

    // Parallel data loading for faster UI response
    _loadDataInParallel();

    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadDataInParallel();
    });
  }

  Future<void> _loadDataInParallel() async {
    // Load user counts and campus overview in parallel
    await Future.wait([
      _loadUserCounts(),
      _loadCampusOverview(),
    ], eagerError: false);
  }

  Future<void> _loadUserCounts() async {
    try {
      final counts = await api.getUserCounts().timeout(
        const Duration(seconds: 8),
      );
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
          _userCounts ??= {'coordinators': 0, 'class_representatives': 0};
        });
      }
    }
  }

  Future<void> _loadCampusOverview() async {
    try {
      final data = await api
          .getCampusOverview(activeWindowMinutes: 5, usageWindowHours: 1)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _totalUsageKwh = (data['total_usage_kwh'] as num?)?.toDouble();
        _activeRooms = data['active_rooms'] as int? ?? 0;
        _totalRooms = data['total_rooms'] as int? ?? 0;
        _inactiveRooms = List<String>.from(data['inactive_rooms'] ?? const []);
        _efficiencyPercent = (data['efficiency_percent'] as num?)?.toDouble();
        _isOverviewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOverviewLoading = false;
      });
      // Keep silent in UI but log to console
      debugPrint('Failed to load campus overview: $e');
    }
  }

  @override
  void dispose() {
    UserCountsStore.instance.counts.removeListener(_onCountsChanged);
    _refreshTimer?.cancel();
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

    return RefreshIndicator(
      onRefresh: _loadDataInParallel,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
              _isOverviewLoading
                  ? const SizedBox(
                    width: 160,
                    height: 120,
                    child: Card(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                  : _CampusStatCard(
                    label: 'Total Usage (1h)',
                    value:
                        _totalUsageKwh != null
                            ? '${_totalUsageKwh!.toStringAsFixed(2)} kWh'
                            : '--',
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
              _isOverviewLoading
                  ? const SizedBox(
                    width: 160,
                    height: 120,
                    child: Card(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                  : _CampusStatCard(
                    label: 'Active Rooms',
                    value:
                        _totalRooms > 0 ? '$_activeRooms / $_totalRooms' : '--',
                    icon: Icons.business_outlined,
                    color: Colors.purple,
                    onTap:
                        _inactiveRooms.isEmpty
                            ? null
                            : () {
                              showModalBottomSheet(
                                context: context,
                                builder: (ctx) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Inactive Rooms',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 12),
                                        if (_inactiveRooms.isEmpty)
                                          const Text(
                                            'All rooms are reporting live data',
                                          )
                                        else
                                          ..._inactiveRooms.map(
                                            (id) => ListTile(
                                              leading: const Icon(
                                                Icons.meeting_room_outlined,
                                              ),
                                              title: Text(id),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                  ),
              _isOverviewLoading
                  ? const SizedBox(
                    width: 160,
                    height: 120,
                    child: Card(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                  : _CampusStatCard(
                    label: 'Efficiency',
                    value:
                        _efficiencyPercent != null
                            ? '${_efficiencyPercent!.toStringAsFixed(1)}%'
                            : '--',
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MonthlyReportPage()),
              );
            },
          ),
          _buildActionCard(
            context,
            'Manage Thresholds',
            'Adjust campus-level anomaly limits.',
            Icons.tune,
          ),
        ],
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
    final sergeantCount = _userCounts?['sergeants'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadUserCounts,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DetailedCoordinatorsPage(),
                ),
              );
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
                  builder: (_) => const DetailedClassRepresentativesPage(),
                ),
              );
            },
          ),
          _buildUserTypeCard(
            context,
            'Sergeants',
            _isLoading ? 'Loading...' : '$sergeantCount Users',
            Icons.security_outlined,
            Colors.purple.shade600,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SergeantListPage()),
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
            'Bulk Export',
            'Export all users to CSV file',
            Icons.download_outlined,
            onTap: () => _exportAllUsersCSV(context),
          ),
          _buildActionCard(
            context,
            'User Permissions',
            'Manage access controls',
            Icons.security_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserPermissionsPage()),
              );
            },
          ),
          _buildActionCard(
            context,
            'Activity Logs',
            'View user activity history',
            Icons.history_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ActivityLogsPage()),
              );
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
      ),
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Coordinators'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor: theme.appBarTheme.backgroundColor ?? scheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? scheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 0,
        actions: [
          TextButton(onPressed: _loadCoordinators, child: const Text('Reload')),
        ],
      ),
      body: Center(
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
                          ElevatedButton(
                            onPressed: _loadCoordinators,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadCoordinators,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
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
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Row(
                                        children: [
                                          FilledButton.icon(
                                            onPressed: _exportData,
                                            icon: const Icon(
                                              Icons.file_download,
                                            ),
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
                                                                child: Text(
                                                                  'CSE',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'ECE',
                                                                child: Text(
                                                                  'ECE',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'ME',
                                                                child: Text(
                                                                  'ME',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'CE',
                                                                child: Text(
                                                                  'CE',
                                                                ),
                                                              ),
                                                              DropdownMenuItem(
                                                                value: 'AD',
                                                                child: Text(
                                                                  'AD',
                                                                ),
                                                              ),
                                                            ],
                                                            onChanged: (value) {
                                                              if (value !=
                                                                  null) {
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
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          },
                                                          child: const Text(
                                                            'Clear',
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () {
                                                            _filterData();
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          },
                                                          child: const Text(
                                                            'Apply',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                              );
                                            },
                                            icon: const Icon(Icons.filter_alt),
                                            label: Text(
                                              _selectedDepartment ==
                                                      'All Departments'
                                                  ? 'Filter'
                                                  : 'Filtered',
                                            ),
                                          ),
                                        ],
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Class Representatives'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor: theme.appBarTheme.backgroundColor ?? scheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? scheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 0,
        actions: [
          TextButton(
            onPressed: _loadClassRepresentatives,
            child: const Text('Reload'),
          ),
        ],
      ),
      body: Center(
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
                          ElevatedButton(
                            onPressed: _loadClassRepresentatives,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadClassRepresentatives,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
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
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons.info_outline,
                                                            color: Colors.blue,
                                                          ),
                                                          tooltip:
                                                              'View details',
                                                          onPressed: () {
                                                            // Show detail dialog using KTU id as primary identifier
                                                            final rep = r;
                                                            final repId =
                                                                rep['ktu_id']
                                                                    ?.toString() ??
                                                                rep['username']
                                                                    ?.toString() ??
                                                                rep['id']
                                                                    ?.toString() ??
                                                                '';
                                                            final phone =
                                                                rep['phone']
                                                                    ?.toString() ??
                                                                'No phone';
                                                            final lastLoginRaw =
                                                                rep['last_login']
                                                                    ?.toString();
                                                            String formatDate(
                                                              String? dateStr,
                                                            ) {
                                                              if (dateStr ==
                                                                  null)
                                                                return 'Never';
                                                              try {
                                                                final date =
                                                                    DateTime.parse(
                                                                      dateStr,
                                                                    );
                                                                return DateFormat(
                                                                  'MMM d, yyyy h:mm a',
                                                                ).format(date);
                                                              } catch (_) {
                                                                return 'Invalid date';
                                                              }
                                                            }

                                                            bool
                                                            isActiveFromLogin(
                                                              String? dateStr,
                                                            ) {
                                                              if (dateStr ==
                                                                  null)
                                                                return false;
                                                              try {
                                                                final date =
                                                                    DateTime.parse(
                                                                      dateStr,
                                                                    );
                                                                return DateTime.now()
                                                                        .difference(
                                                                          date,
                                                                        ) <=
                                                                    const Duration(
                                                                      days: 30,
                                                                    );
                                                              } catch (_) {
                                                                return false;
                                                              }
                                                            }

                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (
                                                                    ctx,
                                                                  ) => AlertDialog(
                                                                    title: Row(
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .person,
                                                                          color:
                                                                              Colors.orange.shade700,
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              8,
                                                                        ),
                                                                        const Text(
                                                                          'Class Representative Details',
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    content: SizedBox(
                                                                      width:
                                                                          400,
                                                                      child: Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          _DetailRow(
                                                                            icon:
                                                                                Icons.badge,
                                                                            label:
                                                                                'Rep ID',
                                                                            value:
                                                                                repId,
                                                                          ),
                                                                          _DetailRow(
                                                                            icon:
                                                                                Icons.person,
                                                                            label:
                                                                                'Name',
                                                                            value:
                                                                                rep['name']?.toString() ??
                                                                                'Unknown',
                                                                          ),
                                                                          _DetailRow(
                                                                            icon:
                                                                                Icons.email,
                                                                            label:
                                                                                'Email',
                                                                            value:
                                                                                rep['email']?.toString() ??
                                                                                'No email',
                                                                          ),
                                                                          _DetailRow(
                                                                            icon:
                                                                                Icons.phone,
                                                                            label:
                                                                                'Phone',
                                                                            value:
                                                                                phone,
                                                                          ),
                                                                          const Divider(),
                                                                          _DetailRow(
                                                                            icon:
                                                                                Icons.verified_user,
                                                                            label:
                                                                                'Status',
                                                                            value:
                                                                                isActiveFromLogin(
                                                                                      lastLoginRaw,
                                                                                    )
                                                                                    ? 'Active'
                                                                                    : 'Inactive',
                                                                            valueColor:
                                                                                isActiveFromLogin(
                                                                                      lastLoginRaw,
                                                                                    )
                                                                                    ? Colors.green.shade700
                                                                                    : Colors.red.shade700,
                                                                          ),
                                                                          _DetailRow(
                                                                            icon:
                                                                                Icons.login,
                                                                            label:
                                                                                'Last Login',
                                                                            value: formatDate(
                                                                              lastLoginRaw,
                                                                            ),
                                                                          ),
                                                                          _DetailRow(
                                                                            icon:
                                                                                Icons.calendar_today,
                                                                            label:
                                                                                'Created',
                                                                            value: formatDate(
                                                                              rep['created_at']?.toString(),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.of(ctx).pop(),
                                                                        child: const Text(
                                                                          'Close',
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                            );
                                                          },
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Colors.red,
                                                          ),
                                                          tooltip:
                                                              'Delete user',
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
                                                      ],
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
  bool _isProxy = false;
  bool _loadingProxyCandidates = false;
  String? _selectedProxyEmail;
  List<Map<String, dynamic>> _proxyCandidates = const [];
  bool _loadingRooms = false;
  String? _selectedRoomId;
  List<Map<String, dynamic>> _connectedRooms = const [];

  static const roles = ['Class Representative', 'Coordinator', 'Sergeant'];
  static const departments = ['CSE', 'ECE', 'ME', 'IT', 'RA', 'EEE'];

  @override
  void initState() {
    super.initState();
    _loadConnectedRooms();
  }

  Future<void> _loadConnectedRooms() async {
    if (!mounted) return;
    setState(() => _loadingRooms = true);
    try {
      List<Map<String, dynamic>> rooms = const [];

      final connectedUri = Uri.parse(
        'http://localhost:5000/rooms/connected-assignable?active_window_minutes=15&department=${Uri.encodeComponent(_department)}',
      );
      final connectedResp = await http
          .get(connectedUri)
          .timeout(const Duration(seconds: 10));
      if (connectedResp.statusCode == 200) {
        final payload = jsonDecode(connectedResp.body);
        final raw =
            (payload is Map<String, dynamic>)
                ? (payload['data'] as List<dynamic>? ?? const [])
                : const [];
        rooms = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      // Department-specific fallback: keep mapping aligned with selected dept.
      if (rooms.isEmpty) {
        final deptRoomsUri = Uri.parse(
          'http://localhost:5000/rooms?department=${Uri.encodeComponent(_department)}',
        );
        final deptRoomsResp = await http
            .get(deptRoomsUri)
            .timeout(const Duration(seconds: 10));
        if (deptRoomsResp.statusCode == 200) {
          final payload = jsonDecode(deptRoomsResp.body);
          final raw =
              (payload is Map<String, dynamic>)
                  ? (payload['data'] as List<dynamic>? ?? const [])
                  : const [];
          rooms =
              raw.map((e) {
                final m = Map<String, dynamic>.from(e as Map);
                m.putIfAbsent('available_slots', () => 1);
                return m;
              }).toList();
        }
      }

      // Deployment policy: for CSE this installation has one operational room only.
      if (_department.trim().toUpperCase() == 'CSE') {
        rooms =
            rooms
                .where((r) {
                  final rid =
                      (r['room_id'] ?? '').toString().trim().toUpperCase();
                  return rid == 'CS-201' || rid == 'CS-C201';
                })
                .map((r) {
                  final m = Map<String, dynamic>.from(r);
                  // Keep real room_id for backend payload; use friendly label for admins.
                  m['room_name'] = 'CS-201';
                  return m;
                })
                .toList();

        if (rooms.isEmpty) {
          rooms = [
            {
              'room_id': 'CS-201',
              'room_name': 'CS-201',
              'department': 'CSE',
              'available_slots': 1,
            },
          ];
        }
      }

      String? nextSelected = _selectedRoomId;
      final hasCurrent = rooms.any(
        (r) => (r['room_id']?.toString() ?? '') == nextSelected,
      );
      if (!hasCurrent) {
        nextSelected =
            rooms.isNotEmpty ? rooms.first['room_id']?.toString() : null;
      }

      if (!mounted) return;
      setState(() {
        _connectedRooms = rooms;
        _selectedRoomId = nextSelected;
      });

      if (_isProxy &&
          (_role == 'Class Representative' || _role == 'Coordinator')) {
        await _loadProxyCandidates();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connectedRooms = const [];
        _selectedRoomId = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingRooms = false);
      }
    }
  }

  Future<void> _loadProxyCandidates() async {
    if (!mounted || !_isProxy) return;

    setState(() => _loadingProxyCandidates = true);
    try {
      final selectedDepartment = _department.trim().toUpperCase();
      final selectedRoom = (_selectedRoomId ?? '').trim().toUpperCase();
      final enteredEmail = _emailCtl.text.trim().toUpperCase();

      List<Map<String, dynamic>> source = const [];
      if (_role == 'Class Representative') {
        source = await api.getClassRepresentatives();
      } else if (_role == 'Coordinator') {
        source = await api.getCoordinators();
      }

      final filtered =
          source
              .where((u) {
                final isProxyUser = (u['is_proxy'] ?? false) == true;
                if (isProxyUser) return false;

                final email =
                    ((u['email'] ?? u['username'] ?? '').toString()).trim();
                if (email.isEmpty) return false;
                if (enteredEmail.isNotEmpty &&
                    enteredEmail == email.toUpperCase()) {
                  return false;
                }

                final dept =
                    (u['department'] ?? '').toString().trim().toUpperCase();
                if (dept != selectedDepartment) return false;

                if (selectedRoom.isNotEmpty) {
                  final room =
                      (u['assigned_room_id'] ?? '')
                          .toString()
                          .trim()
                          .toUpperCase();
                  if (room.isNotEmpty && room != selectedRoom) {
                    return false;
                  }
                }

                return true;
              })
              .map((u) {
                final email =
                    ((u['email'] ?? u['username'] ?? '').toString()).trim();
                final name = (u['name'] ?? email).toString().trim();
                return {
                  ...u,
                  'email': email,
                  'display_name': name.isEmpty ? email : name,
                };
              })
              .toList();

      String? nextSelected = _selectedProxyEmail;
      final hasCurrent =
          nextSelected != null &&
          filtered.any(
            (u) =>
                u['email'].toString().toUpperCase() ==
                nextSelected!.toUpperCase(),
          );
      if (!hasCurrent) {
        nextSelected =
            filtered.isNotEmpty ? filtered.first['email'].toString() : null;
      }

      if (!mounted) return;
      setState(() {
        _proxyCandidates = filtered;
        _selectedProxyEmail = nextSelected;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _proxyCandidates = const [];
        _selectedProxyEmail = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingProxyCandidates = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _admissionCtl.dispose();
    super.dispose();
  }

  // Inside _AddUserPageState in admin_dashboard.dart
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_role == 'Class Representative' || _role == 'Coordinator') &&
        (_selectedRoomId == null || _selectedRoomId!.isEmpty)) {
      AppNotifier.showError(
        context,
        'Select a room mapping before creating this user.',
      );
      return;
    }
    if (_isProxy &&
        (_selectedProxyEmail == null || _selectedProxyEmail!.trim().isEmpty)) {
      AppNotifier.showError(
        context,
        'Select a primary user for proxy creation.',
      );
      return;
    }
    if (_isProxy && _proxyCandidates.isEmpty) {
      AppNotifier.showError(
        context,
        'No eligible primary users found for this department and room.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (_role == 'Sergeant' && token.isEmpty) {
        throw api.ApiError('Admin session expired. Please login again.');
      }

      if (_role == 'Sergeant') {
        final response = await api.createSergeantAsAdmin(
          token: token,
          name: _nameCtl.text.trim(),
          email: _emailCtl.text.trim(),
          phone: _phoneCtl.text.trim(),
        );

        if (!mounted) return;
        Navigator.pop(context);

        final data = response['data'] as Map<String, dynamic>? ?? const {};
        final credentials =
            response['credentials'] as Map<String, dynamic>? ?? const {};
        final sergeantId =
            (data['sergeant_id'] ?? credentials['sergeant_id'] ?? '')
                .toString();
        final password = (credentials['password'] ?? '').toString();
        final emailSent = (data['email_sent'] ?? false) == true;

        AppNotifier.showSuccess(
          context,
          'Sergeant created: $sergeantId. Credentials ${emailSent ? 'sent by email' : 'generated'}.',
        );

        await showDialog<void>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Sergeant Credentials'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sergeant ID: $sergeantId'),
                    Text('Password: $password'),
                    const SizedBox(height: 8),
                    Text(
                      emailSent
                          ? 'Credentials have also been sent to the provided email.'
                          : 'Email could not be sent. Share these credentials securely.',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );

        if (!mounted) return;
        Navigator.pop(context, {'role': _role, 'name': _nameCtl.text.trim()});
        return;
      }

      final payload = <String, dynamic>{
        'username': _emailCtl.text.trim(),
        'role': _role,
        'name': _nameCtl.text.trim(),
        'department': _department,
        if (_role == 'Class Representative') 'year': _year,
        if (_role == 'Class Representative')
          'ktu_id': _admissionCtl.text.trim(),
        'email': _emailCtl.text.trim(),
        if ((_role == 'Class Representative' || _role == 'Coordinator') &&
            _selectedRoomId != null)
          'room_id': _selectedRoomId,
        if (_isProxy) 'is_proxy': true,
        if (_isProxy) 'proxy_for_email': _selectedProxyEmail,
      };

      final inviteResp = await http
          .post(
            Uri.parse('http://localhost:5000/admin/invite-user'),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (inviteResp.statusCode != 200) {
        String err = 'Invite failed (${inviteResp.statusCode})';
        try {
          final decoded = jsonDecode(inviteResp.body);
          if (decoded is Map<String, dynamic>) {
            err = (decoded['detail'] ?? decoded['message'] ?? err).toString();
          }
        } catch (_) {
          // keep fallback
        }
        throw api.ApiError(err);
      }

      final decoded = jsonDecode(inviteResp.body);
      final response =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

      if (!mounted) return;
      Navigator.pop(context);
      final msg = (response['message'] ?? 'Invitation email sent!').toString();
      AppNotifier.showSuccess(context, msg);
      Navigator.pop(context, {'role': _role, 'name': _nameCtl.text.trim()});
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      final message =
          e is api.ApiError ? e.message : 'Failed to create user: $e';
      AppNotifier.showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add New User'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        foregroundColor:
            theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
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
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _role = v;
                        _selectedRoomId = null;
                        _isProxy = false;
                        _selectedProxyEmail = null;
                        _proxyCandidates = const [];
                      });
                      if (_role == 'Class Representative' ||
                          _role == 'Coordinator') {
                        _loadConnectedRooms();
                      }
                    },
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
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _department = v;
                          _selectedRoomId = null;
                          _selectedProxyEmail = null;
                          _proxyCandidates = const [];
                        });
                        _loadConnectedRooms();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (_role == 'Class Representative' ||
                      _role == 'Coordinator') ...[
                    DropdownButtonFormField<String>(
                      value: _selectedRoomId,
                      decoration: InputDecoration(
                        labelText:
                            _loadingRooms
                                ? 'Room Mapping (loading...)'
                                : 'Room Mapping',
                        helperText: 'Active connected rooms are prioritized.',
                      ),
                      items:
                          _connectedRooms
                              .map(
                                (r) => DropdownMenuItem<String>(
                                  value: r['room_id']?.toString(),
                                  child: Text(
                                    '${r['room_name'] ?? r['room_id']} (${r['room_id']})',
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          _loadingRooms
                              ? null
                              : (v) {
                                setState(() => _selectedRoomId = v);
                                if (_isProxy) {
                                  _loadProxyCandidates();
                                }
                              },
                      validator: (v) {
                        if ((_role == 'Class Representative' ||
                                _role == 'Coordinator') &&
                            (v == null || v.isEmpty)) {
                          return 'Room mapping is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (_role == 'Class Representative' ||
                      _role == 'Coordinator') ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Create as Proxy User'),
                      subtitle: const Text(
                        'Proxy gets the same room/department anomaly scope as primary user.',
                      ),
                      value: _isProxy,
                      onChanged: (v) {
                        setState(() {
                          _isProxy = v;
                          _selectedProxyEmail = null;
                          _proxyCandidates = const [];
                        });
                        if (v) {
                          _loadProxyCandidates();
                        }
                      },
                    ),
                    if (_isProxy) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedProxyEmail,
                        decoration: InputDecoration(
                          labelText:
                              _loadingProxyCandidates
                                  ? 'Primary User (loading...)'
                                  : 'Primary User',
                          helperText:
                              'Select an existing non-proxy user from the same department/room.',
                        ),
                        items:
                            _proxyCandidates
                                .map(
                                  (u) => DropdownMenuItem<String>(
                                    value: u['email'].toString(),
                                    child: Text(
                                      '${u['display_name']} (${u['email']})',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            _loadingProxyCandidates
                                ? null
                                : (v) =>
                                    setState(() => _selectedProxyEmail = v),
                        validator: (v) {
                          if (_isProxy && (v == null || v.trim().isEmpty)) {
                            return 'Primary user selection is required for proxy';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
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
                                  child: Text('Year $y'),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(() => _year = v!),
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
  List<Map<String, dynamic>> _cachedLogs = []; // Cache last successful response
  bool _hasLoadedOnce = false; // Track if we've ever loaded successfully

  @override
  void initState() {
    super.initState();
    _activityLogsFuture = _fetchActivityLogs();
    // Refresh logs every 45 seconds (increased to reduce backend load)
    _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
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
    int retries = 0;
    const maxRetries = 1; // API already retries across candidate backends

    while (retries < maxRetries) {
      try {
        final logs = await api
            .getActivityLogs(limit: 5, days: 1)
            .timeout(
              const Duration(seconds: 12),
              onTimeout: () {
                throw TimeoutException('Activity logs request timed out');
              },
            );

        // Cache successful response
        if (logs.isNotEmpty) {
          _cachedLogs = logs;
          _hasLoadedOnce = true;
        }

        return logs;
      } catch (e) {
        retries++;
        if (retries >= maxRetries) {
          debugPrint(
            '[Admin Dashboard] Failed to fetch activity logs after $maxRetries attempts: $e',
          );

          // Return cached logs if available, otherwise empty
          if (_cachedLogs.isNotEmpty) {
            debugPrint(
              '[Admin Dashboard] Returning ${_cachedLogs.length} cached activity logs',
            );
            return _cachedLogs;
          }
          return [];
        }
        // Exponential backoff: 2s, 4s
        final backoffSeconds = 2 * retries;
        debugPrint(
          '[Admin Dashboard] Retry $retries/$maxRetries after ${backoffSeconds}s...',
        );
        await Future.delayed(Duration(seconds: backoffSeconds));
      }
    }

    // Fallback to cached logs
    return _cachedLogs.isNotEmpty ? _cachedLogs : [];
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

/// Helper widget for displaying detail row with icon, label, and value
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
