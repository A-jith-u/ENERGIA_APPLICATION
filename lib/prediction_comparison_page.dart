import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PredictionComparisonPage extends StatefulWidget {
  final String roomName;
  const PredictionComparisonPage({super.key, required this.roomName});

  @override
  State<PredictionComparisonPage> createState() => _PredictionComparisonPageState();
}

class _PredictionComparisonPageState extends State<PredictionComparisonPage> {
  bool _loading = false;
  String? _error;

  DateTime? _predictedForLocal;
  double? _predictedW;
  double? _actualW;
  DateTime? _actualAtLocal;
  bool _isLiveDataBased = false;  // Track if prediction uses live data

  // Change if your sensor cadence differs
  final Duration _targetWindow = const Duration(minutes: 6);

  // Both prediction + sensor live on port 5000
  List<String> _baseCandidates() => const [
        'http://localhost:5000',      // Try localhost first
        'http://127.0.0.1:5000',
        'http://192.168.160.1:5000',
        'http://10.0.2.2:5000',       // Try emulator last
      ];

  // Sensor "ds" example: 2026-01-10 12:36:46.135623  (NO timezone)
  // Treat as LOCAL time. Do NOT append 'Z'.
  DateTime? _parseSensorDsLocal(dynamic ts) {
    if (ts == null) return null;
    final s = ts.toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  // Prophet timestamp returned as ISO (usually with timezone) -> convert to local
  DateTime? _parseIsoToLocal(dynamic ts) {
    if (ts == null) return null;
    final s = ts.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  // Parse timestamp from various formats
  DateTime? _parseTimestamp(dynamic ts) {
    return _parseSensorDsLocal(ts) ?? _parseIsoToLocal(ts);
  }

  // Parse power value from reading (supports 'power', 'value', 'energy' fields)
  double _parsePowerW(Map<String, dynamic> reading) {
    final power = (reading['power'] as num?)?.toDouble() ??
        (reading['value'] as num?)?.toDouble() ??
        (reading['energy'] as num?)?.toDouble() ??
        0.0;
    return power;
  }

  Future<void> _fetchPrediction5Min() async {
    setState(() {
      _loading = true;
      _error = null;
      _predictedForLocal = null;
      _predictedW = null;
      _actualW = null;
      _actualAtLocal = null;
      _actualSeriesW = [];
      _predSeriesW = [];
      _isLiveDataBased = false;
    });

    for (final base in _baseCandidates()) {
      try {
        // Try with /model/ prefix first (mounted API), then without
        final uris = [
          Uri.parse('$base/model/predict_5min'),
          Uri.parse('$base/predict_5min'),
        ];
        
        for (final uri in uris) {
          try {
            print('🔍 Trying: $uri with room: ${widget.roomName}');
            
            // Send room_name in request body for live data context
            final body = jsonEncode({
              'horizon_minutes': 5,
              'room_name': widget.roomName,
            });
            
            http.Response resp;
            try {
              resp = await http.post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: body,
              ).timeout(const Duration(seconds: 5));
            } catch (_) {
              resp = await http.get(uri, headers: {'Content-Type': 'application/json'})
                .timeout(const Duration(seconds: 5));
            }

            print('📊 Response: ${resp.statusCode}');
            if (resp.statusCode != 200) continue;

            final respBody = jsonDecode(resp.body) as Map<String, dynamic>;
            final when = _parseIsoToLocal(respBody['timestamp'] ?? respBody['ds']);
            
            // Extract yhat safely - could be in different fields
            final yhatValue = respBody['yhat'] ?? respBody['predicted_energy'] ?? respBody['predicted'];
            final yhat = yhatValue is num ? yhatValue : null;
            
            // Check if this prediction is based on live data
            final isLiveBased = respBody['based_on_live_data'] as bool? ?? false;

            print('✅ Prediction received: yhat=$yhat, when=$when, live_based=$isLiveBased');
            
            if (when == null || yhat == null) {
              print('❌ Missing required fields: when=$when, yhat=$yhat');
              continue;
            }

            setState(() {
              _predictedForLocal = when;
              _predictedW = (yhat as num).toDouble();
              _isLiveDataBased = isLiveBased;
              _loading = false;
            });
            return;
          } catch (e) {
            print('❌ Error: $e');
            continue;
          }
        }
      } catch (_) {
        continue;
      }
    }

    setState(() {
      _loading = false;
      _error = 'Prediction endpoint not reachable on :5000. Ensure /model/predict_5min exists.';
    });
  }

  List<FlSpot> _actualSeriesW = [];
  List<FlSpot> _predSeriesW = [];

  Future<void> _fetchActualForPredictedTime() async {
    final target = _predictedForLocal;
    if (target == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _actualW = null;
      _actualSeriesW = [];
      _predSeriesW = [];
    });

    for (final base in _baseCandidates()) {
      try {
        final uri = Uri.parse('$base/sensor-data?limit=120&room=${Uri.encodeComponent(widget.roomName)}');
        final resp = await http.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) continue;

        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final readings = (body['data'] as List?) ?? [];
        if (readings.isEmpty) continue;

        // Build actual series (oldest -> newest)
        final ordered = readings.reversed.toList();
        final List<FlSpot> actual = [];
        for (int i = 0; i < ordered.length; i++) {
          final r = ordered[i] as Map<String, dynamic>;
          actual.add(FlSpot(i.toDouble(), _parsePowerW(r)));
        }

        // Find closest reading to predicted time (for the numeric comparison)
        Map<String, dynamic>? best;
        Duration? bestDelta;

        for (final item in readings) {
          final r = item as Map<String, dynamic>;
          final ts = _parseTimestamp(r['ds'] ?? r['timestamp'] ?? r['ts']);
          if (ts == null) continue;
          final delta = ts.difference(target).abs();
          if (delta > _targetWindow) continue;

          if (best == null || (bestDelta != null && delta < bestDelta!)) {
            best = r;
            bestDelta = delta;
          }
        }

        // Build predicted line segment at the end of the chart
        final predW = _predictedW ?? 0.0;
        final lastX = max(0, actual.length - 1).toDouble();
        final List<FlSpot> predLine = [
          FlSpot(lastX, predW),
          FlSpot(lastX + 5, predW), // “next 5 minutes” segment (visual)
        ];

        setState(() {
          _actualSeriesW = actual;
          _predSeriesW = predLine;
          _actualW = best != null ? _parsePowerW(best!) : null;
          _loading = false;
          _error = best == null
              ? 'No sensor reading near predicted time yet. Try again after a few minutes.'
              : null;
        });
        return;
      } catch (_) {
        continue;
      }
    }

