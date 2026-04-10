import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/dashboard_scaffold.dart';
import 'package:energia/models/room_data_simulator.dart';
import 'package:energia/models/user_role_model.dart';
import 'package:energia/services/department_customization_service.dart';
import 'package:energia/widgets/department_dashboard_widget.dart';
import 'package:energia/widgets/energy_visualization_widgets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'alert_reminder_service.dart';
import 'dart:math';
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
  Timer? _liveTimer;
  EnhancedUser? _currentUser;
  String? _userDepartment; // Store department for filtering
  final DepartmentCustomizationService _customizationService =
      DepartmentCustomizationService();
  List<String> _accessibleRooms = [];
  List<Map<String, dynamic>> _anomalies = [];
  Map<String, Map<String, dynamic>> _notificationsByRoom = {}; // roomId -> notification data
  int _badgeCount = 0;
  late AlertReminderService _reminderService;

// 1. COMBINED INITSTATE (Fixes error G351DE6FA)
  @override
  void initState() {
    super.initState();
    
    // Extract department from the passed user or from saved preferences
    _currentUser = widget.user;
    if (_currentUser?.department != null) {
      _userDepartment = _currentUser!.department!.name;
    } else {
      // Fallback to shared preferences if available
      _loadUserDepartmentFromPrefs();
    }
    
    // Load initial data for both room view and analytics
    _loadLiveData(); 
    _loadDepartmentAnalyticsData();
    _fetchAnomalyAlerts(); 
    
    // Setup the periodic timer for live updates.
    _liveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadLiveData();
      _loadDepartmentAnalyticsData();
      _fetchAnomalyAlerts();
    });

    // ── In-app reminder service ─────────────────────────────────────────
    _reminderService = AlertReminderService(
      contextGetter: () => context,
      onBadgeUpdate: (count) {
        if (mounted) setState(() => _badgeCount = count);
      },
      onResolve: (alertId) => _resolveAlertFromPopup(alertId),
      onViewAlerts: () {
        if (mounted) setState(() => _currentIndex = 3);
      },
    );
  }
  
  Future<void> _loadUserDepartmentFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deptJson = prefs.getString('user_department');
      if (deptJson != null) {
        final deptMap = jsonDecode(deptJson) as Map<String, dynamic>;
        setState(() {
          _userDepartment = deptMap['name'] ?? deptMap['id'];
        });
      }
    } catch (e) {
      // Silent fail - will use null department which means show all
    }
  }

  Future<void> _loadDepartmentAnalyticsData() async {
    /// Fetch aggregate analytics data for the entire department
    try {
      const apiCandidates = [
        'http://10.0.2.2:5000',
        'http://192.168.160.1:5000',
        'http://localhost:5000',
        'http://127.0.0.1:5000',
      ];

      for (final baseUrl in apiCandidates) {
        try {
          String queryString = '/sensor-data?limit=100';
          if (_userDepartment != null && _userDepartment!.isNotEmpty) {
            queryString += '&department=${Uri.encodeComponent(_userDepartment!)}';
          }

          final resp = await http
              .get(
                Uri.parse('$baseUrl$queryString'),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(const Duration(seconds: 6));

          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            final readings = data['data'] as List? ?? [];
            
            if (readings.isNotEmpty && mounted) {
              setState(() {
                _sensorData = readings.first as Map<String, dynamic>;
                _timeSeriesData = List<Map<String, dynamic>>.from(
                  readings.whereType<Map<String, dynamic>>(),
                );
              });
            }
            return;
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  void dispose() {
    _dataRefreshTimer?.cancel();
    _liveTimer?.cancel();
    _reminderService.dispose();
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
    department: _userDepartment,
    notificationsByRoom: _notificationsByRoom,
    baseUrls: const [
      'http://127.0.0.1:5000',
      'http://localhost:5000',
      'http://10.0.2.2:5000',
      'http://192.168.160.1:5000',
    ],
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
        // For simulated rooms, use fallback to simulation
        _generateSimulatedData(roomIdToLoad);
      }
    } catch (e) {
      // If any error occurs, fall back to simulated data
      String roomIdToLoad =
          _firstDropdownValue == 'floorwise'
              ? _thirdDropdownValue
              : _secondDropdownValue;
      _generateSimulatedData(roomIdToLoad);
    } finally {
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }
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
        // Build query with device_id and department if provided
        String queryString = '/sensor-data?limit=24';
        
        if (deviceId != null) {
          queryString += '&device_id=$deviceId';
        }
        
        if (_userDepartment != null && _userDepartment!.isNotEmpty) {
          queryString += '&department=${Uri.encodeComponent(_userDepartment!)}';
        }

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

  Future<void> _fetchAnomalyAlerts() async {
    // Fetch anomaly alerts from backend, filtered by department
    try {
      const apiCandidates = [
        'http://10.0.2.2:5000',
        'http://192.168.160.1:5000',
        'http://localhost:5000',
        'http://127.0.0.1:5000',
      ];

      for (final baseUrl in apiCandidates) {
        try {
          // 1. Fetch anomalies
          String queryString = '/anomalies';
          if (_userDepartment != null && _userDepartment!.isNotEmpty) {
            queryString += '?department=${Uri.encodeComponent(_userDepartment!)}';
          }
          
          final anomResp = await http
              .get(
                Uri.parse('$baseUrl$queryString'),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(const Duration(seconds: 6));

          if (anomResp.statusCode == 200) {
            final anomData = jsonDecode(anomResp.body);
            final anomalies = anomData is List ? anomData : (anomData['anomalies'] as List? ?? []);
            
            // 2. Fetch notifications for this coordinator
            final coordEmail = _currentUser?.email ?? '';
            Map<String, Map<String, dynamic>> notifsByRoom = {};
            
            if (coordEmail.isNotEmpty) {
              try {
                final notifResp = await http
                    .get(
                      Uri.parse('$baseUrl/notify/notifications?email=${Uri.encodeComponent(coordEmail)}&limit=100'),
                      headers: {'Content-Type': 'application/json'},
                    )
                    .timeout(const Duration(seconds: 6));
                
                if (notifResp.statusCode == 200) {
                  final notifData = jsonDecode(notifResp.body);
                  final notifications = notifData['notifications'] as List? ?? [];
                  
                  // Index notifications by room_id
                  for (final notif in notifications) {
                    final roomId = notif['room_id'] ?? '';
                    if (roomId.isNotEmpty) {
                      notifsByRoom[roomId] = notif as Map<String, dynamic>;
                    }
                  }
                }
              } catch (_) {
                // Silently skip if notifications fail
              }
            }
            
            if (mounted) {
              final fetched = List<Map<String, dynamic>>.from(
                anomalies.whereType<Map<String, dynamic>>(),
              );
              setState(() { 
                _anomalies = fetched;
                _notificationsByRoom = notifsByRoom;
              });
              // Feed reminder service — shows popup for new alerts + schedules timers
              _reminderService.syncAlerts(fetched);
            }
            return;
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      // Ignore errors silently
    }
  }

  void _onFirstDropdownChanged(String? value) {
    if (value != null && mounted) {
      setState(() {
        _firstDropdownValue = value;
        _loadingData = true;
      });
      _loadLiveData();
    }
  }

  void _onSecondDropdownChanged(String? value) {
    if (value != null && mounted) {
      setState(() {
        _secondDropdownValue = value;
        _loadingData = true;
      });
      _loadLiveData();
    }
  }

  void _onThirdDropdownChanged(String? value) {
    if (value != null && mounted) {
      setState(() {
        _thirdDropdownValue = value;
        _loadingData = true;
      });
      _loadLiveData();
    }
  }

  Widget _buildDepartmentDashboard(ColorScheme scheme) {
    return DashboardScaffold(
      title: 'Coordinator Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: _performLogout,
        ),
      ],
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPage(_currentIndex, scheme),
      ),
      currentIndex: _currentIndex,
      onBottomNavTapped: (index) {
        if (index == 4) {
          _performLogout();
        } else {
          setState(() {
            _currentIndex = index;
          });
          if (index == 3) {
            _fetchAnomalyAlerts();
            setState(() => _badgeCount = 0);
            _reminderService.clearBadge();
          }
        }
      },
      bottomNavItems: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Overview',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.room_outlined),
          activeIcon: Icon(Icons.room),
          label: 'Rooms',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: AlertBadgeIcon(icon: Icons.notifications_outlined, count: _badgeCount),
          activeIcon: AlertBadgeIcon(icon: Icons.notifications, count: _badgeCount),
          label: 'Alerts',
        ),
      ],
    );
  }

  Future<void> _resolveAlertFromPopup(dynamic alertId) async {
    const candidates = [
      'http://127.0.0.1:5000',
      'http://localhost:5000',
      'http://10.0.2.2:5000',
      'http://192.168.160.1:5000',
    ];
    for (final base in candidates) {
      try {
        final r = await http.put(
          Uri.parse('$base/anomalies/$alertId/resolve'),
          headers: {'Content-Type': 'application/json'},
          body: '{"status":"resolved"}',
        ).timeout(const Duration(seconds: 8));
        if (r.statusCode == 200 || r.statusCode == 204) {
          await _fetchAnomalyAlerts();
          return;
        }
      } catch (_) { continue; }
    }
  }

  void _performLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep coordinator page on the app-wide theme so it matches other dashboards.
    final colorScheme = Theme.of(context).colorScheme;
    return DashboardScaffold(
      title: 'Coordinator Dashboard',
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
           if (index == 3) {
             _fetchAnomalyAlerts();
             setState(() => _badgeCount = 0);
            _reminderService.clearBadge();
           }
        }
      },
      bottomNavItems: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Overview',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.room_outlined),
          activeIcon: Icon(Icons.room),
          label: 'Rooms',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: AlertBadgeIcon(icon: Icons.notifications_outlined, count: _badgeCount),
          activeIcon: AlertBadgeIcon(icon: Icons.notifications, count: _badgeCount),
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
          departmentName: _userDepartment ?? '',
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
        return _DepartmentRoomsSection(
          sensorData: _sensorData,
          timeSeriesData: _timeSeriesData,
          department: _userDepartment,
        );
      case 2:
        return _DepartmentAnalyticsSection(
          sensorData: _sensorData,
          timeSeriesData: _timeSeriesData,
          anomalies: _anomalies,
          loadingData: _loadingData,
          department: _userDepartment,
        );
      case 3:
        return _DepartmentAlertsSection(
          anomalies: _anomalies,
          onRefresh: _fetchAnomalyAlerts,
          department: _userDepartment,
          notificationsByRoom: _notificationsByRoom,
          baseUrls: const [
            'http://127.0.0.1:5000',
            'http://localhost:5000',
            'http://10.0.2.2:5000',
            'http://192.168.160.1:5000',
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// OVERVIEW PAGE WITH DYNAMIC DROPDOWNS
class _CoordinatorOverviewPage extends StatelessWidget {
  final ColorScheme scheme;
  final String departmentName;
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
    required this.departmentName,
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
    const cardWidth = 500.0;
    final latestPower = sensorData?['power']?.toDouble() ?? 0.0;
    final liveLoading = loadingData;
    final normalizedDepartmentName =
      departmentName.trim().isEmpty || departmentName.trim().toLowerCase() == 'admin'
        ? 'Department'
        : departmentName.trim();
   
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
                                'Welcome, Coordinator!',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$normalizedDepartmentName Energy Coordinator',
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
                  width: cardWidth,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Department Energy Flow (Last 24 Hours)',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          ResponsiveLineChart(
                            spots: const [
                                  FlSpot(0, 8.5), FlSpot(1, 9.2), FlSpot(2, 8.8), FlSpot(3, 12.5),
                                  FlSpot(4, 15.2), FlSpot(5, 18.4), FlSpot(6, 19.5), FlSpot(7, 17.8),
                                  FlSpot(8, 16.2), FlSpot(9, 14.5), FlSpot(10, 13.2), FlSpot(11, 12.8),
                                  FlSpot(12, 14.5), FlSpot(13, 15.8), FlSpot(14, 16.2), FlSpot(15, 17.1),
                                  FlSpot(16, 18.4), FlSpot(17, 16.9), FlSpot(18, 15.3), FlSpot(19, 13.5),
                                  FlSpot(20, 12.2), FlSpot(21, 10.8), FlSpot(22, 9.5), FlSpot(23, 8.8),
                                ],
                            title: 'Department Load Profile',
                            unit: 'kW',
                            maxY: 25.0,
                            isMonthly: false,
                            lineColor: EnergyColorScheme.infoTeal,
                          ),
                        ],
                      ),
                    ),
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

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final cardWidth = (MediaQuery.of(context).size.width / 2) - 28;
    
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
                maxLines: 1,
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
                  Flexible(
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
        return ThresholdSettingsDialog(theme: theme, scheme: this.scheme);
      },
    );
  }
}

