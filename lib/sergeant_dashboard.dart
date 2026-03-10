import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'role_selection_page.dart';
import 'sergeant_profile_page.dart';
import 'services/notifier.dart';
import 'services/sergeant_api.dart';

class SergeantDashboardPage extends StatefulWidget {
  const SergeantDashboardPage({super.key});

  @override
  State<SergeantDashboardPage> createState() => _SergeantDashboardPageState();
}

class _SergeantDashboardPageState extends State<SergeantDashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _mappings = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _recentAnomalies = [];
  Map<String, String> _lastActionsByRoom = {};
  Set<String> _onlineRelayDeviceIds = <String>{};
  Map<String, bool> _relayOnlineById = <String, bool>{};
  Map<String, String> _relayDeviceStateById = {};
  Timer? _refreshTimer;

  bool get _isAfterHoursNow {
    final now = DateTime.now();
    final hour = now.hour;
    // Campus normal hours: 08:00 to 17:59
    return hour < 8 || hour >= 18;
  }

  bool get _hasSensorData {
    final activeRooms = _overview['active_rooms'] as int? ?? 0;
    return activeRooms > 0;
  }

  bool get _hasRelayConnection {
    // Strict live status from backend only.
    return _onlineRelayDeviceIds.isNotEmpty;
  }

  bool get _hasLiveData {
    return _hasSensorData || _hasRelayConnection;
  }

  String _normalizeRoomId(String input) {
    var value = input.trim().toUpperCase();
    if (value.startsWith('ESP32-')) {
      value = value.substring('ESP32-'.length);
    }
    if (value.endsWith('-CH1') || value.endsWith('-CH2')) {
      value = value.substring(0, value.length - 4);
    }
    if (value.endsWith('_CH1') || value.endsWith('_CH2')) {
      value = value.substring(0, value.length - 4);
    }
    return value;
  }

  DateTime? _parseAnyTimestamp(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  List<Map<String, dynamic>> _buildAfterHoursRiskRooms() {
    final byRoom = <String, Map<String, dynamic>>{};
    for (final row in _recentAnomalies) {
      final roomIdRaw = (row['device_id'] ?? '').toString();
      final roomId = _normalizeRoomId(roomIdRaw);
      if (roomId.isEmpty) {
        continue;
      }

      final occupancy = row['occupancy'] as num? ?? 0;
      final power = row['power'] as num? ?? 0;
      final ts = _parseAnyTimestamp(row['timestamp']);

      final isAfterHours = ts == null ? _isAfterHoursNow : (ts.hour < 8 || ts.hour >= 18);
      if (!isAfterHours || occupancy > 0 || power < 20) {
        continue;
      }

      final existing = byRoom[roomId];
      if (existing == null) {
        byRoom[roomId] = {
          'room_id': roomId,
          'power': power,
          'occupancy': occupancy,
          'score': row['score'],
          'timestamp': row['timestamp'],
        };
        continue;
      }

      final existingPower = existing['power'] as num? ?? 0;
      if (power > existingPower) {
        byRoom[roomId] = {
          'room_id': roomId,
          'power': power,
          'occupancy': occupancy,
          'score': row['score'],
          'timestamp': row['timestamp'],
        };
      }
    }

    final rows = byRoom.values.toList();
    rows.sort((a, b) => ((b['power'] as num?) ?? 0).compareTo((a['power'] as num?) ?? 0));
    return rows;
  }

  bool _hasValidRelayConfig(Map<String, dynamic> room) {
    final roomId = (room['room_id'] ?? '').toString().trim();
    final deviceId = (room['relay_device_id'] ?? '').toString().trim();
    final channel = int.tryParse((room['relay_channel'] ?? '').toString());
    return roomId.isNotEmpty && deviceId.isNotEmpty && (channel == 1 || channel == 2);
  }

  Set<String> _inactiveRoomIdsFromOverview() {
    final raw = _overview['inactive_rooms'];
    if (raw is! List) {
      return <String>{};
    }

    return raw
        .map((e) => e.toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  List<Map<String, dynamic>> _activeMappedRooms() {
    final inactiveRoomIds = _inactiveRoomIdsFromOverview();
    final onlineDeviceIds = _onlineRelayDeviceIds;
    final onlineStateById = _relayOnlineById;
    final deviceStates = _relayDeviceStateById;

    return _mappings.where((room) {
      if (!_hasValidRelayConfig(room)) {
        return false;
      }

      final deviceId = (room['relay_device_id'] ?? '').toString().trim().toUpperCase();
      final isOnline = onlineStateById[deviceId] == true;
      final state = (deviceStates[deviceId] ?? '').toUpperCase();
      if (!isOnline) {
        return false;
      }
      if (state.isEmpty || state == 'UNKNOWN') {
        return false;
      }

      if (onlineDeviceIds.isNotEmpty && !onlineDeviceIds.contains(deviceId)) {
        return false;
      }

      final roomId = (room['room_id'] ?? '').toString().trim();
      return inactiveRoomIds.isEmpty || !inactiveRoomIds.contains(roomId);
    }).toList();
  }

  void _setLocalRoomConnectionState(String roomId, String action) {
    final normalizedAction = action.trim().toUpperCase();
    _lastActionsByRoom[roomId] = normalizedAction;

    final mappedRoom = _mappings.cast<Map<String, dynamic>?>().firstWhere(
          (row) => (row?['room_id'] ?? '').toString() == roomId,
          orElse: () => null,
        );
    if (mappedRoom == null) {
      return;
    }

    final deviceId = (mappedRoom['relay_device_id'] ?? '').toString().trim().toUpperCase();
    if (deviceId.isNotEmpty) {
      _relayDeviceStateById[deviceId] = normalizedAction;
    }
  }

  String _connectionStateForRoom(Map<String, dynamic> room) {
    final roomId = (room['room_id'] ?? '').toString();
    final deviceId = (room['relay_device_id'] ?? '').toString().trim().toUpperCase();

    final lastAction = (_lastActionsByRoom[roomId] ?? '').toUpperCase();
    final deviceState = (_relayDeviceStateById[deviceId] ?? '').toUpperCase();

    final effectiveState = (lastAction == 'ON' || lastAction == 'OFF')
        ? lastAction
        : deviceState;

    return effectiveState == 'ON' ? 'UP' : 'DOWN';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadData(showLoader: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
      (route) => false,
    );
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = await _readToken();
      if (token == null || token.isEmpty) {
        throw SergeantApiError('Session expired. Please login again.');
      }

      final criticalData = await Future.wait<dynamic>([
        getSergeantProfile(token),
        getCampusOverview(),
        getRelayMappings(token),
        getRelayLogs(token),
      ]);

      Set<String> onlineRelayDeviceIds = <String>{};
      var relayOnlineById = <String, bool>{};
      final relayDeviceStateById = <String, String>{};
      try {
        final deviceStatus = await getAllRelayDeviceStatus(token).timeout(const Duration(seconds: 5));
        for (final device in deviceStatus) {
          final deviceId = (device['device_id'] ?? '').toString().trim().toUpperCase();
          final isOnline = device['is_online'] == true;
          final state = (device['state'] ?? 'UNKNOWN').toString().trim().toUpperCase();
          if (deviceId.isNotEmpty) {
            relayOnlineById[deviceId] = isOnline;
            relayDeviceStateById[deviceId] = state;
          }
        }

        onlineRelayDeviceIds = deviceStatus
            .where((device) => device['is_online'] == true)
            .where((device) => (device['state'] ?? 'UNKNOWN').toString().toUpperCase() != 'UNKNOWN')
            .map((device) => (device['device_id'] ?? '').toString().trim().toUpperCase())
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {
        // Device status is best-effort and should not block rendering.
        onlineRelayDeviceIds = <String>{};
        relayOnlineById = <String, bool>{};
      }

      List<Map<String, dynamic>> alerts = [];
      try {
        alerts = await getActiveAnomalyAlerts().timeout(const Duration(seconds: 10));
      } catch (e) {
        // Alerts should not block dashboard rendering.
        debugPrint('Failed to load active anomaly alerts: $e');
        alerts = [];
      }

      List<Map<String, dynamic>> anomalies = [];
      try {
        anomalies = await getRecentAnomalies(limit: 120).timeout(const Duration(seconds: 5));
      } catch (_) {
        anomalies = [];
      }

      final profile = Map<String, dynamic>.from(criticalData[0] as Map<String, dynamic>);
      final overview = Map<String, dynamic>.from(criticalData[1] as Map<String, dynamic>);
      final mappings = List<Map<String, dynamic>>.from(criticalData[2] as List<Map<String, dynamic>>);
      final logs = List<Map<String, dynamic>>.from(criticalData[3] as List<Map<String, dynamic>>);

      final latestByRoom = <String, String>{};
      for (final log in logs) {
        final roomId = (log['room_id'] ?? '').toString();
        if (roomId.isEmpty || latestByRoom.containsKey(roomId)) {
          continue;
        }
        latestByRoom[roomId] = (log['action'] ?? 'UNKNOWN').toString();
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _overview = overview;
        _mappings = mappings;
        _alerts = alerts;
        _recentAnomalies = anomalies;
        _lastActionsByRoom = latestByRoom;
        _onlineRelayDeviceIds = onlineRelayDeviceIds;
        _relayOnlineById = relayOnlineById;
        _relayDeviceStateById = relayDeviceStateById;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is SergeantApiError ? e.message : 'Failed to load dashboard: $e';
      });
    }
  }

  Future<void> _controlRoomPower(String roomId, String action) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      AppNotifier.showError(context, 'Session expired. Please login again.');
      return;
    }

    try {
      await controlRelay(
        token,
        roomId: roomId,
        action: action,
        reason: 'Manual power control by Sergeant dashboard',
      );

      setState(() {
        _setLocalRoomConnectionState(roomId, action);
      });

      if (!mounted) return;
      AppNotifier.showSuccess(context, 'Room $roomId power set to ${action.toUpperCase()}');
    } catch (e) {
      if (!mounted) return;
      final msg = e is SergeantApiError ? e.message : 'Power control failed: $e';
      AppNotifier.showError(context, msg);
    }
  }

  Future<void> _cutOffRiskRooms(List<Map<String, dynamic>> riskRooms) async {
    if (riskRooms.isEmpty) {
      if (!mounted) return;
      AppNotifier.showInfo(context, 'No risky after-hours rooms found.');
      return;
    }

    final token = await _readToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      AppNotifier.showError(context, 'Session expired. Please login again.');
      return;
    }

    // Filter risk rooms to only include those with valid relay mappings
    final controllableRooms = <Map<String, dynamic>>[];
    for (final room in riskRooms) {
      final roomId = (room['room_id'] ?? '').toString();
      if (roomId.isEmpty) continue;
      
      // Check if this room has a relay mapping
      final hasMapping = _mappings.any((m) {
        final mappedRoomId = (m['room_id'] ?? '').toString().trim();
        final deviceId = (m['relay_device_id'] ?? '').toString().trim();
        return mappedRoomId == roomId && deviceId.isNotEmpty;
      });
      
      if (hasMapping) {
        controllableRooms.add(room);
      }
    }

    if (controllableRooms.isEmpty) {
      if (!mounted) return;
      AppNotifier.showError(context, 'None of the ${riskRooms.length} risk room(s) have relay mappings configured.');
      return;
    }

    var successCount = 0;
    var failedCount = 0;
    final errors = <String>[];
    
    for (final room in controllableRooms) {
      final roomId = (room['room_id'] ?? '').toString();
      try {
        await controlRelay(
          token,
          roomId: roomId,
          action: 'OFF',
          reason: 'After-hours anomaly cutoff by Sergeant duty action',
        );
        successCount += 1;
        _setLocalRoomConnectionState(roomId, 'OFF');
      } catch (e) {
        failedCount += 1;
        errors.add('$roomId: ${e.toString()}');
      }
    }

    if (!mounted) return;
    setState(() {});
    
    if (successCount > 0) {
      if (failedCount == 0) {
        AppNotifier.showSuccess(context, 'Power OFF sent to all $successCount risky room(s).');
      } else {
        AppNotifier.showSuccess(context, 'Power OFF sent to $successCount of ${controllableRooms.length} room(s). $failedCount failed.');
      }
    } else {
      final errorMsg = errors.isNotEmpty ? '\n${errors.take(3).join('\n')}' : '';
      AppNotifier.showError(context, 'Failed to send OFF commands to risky rooms.$errorMsg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final activeMappedRooms = _activeMappedRooms();
    final riskRooms = _buildAfterHoursRiskRooms();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final room in activeMappedRooms) {
      final department = (room['department'] ?? 'Unassigned').toString();
      grouped.putIfAbsent(department, () => []);
      grouped[department]!.add(room);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sergeant Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () async {
              final navigator = Navigator.of(context);
              final token = await _readToken();
              if (token == null || token.isEmpty) return;
              if (!mounted) return;
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => SergeantProfilePage(
                    profile: _profile,
                    token: token,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.account_circle),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Pull down to refresh live status',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: scheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${_profile['name'] ?? 'Sergeant'}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${_profile['sergeant_id'] ?? '-'} | Email: ${_profile['email'] ?? '-'}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onPrimaryContainer.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_hasLiveData)
                        Card(
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(Icons.sensors_off, color: Colors.orange.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No Live Data Connection',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        !_hasSensorData && !_hasRelayConnection
                                            ? 'Sensors and relay devices are offline. Waiting for connection...'
                                            : !_hasSensorData
                                                ? 'ESP32 sensors are not sending data. Check sensor connections.'
                                                : 'Relay devices are offline. Check relay connections.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!_hasLiveData) const SizedBox(height: 10),
                      _buildOverviewGrid(theme, activeMappedRooms.length),
                      const SizedBox(height: 10),
                      Card(
                        child: ListTile(
                          leading: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                          title: const Text('Active anomaly alerts'),
                          trailing: Text(
                            '${_alerts.length}',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        color: _isAfterHoursNow
                            ? Colors.orange.shade50
                            : scheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _isAfterHoursNow ? Icons.nightlight_round : Icons.schedule,
                                    color: _isAfterHoursNow ? Colors.orange.shade800 : scheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isAfterHoursNow
                                          ? 'After-Hours Duty Monitoring'
                                          : 'Normal-Hours Monitoring',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: _isAfterHoursNow
                                            ? Colors.orange.shade900
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Risk rooms (power usage with zero occupancy): ${riskRooms.length}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _isAfterHoursNow
                                      ? Colors.orange.shade900
                                      : scheme.onSurface.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: riskRooms.isEmpty ? null : () => _cutOffRiskRooms(riskRooms),
                                icon: const Icon(Icons.power_settings_new),
                                label: const Text('Cut OFF All Risk Rooms'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (riskRooms.isNotEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'After-Hours Anomaly Watchlist',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ...riskRooms.take(8).map((risk) {
                                  final roomId = (risk['room_id'] ?? '').toString();
                                  final power = (risk['power'] as num?)?.toDouble() ?? 0;
                                  final occupancy = (risk['occupancy'] as num?)?.toInt() ?? 0;
                                  final score = (risk['score'] as num?)?.toDouble();

                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    leading: Icon(Icons.report_problem, color: Colors.orange.shade700),
                                    title: Text(roomId),
                                    subtitle: Text(
                                      'Power: ${power.toStringAsFixed(1)}W | Occupancy: $occupancy'
                                      '${score != null ? ' | Score: ${score.toStringAsFixed(2)}' : ''}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => _controlRoomPower(roomId, 'ON'),
                                          icon: const Icon(Icons.power, size: 16),
                                          label: const Text('ON'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _controlRoomPower(roomId, 'OFF'),
                                          icon: const Icon(Icons.power_settings_new, size: 16),
                                          label: const Text('OFF'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Department-wise Rooms & Power Control',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (grouped.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No active room-relay mappings found. Ask admin to configure mappings or check live room activity.'),
                          ),
                        ),
                      ...grouped.entries.map((entry) {
                        final dept = entry.key;
                        final rooms = entry.value;
                        return Card(
                          child: ExpansionTile(
                            leading: const Icon(Icons.apartment_outlined),
                            title: Text('$dept (${rooms.length} rooms)'),
                            children: rooms.map((room) {
                              final roomId = (room['room_id'] ?? '').toString();
                              final roomName = (room['room_name'] ?? roomId).toString();
                              final channel = room['relay_channel']?.toString() ?? '-';
                              final status = _lastActionsByRoom[roomId] ?? 'UNKNOWN';
                              final deviceId = (room['relay_device_id'] ?? '').toString().trim().toUpperCase();
                              final deviceState = (_relayDeviceStateById[deviceId] ?? 'UNKNOWN').toUpperCase();
                              final connectionState = _connectionStateForRoom(room);
                              final isConnectionUp = connectionState == 'UP';

                              return ListTile(
                                title: Text('$roomName ($roomId)'),
                                subtitle: Text(
                                  'Relay channel: $channel | Connection: $connectionState | Last action: $status | Device: $deviceState',
                                ),
                                leading: Icon(
                                  isConnectionUp ? Icons.link : Icons.link_off,
                                  color: isConnectionUp ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _controlRoomPower(roomId, 'ON'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                      child: const Text('ON'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _controlRoomPower(roomId, 'OFF'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                                      child: const Text('OFF'),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildOverviewGrid(ThemeData theme, int mappedRelayCount) {
    final totalUsage = _overview['total_usage_kwh']?.toString() ?? '0';
    final activeRooms = _overview['active_rooms']?.toString() ?? '0';
    final totalRooms = _overview['total_rooms']?.toString() ?? '0';
    final efficiency = _overview['efficiency_percent']?.toString() ?? '0';

    // Show only live mapped rooms (online + known state).
    final hasRelayMappings = mappedRelayCount > 0;
    final relayDisplayValue = '$mappedRelayCount';
    final relayIsConnected = _hasRelayConnection;

    final cards = [
      _MetricCard(
        title: 'Live Campus Usage',
        value: _hasSensorData ? '$totalUsage kWh' : 'No Data',
        icon: Icons.bolt,
        color: _hasSensorData ? Colors.amber.shade700 : Colors.grey.shade600,
        isDisconnected: !_hasSensorData,
      ),
      _MetricCard(
        title: 'Active Rooms',
        value: _hasSensorData ? '$activeRooms/$totalRooms' : 'Disconnected',
        icon: Icons.meeting_room_outlined,
        color: _hasSensorData ? Colors.blue.shade700 : Colors.grey.shade600,
        isDisconnected: !_hasSensorData,
      ),
      _MetricCard(
        title: 'Efficiency',
        value: _hasSensorData ? '$efficiency%' : '--',
        icon: Icons.insights_outlined,
        color: _hasSensorData ? Colors.green.shade700 : Colors.grey.shade600,
        isDisconnected: !_hasSensorData,
      ),
      _MetricCard(
        title: 'Mapped Relay Rooms',
        value: relayDisplayValue,
        icon: Icons.settings_remote_outlined,
        color: (hasRelayMappings && relayIsConnected)
            ? Colors.deepPurple.shade700
            : Colors.grey.shade600,
        isDisconnected: !hasRelayMappings || !relayIsConnected,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 800
                ? 2
                : 1;
        final ratio = width >= 1200
            ? 3.6
            : width >= 800
                ? 3.0
                : 2.6;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: ratio,
          ),
          itemBuilder: (_, i) => cards[i],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDisconnected;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isDisconnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDisconnected ? Colors.grey.shade100 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDisconnected ? Colors.grey.shade600 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDisconnected ? Colors.grey.shade700 : null,
                        ),
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