    setState(() {
      _loading = false;
      _error = 'Could not fetch sensor data (check backend URL/room mapping).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pred = _predictedW;
    final act = _actualW;

    double? pctErr;
    if (pred != null && act != null && act > 0) {
      pctErr = ((pred - act).abs() / act) * 100.0;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Prediction vs Live • ${widget.roomName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Step 1: Get 5‑minute prediction', style: theme.textTheme.titleMedium),
                      const SizedBox(width: 8),
                      if (_isLiveDataBased)
                        Chip(
                          label: const Text('📡 Live Data', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.green.shade100,
                        )
                      else
                        Chip(
                          label: const Text('📊 Historical', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.shade100,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _loading ? null : _fetchPrediction5Min,
                    icon: const Icon(Icons.insights),
                    label: const Text('Fetch Prediction'),
                  ),
                  const SizedBox(height: 10),
                  Text('Predicted for: ${_predictedForLocal?.toString() ?? '—'}'),
                  Text('Predicted power: ${pred != null ? '${pred.toStringAsFixed(2)} W' : '—'}'),
                  if (_isLiveDataBased)
                    Text(
                      'ℹ️ Based on latest live sensor data (24h history)',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    )
                  else if (_predictedForLocal != null)
                    Text(
                      'ℹ️ Based on historical training data',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Step 2: Compare with live sensor reading', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: (_loading || _predictedForLocal == null) ? null : _fetchActualForPredictedTime,
                    icon: const Icon(Icons.sensors),
                    label: const Text('Fetch Actual Near Predicted Time'),
                  ),
                  const SizedBox(height: 10),
                  Text('Actual power: ${act != null ? '${act.toStringAsFixed(2)} W' : '—'}'),
                  Text('Absolute error: ${(pred != null && act != null) ? '${(pred - act).abs().toStringAsFixed(2)} W' : '—'}'),
                  Text('Percent error: ${pctErr != null ? '${pctErr.toStringAsFixed(2)}%' : '—'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (pred != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Power Comparison (Watts)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Predicted vs Actual • Live Sensor Data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 240,
                      child: BarChart(
                        BarChartData(
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, meta) {
                                  final label = v.toInt() == 0 ? 'Predicted' : 'Actual';
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(label),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: pred, color: theme.colorScheme.primary)]),
                            BarChartGroupData(
                              x: 1,
                              barRods: [
                                BarChartRodData(
                                  toY: act ?? 0,
                                  color: act == null ? theme.colorScheme.outline : theme.colorScheme.secondary,
                                ),
                              ],
                            ),
                          ],
                          maxY: max(pred, act ?? 0) * 1.2 + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 12),
          if (_actualSeriesW.isNotEmpty && _predSeriesW.isNotEmpty) _buildCompareChart(),
        ],
      ),
    );
  }

  // Neat standard chart: actual line + predicted dashed-like segment (simple flat segment)
  Widget _buildCompareChart() {
    final theme = Theme.of(context);
    final maxY = [
      ..._actualSeriesW.map((e) => e.y),
      ..._predSeriesW.map((e) => e.y),
      1.0
    ].reduce(max) * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Power Trend Over Time',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Unit: Watts (W) • Live Data Comparison',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LegendDot(color: theme.colorScheme.primary, label: 'Actual (sensor)'),
                const SizedBox(width: 16),
                _LegendDot(color: theme.colorScheme.secondary, label: 'Predicted (5 min)'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _actualSeriesW,
                      isCurved: true,
                      barWidth: 3,
                      color: theme.colorScheme.primary,
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: _predSeriesW,
                      isCurved: false,
                      barWidth: 3,
                      color: theme.colorScheme.secondary,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}