// ignore_for_file: deprecated_member_use, file_names, unused_field, unused_local_variable
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class PredictionComparisonPage extends StatefulWidget {
  final String roomName;
  const PredictionComparisonPage({super.key, required this.roomName});

  @override
  State<PredictionComparisonPage> createState() =>
      _PredictionComparisonPageState();
}

class _PredictionComparisonPageState extends State<PredictionComparisonPage> {
  bool _loading = false;
  String? _error;
  String? _authToken;

  // Prediction data
  DateTime? _predictedForLocal;
  double? _predictedW;
  double? _predictedLower;
  double? _predictedUpper;
  double? _actualW;
  DateTime? _actualAtLocal;
  bool _isLiveDataBased = false;

  // Live sensor tracking
  double? _latestLivePowerW;
  DateTime? _latestLiveTime;
  double? _avgPower24h;
  double? _maxPower24h;
  double? _minPower24h;
  String? _trendDirection; // 'increasing', 'decreasing', 'stable'
  double? _accuracyPercent;

  Timer? _autoRefreshTimer;
  int _refreshCountdown = 60;
  DateTime? _lastUpdateTime;

  final Duration _targetWindow = const Duration(minutes: 6);

  List<String> _baseCandidates() => const [
    'http://localhost:5000',
    'http://127.0.0.1:5000',
    'http://localhost:5000',
    'http://10.0.2.2:5000',
  ];

