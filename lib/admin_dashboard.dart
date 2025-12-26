import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';
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


// --- HELPER WIDGETS ---

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

class _CampusEnergyPieChart extends StatelessWidget {
  const _CampusEnergyPieChart({super.key}); 
  
  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 50,
        startDegreeOffset: -90,
        sections: [
          PieChartSectionData(
            value: 30,
            color: Colors.blue.shade600,
            title: '30%',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            titlePositionPercentageOffset: 0.55,
            badgeWidget: _buildBadge('CS', Colors.blue.shade600),
            badgePositionPercentageOffset: 1.3,
          ),
          PieChartSectionData(
            value: 25,
            color: Colors.green.shade600,
            title: '25%',
            radius: 75,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            titlePositionPercentageOffset: 0.55,
            badgeWidget: _buildBadge('ECE', Colors.green.shade600),
            badgePositionPercentageOffset: 1.3,
          ),
          PieChartSectionData(
            value: 20,
            color: Colors.orange.shade600,
            title: '20%',
            radius: 70,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            titlePositionPercentageOffset: 0.55,
            badgeWidget: _buildBadge('Mech', Colors.orange.shade600),
            badgePositionPercentageOffset: 1.3,
          ),
          PieChartSectionData(
            value: 15,
            color: Colors.purple.shade600,
            title: '15%',
            radius: 65,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            titlePositionPercentageOffset: 0.55,
            badgeWidget: _buildBadge('IT', Colors.purple.shade600),
            badgePositionPercentageOffset: 1.3,
          ),
          PieChartSectionData(
            value: 10,
            color: Colors.cyan.shade600,
            title: '10%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            titlePositionPercentageOffset: 0.55,
            badgeWidget: _buildBadge('Admin', Colors.cyan.shade600),
            badgePositionPercentageOffset: 1.3,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
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
class _CampusOverviewSection extends StatelessWidget {
  final ColorScheme scheme;
  const _CampusOverviewSection({required this.scheme});

  // Helper to build the Department Status Tiles
  Widget _buildDepartmentStatusTile(BuildContext context, String dept, String usage, String efficiency, Color color, String status, {VoidCallback? onTap}) {
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
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Admin Welcome Card
        _AdminWelcomeCard(scheme: scheme),
        const SizedBox(height: 24),
        
        // Campus-wide Key Stats
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
            _CampusStatCard(label: 'Total Usage', value: '247.8 kW', icon: Icons.electric_bolt_outlined, color: Colors.red),
            _CampusStatCard(label: 'Active Users', value: '1,247', icon: Icons.people_outlined, color: Colors.blue),
            _CampusStatCard(label: 'Buildings', value: '12 Online', icon: Icons.business_outlined, color: Colors.purple),
            _CampusStatCard(label: 'Efficiency', value: '94.2%', icon: Icons.eco_outlined, color: Colors.green),
          ],
        ),
        const SizedBox(height: 32),
        
        // Campus Energy Distribution (Pie Chart is essential for high-level visualization)
        Text(
          'Energy Distribution by Department',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 300, child: _CampusEnergyPieChart()),
        
        const SizedBox(height: 32),
        
        // Department Status (Detailed list is good for Admin oversight)
        Text(
          'Department Status',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        // 1. Computer Science (Navigates to CS Classrooms Page)
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
              MaterialPageRoute(builder: (context) => const ComputerScienceClassroomsPage()),
            );
          },
        ),
        
