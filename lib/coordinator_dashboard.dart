import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';
import 'package:energia/models/room_data_simulator.dart';
import 'package:energia/models/user_role_model.dart';
import 'package:energia/services/department_customization_service.dart';
import 'package:energia/widgets/department_dashboard_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'role_selection_page.dart';

class CoordinatorDashboardPage extends StatefulWidget {
  final EnhancedUser? user; // Accept user object with department info

  const CoordinatorDashboardPage({super.key, this.user});

  @override
  State<CoordinatorDashboardPage> createState() =>
      _CoordinatorDashboardPageState();
}

class _CoordinatorDashboardPageState extends State<CoordinatorDashboardPage> {
  int _currentIndex = 0;
  String _firstDropdownValue = 'all';
  String _secondDropdownValue = '';
  String _thirdDropdownValue = ''; // For floorwise third dropdown
  bool _loadingData = true;
  Map<String, dynamic>? _sensorData;
  List<Map<String, dynamic>>? _timeSeriesData;
  List<Map<String, dynamic>> _secondDropdownOptions = [];
  List<Map<String, dynamic>> _thirdDropdownOptions =
      []; // For floorwise third dropdown
  Timer? _dataRefreshTimer;
  EnhancedUser? _currentUser;
  late DepartmentCustomizationService _customizationService;
  List<String> _accessibleRooms = [];

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
    _dataRefreshTimer?.cancel();
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
      // Determine which room to load data for
      String roomIdToLoad =
          _firstDropdownValue == 'floorwise'
              ? _thirdDropdownValue
              : _secondDropdownValue;

