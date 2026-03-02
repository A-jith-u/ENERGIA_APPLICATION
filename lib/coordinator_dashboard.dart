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

  @override
  void initState() {
    super.initState();
    _customizationService = DepartmentCustomizationService();
    _loadUserAndInitialize();
  }

  Future<void> _loadUserAndInitialize() async {
    // Load user from widget or shared preferences
    if (widget.user != null) {
      _currentUser = widget.user;
      _filterRoomsByDepartment();
      _initializeSecondDropdown();
      _loadSensorData();
    } else {
      // Try to load from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson);
          _currentUser = EnhancedUser.fromJson(userData);
          _filterRoomsByDepartment();
          _initializeSecondDropdown();
          _loadSensorData();
        } catch (e) {
          print('Error loading user: $e');
        }
      }
    }
    
    // Start refresh timer
    _dataRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadSensorData(),
    );
  }

  void _filterRoomsByDepartment() {
    if (_currentUser == null) return;
    
    // Get rooms accessible to this department
    _accessibleRooms = _customizationService.getAccessibleRoomsByDepartment(
      _currentUser!.department,
    );
  }

  @override
  void dispose() {
    _dataRefreshTimer?.cancel();
    super.dispose();
  }

  void _initializeSecondDropdown() {
    // Get options based on filter type
    _secondDropdownOptions = RoomDataSimulator.getSecondDropdownOptions(
      _firstDropdownValue,
    );
    
    // Filter by accessible rooms if user is available
    if (_currentUser != null && _accessibleRooms.isNotEmpty) {
      if (_firstDropdownValue == 'all') {
        // Filter to only show accessible rooms
        _secondDropdownOptions = _secondDropdownOptions.where((room) {
          final roomId = room['id'] as String;
          return _accessibleRooms.contains(roomId);
        }).toList();
      } else if (_firstDropdownValue == 'department') {
        // Show only this user's department
        final deptName = departmentNames[_currentUser!.department] ?? '';
        _secondDropdownOptions = _secondDropdownOptions.where((room) {
          final roomLabel = room['label'] as String? ?? '';
          return roomLabel.toLowerCase().contains(deptName.toLowerCase()) ||
                 _accessibleRooms.contains(room['id'] as String);
        }).toList();
      }
    }
    
    if (_secondDropdownOptions.isNotEmpty) {
      _secondDropdownValue = _secondDropdownOptions.first['id'] as String;
      // If floorwise, also initialize third dropdown
      if (_firstDropdownValue == 'floorwise') {
        _initializeThirdDropdown();
      }
    }
  }

  void _initializeThirdDropdown() {
    if (_firstDropdownValue == 'floorwise') {
      _thirdDropdownOptions = RoomDataSimulator.getClassesByFloor(
        _secondDropdownValue,
      );
      if (_thirdDropdownOptions.isNotEmpty) {
        _thirdDropdownValue = _thirdDropdownOptions.first['id'] as String;
      } else {
        _thirdDropdownValue = '';
      }
    }
  }

  void _onFirstDropdownChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _firstDropdownValue = newValue;
      _initializeSecondDropdown();
      if (_firstDropdownValue != 'floorwise') {
        _thirdDropdownValue = '';
        _thirdDropdownOptions = [];
      }
      _loadSensorData();
    });
  }

  void _onSecondDropdownChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _secondDropdownValue = newValue;
      if (_firstDropdownValue == 'floorwise') {
        _initializeThirdDropdown();
      }
      _loadSensorData();
    });
  }

  void _onThirdDropdownChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _thirdDropdownValue = newValue;
      _loadSensorData();
    });
  }

  Future<void> _loadSensorData() async {
    setState(() {
      _loadingData = true;
    });

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
          await _fetchFromDatabase();
        } catch (_) {
          _generateSimulatedData(roomIdToLoad);
        }
      }
    } catch (_) {
      final roomId =
          _firstDropdownValue == 'floorwise'
              ? _thirdDropdownValue
              : _secondDropdownValue;
      _generateSimulatedData(roomId);
    }

    if (mounted) {
      setState(() {
        _loadingData = false;
      });
    }
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
    );
  }

  Widget _buildDepartmentDashboard(ColorScheme colorScheme) {
    final departmentName = departmentNames[_currentUser!.department] ?? 'Department';
    final departmentColor = departmentColors[_currentUser!.department] ?? Colors.blue;
    
    return DashboardScaffold(
      title: '🏢 $departmentName ENERGIA',
      actions: [
        // Department indicator
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: departmentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: departmentColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                departmentIcons[_currentUser!.department],
                size: 16,
                color: departmentColor,
              ),
              const SizedBox(width: 6),
              Text(
                departmentName,
                style: TextStyle(
                  color: departmentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
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
        return const _DepartmentAlertsSection();
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
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading sensor data...',
                  style: theme.textTheme.bodyLarge,
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

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                '$value $unit'.trim(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
  const _DepartmentAlertsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text('Alerts Section', style: theme.textTheme.headlineSmall),
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