        // 2. Mechanical (Navigates to Mechan Page)
        _buildDepartmentStatusTile(
          context, 
          'Mechanical', 
          '31.5 kW', 
          '78%', 
          Colors.orange.shade600,
          'Moderate',
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const Mechan()),
            );
          },
        ),
        
        // 3. Electrical (Navigates to Elect Page)
        _buildDepartmentStatusTile(
          context, 
          'Electrical', 
          '45.7 kW', 
          '72%', 
          Colors.red.shade600,
          'Alert',
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const Elect()),
            );
          },
        ),
        
        // 4. Electronics and communication (Navigates to Electrns Page)
        _buildDepartmentStatusTile(
          context, 
          'Electronics and communication', 
          '8.2 kW', 
          '95%', 
          Colors.cyan.shade600, 
          'Excellent',
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const Electrns()),
            );
          },
        ),

        // 5. IT (Navigates to Itpage Page)
        _buildDepartmentStatusTile(
          context, 
          'IT', 
          '45.7 kW', 
          '72%', 
          Colors.yellow.shade600,
          'Alert',
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const Itpage()),
            );
          },
        ),
        
        // 6. Adminblock (Navigates to AdmPage Page)
        _buildDepartmentStatusTile(
          context, 
          'Adminblock', 
          '45.7 kW', 
          '72%', 
          Colors.blue.shade600,
          'Alert',
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const AdmPage()),
            );
          },
        ),

        const SizedBox(height: 32),
        
        // Quick Links (Admin specific actions)
        Text(
          'Admin Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildActionCard(context, 'Generate Monthly Report', 'Create campus-wide consumption report.', Icons.picture_as_pdf), //
        _buildActionCard(context, 'Manage Thresholds', 'Adjust campus-level anomaly limits.', Icons.tune), //

      ],
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
        
        // Tappable User Type Cards with navigation (hide Administrators & Students as requested)
        _buildUserTypeCard(
          context,
          'Coordinators', 
          '24 Users', 
          Icons.supervisor_account_outlined, 
          Colors.orange.shade600,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoordinatorsPage()));
          },
        ),
        _buildUserTypeCard(
          context,
          'Class Representatives', 
          '156 Users', 
          Icons.school_outlined, 
          Colors.blue.shade600,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClassRepresentativesPage()));
          },
        ),
        // (Students card removed)
        
        const SizedBox(height: 24),
        
        // Quick Actions
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        _buildActionCard(
          context, 
          'Add New User', 
          'Register a new system user', 
          Icons.person_add_outlined,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddUserPage()));
          },
        ),
        _buildActionCard(
          context, 
          'Bulk Import', 
          'Export all users to CSV file', 
          Icons.download_outlined,
          onTap: () => _exportAllUsersCSV(context),
        ),
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

  void _exportAllUsersCSV(BuildContext context) async {
    // Get all coordinators data
    final coordinators = _CoordinatorsPageState._allCoordinators;
    
    // Get all class representatives data
    final classReps = _ClassRepresentativesPageState._generateReps();
    
    // Export to CSV
    final filePath = await exportUsersCSV(
      coordinators: coordinators,
      classReps: classReps,
    );
    
    if (context.mounted) {
      final msg = filePath != null
          ? 'CSV exported to: $filePath'
          : 'CSV export initiated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Widget _buildUserTypeCard(BuildContext context, String type, String count, IconData icon, Color color, {VoidCallback? onTap}) {
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
        onTap: onTap,
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String description, IconData icon, {VoidCallback? onTap}) {
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
  static const List<Map<String, String>> _allCoordinators = [
    {
      'name': 'Dr. Priya Nair',
      'ktuid': 'KTU-1001',
      'department': 'Computer Science',
    },
    {'name': 'Suman R', 'ktuid': 'KTU-1002', 'department': 'Electronics'},
    {'name': 'Manish K', 'ktuid': 'KTU-1003', 'department': 'Mechanical'},
    {'name': 'Anita P', 'ktuid': 'KTU-1004', 'department': 'Civil'},
    {'name': 'Richa T', 'ktuid': 'KTU-1005', 'department': 'Administrative'},
  ];

  final _searchController = TextEditingController();
  String _selectedDepartment = 'All Departments';
  List<Map<String, String>> _filteredCoordinators = [];

  @override
  void initState() {
    super.initState();
    _filteredCoordinators = List.from(_allCoordinators);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterData() {
    setState(() {
      _filteredCoordinators = _allCoordinators.where((coord) {
        final matchesSearch = _searchController.text.isEmpty ||
            coord['name']!.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            coord['ktuid']!.toLowerCase().contains(_searchController.text.toLowerCase());
        
        final matchesDepartment = _selectedDepartment == 'All Departments' ||
            coord['department'] == _selectedDepartment;
        
        return matchesSearch && matchesDepartment;
      }).toList();
    });
  }

  void _exportData() {
    final headers = ['Name', 'KTU ID', 'Department'];
    final rows = _filteredCoordinators
        .map((c) => [c['name'] ?? '', c['ktuid'] ?? '', c['department'] ?? ''])
        .toList();

    exportTablePdfAutoSave(
      'Department Coordinators',
      headers,
      rows,
      subtitle: 'Exported ${_filteredCoordinators.length} coordinators · ${DateTime.now()}',
    ).then((savedPath) {
      final msg = savedPath != null
          ? 'Saved PDF to: $savedPath'
          : 'PDF ready – choose location in Save/Share';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinators'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.surfaceContainerLowest, scheme.surfaceContainerHigh],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Card(
                      elevation: 0,
                      color: scheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.supervisor_account, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Department Coordinators', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                                Text('Manage and review coordinator roster', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer.withOpacity(0.85))),
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
                                builder: (context) => AlertDialog(
                                  title: const Text('Filter Options'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: _selectedDepartment,
                                        decoration: const InputDecoration(
                                          labelText: 'Department',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(value: 'All Departments', child: Text('All Departments')),
                                          DropdownMenuItem(value: 'Computer Science', child: Text('Computer Science')),
                                          DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
                                          DropdownMenuItem(value: 'Mechanical', child: Text('Mechanical')),
                                          DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                                          DropdownMenuItem(value: 'Administrative', child: Text('Administrative')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedDepartment = value;
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
                                          _selectedDepartment = 'All Departments';
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
                            label: Text(_selectedDepartment == 'All Departments' ? 'Filter' : 'Filtered'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Content Card with centered table
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Search bar
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => _filterData(),
                            decoration: const InputDecoration(
                              hintText: 'Search by name or KTU ID',
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
                                DataColumn(label: Text('Name', style: theme.textTheme.titleMedium)),
                                DataColumn(label: Text('KTU ID', style: theme.textTheme.titleMedium)),
                                DataColumn(label: Text('Department', style: theme.textTheme.titleMedium)),
                              ],
                              rows: _filteredCoordinators.map((c) {
                                return DataRow(cells: [
                                  DataCell(Text(c['name']!)),
                                  DataCell(Text(c['ktuid']!)),
                                  DataCell(Text(c['department']!)),
                                ]);
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
                      Expanded(child: _UserStatsCard(title: 'Total Coordinators', value: '${_filteredCoordinators.length}', icon: Icons.people, color: Colors.blue.shade600)),
                      const SizedBox(width: 12),
                      Expanded(child: _UserStatsCard(title: 'Active Today', value: '6', icon: Icons.online_prediction, color: Colors.green.shade600)),
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
  State<ClassRepresentativesPage> createState() => _ClassRepresentativesPageState();
}

class _ClassRepresentativesPageState extends State<ClassRepresentativesPage> {
  final _searchController = TextEditingController();
  String _selectedDepartment = 'All Departments';
  List<Map<String, String>> _filteredReps = [];
  late List<Map<String, String>> _allReps;
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _allReps = _generateReps();
    _filteredReps = List.from(_allReps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Generates unique realistic-looking student names and details
  static List<Map<String, String>> _generateReps() {
    final depts = {
      'CS': 'Computer Science',
      'ECE': 'Electronics',
      'ME': 'Mechanical',
      'CE': 'Civil',
      'AD': 'Administrative',
    };

    final maleFirst = [
      'Arjun',
      'Rahul',
      'Vineet',
      'Sandeep',
      'Karthik',
      'Akhil',
      'Manav',
      'Rohit',
      'Anil',
      'Deepak',
    ];
    final femaleFirst = [
      'Anjali',
      'Priya',
      'Riya',
      'Neha',
      'Sana',
      'Pooja',
      'Isha',
      'Meera',
      'Divya',
      'Kavya',
    ];
    final surnames = [
      'Nair',
      'Menon',
      'Thomas',
      'Kumar',
      'Varma',
      'Reddy',
      'Sharma',
      'Patel',
      'Singh',
      'Joseph',
    ];

    final out = <Map<String, String>>[];
    var counter = 1001; // starting KTU id suffix for uniqueness

    for (final entry in depts.entries) {
      final abbr = entry.key;
      final deptName = entry.value;
      for (var year = 1; year <= 4; year++) {
        // Boy representative
        final maleIdx = (counter + year) % maleFirst.length;
        final surnameIdx = (counter + year) % surnames.length;
        final maleName = '${maleFirst[maleIdx]} ${surnames[surnameIdx]}';
        out.add({
          'name': maleName,
          'ktuid': 'KTU-$counter',
          'department': deptName,
          'room': '${abbr.toLowerCase()}${year}01',
          'year': '$year',
          'gender': 'Male',
        });
        counter++;

        // Girl representative
        final femaleIdx = (counter + year) % femaleFirst.length;
        final surnameIdx2 = (counter + year) % surnames.length;
        final femaleName = '${femaleFirst[femaleIdx]} ${surnames[surnameIdx2]}';
        out.add({
          'name': femaleName,
          'ktuid': 'KTU-$counter',
          'department': deptName,
          'room': '${abbr.toLowerCase()}${year}02',
          'year': '$year',
          'gender': 'Female',
        });
        counter++;
      }
    }
    return out;
  }

  void _filterData() {
    setState(() {
      _filteredReps = _allReps.where((rep) {
        final matchesSearch = _searchController.text.isEmpty ||
            rep['name']!.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            rep['ktuid']!.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            rep['room']!.toLowerCase().contains(_searchController.text.toLowerCase());
        
        final matchesDepartment = _selectedDepartment == 'All Departments' ||
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
          comparison = a['name']!.compareTo(b['name']!);
          break;
        case 'ktuid':
          comparison = a['ktuid']!.compareTo(b['ktuid']!);
          break;
        case 'department':
          comparison = a['department']!.compareTo(b['department']!);
          break;
        case 'year':
          comparison = int.parse(a['year']!).compareTo(int.parse(b['year']!));
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  void _exportData() {
    final headers = ['Name', 'KTU ID', 'Department', 'Room No', 'Year', 'Gender'];
    final rows = _filteredReps
        .map((r) => [
              r['name'] ?? '',
              r['ktuid'] ?? '',
              r['department'] ?? '',
              r['room'] ?? '',
              r['year'] ?? '',
              r['gender'] ?? '',
            ])
        .toList();

    exportTablePdfAutoSave(
      'Class Representatives',
      headers,
      rows,
      subtitle: 'Exported ${_filteredReps.length} reps · ${DateTime.now()}',
    ).then((savedPath) {
      final msg = savedPath != null
          ? 'Saved PDF to: $savedPath'
          : 'PDF ready – choose location in Save/Share';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Representatives'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.surfaceContainerLowest, scheme.surfaceContainerHigh],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Card(
                      elevation: 0,
                      color: scheme.secondaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                          Icon(Icons.school, color: scheme.onSecondaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Class Representatives Directory', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer)),
                                Text('Browse class reps by department and year', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer.withOpacity(0.85))),
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
                                builder: (context) => AlertDialog(
                                  title: const Text('Sort Options'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
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
                                        title: const Text('KTU ID'),
                                        value: 'ktuid',
                                        groupValue: _sortBy,
                                        onChanged: (value) {
                                          setState(() {
                                            _sortBy = value!;
                                          });
                                        },
                                      ),
                                      RadioListTile<String>(
                                        title: const Text('Department'),
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
                                        title: const Text('Ascending'),
                                        value: _sortAscending,
                                        onChanged: (value) {
                                          setState(() {
                                            _sortAscending = value;
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    hintText: 'Search reps by name, KTU ID or room',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: _selectedDepartment,
                                items: const [
                                  DropdownMenuItem(value: 'All Departments', child: Text('All Departments')),
                                  DropdownMenuItem(value: 'Computer Science', child: Text('Computer Science')),
                                  DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
                                  DropdownMenuItem(value: 'Mechanical', child: Text('Mechanical')),
                                  DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                                  DropdownMenuItem(value: 'Administrative', child: Text('Administrative')),
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
                                DataColumn(label: Text('Name', style: theme.textTheme.titleMedium)),
                                DataColumn(label: Text('KTU ID', style: theme.textTheme.titleMedium)),
                                DataColumn(label: Text('Department', style: theme.textTheme.titleMedium)),
                                DataColumn(label: Text('Room No', style: theme.textTheme.titleMedium)),
                                DataColumn(label: Text('Year', style: theme.textTheme.titleMedium)),
                                DataColumn(label: Text('Gender', style: theme.textTheme.titleMedium)),
                              ],
                              rows: _filteredReps.map((r) {
                                return DataRow(cells: [
                                  DataCell(Text(r['name']!)),
                                  DataCell(Text(r['ktuid']!)),
                                  DataCell(Text(r['department']!)),
                                  DataCell(Text(r['room']!)),
                                  DataCell(Text(r['year']!)),
                                  DataCell(Text(r['gender']!)),
                                ]);
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
                      Expanded(child: _UserStatsCard(title: 'Total Representatives', value: '${_filteredReps.length}', icon: Icons.groups, color: Colors.blue.shade600)),
                      const SizedBox(width: 12),
                      Expanded(child: _UserStatsCard(title: 'Filtered Results', value: '${_filteredReps.length}/${_allReps.length}', icon: Icons.new_releases, color: Colors.orange.shade600)),
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
  final _passwordCtl = TextEditingController();
  final _admissionCtl = TextEditingController();

  String _role = 'Student';
  String _department = 'CSE';
  String _year = '2';
  String _semester = 'S3';
  String _classGroup = 'CSE - A';

  static const roles = [
    'Student',
    'Class Representative',
    'Coordinator',
    'Administrator',
  ];
  static const departments = ['CSE', 'ECE', 'ME', 'CE', 'AD'];

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _passwordCtl.dispose();
    _admissionCtl.dispose();
    super.dispose();
  }

  void _submit() {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created ${user['role']}: ${user['name']}')),
    );
    Navigator.of(context).pop(user);
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
                    validator:
                        (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'rahul.krishnan@geci.ac.in',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator:
                        (v) =>
                            (v ?? '').contains('@')
                                ? null
                                : 'Enter valid email',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      hintText: '9876543210',
                    ),
                    keyboardType: TextInputType.phone,
                    validator:
                        (v) =>
                            (v ?? '').trim().length >= 10
                                ? null
                                : 'Enter phone',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtl,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Cr@12345',
                    ),
                    obscureText: true,
                    validator:
                        (v) => (v ?? '').length >= 6 ? null : 'Min 6 chars',
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

                  // Extra fields shown only when Role == Class Representative
                  if (_role == 'Class Representative') ...[
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
                        labelText: 'Admission No',
                        hintText: '9316',
                      ),
                      validator:
                          (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
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