      // Check if the selected room has real database data
      if (RoomDataSimulator.hasRealDatabaseData(roomIdToLoad)) {
        final deviceId = RoomDataSimulator.getDeviceId(roomIdToLoad);
        await _fetchFromDatabase(deviceId: deviceId);
      } else {
        // For simulated rooms, try database first, then fall back to simulation
        try {
          final resp = await http
              .get(Uri.parse('$baseUrl/auth/api/sensor-data?limit=60'), headers: {'Content-Type': 'application/json'})
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

  Future<void> _fetchFromDatabase({String? deviceId}) async {
    const apiCandidates = [
      'http://10.0.2.2:5000',
      'http://192.168.160.1:5000',
      'http://localhost:5000',
      'http://127.0.0.1:5000',
    ];

    for (final baseUrl in apiCandidates) {
      try {
        // Build query with device_id if provided
        final queryString =
            deviceId != null
                ? '/api/sensor-data?device_id=$deviceId&limit=24'
                : '/api/sensor-data?limit=24';

        final resp = await http
            .get(
              Uri.parse('$baseUrl$queryString'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final readings = data['data'] as List? ?? [];
          if (readings.isNotEmpty) {
            _sensorData = readings.first as Map<String, dynamic>;
            _timeSeriesData = List<Map<String, dynamic>>.from(
              readings.whereType<Map<String, dynamic>>(),
            );
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }

    throw Exception('Database connection failed');
  }

  void _generateSimulatedData(String roomId) {
    _sensorData = RoomDataSimulator.generateSensorData(roomId);
    _timeSeriesData = RoomDataSimulator.generateTimeSeriesData(roomId, 24);
  }

  void _performLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If user is loaded, use department-themed dashboard
    if (_currentUser != null) {
      final departmentTheme = _customizationService.getDepartmentTheme(_currentUser!.department);
      return Theme(
        data: departmentTheme,
        child: _buildDepartmentDashboard(departmentTheme.colorScheme),
      );
    }
    
    // Fallback to default theme if user not loaded
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardScaffold(
      title: '🏢 ENERGIA Dashboard',
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
        return _CoordinatorOverviewPage(
          scheme: scheme,
          firstDropdownValue: _firstDropdownValue,
          secondDropdownValue: _secondDropdownValue,
          thirdDropdownValue: _thirdDropdownValue,
          secondDropdownOptions: _secondDropdownOptions,
          thirdDropdownOptions: _thirdDropdownOptions,
          onFirstDropdownChanged: _onFirstDropdownChanged,
          onSecondDropdownChanged: _onSecondDropdownChanged,
          onThirdDropdownChanged: _onThirdDropdownChanged,
          sensorData: _sensorData,
          timeSeriesData: _timeSeriesData,
          loadingData: _loadingData,
        );
      case 1:
        return const _DepartmentRoomsSection();
      case 2:
        return const _DepartmentAnalyticsSection();
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
}

// OVERVIEW PAGE WITH DYNAMIC DROPDOWNS
class _CoordinatorOverviewPage extends StatelessWidget {
  final ColorScheme scheme;
  final String firstDropdownValue;
  final String secondDropdownValue;
  final String thirdDropdownValue;
  final List<Map<String, dynamic>> secondDropdownOptions;
  final List<Map<String, dynamic>> thirdDropdownOptions;
  final Function(String?) onFirstDropdownChanged;
  final Function(String?) onSecondDropdownChanged;
  final Function(String?) onThirdDropdownChanged;
  final Map<String, dynamic>? sensorData;
  final List<Map<String, dynamic>>? timeSeriesData;
  final bool loadingData;

  const _CoordinatorOverviewPage({
    required this.scheme,
    required this.firstDropdownValue,
    required this.secondDropdownValue,
    required this.thirdDropdownValue,
    required this.secondDropdownOptions,
    required this.thirdDropdownOptions,
    required this.onFirstDropdownChanged,
    required this.onSecondDropdownChanged,
    required this.onThirdDropdownChanged,
    required this.sensorData,
    required this.timeSeriesData,
    required this.loadingData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
   
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // WELCOME SECTION
        TweenAnimationBuilder<Offset>(
          duration: const Duration(milliseconds: 1000),
          tween: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: const Offset(0.0, 0.0),
          ),
          builder: (context, offset, child) {
            return SlideTransition(
              position: AlwaysStoppedAnimation<Offset>(offset),
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
                  border: Border.all(
                    color: scheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
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
                                'Welcome, Department Leader!',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'CS Department Energy Coordinator',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: scheme.onPrimaryContainer.withOpacity(
                                    0.8,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Orchestrating efficiency across multiple rooms • Leading sustainability',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: scheme.onPrimaryContainer.withOpacity(
                                    0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Your leadership drives campus-wide energy transformation',
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

        const SizedBox(height: 32),

        // FILTER SECTION
        Text(
          'Room Selection & Filtering',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                firstDropdownValue == 'floorwise'
                    ? Row(
                      children: [
                        // First dropdown: Filter Type
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter Type',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                value: firstDropdownValue,
                                isExpanded: true,
                                isDense: true,
                                onChanged: onFirstDropdownChanged,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'floorwise',
                                    child: Text('Floor-wise'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'classwise',
                                    child: Text('Class-wise'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All Rooms'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'others',
                                    child: Text('Labs & Staff Rooms'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Second dropdown: Floor selection
                        if (secondDropdownOptions.isNotEmpty)
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Floor',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButton<String>(
                                  value: secondDropdownValue,
                                  isExpanded: true,
                                  isDense: true,
                                  onChanged: onSecondDropdownChanged,
                                  items:
                                      secondDropdownOptions.map((option) {
                                        return DropdownMenuItem(
                                          value: option['id'] as String,
                                          child: Text(option['name'] as String),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 16),

                        // Third dropdown: Room/Class selection
                        if (thirdDropdownOptions.isNotEmpty)
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Room',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButton<String>(
                                  value: thirdDropdownValue,
                                  isExpanded: true,
                                  isDense: true,
                                  onChanged: onThirdDropdownChanged,
                                  items:
                                      thirdDropdownOptions.map((option) {
                                        return DropdownMenuItem(
                                          value: option['id'] as String,
                                          child: Text(option['name'] as String),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filter Type',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<String>(
                                value: firstDropdownValue,
                                isExpanded: true,
                                isDense: true,
                                onChanged: onFirstDropdownChanged,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'floorwise',
                                    child: Text('Floor-wise'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'classwise',
                                    child: Text('Class-wise'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('All Rooms'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'others',
                                    child: Text('Labs & Staff Rooms'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        if (secondDropdownOptions.isNotEmpty)
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _getSecondDropdownLabel(),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (RoomDataSimulator.hasRealDatabaseData(
                                      secondDropdownValue,
                                    ))
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          border: Border.all(
                                            color: Colors.green,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.storage,
                                              size: 14,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Live DB',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                DropdownButton<String>(
                                  value: secondDropdownValue,
                                  isExpanded: true,
                                  isDense: true,
                                  onChanged: onSecondDropdownChanged,
                                  items:
                                      secondDropdownOptions.map((option) {
                                        return DropdownMenuItem(
                                          value: option['id'] as String,
                                          child: Text(option['name'] as String),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
          ),
        ),

        const SizedBox(height: 32),

        // ENERGY METRICS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Real-Time Energy Metrics',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showThresholdSettingsDialog(context, theme),
              icon: const Icon(Icons.settings),
              label: const Text('Room Threshold Settings'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (loadingData)
          Center(
            child: Column(
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
            ),
          )
        else if (sensorData != null)
          _buildEnergyMetricsGrid(context, theme),

        const SizedBox(height: 32),

        // TIME SERIES GRAPHS
        if (!loadingData &&
            timeSeriesData != null &&
            timeSeriesData!.isNotEmpty)
          _buildTimeSeriesGraphs(context, theme),

        const SizedBox(height: 32),
      ],
    );
  }

  String _getSecondDropdownLabel() {
    switch (firstDropdownValue) {
      case 'floorwise':
        return 'Select Floor';
      case 'classwise':
        return 'Select Class';
      case 'all':
        return 'Select Room';
      case 'others':
        return 'Select Lab or Staff Room';
      default:
        return 'Select Item';
    }
  }

  Widget _buildEnergyMetricsGrid(BuildContext context, ThemeData theme) {
    if (sensorData == null) return const SizedBox.shrink();

    final voltage = sensorData!['voltage'] ?? 0.0;
    final current = sensorData!['current'] ?? 0.0;
    final power = sensorData!['power'] ?? 0.0;
    final energy = sensorData!['energy'] ?? 0.0;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildMetricCard(
          context,
          'Voltage',
          voltage.toStringAsFixed(1),
          'V',
          Icons.flash_on,
          Colors.blue,
        ),
        _buildMetricCard(
          context,
          'Current',
          current.toStringAsFixed(2),
          'A',
          Icons.electrical_services,
          Colors.orange,
        ),
        _buildMetricCard(
          context,
          'Power',
          power.toStringAsFixed(2),
          'kW',
          Icons.power_settings_new,
          Colors.red,
        ),
        _buildMetricCard(
          context,
          'Energy Consumed',
          energy.toStringAsFixed(2),
          'kWh',
          Icons.energy_savings_leaf,
          Colors.green,
        ),
      ],
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
  //final cardWidth = (MediaQuery.of(context).size.width / 2) - 24;
 final cardWidth = MediaQuery.of(context).size.width - 70;
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

  Widget _buildTimeSeriesGraphs(BuildContext context, ThemeData theme) {
    if (timeSeriesData == null || timeSeriesData!.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<FlSpot> powerSpots = [];
    final List<FlSpot> currentSpots = [];
    final List<FlSpot> energySpots = [];
    final List<FlSpot> voltageSpots = [];
    final List<String> dateLabels = [];
    final List<DateTime> timestamps = [];

    for (int i = 0; i < timeSeriesData!.length; i++) {
      final data = timeSeriesData![i];
      powerSpots.add(
        FlSpot(i.toDouble(), (data['power'] as num?)?.toDouble() ?? 0.0),
      );
      currentSpots.add(
        FlSpot(i.toDouble(), (data['current'] as num?)?.toDouble() ?? 0.0),
      );
      energySpots.add(
        FlSpot(i.toDouble(), (data['energy'] as num?)?.toDouble() ?? 0.0),
      );
      voltageSpots.add(
        FlSpot(i.toDouble(), (data['voltage'] as num?)?.toDouble() ?? 0.0),
      );
      // Extract date and time from timestamp
      if (data['timestamp'] != null) {
        final date = DateTime.parse(data['timestamp'].toString());
        timestamps.add(date);
        dateLabels.add(
          '${date.day}/${date.month}\n${date.hour}:${date.minute.toString().padLeft(2, '0')}',
        );
      } else {
        timestamps.add(
          DateTime.now().subtract(Duration(hours: timeSeriesData!.length - i)),
        );
        dateLabels.add('${i}h');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Energy Usage Over Time',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildGraph(
          'Voltage (V)',
          voltageSpots,
          Colors.blue,
          theme,
          dateLabels,
        ),
        const SizedBox(height: 16),
        _buildGraph(
          'Power Consumption (kW)',
          powerSpots,
          Colors.red,
          theme,
          dateLabels,
        ),
        const SizedBox(height: 16),
        _buildGraph(
          'Current Draw (A)',
          currentSpots,
          Colors.orange,
          theme,
          dateLabels,
        ),
        const SizedBox(height: 16),
        _buildGraph(
          'Energy Consumed (kWh)',
          energySpots,
          Colors.green,
          theme,
          dateLabels,
        ),
      ],
    );
  }

  Widget _buildGraph(
    String title,
    List<FlSpot> spots,
    Color color,
    ThemeData theme,
    List<String> dateLabels,
  ) {
    // Calculate width: each data point gets 100px of space (increased from 60px)
    final chartWidth = (spots.length * 100).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: 350,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall,
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 70,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < dateLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  dateLabels[index],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: color,
                              strokeWidth: 0,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThresholdSettingsDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return ThresholdSettingsDialog(theme: theme, scheme: scheme);
      },
    );
  }
}

class _DepartmentRoomsSection extends StatelessWidget {
  const _DepartmentRoomsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text('Rooms Section', style: theme.textTheme.headlineSmall),
    );
  }
}

class _DepartmentAnalyticsSection extends StatelessWidget {
  const _DepartmentAnalyticsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text('Analytics Section', style: theme.textTheme.headlineSmall),
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

// THRESHOLD SETTINGS DIALOG
class ThresholdSettingsDialog extends StatefulWidget {
  final ThemeData theme;
  final ColorScheme scheme;

  const ThresholdSettingsDialog({
    required this.theme,
    required this.scheme,
    super.key,
  });

  @override
  State<ThresholdSettingsDialog> createState() =>
      _ThresholdSettingsDialogState();
}

class _ThresholdSettingsDialogState extends State<ThresholdSettingsDialog> {
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  Map<String, TextEditingController> _thresholdControllers = {};
  bool _loading = true;
  String? _editingRoomId;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_filterRooms);
    _loadRooms();
  }

  @override
  void dispose() {
    for (var controller in _thresholdControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _loading = true;
    });

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
              .get(
                Uri.parse('$baseUrl/api/rooms'),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(const Duration(seconds: 6));

          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            final rooms = data['data'] as List? ?? [];
            setState(() {
              _rooms = List<Map<String, dynamic>>.from(
                rooms.whereType<Map<String, dynamic>>(),
              );
              _filteredRooms = List.from(_rooms);
              // Initialize controllers for each room
              for (var room in _rooms) {
                _thresholdControllers[room['room_id']] = TextEditingController(
                  text: (room['threshold'] ?? 0.0).toString(),
                );
              }
              _loading = false;
            });
            return;
          }
        } catch (_) {
          continue;
        }
      }

      // If we reach here, all attempts failed
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load rooms')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  double _calculateFuzzyScore(String query, String text) {
    if (query.isEmpty) return 1.0;

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();

    // Exact match is best
    if (textLower == queryLower) return 1.0;

    // Contains match is good
    if (textLower.contains(queryLower)) {
      return 0.9;
    }

    // Character-by-character fuzzy matching
    int matches = 0;
    int queryIndex = 0;

    for (
      int i = 0;
      i < textLower.length && queryIndex < queryLower.length;
      i++
    ) {
      if (textLower[i] == queryLower[queryIndex]) {
        matches++;
        queryIndex++;
      }
    }

    if (queryIndex < queryLower.length)
      return 0.0; // Not all query chars matched

    return matches / queryLower.length;
  }

  void _filterRooms() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _filteredRooms = List.from(_rooms);
      });
      return;
    }

    final filtered =
        _rooms.where((room) {
          final roomName = room['room_name']?.toString() ?? '';
          final roomId = room['room_id']?.toString() ?? '';
          final floorNum = room['floor_number']?.toString() ?? '';

          final nameScore = _calculateFuzzyScore(query, roomName);
          final idScore = _calculateFuzzyScore(query, roomId);
          final floorScore = _calculateFuzzyScore(query, floorNum);

          return nameScore > 0 || idScore > 0 || floorScore > 0;
        }).toList();

    setState(() {
      _filteredRooms = filtered;
    });
  }

  Future<void> _updateThreshold(
    String roomId,
    String roomName,
    double newThreshold,
  ) async {
    try {
      const apiCandidates = [
        'http://10.0.2.2:5000',
        'http://192.168.160.1:5000',
        'http://localhost:5000',
        'http://127.0.0.1:5000',
      ];

      for (final baseUrl in apiCandidates) {
        try {
          final encodedRoomId = Uri.encodeComponent(roomId);
          final resp = await http
              .put(
                Uri.parse(
                  '$baseUrl/api/rooms/$encodedRoomId/threshold?threshold=$newThreshold',
                ),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(const Duration(seconds: 6));

          if (resp.statusCode == 200) {
            setState(() {
              _editingRoomId = null;
              // Update the rooms list with new threshold
              final index = _rooms.indexWhere((r) => r['room_id'] == roomId);
              if (index != -1) {
                _rooms[index]['threshold'] = newThreshold;
              }
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Threshold for $roomName updated successfully'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            return;
          }
        } catch (_) {
          continue;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update threshold')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.scheme.primaryContainer,
                    widget.scheme.primaryContainer.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Room Threshold Settings',
                    style: widget.theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.scheme.onPrimaryContainer,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Bar
            if (!_loading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search rooms by name, ID, or floor...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterRooms();
                              },
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: widget.scheme.surfaceContainer,
                  ),
                ),
              ),

            // Content
            Expanded(
              child:
                  _loading
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Loading rooms...',
                              style: widget.theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                      : _rooms.isEmpty
                      ? Center(
                        child: Text(
                          'No rooms available',
                          style: widget.theme.textTheme.bodyLarge,
                        ),
                      )
                      : _filteredRooms.isEmpty
                      ? Center(
                        child: Text(
                          'No rooms match your search',
                          style: widget.theme.textTheme.bodyLarge,
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredRooms.length,
                        itemBuilder: (context, index) {
                          final room = _filteredRooms[index];
                          final roomId = room['room_id'];
                          final roomName = room['room_name'];
                          final floorNumber = room['floor_number'];
                          final currentThreshold = room['threshold'];
                          final isEditing = _editingRoomId == roomId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              roomName,
                                              style: widget
                                                  .theme
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Floor ${floorNumber.toString()}',
                                              style: widget
                                                  .theme
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        widget.scheme.outline,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isEditing)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _editingRoomId = roomId;
                                            });
                                          },
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Edit'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (isEditing)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current Threshold: ${currentThreshold.toString()} kW',
                                          style:
                                              widget.theme.textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller:
                                              _thresholdControllers[roomId]!,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Enter new threshold (kW)',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            suffixText: 'kW',
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _editingRoomId = null;
                                                  _thresholdControllers[roomId]
                                                      ?.text = currentThreshold
                                                          .toString();
                                                });
                                              },
                                              child: const Text('Cancel'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () {
                                                final newThreshold =
                                                    double.tryParse(
                                                      _thresholdControllers[roomId]!
                                                          .text,
                                                    );
                                                if (newThreshold != null &&
                                                    newThreshold > 0) {
                                                  _updateThreshold(
                                                    roomId,
                                                    roomName,
                                                    newThreshold,
                                                  );
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Please enter a valid threshold value',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      'Current Threshold: ${currentThreshold.toString()} kW',
                                      style: widget.theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: widget.scheme.outlineVariant),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
