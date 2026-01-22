import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';
import 'services/notifier.dart'; // Added import for notifier
import 'package:energia/widgets/energy_visualization_widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';

// Assuming Analysis is in graph_adm.dart and Anomaly is in anomaly_adm.dart
import 'graph_adm.dart'; 
import 'anomaly_adm.dart'; 
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
  double _latestPower = 0;
  double _livePeak = 0;
  List<FlSpot> _liveSeries = [];
  bool _liveLoading = true;
  Timer? _liveTimer;
  List<dynamic> _anomalies = []; // Added for AI alerts
  bool _isLoadingAnomalies = false;
  // FETCH METHOD: Call this to get data from your FastAPI backend
  Future<void> _fetchAnomalyAlerts() async {
    setState(() => _isLoadingAnomalies = true);
    try {
      // Ensure the URL matches your backend address
      final response = await http.get(Uri.parse('http://127.0.0.1:5000/auth/anomalies'));
      if (response.statusCode == 200) {
        setState(() {
          _anomalies = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching anomalies: $e");
    } finally {
      setState(() => _isLoadingAnomalies = false);
    }
  }

// 1. COMBINED INITSTATE (Fixes error G351DE6FA)
  @override
  void initState() {
    super.initState();
    
    // Load initial data
    _loadLiveData(); 
    _fetchAnomalyAlerts(); 
    
    // Setup the periodic timer for live updates
    _liveTimer = Timer.periodic(const Duration(minutes: 1), (_) => _loadLiveData());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  // Dynamic active rooms tracking
  final List<Map<String, dynamic>> _allRooms = [
    {'room': 'CS-404', 'status': 'Normal', 'usage': '5.2 kW', 'isActive': true},
    {'room': 'CS-Lab 1', 'status': 'High Usage', 'usage': '8.6 kW', 'isActive': true},
    {'room': 'CS-Lab 2', 'status': 'Moderate', 'usage': '3.4 kW', 'isActive': true},
    {'room': 'Server Room', 'status': 'Critical System', 'usage': '4.5 kW', 'isActive': true},
    {'room': 'CS-Faculty Room', 'status': 'Low Usage', 'usage': '5.2 kW', 'isActive': true},
    {'room': 'CS-Seminar Hall', 'status': 'Offline', 'usage': '0.0 kW', 'isActive': false},
    {'room': 'CS-405', 'status': 'Offline', 'usage': '0.0 kW', 'isActive': false},
    {'room': 'CS-Lab 3', 'status': 'Offline', 'usage': '0.0 kW', 'isActive': false},
    {'room': 'CS-Study Area', 'status': 'Offline', 'usage': '0.0 kW', 'isActive': false},
    {'room': 'CS-Conference', 'status': 'Offline', 'usage': '0.0 kW', 'isActive': false},
    {'room': 'CS-406', 'status': 'Offline', 'usage': '0.0 kW', 'isActive': false},
    {'room': 'CS-Library', 'status': 'Offline', 'usage': '0.0 kW', 'isActive': false},
  ];

Widget _buildAnomalyTab() {
  return _DepartmentAlertsSection(
    anomalies: _anomalies, 
    onRefresh: _fetchAnomalyAlerts,
  );
}
  Future<void> _loadLiveData() async {
    try {
      const apiCandidates = [
        'http://10.0.2.2:5000',
        'http://192.168.160.1:5000',
        'http://localhost:5000',
        'http://127.0.0.1:5000',
      ];

      for (final baseUrl in apiCandidates) {
        try {
          final resp = await http
              .get(Uri.parse('$baseUrl/api/sensor-data?limit=60'), headers: {'Content-Type': 'application/json'})
              .timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            final readings = data['data'] as List? ?? [];
            if (readings.isEmpty) continue;

            double peak = 0;
            final List<FlSpot> spots = [];
            for (int i = 0; i < readings.length; i++) {
              final r = readings[i];
              final p = (r['power'] as num?)?.toDouble() ?? (r['value'] as num?)?.toDouble() ?? 0;
              peak = max(peak, p);
              spots.add(FlSpot(i.toDouble(), p));
            }

            final latest = (readings.first['power'] as num?)?.toDouble() ??
                (readings.first['value'] as num?)?.toDouble() ?? 0;

            if (mounted) {
              setState(() {
                _latestPower = latest;
                _livePeak = peak;
                _liveSeries = spots;
                _liveLoading = false;
              });
            }
            return;
          }
        } catch (_) {
          continue;
        }
      }
      if (mounted) setState(() => _liveLoading = false);
    } catch (_) {
      if (mounted) setState(() => _liveLoading = false);
    }
  }

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
        if (index == 4) {
           _performLogout();
        } else {
           setState(() {
             _currentIndex = index;
           });
           // --- NEW: Auto-refresh data when the user enters the Alerts tab ---
           if (index == 3) {
             _fetchAnomalyAlerts();
           }
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
        return _DepartmentOverviewSection(
          scheme: scheme, 
          onActiveRoomsTap: _showActiveRooms, 
          onAlertsTap: _showAlerts,
          activeRooms: _allRooms.where((room) => room['isActive'] as bool).toList(),
          totalRooms: _allRooms.length,
          onActivateRoom: _activateRandomRoom,
          latestPower: _latestPower,
          livePeak: _livePeak,
          liveSeries: _liveSeries,
          liveLoading: _liveLoading,
        );
      case 1:
        return _DepartmentRoomsSection(scheme: scheme, rooms: _allRooms);
      case 2:
        return _DepartmentAnalyticsSection(scheme: scheme);
      case 3:
        // --- UPDATED: Pass the AI anomalies and refresh logic here ---
        return _DepartmentAlertsSection(
          anomalies: _anomalies, 
          onRefresh: _fetchAnomalyAlerts,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showActiveRooms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Rooms'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allRooms.where((room) => room['isActive'] as bool).length,
            itemBuilder: (context, index) {
              final room = _allRooms.where((room) => room['isActive'] as bool).toList()[index];
              return ListTile(
                leading: Icon(Icons.room, color: Colors.blue),
                title: Text(room['room'] as String),
                subtitle: Text('${room['status']} • ${room['usage']}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAlerts() {
    // Hardcoded alerts for demonstration
    final alerts = [
      {'room': 'CS-Lab 1', 'type': 'High Consumption', 'message': 'Energy usage exceeded 8 kW threshold', 'time': '2 hours ago', 'severity': 'High'},
      {'room': 'CS-404', 'type': 'Anomaly Detected', 'message': 'Unusual power spike detected', 'time': '4 hours ago', 'severity': 'Medium'},
      {'room': 'Server Room', 'type': 'Temperature Alert', 'message': 'Room temperature above safe limit', 'time': '6 hours ago', 'severity': 'High'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active Alerts'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              Color severityColor;
              switch (alert['severity']) {
                case 'High':
                  severityColor = Colors.red;
                  break;
                case 'Medium':
                  severityColor = Colors.orange;
                  break;
                default:
                  severityColor = Colors.yellow;
              }
              return ListTile(
                leading: Icon(Icons.warning, color: severityColor),
                title: Text('${alert['room']} - ${alert['type']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert['message'] as String),
                    Text(alert['time'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _activateRandomRoom() {
    setState(() {
      // Find inactive rooms
      final inactiveRooms = _allRooms.where((room) => !(room['isActive'] as bool)).toList();
      if (inactiveRooms.isNotEmpty) {
        // Activate a random inactive room
        final randomRoom = inactiveRooms[DateTime.now().millisecondsSinceEpoch % inactiveRooms.length];
        randomRoom['isActive'] = true;
        randomRoom['status'] = 'Normal'; // Set a default status
        randomRoom['usage'] = '${(DateTime.now().millisecondsSinceEpoch % 5 + 1)}.${DateTime.now().millisecondsSinceEpoch % 9} kW'; // Random usage
      }
    });
  }
}

class _DepartmentOverviewSection extends StatelessWidget {
  final ColorScheme scheme;
  final VoidCallback onActiveRoomsTap;
  final VoidCallback onAlertsTap;
  final List<Map<String, dynamic>> activeRooms;
  final int totalRooms;
  final VoidCallback onActivateRoom;
  final double latestPower;
  final double livePeak;
  final List<FlSpot> liveSeries;
  final bool liveLoading;
  const _DepartmentOverviewSection({
    required this.scheme, 
    required this.onActiveRoomsTap, 
    required this.onAlertsTap,
    required this.activeRooms,
    required this.totalRooms,
    required this.onActivateRoom,
    required this.latestPower,
    required this.livePeak,
    required this.liveSeries,
    required this.liveLoading,
  });

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
        
        // Department Stats - Using proper responsive layout
        Text(
          'Department Overview',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Key Metrics - Horizontal Layout
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              'Total Department Usage',
              '18.4',
              'kW',
              Icons.electric_bolt_outlined,
              Colors.orange,
            ),
            _buildStatCard(
              context,
              'Active Rooms',
              '${activeRooms.length}',
              'of $totalRooms',
              Icons.room_outlined,
              Colors.blue,
            ),
            _buildStatCard(
              context,
              'Department Efficiency',
              '87',
              '%',
              Icons.trending_up_outlined,
              Colors.green,
            ),
            _buildStatCard(
              context,
              'Active Alerts',
              '3',
              'anomalies',
              Icons.warning_outlined,
              Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Active Rooms Section
        Text(
          'Active Rooms',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (activeRooms.isNotEmpty)
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: activeRooms.length,
              itemBuilder: (context, index) {
                final room = activeRooms[index];
                return Padding(
                  padding: EdgeInsets.only(right: index < activeRooms.length - 1 ? 16 : 0),
                  child: _buildActiveRoomCard(context, room, theme, scheme),
                );
              },
            ),
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No active rooms',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ),
          ),
        const SizedBox(height: 32),
        
        // Live energy meters and charts (responsive grid)
        Text(
          'Top Energy Consumers',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1100;
            final cardWidth = isWide ? (constraints.maxWidth - 32) / 2 : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: LiveEnergyMeter(
                    currentPower: latestPower,
                    maxCapacity: 10.0,
                    label: 'CS-Lab 1',
                    status: liveLoading ? 'Loading...' : (latestPower > 0 ? 'Active Usage' : 'Idle'),
                    showTrend: true,
                    trendPercentage: latestPower > 5 ? 5 : -2,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: LiveEnergyMeter(
                    currentPower: latestPower,
                    maxCapacity: 8.0,
                    label: 'Server Room',
                    status: liveLoading ? 'Loading...' : (latestPower > 0 ? 'Active Usage' : 'Idle'),
                    showTrend: true,
                    trendPercentage: latestPower > 5 ? 5 : -2,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: EnergyDistributionDonut(
                    labels: const ['AC Systems', 'Lighting', 'Lab Equipment', 'Server', 'Other'],
                    values: const [32.5, 18.3, 28.7, 15.2, 5.3],
                    title: 'Department Energy Distribution',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: ComparativeBarChart(
                    labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                    values: const [156.2, 162.4, 158.9, 171.3, 165.8, 98.4, 102.6],
                    title: 'Weekly Department Usage (kWh)',
                    unit: 'kWh',
                    maxY: 180.0,
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Department Energy Flow (Last 24 Hours)',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      ResponsiveLineChart(
                        spots: liveSeries.isNotEmpty
                            ? liveSeries
                            : [
                                const FlSpot(0, 8.5), const FlSpot(1, 9.2), const FlSpot(2, 8.8), const FlSpot(3, 12.5),
                                const FlSpot(4, 15.2), const FlSpot(5, 18.4), const FlSpot(6, 19.5), const FlSpot(7, 17.8),
                                const FlSpot(8, 16.2), const FlSpot(9, 14.5), const FlSpot(10, 13.2), const FlSpot(11, 12.8),
                                const FlSpot(12, 14.5), const FlSpot(13, 15.8), const FlSpot(14, 16.2), const FlSpot(15, 17.1),
                                const FlSpot(16, 18.4), const FlSpot(17, 16.9), const FlSpot(18, 15.3), const FlSpot(19, 13.5),
                                const FlSpot(20, 12.2), const FlSpot(21, 10.8), const FlSpot(22, 9.5), const FlSpot(23, 8.8),
                              ],
                        title: liveSeries.isNotEmpty ? 'Department Load Profile (live)' : 'Department Load Profile',
                        unit: 'kW',
                        maxY: (livePeak * 1.2).clamp(10.0, 25.0),
                        isMonthly: false,
                        lineColor: EnergyColorScheme.infoTeal,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        
        // Action Buttons
        Center(
          child: ElevatedButton.icon(
            onPressed: onActivateRoom,
            icon: const Icon(Icons.power),
            label: const Text('Simulate Room Activation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActiveRoomCard(BuildContext context, Map<String, dynamic> room, ThemeData theme, ColorScheme scheme) {
    Color statusColor;
    switch (room['status']) {
      case 'Normal':
        statusColor = Colors.green;
        break;
      case 'High Usage':
        statusColor = Colors.red;
        break;
      case 'Moderate':
        statusColor = Colors.orange;
        break;
      case 'Critical System':
        statusColor = Colors.purple;
        break;
      case 'Low Usage':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        _showActiveRoomDetailsDialog(context, room, theme, statusColor);
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(0.1),
                statusColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Room Number Header
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  room['room'] as String,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  room['status'] as String,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              
              // Usage Display
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    room['usage'] as String,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              
              // Active Indicator
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tap to view details hint
              const SizedBox(height: 8),
              Text(
                'Tap for details',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActiveRoomDetailsDialog(BuildContext context, Map<String, dynamic> room, ThemeData theme, Color statusColor) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(0.05),
                statusColor.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.room,
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room['room'] as String,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Active Room Details',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    splashRadius: 24,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Divider
              Container(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              
              // Details Grid
              _buildDetailRow(theme, 'Room Number', room['room'] as String, Icons.room),
              const SizedBox(height: 16),
              _buildDetailRow(theme, 'Current Status', room['status'] as String, Icons.info_outline, statusColor),
              const SizedBox(height: 16),
              _buildDetailRow(theme, 'Energy Usage', room['usage'] as String, Icons.electric_bolt, Colors.orange),
              const SizedBox(height: 16),
              _buildDetailRow(theme, 'Status', 'ACTIVE', Icons.check_circle, Colors.green),
              const SizedBox(height: 24),
              
              // Divider
              Container(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              
              // Quick Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox(
                      theme,
                      'Uptime',
                      '2h 34m',
                      Icons.timer,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      theme,
                      'Efficiency',
                      '92%',
                      Icons.trending_up,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value, IconData icon, [Color? iconColor]) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
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

Widget _buildStatCard(
  BuildContext context,
  String label,
  String value,
  String unit,
  IconData icon,
  Color color,
) {
  final theme = Theme.of(context);
  
  // Calculate width to fit 2 cards per row in a Wrap, minus spacing
  final cardWidth = (MediaQuery.of(context).size.width / 2) - 24;

  // REMOVED: Expanded widget (Fixes the crash)
  return SizedBox(
    width: cardWidth,
    child: Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.08),
              color.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1, // Reduced to 1 to keep cards aligned
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible( // Added Flexible to prevent overflow of units
                  child: Text(
                    unit,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

class _DepartmentRoomsSection extends StatelessWidget {
  final ColorScheme scheme;
  final List<Map<String, dynamic>> rooms;
  const _DepartmentRoomsSection({required this.scheme, required this.rooms});

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
        ...rooms.map((data) {
          Color statusColor;
          switch (data['status']) {
            case 'Normal':
              statusColor = Colors.green;
              break;
            case 'High Usage':
              statusColor = Colors.red;
              break;
            case 'Moderate':
              statusColor = Colors.orange;
              break;
            case 'Critical System':
              statusColor = Colors.purple;
              break;
            case 'Low Usage':
              statusColor = Colors.blue;
              break;
            case 'Offline':
              statusColor = Colors.grey;
              break;
            default:
              statusColor = Colors.grey;
          }
          return _buildRoomMonitorCard(
            context, 
            data['room'] as String, 
            data['usage'] as String, 
            0.5, // Default load
            statusColor, 
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
          child: _DepartmentRoomsDistributionChart(roomData: rooms.map((room) {
            Color statusColor;
            switch (room['status']) {
              case 'Normal':
                statusColor = Colors.green;
                break;
              case 'High Usage':
                statusColor = Colors.red;
                break;
              case 'Moderate':
                statusColor = Colors.orange;
                break;
              case 'Critical System':
                statusColor = Colors.purple;
                break;
              case 'Low Usage':
                statusColor = Colors.blue;
                break;
              case 'Offline':
                statusColor = Colors.grey;
                break;
              default:
                statusColor = Colors.grey;
            }
            final usageStr = room['usage'] as String;
            final usageKw = double.tryParse(usageStr.split(' ')[0]) ?? 0.0;
            return {
              'room': room['room'],
              'usage_kw': usageKw,
              'color': statusColor,
            };
          }).toList()),
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
            children: [
              Text(
                'Total Live Usage: ${totalUsage.toStringAsFixed(1)} kW',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Make legend scrollable to prevent overflow
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: legendItems,
                  ),
                ),
              ),
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
  final List<dynamic> anomalies;
  final VoidCallback onRefresh;

  const _DepartmentAlertsSection({
    super.key, 
    required this.anomalies, 
    required this.onRefresh
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: anomalies.isEmpty
          ? const Center(child: Text("No anomaly alerts detected."))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: anomalies.length,
              itemBuilder: (context, index) {
                final alert = anomalies[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    ),
                    title: Text(
                      "Anomaly in ${alert['device_id']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Power: ${alert['power']}W | Occupancy: ${alert['occupancy']}\nScore: ${alert['score']}",
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Logic to show alert details or navigate
                      _showAlertDialog(context, alert);
                    },
                  ),
                );
              },
            ),
    );
  }

  void _showAlertDialog(BuildContext context, dynamic alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Alert Detail: ${alert['device_id']}"),
        content: Text("An unusual power consumption of ${alert['power']}W was detected when occupancy was ${alert['occupancy']}.\n\nTimestamp: ${alert['timestamp']}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Dismiss")),
        ],
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
  final VoidCallback? onTap;
  const _DepartmentStatCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});

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
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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