class _DepartmentRoomsSection extends StatefulWidget {
  final Map<String, dynamic>? sensorData;
  final List<Map<String, dynamic>>? timeSeriesData;
  final String? department; // Department to filter rooms

  const _DepartmentRoomsSection({
    required this.sensorData,
    required this.timeSeriesData,
    this.department,
  });

  @override
  State<_DepartmentRoomsSection> createState() => _DepartmentRoomsSectionState();
}

class _DepartmentRoomsSectionState extends State<_DepartmentRoomsSection> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _thresholdController = TextEditingController();

  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _filteredRooms = [];
  List<int> _floors = [];
  String _selectedFloor = 'all';
  bool _loading = true;
  
  // Live data tracking for each room
  Map<String, Map<String, dynamic>> _roomLiveData = {};
  Map<String, Map<String, dynamic>> _relayMappingByRoom = {};
  Map<String, bool> _relayOnlineByDevice = {};
  Map<String, String> _relayStateByDevice = {};
  Map<String, String> _lastRelayActionByRoom = {};
  Set<String> _onlineRelayDeviceIds = <String>{};
  String? _authToken;
  Timer? _liveDataTimer;

  static const List<String> _apiCandidates = [
    'http://10.0.2.2:5000',
    'http://192.168.160.1:5000',
    'http://localhost:5000',
    'http://127.0.0.1:5000',
  ];

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _searchController.addListener(_applyFilters);
    _loadAuthToken();
    
    // Setup live data refresh timer
    _liveDataTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchLiveDataForDepartment();
      _fetchRelayConnectivity();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _thresholdController.dispose();
    _liveDataTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (!mounted) return;
      setState(() {
        _authToken = token;
      });
      await _fetchRelayConnectivity();
    } catch (_) {
      // Best-effort only; room metrics still work without relay controls.
    }
  }

  Future<void> _loadRooms() async {
    setState(() => _loading = true);
    for (final baseUrl in _apiCandidates) {
      try {
        String queryString = '/rooms';
        if (widget.department != null && widget.department!.isNotEmpty) {
          queryString += '?department=${Uri.encodeComponent(widget.department!)}';
        }
        
        final resp = await http
            .get(
              Uri.parse('$baseUrl$queryString'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final payload = jsonDecode(resp.body) as Map<String, dynamic>;
          final list = (payload['data'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          final floors = list
              .map((r) => r['floor_number'])
              .whereType<num>()
              .map((v) => v.toInt())
              .toSet()
              .toList()
            ..sort();

          if (!mounted) return;
          setState(() {
            _rooms = list;
            _floors = floors;
            _applyFilters();
            _loading = false;
          });
          
          // Fetch live data for all rooms
          await _fetchLiveDataForDepartment();
          await _fetchRelayConnectivity();
          return;
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    setState(() {
      _rooms = [];
      _filteredRooms = [];
      _floors = [];
      _loading = false;
    });
  }

  Future<void> _fetchLiveDataForDepartment() async {
    if (widget.department == null || widget.department!.isEmpty) return;
    
    for (final baseUrl in _apiCandidates) {
      try {
        final queryString = '/sensor-data?limit=100&department=${Uri.encodeComponent(widget.department!)}';
        
        final resp = await http
            .get(
              Uri.parse('$baseUrl$queryString'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final payload = jsonDecode(resp.body) as Map<String, dynamic>;
          final readings = (payload['data'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          // Group readings by device_id (room)
          Map<String, Map<String, dynamic>> groupedData = {};
          for (final reading in readings) {
            final deviceId = reading['device_id']?.toString() ?? 'unknown';
            // Keep the most recent reading for each device
            if (!groupedData.containsKey(deviceId)) {
              groupedData[deviceId] = reading;
            }
          }

          if (mounted) {
            setState(() {
              _roomLiveData = groupedData;
            });
          }
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _fetchRelayConnectivity() async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      return;
    }

    for (final baseUrl in _apiCandidates) {
      try {
        final mappingsResp = await http
            .get(
              Uri.parse('$baseUrl/relay/mappings'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 6));

        final statusResp = await http
            .get(
              Uri.parse('$baseUrl/relay/all-device-status'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 6));

        if (mappingsResp.statusCode != 200 || statusResp.statusCode != 200) {
          continue;
        }

        final mappingPayload = jsonDecode(mappingsResp.body) as Map<String, dynamic>;
        final statusPayload = jsonDecode(statusResp.body) as Map<String, dynamic>;

        final rawMappings = (mappingPayload['data'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final rawStatuses = (statusPayload['devices'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final mappingByRoom = <String, Map<String, dynamic>>{};
        for (final row in rawMappings) {
          final roomId = (row['room_id'] ?? '').toString().trim();
          if (roomId.isEmpty) continue;
          mappingByRoom[roomId] = row;
        }

        final relayOnlineByDevice = <String, bool>{};
        final relayStateByDevice = <String, String>{};
        final onlineDeviceIds = <String>{};
        for (final device in rawStatuses) {
          final deviceId = (device['device_id'] ?? '').toString().trim().toUpperCase();
          final isOnline = device['is_online'] == true;
          final state = (device['state'] ?? 'UNKNOWN').toString().trim().toUpperCase();
          if (deviceId.isEmpty) continue;
          relayOnlineByDevice[deviceId] = isOnline;
          relayStateByDevice[deviceId] = state;
          if (isOnline && state != 'UNKNOWN') {
            onlineDeviceIds.add(deviceId);
          }
        }

        if (!mounted) return;
        setState(() {
          _relayMappingByRoom = mappingByRoom;
          _relayOnlineByDevice = relayOnlineByDevice;
          _relayStateByDevice = relayStateByDevice;
          _onlineRelayDeviceIds = onlineDeviceIds;
        });
        return;
      } catch (_) {
        continue;
      }
    }
  }

  bool _hasActiveRelayConnectionForRoom(String roomId) {
    final mapping = _relayMappingByRoom[roomId];
    if (mapping == null) return false;

    final relayDeviceId = (mapping['relay_device_id'] ?? '').toString().trim().toUpperCase();
    final relayChannel = int.tryParse((mapping['relay_channel'] ?? '').toString());
    if (relayDeviceId.isEmpty || (relayChannel != 1 && relayChannel != 2)) {
      return false;
    }

    final isOnline = _relayOnlineByDevice[relayDeviceId] == true;
    final state = (_relayStateByDevice[relayDeviceId] ?? 'UNKNOWN').toUpperCase();
    if (!isOnline || state == 'UNKNOWN') {
      return false;
    }

    if (_onlineRelayDeviceIds.isNotEmpty && !_onlineRelayDeviceIds.contains(relayDeviceId)) {
      return false;
    }

    return true;
  }

  String _relayConnectionLabel(String roomId) {
    final mapping = _relayMappingByRoom[roomId];
    if (mapping == null) return 'Relay: Not configured';

    final relayDeviceId = (mapping['relay_device_id'] ?? '').toString().trim().toUpperCase();
    final relayChannel = (mapping['relay_channel'] ?? '').toString();
    final state = (_relayStateByDevice[relayDeviceId] ?? 'UNKNOWN').toUpperCase();
    final isActive = _hasActiveRelayConnectionForRoom(roomId);
    if (!isActive) {
      return 'Relay: Offline/unknown (Device $relayDeviceId, CH$relayChannel)';
    }

    final localAction = (_lastRelayActionByRoom[roomId] ?? '').toUpperCase();
    final effectiveState = (localAction == 'ON' || localAction == 'OFF') ? localAction : state;
    return 'Relay: Active (Device $relayDeviceId, CH$relayChannel, State $effectiveState)';
  }

  void _setLocalRelayRoomState(String roomId, String action) {
    final normalized = action.toUpperCase();
    _lastRelayActionByRoom[roomId] = normalized;
    final mapping = _relayMappingByRoom[roomId];
    if (mapping == null) return;
    final relayDeviceId = (mapping['relay_device_id'] ?? '').toString().trim().toUpperCase();
    if (relayDeviceId.isNotEmpty) {
      _relayStateByDevice[relayDeviceId] = normalized;
    }
  }

  Future<void> _controlRoomPower(String roomId, String action) async {
    final token = _authToken;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please login again.')),
      );
      return;
    }

    for (final baseUrl in _apiCandidates) {
      try {
        final resp = await http
            .post(
              Uri.parse('$baseUrl/relay/control'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({
                'room_id': roomId,
                'action': action.toUpperCase(),
                'reason': 'Manual room control by coordinator dashboard',
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          if (!mounted) return;
          setState(() {
            _setLocalRelayRoomState(roomId, action);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Room $roomId power set to ${action.toUpperCase()}')),
          );
          return;
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to set $roomId to ${action.toUpperCase()}')),
    );
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final floorFilter = _selectedFloor;

    _filteredRooms = _rooms.where((room) {
      final roomName = (room['room_name'] ?? '').toString().toLowerCase();
      final roomId = (room['room_id'] ?? '').toString().toLowerCase();
      final floorNum = (room['floor_number'] ?? '').toString();

      final matchesFloor = floorFilter == 'all' || floorNum == floorFilter;
      final matchesQuery =
          query.isEmpty || roomName.contains(query) || roomId.contains(query);

      return matchesFloor && matchesQuery;
    }).toList();

    if (mounted) {
      setState(() {});
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _statusForRoom(Map<String, dynamic> room) {
    final roomId = (room['room_id'] ?? '').toString();
    final threshold = _toDouble(room['threshold']);
    final liveData = _roomLiveData[roomId];
    final currentPower = liveData != null 
        ? _toDouble(liveData['power'] ?? liveData['value'])
        : 0.0;

    if (currentPower <= 0) return 'Idle';
    if (threshold > 0 && currentPower > threshold) return 'High Usage';
    return 'Normal';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'High Usage':
        return Colors.red;
      case 'Idle':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  Future<void> _editThreshold(Map<String, dynamic> room) async {
    final roomId = (room['room_id'] ?? '').toString();
    final roomName = (room['room_name'] ?? roomId).toString();
    _thresholdController.text = (room['threshold'] ?? '').toString();

    final newVal = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Update Threshold • $roomName'),
          content: TextField(
            controller: _thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Threshold',
              suffixText: 'kW',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(_thresholdController.text.trim());
                Navigator.pop(context, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newVal == null || newVal <= 0) return;

    for (final baseUrl in _apiCandidates) {
      try {
        final resp = await http
            .put(
              Uri.parse('$baseUrl/rooms/$roomId/threshold?threshold=$newVal'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          await _loadRooms();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Threshold updated successfully')),
          );
          return;
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update threshold')),
    );
  }

  Widget _buildRoomLiveMetrics(Map<String, dynamic> room) {
    final roomId = (room['room_id'] ?? '').toString();
    final liveData = _roomLiveData[roomId];
    
    if (liveData == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Waiting for live data...',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      );
    }

    final power = _toDouble(liveData['power'] ?? liveData['value']);
    final voltage = _toDouble(liveData['voltage']);
    final current = _toDouble(liveData['current']);
    final energy = _toDouble(liveData['energy']);
    final threshold = _toDouble(room['threshold']);
    final utilization = threshold > 0 ? (power / threshold * 100).clamp(0, 999) : 0.0;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildMetricChip('⚡ Power', '${power.toStringAsFixed(2)} kW', Colors.red),
        _buildMetricChip('🔋 Energy', '${energy.toStringAsFixed(2)} kWh', Colors.green),
        _buildMetricChip('⚙️ Current', '${current.toStringAsFixed(2)} A', Colors.orange),
        _buildMetricChip('📊 Voltage', '${voltage.toStringAsFixed(1)} V', Colors.blue),
        _buildMetricChip('📈 Usage', '${utilization.toStringAsFixed(1)}%', 
          utilization > 100 ? Colors.red : utilization > 75 ? Colors.orange : Colors.green),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final totalRooms = _rooms.length;
    final visibleRooms = _filteredRooms.length;
    final highUsageCount = _filteredRooms
        .where((room) => _statusForRoom(room) == 'High Usage')
        .length;
    final floorsCount = _floors.length;

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Rooms Management',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.department != null 
              ? 'Monitor ${widget.department} department rooms with live energy metrics'
              : 'Monitor rooms with live energy metrics',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // KPI Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _roomKpiCard(context, 'Total Rooms', totalRooms.toString(), Icons.meeting_room_outlined, Colors.blue),
              _roomKpiCard(context, 'Visible', visibleRooms.toString(), Icons.filter_list, Colors.indigo),
              _roomKpiCard(context, 'Floors', floorsCount.toString(), Icons.apartment, Colors.teal),
              _roomKpiCard(context, 'High Usage', highUsageCount.toString(), Icons.warning_amber_rounded, 
                highUsageCount > 0 ? Colors.red : Colors.green),
            ],
          ),

          const SizedBox(height: 16),
          
          // Filter and Controls
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search room name or ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _selectedFloor,
                      decoration: const InputDecoration(
                        labelText: 'Floor',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Floors')),
                        ..._floors.map(
                          (floor) => DropdownMenuItem(
                            value: floor.toString(),
                            child: Text('Floor $floor'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        _selectedFloor = value ?? 'all';
                        _applyFilters();
                      },
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      _loadRooms();
                      _fetchLiveDataForDepartment();
                    },
                    child: const Text('Reload'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => ThresholdSettingsDialog(theme: theme, scheme: scheme),
                    ),
                    icon: const Icon(Icons.tune),
                    label: const Text('Bulk Threshold Settings'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredRooms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No rooms found for selected filters',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            )
          else
            ..._filteredRooms.map((room) {
              final status = _statusForRoom(room);
              final color = _statusColor(status);
              final roomId = (room['room_id'] ?? '').toString();
              final roomName = (room['room_name'] ?? roomId).toString();
              final floor = (room['floor_number'] ?? '-').toString();
              final hasActiveRelay = _hasActiveRelayConnectionForRoom(roomId);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Room Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roomName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ID: $roomId • Floor: $floor',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _relayConnectionLabel(roomId),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: hasActiveRelay ? Colors.green.shade700 : Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Live Metrics
                      _buildRoomLiveMetrics(room),
                      
                      const SizedBox(height: 12),
                      
                      // Action Buttons
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _editThreshold(room),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Threshold'),
                          ),
                          const SizedBox(width: 10),
                          if (hasActiveRelay) ...[
                            ElevatedButton(
                              onPressed: () => _controlRoomPower(roomId, 'ON'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                              child: const Text('ON'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _controlRoomPower(roomId, 'OFF'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                              child: const Text('OFF'),
                            ),
                            const SizedBox(width: 10),
                          ],
                          TextButton.icon(
                            onPressed: () {
                              final liveData = _roomLiveData[roomId];
                              if (liveData != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Last update: ${liveData['timestamp'] ?? 'Just now'}')),
                                );
                              }
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: Text(hasActiveRelay ? 'Details' : 'Details (Relay unavailable)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _roomKpiCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 2),
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
          ),
        ),
      ),
    );
  }
}

class _DepartmentAnalyticsSection extends StatelessWidget {
  final Map<String, dynamic>? sensorData;
  final List<Map<String, dynamic>>? timeSeriesData;
  final List<Map<String, dynamic>> anomalies;
  final bool loadingData;
  final String? department;

  const _DepartmentAnalyticsSection({
    required this.sensorData,
    required this.timeSeriesData,
    required this.anomalies,
    required this.loadingData,
    this.department,
  });

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final points = (timeSeriesData ?? const <Map<String, dynamic>>[])
        .take(24)
        .toList()
        .reversed
        .toList();

    final powerValues = points
        .map((item) => _toDouble(item['power'] ?? item['value']))
        .toList();

    final currentPower = _toDouble(sensorData?['power'] ?? sensorData?['value']);
    final avgPower = powerValues.isEmpty
        ? currentPower
        : powerValues.reduce((a, b) => a + b) / powerValues.length;
    final peakPower = powerValues.isEmpty
        ? currentPower
        : powerValues.reduce(max);
    final basePower = powerValues.isEmpty
        ? currentPower
        : powerValues.reduce(min);
    final anomalyCount = anomalies.length;

    final trend = powerValues.length >= 2
        ? powerValues.last - powerValues.first
        : 0.0;

    final lineSpots = powerValues
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();

    final maxY = powerValues.isEmpty
        ? (currentPower <= 0 ? 10.0 : currentPower * 1.4)
        : (powerValues.reduce(max) * 1.2).clamp(5.0, 1000.0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          department != null ? '$department Analytics' : 'Department Analytics',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Live performance indicators and trend insights from recent readings across all department rooms',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        if (loadingData)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _analyticsMetricCard(
                context,
                label: 'Current Power',
                value: '${currentPower.toStringAsFixed(2)} kW',
                icon: Icons.bolt,
                color: Colors.amber,
              ),
              _analyticsMetricCard(
                context,
                label: 'Average (24 pts)',
                value: '${avgPower.toStringAsFixed(2)} kW',
                icon: Icons.show_chart,
                color: Colors.blue,
              ),
              _analyticsMetricCard(
                context,
                label: 'Peak Usage',
                value: '${peakPower.toStringAsFixed(2)} kW',
                icon: Icons.trending_up,
                color: Colors.redAccent,
              ),
              _analyticsMetricCard(
                context,
                label: 'Anomalies',
                value: anomalyCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: anomalyCount > 0 ? Colors.orange : Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Power Trend (Recent Samples)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lineSpots.isEmpty
                        ? 'No recent readings available'
                        : 'Trend: ${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(2)} kW',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: lineSpots.isEmpty
                        ? Center(
                            child: Text(
                              'No data to plot yet',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: (lineSpots.length - 1).toDouble(),
                              minY: 0,
                              maxY: maxY,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: maxY / 5,
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 42,
                                    interval: maxY / 5,
                                  ),
                                ),
                                bottomTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    interval: 4,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: lineSpots,
                                  isCurved: true,
                                  barWidth: 3,
                                  color: scheme.primary,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: scheme.primary.withOpacity(0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Insights',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _insightRow(
                    context,
                    'Base Load',
                    '${basePower.toStringAsFixed(2)} kW',
                    Icons.low_priority,
                  ),
                  _insightRow(
                    context,
                    'Peak to Base Ratio',
                    '${basePower > 0 ? (peakPower / basePower).toStringAsFixed(2) : 'N/A'}x',
                    Icons.compare_arrows,
                  ),
                  _insightRow(
                    context,
                    'Risk Level',
                    anomalyCount >= 5
                        ? 'High'
                        : anomalyCount > 0
                            ? 'Moderate'
                            : 'Low',
                    Icons.shield_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _analyticsMetricCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall,
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
          ),
        ),
      ),
    );
  }

  Widget _insightRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentAlertsSection extends StatefulWidget {
  final List<dynamic> anomalies;
  final Future<void> Function() onRefresh;
  final String? department;
  final List<String> baseUrls;
  final Map<String, Map<String, dynamic>> notificationsByRoom;

  const _DepartmentAlertsSection({
    super.key,
    required this.anomalies,
    required this.onRefresh,
    required this.baseUrls,
    this.department,
    this.notificationsByRoom = const {},
  });

  @override
  State<_DepartmentAlertsSection> createState() =>
      _DepartmentAlertsSectionState();
}

class _DepartmentAlertsSectionState extends State<_DepartmentAlertsSection> {
  late List<Map<String, dynamic>> _localAnomalies;
  final Set<dynamic> _resolvingIds = {};
  Timer? _selfRefreshTimer;

  @override
  void initState() {
    super.initState();
    _localAnomalies = _cast(widget.anomalies);
    // Auto-refresh every 6 seconds — no manual refresh needed
    _selfRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _selfFetch();
    });
  }

  @override
  void dispose() {
    _selfRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_DepartmentAlertsSection old) {
    super.didUpdateWidget(old);
    if (old.anomalies != widget.anomalies) {
      setState(() {
        _localAnomalies = _cast(widget.anomalies)
            .where((a) => !_resolvingIds.contains(a['id'] ?? a['_id']))
            .toList();
      });
    }
  }

  List<Map<String, dynamic>> _cast(List<dynamic> raw) =>
      raw.whereType<Map<String, dynamic>>().toList();

  // Self-contained fetch — identical to CR page
  Future<void> _selfFetch() async {
    for (final base in widget.baseUrls) {
      try {
        var url = '$base/anomalies';
        if (widget.department != null && widget.department!.isNotEmpty) {
          url += '?department=${Uri.encodeComponent(widget.department!)}';
        }
        final resp = await http
            .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final raw = body is List ? body : (body['anomalies'] as List? ?? []);
          final fetched = raw.whereType<Map<String, dynamic>>().toList();
          if (!mounted) return;
          setState(() {
            _localAnomalies = fetched
                .where((a) => !_resolvingIds.contains(a['id'] ?? a['_id']))
                .toList();
          });
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _resolveAlert(int index) async {
    final alert = _localAnomalies[index];
    final alertId = alert['id'] ?? alert['_id'];

    if (alertId == null) {
      setState(() => _localAnomalies.removeAt(index));
      return;
    }

    setState(() => _resolvingIds.add(alertId));
    bool success = false;

    for (final base in widget.baseUrls) {
      try {
        final put = await http
            .put(
              Uri.parse('$base/anomalies/$alertId/resolve'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'status': 'resolved'}),
            )
            .timeout(const Duration(seconds: 8));
        if (put.statusCode == 200 || put.statusCode == 204) {
          success = true;
          break;
        }
        // Fallback DELETE
        final del = await http
            .delete(Uri.parse('$base/anomalies/$alertId'),
                headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 8));
        if (del.statusCode == 200 || del.statusCode == 204 || del.statusCode == 404) {
          success = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;

    if (success) {
      setState(() {
        _resolvingIds.remove(alertId);
        _localAnomalies.removeWhere((a) => (a['id'] ?? a['_id']) == alertId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Alert resolved successfully.'),
        ]),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } else {
      setState(() => _resolvingIds.remove(alertId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.error_outline, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Could not reach server. Try again.')),
        ]),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            final retryIndex = _localAnomalies
                .indexWhere((a) => (a['id'] ?? a['_id']) == alertId);
            if (retryIndex >= 0) _resolveAlert(retryIndex);
          },
        ),
      ));
    }
  }

  // Severity helpers
  Color _severityColor(dynamic power) {
    final p = (power as num?)?.toDouble() ?? 0;
    if (p > 5000) return const Color(0xFFB71C1C);
    if (p > 3000) return Colors.orange.shade700;
    return Colors.amber.shade700;
  }

  String _severityLabel(dynamic power) {
    final p = (power as num?)?.toDouble() ?? 0;
    if (p > 5000) return 'CRITICAL';
    if (p > 3000) return 'HIGH';
    return 'MEDIUM';
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return '${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return ts.toString();
    }
  }

  /// Build the alert message content widget, showing formatted notification message
  /// if available, otherwise fall back to raw anomaly data
  Widget _buildAlertMessageContent(Map<String, dynamic> alert) {
    final roomId = alert['device_id'] ?? '';
    final notification = widget.notificationsByRoom[roomId];
    final theme = Theme.of(context);

    if (notification != null) {
      // Display formatted role-based notification message
      final title = notification['title'] ?? '';
      final message = notification['message'] ?? '';
      final power = notification['power'];
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role-specific title
          if (title.isNotEmpty)
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (title.isNotEmpty) const SizedBox(height: 4),
          // Formatted message with recommendations
          if (message.isNotEmpty)
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          if (message.isNotEmpty) const SizedBox(height: 4),
          // Metadata now fallback
          Text(
            '${_formatTime(alert['timestamp'])} • Power: ${power?.toStringAsFixed(1) ?? alert['power']}W',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    // Fallback: display raw anomaly data if no formatted notification
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Power: ${alert['power']}W  |  Occupancy: ${alert['occupancy']}',
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'Score: ${alert['score']}  |  ${_formatTime(alert['timestamp'])}',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dept = widget.department ?? 'Department';

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Text(
            '$dept Anomaly Alerts',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live anomaly detections · auto-refreshes every 6 s',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ),
              if (_localAnomalies.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    '${_localAnomalies.length} active',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Empty state ───────────────────────────────────────────────────
          if (_localAnomalies.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Column(children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: Colors.green.withOpacity(0.55)),
                  const SizedBox(height: 14),
                  Text('No anomaly alerts detected',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('All sensors operating normally',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade500)),
                ]),
              ),
            )

          // ── Alert cards — identical layout to CR page ─────────────────────
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localAnomalies.length,
              itemBuilder: (context, i) {
                final alert = _localAnomalies[i];
                final alertId = alert['id'] ?? alert['_id'];
                final isResolving = _resolvingIds.contains(alertId);
                final sevColor = _severityColor(alert['power']);
                final sevLabel = _severityLabel(alert['power']);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Severity bar at top of card
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: sevColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── Icon ────────────────────────────────────────
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: CircleAvatar(
                                backgroundColor: sevColor.withOpacity(0.12),
                                child: Icon(Icons.warning_amber_rounded,
                                    color: sevColor),
                              ),
                            ),

                            // ── Text info ────────────────────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Anomaly in ${alert['device_id']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: sevColor.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          sevLabel,
                                          style: TextStyle(
                                            color: sevColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Display formatted notification message if available
                                  _buildAlertMessageContent(alert),
                                ],
                              ),
                            ),

                            // ── Resolve button — always visible ───────────────
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 6, right: 8),
                              child: ElevatedButton.icon(
                                onPressed: isResolving
                                    ? null
                                    : () => _resolveAlert(i),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isResolving
                                      ? Colors.green.withOpacity(0.5)
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.green.withOpacity(0.5),
                                  disabledForegroundColor: Colors.white70,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                icon: isResolving
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 16),
                                label: Text(
                                  isResolving ? 'Resolving...' : 'Resolve',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
                Uri.parse('$baseUrl/rooms'),
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
                  '$baseUrl/rooms/$encodedRoomId/threshold?threshold=$newThreshold',
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

// ── Badge widget for coordinator nav bar ─────────────────────────────────────
class _CoordAlertsBadge extends StatelessWidget {
  final int count;
  final Widget child;
  const _CoordAlertsBadge({required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6, top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                  color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