  String _roomToDeviceId(String roomName) {
    final r = roomName.trim().toUpperCase().replaceAll(' ', '');
    if (r.startsWith('ESP32-')) return r;
    if (r.startsWith('CS-')) return 'ESP32-CS-C${r.split('-').last}';
    if (r.startsWith('CS') && r.length > 2) {
      return 'ESP32-CS-C${r.substring(2)}';
    }
    return r;
  }

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    _startAutoRefresh();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      try {
        JwtDecoder.decode(token);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _authToken = token;
        });
      } else {
        _authToken = token;
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_refreshCountdown > 0) {
          _refreshCountdown--;
        }
      });
    });
  }

  DateTime? _parseSensorDsLocal(dynamic ts) {
    if (ts == null) return null;
    final s = ts.toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  DateTime? _parseIsoToLocal(dynamic ts) {
    if (ts == null) return null;
    final s = ts.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  DateTime? _parseTimestamp(dynamic ts) {
    return _parseSensorDsLocal(ts) ?? _parseIsoToLocal(ts);
  }

  String _extractBackendDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } catch (_) {
      // Ignore parse errors and use fallback message.
    }
    return 'Prediction is temporarily unavailable.';
  }

  double _parsePowerW(Map<String, dynamic> reading) {
    final power =
        (reading['power'] as num?)?.toDouble() ??
        (reading['value'] as num?)?.toDouble() ??
        (reading['energy'] as num?)?.toDouble() ??
        0.0;
    return power;
  }

  Future<void> _fetchPrediction5Min() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _predictedForLocal = null;
      _predictedW = null;
      _predictedLower = null;
      _predictedUpper = null;
      _actualW = null;
    });

    for (final base in _baseCandidates()) {
      try {
        final uris = [Uri.parse('$base/model/predict_5min')];

        for (final uri in uris) {
          try {
            debugPrint('🔍 Fetching prediction from: $uri');

            final body = jsonEncode({
              'horizon_minutes': 5,
              'room_name': widget.roomName,
            });
            final headers = {
              'Content-Type': 'application/json',
              if (_authToken != null) 'Authorization': 'Bearer $_authToken',
            };

            http.Response resp;
            try {
              resp = await http
                  .post(uri, headers: headers, body: body)
                  .timeout(
                    const Duration(seconds: 5),
                    onTimeout: () {
                      throw TimeoutException('Request timed out');
                    },
                  );
            } catch (_) {
              resp = await http
                  .get(uri, headers: headers)
                  .timeout(
                    const Duration(seconds: 5),
                    onTimeout: () {
                      throw TimeoutException('Request timed out');
                    },
                  );
            }

            if (resp.statusCode == 409) {
              final detail = _extractBackendDetail(resp.body);
              if (!mounted) return;
              setState(() {
                _loading = false;
                _error = detail;
              });
              return;
            }

            if (resp.statusCode != 200) continue;

            final respBody = jsonDecode(resp.body) as Map<String, dynamic>;
            final when = _parseIsoToLocal(
              respBody['timestamp'] ?? respBody['ds'],
            );

            final yhatValue =
                respBody['yhat'] ??
                respBody['predicted_energy'] ??
                respBody['predicted'];
            final yhat = yhatValue is num ? yhatValue.toDouble() : null;

            final lowerValue =
                respBody['yhat_lower'] ?? respBody['lower_bound'];
            final lower = lowerValue is num ? lowerValue.toDouble() : null;

            final upperValue =
                respBody['yhat_upper'] ?? respBody['upper_bound'];
            final upper = upperValue is num ? upperValue.toDouble() : null;

            final isLiveBased =
                respBody['based_on_live_data'] as bool? ?? false;

            debugPrint('✅ Prediction received: yhat=$yhat');

            if (when == null || yhat == null) {
              debugPrint('❌ Missing required fields');
              continue;
            }

            await _fetchLiveData();

            if (!mounted) return;
            setState(() {
              _predictedForLocal = when;
              _predictedW = yhat;
              _predictedLower = lower;
              _predictedUpper = upper;
              _isLiveDataBased = isLiveBased;
              _lastUpdateTime = DateTime.now();
              _refreshCountdown = 60;
              _loading = false;
            });
            return;
          } catch (e) {
            debugPrint('❌ Error: $e');
            continue;
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error =
          'Could not fetch prediction. Please check your server connection.';
    });
  }

  Future<void> _fetchLiveData() async {
    final deviceId = _roomToDeviceId(widget.roomName);
    for (final base in _baseCandidates()) {
      try {
        final uri = Uri.parse(
          '$base/api/sensor-data?limit=120&device_id=${Uri.encodeComponent(deviceId)}',
        );
        final headers = {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        };
        final resp = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode != 200) continue;

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final readings = (body['data'] as List?) ?? [];
        if (readings.isEmpty) continue;

        // Get latest reading
        final latest = readings.first as Map<String, dynamic>;
        final latestPower = _parsePowerW(latest);
        final latestTime = _parseTimestamp(latest['ds'] ?? latest['timestamp']);

        // Calculate statistics (last 24 hours of data)
        List<double> powerValues = [];
        for (final r in readings) {
          final reading = r as Map<String, dynamic>;
          powerValues.add(_parsePowerW(reading));
        }

        double avgPower = 0;
        double maxPower = 0;
        double minPower = 0;

        if (powerValues.isNotEmpty) {
          avgPower = powerValues.reduce((a, b) => a + b) / powerValues.length;
          maxPower = powerValues.reduce((a, b) => a > b ? a : b);
          minPower = powerValues.reduce((a, b) => a < b ? a : b);
        }

        // Determine trend
        String trend = 'stable';
        if (powerValues.length > 5) {
          final recentAvg = powerValues.take(5).reduce((a, b) => a + b) / 5;
          final oldAvg =
              powerValues.skip(powerValues.length - 5).reduce((a, b) => a + b) /
              5;
          if (recentAvg > oldAvg * 1.1) {
            trend = 'increasing';
          } else if (recentAvg < oldAvg * 0.9) {
            trend = 'decreasing';
          }
        }

        if (!mounted) return;
        setState(() {
          _latestLivePowerW = latestPower;
          _latestLiveTime = latestTime;
          _avgPower24h = avgPower;
          _maxPower24h = maxPower;
          _minPower24h = minPower;
          _trendDirection = trend;
        });

        return;
      } catch (e) {
        debugPrint('Error fetching live data: $e');
        continue;
      }
    }
  }

  Future<void> _fetchActualForPredictedTime() async {
    final target = _predictedForLocal;
    if (target == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _actualW = null;
    });

    for (final base in _baseCandidates()) {
      try {
        final uri = Uri.parse(
          '$base/api/sensor-data?limit=120&room=${Uri.encodeComponent(widget.roomName)}',
        );
        final headers = {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        };
        final resp = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));

        if (resp.statusCode != 200) continue;

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final readings = (body['data'] as List?) ?? [];
        if (readings.isEmpty) continue;

        Map<String, dynamic>? best;
        Duration? bestDelta;

        for (final item in readings) {
          final r = item as Map<String, dynamic>;
          final ts = _parseTimestamp(r['ds'] ?? r['timestamp'] ?? r['ts']);
          if (ts == null) continue;
          final delta = ts.difference(target).abs();
          if (delta > _targetWindow) continue;

          if (best == null || (bestDelta != null && delta < bestDelta)) {
            best = r;
            bestDelta = delta;
          }
        }

        if (best != null) {
          final actualPower = _parsePowerW(best);
          final predicted = _predictedW ?? 0;

          // Calculate accuracy
          double accuracy = 100;
          if (predicted > 0 && actualPower > 0) {
            final error = ((predicted - actualPower).abs() / actualPower) * 100;
            accuracy = max(0, 100 - error);
          }

          setState(() {
            _actualW = actualPower;
            _accuracyPercent = accuracy;
            _loading = false;
            _error = null;
          });
          return;
        }

        setState(() {
          _loading = false;
          _error =
              'No sensor reading near predicted time. Data may still be collecting.';
        });
        return;
      } catch (e) {
        debugPrint('Error fetching actual data: $e');
        continue;
      }
    }

    setState(() {
      _loading = false;
      _error = 'Could not fetch sensor data. Check connection.';
    });
  }

  Color _getStatusColor(double value, double limit) {
    if (value > limit * 0.8) return Colors.red;
    if (value > limit * 0.5) return Colors.orange;
    return Colors.green;
  }

  String _getTrendIcon(String? trend) {
    switch (trend) {
      case 'increasing':
        return '📈';
      case 'decreasing':
        return '📉';
      default:
        return '➡️';
    }
  }

  Color _getTrendColor(String? trend) {
    switch (trend) {
      case 'increasing':
        return Colors.orange;
      case 'decreasing':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '—';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardTextPrimary = isDark ? Colors.white : Colors.black87;
    final cardTextSecondary = isDark ? Colors.white70 : Colors.grey.shade700;
    final pred = _predictedW ?? 0;
    final act = _actualW;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Energy Forecast • ${widget.roomName}'),
            if (_lastUpdateTime != null)
              Text(
                'Updated: ${_formatTime(_lastUpdateTime)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade300),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPrediction5Min,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // ===== LIVE POWER READING =====
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Power Usage',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cardTextPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🔴 Live',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _latestLivePowerW?.toStringAsFixed(1) ?? '—',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(
                                    _latestLivePowerW ?? 0,
                                    100,
                                  ),
                                ),
                              ),
                              Text(
                                'Watts (W)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cardTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_trendDirection != null)
                              Row(
                                children: [
                                  Text(
                                    _getTrendIcon(_trendDirection),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _trendDirection ?? '—',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getTrendColor(_trendDirection),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(_latestLiveTime),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cardTextSecondary,
                              ),
                            ),
                            Text(
                              'Latest reading',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cardTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            label: 'Average (24h)',
                            value: _avgPower24h?.toStringAsFixed(1) ?? '—',
                            unit: 'W',
                            icon: '📊',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBox(
                            label: 'Peak (24h)',
                            value: _maxPower24h?.toStringAsFixed(1) ?? '—',
                            unit: 'W',
                            icon: '⬆️',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBox(
                            label: 'Low (24h)',
                            value: _minPower24h?.toStringAsFixed(1) ?? '—',
                            unit: 'W',
                            icon: '⬇️',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ===== FETCH BUTTONS ROW =====
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _fetchPrediction5Min,
                    icon: const Icon(Icons.insights),
                    label: const Text('Get Forecast'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed:
                        (_loading || _predictedW == null)
                            ? null
                            : _fetchActualForPredictedTime,
                    child: const Text('Compare'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ===== PREDICTION CARD =====
            if (_predictedW != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next 5 Minutes Forecast',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cardTextPrimary,
                            ),
                          ),
                          if (_isLiveDataBased)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '📡 Live Data',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '📚 Historical',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _predictedW?.toStringAsFixed(1) ?? '—',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextPrimary,
                                  ),
                                ),
                                Text(
                                  'Expected Power',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cardTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(_predictedForLocal),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cardTextSecondary,
                                ),
                              ),
                              Text(
                                'Prediction time',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cardTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_predictedLower != null &&
                          _predictedUpper != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Confidence Range',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '${_predictedLower!.toStringAsFixed(1)}W - ${_predictedUpper!.toStringAsFixed(1)}W',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ===== COMPARISON CARD =====
            if (_actualW != null)
              Card(
                elevation: 2,
                color:
                    _accuracyPercent != null && _accuracyPercent! > 80
                        ? Colors.green.shade50
                        : _accuracyPercent != null && _accuracyPercent! > 60
                        ? Colors.orange.shade50
                        : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Forecast Accuracy',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (_accuracyPercent != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    _accuracyPercent! > 80
                                        ? Colors.green
                                        : _accuracyPercent! > 60
                                        ? Colors.orange
                                        : Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_accuracyPercent!.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Predicted',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  _predictedW?.toStringAsFixed(1) ?? '—',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'W',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Icon(
                                Icons.compare_arrows,
                                size: 28,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Actual',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  _actualW?.toStringAsFixed(1) ?? '—',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'W',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Error',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '${((_predictedW ?? 0) - (_actualW ?? 0)).abs().toStringAsFixed(1)}W',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Difference',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '${(((_predictedW ?? 0) - (_actualW ?? 0)).abs() / (_actualW ?? 1) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ===== INSIGHTS CARD =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Insights',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cardTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InsightTile(
                      icon: '⚡',
                      title: 'Current Status',
                      description:
                          _latestLivePowerW != null
                              ? 'Using ${_latestLivePowerW!.toStringAsFixed(1)}W (${((_latestLivePowerW! / (_avgPower24h ?? 1) * 100).toStringAsFixed(0))}% of daily average)'
                              : 'Loading live data...',
                    ),
                    const SizedBox(height: 8),
                    if (_trendDirection != null)
                      _InsightTile(
                        icon: _getTrendIcon(_trendDirection),
                        title: 'Trend',
                        description:
                            _trendDirection == 'increasing'
                                ? 'Power usage is increasing - consider reducing load'
                                : _trendDirection == 'decreasing'
                                ? 'Power usage is decreasing - good energy management'
                                : 'Power usage is stable',
                      ),
                    const SizedBox(height: 8),
                    if (_accuracyPercent != null)
                      _InsightTile(
                        icon: '🎯',
                        title: 'Forecast Quality',
                        description:
                            _accuracyPercent! > 80
                                ? 'Excellent forecast - highly reliable for planning'
                                : _accuracyPercent! > 60
                                ? 'Good forecast - useful for decision making'
                                : 'Fair forecast - consider other factors',
                      ),
                  ],
                ),
              ),
            ),

            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String icon;
  final String title;
  final String description;

  const _InsightTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
