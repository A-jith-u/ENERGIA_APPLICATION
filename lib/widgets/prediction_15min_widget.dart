import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';

/// Widget for displaying 15-minute energy prediction with live sensor data
class Prediction15MinWidget extends StatefulWidget {
  final String? userToken;
  final bool showHeader;
  final String? roomName;

  const Prediction15MinWidget({
    super.key,
    this.userToken,
    this.showHeader = true,
    this.roomName,
  });

  @override
  State<Prediction15MinWidget> createState() => _Prediction15MinWidgetState();
}

class _Prediction15MinWidgetState extends State<Prediction15MinWidget> {
  Map<String, dynamic>? _predictionData;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _fetchPrediction();
    // Auto-refresh every 2 minutes
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _fetchPrediction(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrediction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<String> apiCandidates = [
        'http://localhost:5000',
        'http://127.0.0.1:5000',
        'http://localhost:5000',
        'http://10.0.2.2:5000',
      ];

      for (final baseUrl in apiCandidates) {
        try {
          final uri = Uri.parse(
            '$baseUrl/model/predict_15min_detailed',
          ).replace(
            queryParameters: {
              if (widget.roomName != null) 'room_name': widget.roomName!,
            },
          );

          final response = await http
              .get(uri, headers: {'Content-Type': 'application/json'})
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  throw TimeoutException('Prediction request timed out');
                },
              );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (!mounted) return;
            setState(() {
              _predictionData = data;
              _isLoading = false;
              _lastUpdated = DateTime.now();
            });
            return;
          }
        } catch (e) {
          if (e is TimeoutException) {
            print('⏱️ Timeout with $baseUrl - trying next...');
          } else {
            print('Error: $e');
          }
          continue;
        }
      }

      // No data from any backend
      setState(() {
        _errorMessage = 'Unable to fetch prediction data';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_isLoading && _predictionData == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: scheme.primary),
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null && _predictionData == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_predictionData == null) {
      return const SizedBox.shrink();
    }

    final predictions =
        (_predictionData!['predictions'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final summary = _predictionData!['summary'] as Map<String, dynamic>? ?? {};
    final latestReading = _predictionData!['latest_reading'] as num? ?? 0;
    final hasLiveData = _predictionData!['has_live_data'] == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚡ 15-Min Energy Forecast',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI-powered prediction using live sensor data',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasLiveData)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Live Data',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Key metrics row
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    context,
                    'Now',
                    '${latestReading.toStringAsFixed(0)}W',
                    Icons.flash_on,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricBox(
                    context,
                    'Trend',
                    (summary['trend'] as String? ?? 'stable').replaceFirst(
                      summary['trend']![0],
                      summary['trend']![0].toUpperCase(),
                    ),
                    _getTrendIcon(summary['trend'] as String? ?? ''),
                    _getTrendColor(summary['trend'] as String? ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricBox(
                    context,
                    'Change',
                    '${(summary['trend_percentage'] as num? ?? 0).toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Prediction chart
            if (predictions.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildPredictionChart(context, theme, predictions),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Details grid
            Row(
              children: [
                Expanded(
                  child: _buildDetailCell(
                    context,
                    'Max',
                    '${(summary['max_power'] as num? ?? 0).toStringAsFixed(0)}W',
                    Icons.arrow_upward,
                    Colors.red.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCell(
                    context,
                    'Avg',
                    '${(summary['avg_power'] as num? ?? 0).toStringAsFixed(0)}W',
                    Icons.show_chart,
                    Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCell(
                    context,
                    'Min',
                    '${(summary['min_power'] as num? ?? 0).toStringAsFixed(0)}W',
                    Icons.arrow_downward,
                    Colors.green.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Info text
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Forecast is updated every 2 minutes',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.blue.shade800,
                      ),
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

  Widget _buildMetricBox(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCell(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionChart(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> predictions,
  ) {
    final spots =
        predictions.asMap().entries.map((entry) {
          return FlSpot(
            entry.key.toDouble(),
            (entry.value['yhat'] as num?)?.toDouble() ?? 0,
          );
        }).toList();

    final maxY = predictions
        .map((p) => (p['yhat_upper'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final minY = max(
      0.0,
      predictions
          .map((p) => (p['yhat_lower'] as num?)?.toDouble() ?? 0)
          .reduce((a, b) => a < b ? a : b),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 150,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: max(10.0, (maxY - minY) / 4),
                getDrawingHorizontalLine:
                    (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 0.5,
                      dashArray: [5, 5],
                    ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget:
                        (value, meta) => Text(
                          '${value.toStringAsFixed(0)}W',
                          style: theme.textTheme.labelSmall,
                        ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: max(
                      1,
                      (predictions.length / 4).ceil().toDouble(),
                    ),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < predictions.length) {
                        return Text(
                          '${index + 1}m',
                          style: theme.textTheme.labelSmall,
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
                  color: Colors.blue.shade600,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: predictions.length <= 10,
                    getDotPainter:
                        (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue.shade600,
                          strokeWidth: 0,
                        ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.1),
                  ),
                ),
              ],
              minX: 0,
              maxX: (predictions.length - 1).toDouble(),
              minY: minY,
              maxY: maxY * 1.1,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTrendIcon(String trend) {
    switch (trend.toLowerCase()) {
      case 'increasing':
        return Icons.trending_up;
      case 'decreasing':
        return Icons.trending_down;
      default:
        return Icons.remove;
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend.toLowerCase()) {
      case 'increasing':
        return Colors.red;
      case 'decreasing':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}
