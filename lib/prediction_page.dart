import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:energia/widgets/energy_visualization_widgets.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:math';

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  Map<String, dynamic>? _prediction;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  int _intervalMinutes = 5; // fixed to 5 minutes horizon
  DateTime? _lastUpdated;
  static const String _roomName = 'CS-201';

  String _roomToDeviceId(String roomName) {
    final r = roomName.trim().toUpperCase().replaceAll(' ', '');
    if (r.startsWith('ESP32-')) return r;
    if (r.startsWith('CS-')) return 'ESP32-CS-C${r.split('-').last}';
    if (r.startsWith('CS') && r.length > 2) return 'ESP32-CS-C${r.substring(2)}';
    return r;
  }

  double _sensorPower(Map<String, dynamic> m) {
    return (m['power'] as num?)?.toDouble() ??
        (m['value'] as num?)?.toDouble() ??
        (m['energy'] as num?)?.toDouble() ??
        0.0;
  }

  @override
  void initState() {
    super.initState();
    _fetchPrediction();
    // Auto-refresh every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchPrediction());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrediction() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<String> apiCandidates = [
        'http://localhost:5000',
        'http://127.0.0.1:5000',
      ];
      
      for (final baseUrl in apiCandidates) {
        try {
          // STEP 1: Fetch latest sensor data from database
          print('🔍 Fetching latest sensor data from $baseUrl');
          final deviceId = _roomToDeviceId(_roomName);
          final sensorResponse = await http.get(
            Uri.parse('$baseUrl/sensor-data?limit=1&device_id=${Uri.encodeComponent(deviceId)}'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('Sensor data request timed out');
          });

          if (sensorResponse.statusCode != 200) continue;

          final sensorData = jsonDecode(sensorResponse.body);
          final sensorReadings = (sensorData['data'] as List?) ?? [];

          if (sensorReadings.isEmpty) {
            print('⚠️ No sensor data available');
            continue;
          }

          final latestSensor = sensorReadings.first as Map<String, dynamic>;
          final latestPower = _sensorPower(latestSensor);
          print('✅ Latest sensor data: ${latestPower.toStringAsFixed(1)}W at ${latestSensor['timestamp']}');

          // STEP 2: Get prediction using the timestamp from sensor data
          print('🔮 Getting prediction for timestamp: ${latestSensor['timestamp']}');
          final predResponse = await http.post(
            Uri.parse('$baseUrl/model/predict_15min'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'horizon_minutes': _intervalMinutes,
              'room_name': _roomName,
            }),
          ).timeout(const Duration(seconds: 5), onTimeout: () {
            throw TimeoutException('Prediction request timed out');
          });

          if (predResponse.statusCode != 200) continue;

          final prediction = jsonDecode(predResponse.body);
          print('✅ Got prediction: ${prediction['yhat']}W');

          // Merge sensor data into prediction
          prediction['latest_sensor_reading'] = latestSensor;
          prediction['latest_sensor_reading']['power'] = latestPower;
          prediction['latest_sensor_timestamp'] = latestSensor['timestamp'];
          prediction['has_live_sensor_data'] = true;

          if (!mounted) return;
          setState(() {
            _prediction = prediction;
            _isLoading = false;
            _lastUpdated = DateTime.now();
          });
          return;
        } catch (e) {
          if (e is TimeoutException) {
            print('⏱️ Timeout with $baseUrl - trying next...');
          } else {
            print('❌ Error with $baseUrl: $e');
          }
          continue;
        }
      }

      // No data from any backend
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No sensor data available - sensor appears to be disconnected';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _fetchLatestSensorData(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sensor-data?limit=1'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Request timed out');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final latestSensor = data['data'][0];
          if (mounted) {
            setState(() {
              _prediction?['latest_sensor_reading'] = latestSensor;
              _prediction?['sensor_data_available'] = true;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching sensor data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Energy Prediction'),
        backgroundColor: const Color(0xFF1B2A3B),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPrediction,
        child: _isLoading && _prediction == null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 280, child: Center(child: CircularProgressIndicator())),
                ],
              )
            : _errorMessage != null && _prediction == null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 360,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                              const SizedBox(height: 16),
                              Text(_errorMessage!, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(
                                'Pull down to refresh',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Section
                        _buildHeader(theme, scheme),
                        const SizedBox(height: 24),

                        _buildIntervalControls(theme, scheme),
                        const SizedBox(height: 12),

                        _buildInfoRow(theme),
                        const SizedBox(height: 24),

                        // Main Prediction Card
                        if (_prediction != null) ...[
                          _buildPredictionCardNew(theme, scheme),
                          const SizedBox(height: 24),

                          // Confidence and Range Chart
                          _buildConfidenceChart(theme, scheme),
                          const SizedBox(height: 24),

                          // Prediction Timeline
                          _buildTimelineChart(theme, scheme),
                          const SizedBox(height: 24),

                          // Details Section
                          _buildDetailsSection(theme, scheme),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EnergyColorScheme.infoTeal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.insights, color: EnergyColorScheme.infoTeal, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Energy Consumption Forecast',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI-powered prediction for next 15 minutes',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prophet model trained on 6 months of historical consumption data',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalControls(ThemeData theme, ColorScheme scheme) {
    // Horizon selection disabled; fixed to 5 minutes for clarity
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Forecast horizon:',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: const Text(
            '5 min (fixed)',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme) {
    final lastUpdateText = _lastUpdated != null
        ? DateFormat('h:mm a').format(_lastUpdated!)
        : '—';
    final livePower = _prediction?['latest_sensor_reading']?['power'] ??
      _prediction?['latest_sensor_reading']?['value'];
    final livePowerText = livePower != null ? '${(livePower as num).toStringAsFixed(2)} kW' : 'No live data';

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _infoChip(Icons.schedule, 'Last update', lastUpdateText),
        _infoChip(Icons.timelapse, 'Horizon', '5 min ahead'),
        _infoChip(Icons.power, 'Live power', livePowerText),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _buildPredictionCardNew(ThemeData theme, ColorScheme scheme) {
    // Handle both old field names and new API field names
    final yhat = _prediction!['yhat'] as num? ?? _prediction!['predicted_energy'] as num? ?? 3.5;
    final yhatLower = _prediction!['yhat_lower'] as num? ?? _prediction!['lower_bound'] as num?;
    final yhatUpper = _prediction!['yhat_upper'] as num? ?? _prediction!['upper_bound'] as num?;
    
    final predictedEnergy = (yhat as num).toDouble();
    final lowerBound = (yhatLower as num? ?? predictedEnergy * 0.8).toDouble();
    final upperBound = (yhatUpper as num? ?? predictedEnergy * 1.2).toDouble();
    
    // Extract live sensor data if available
    dynamic latestSensor = _prediction!['latest_sensor_reading'];
    double currentEnergy = 0;
    String sensorStatus = 'No recent data';
    String lastUpdate = '';
    
    if (latestSensor != null) {
      if (latestSensor is Map) {
        currentEnergy = (latestSensor['value'] as num?)?.toDouble() ?? 0;
        lastUpdate = latestSensor['timestamp'] as String? ?? '';
        if (lastUpdate.isNotEmpty) {
          try {
            final dt = DateTime.parse(lastUpdate);
            final now = DateTime.now();
            final diff = now.difference(dt);
            if (diff.inSeconds < 120) {
              sensorStatus = 'Live (${diff.inSeconds}s ago)';
            } else if (diff.inMinutes < 60) {
              sensorStatus = 'Recent (${diff.inMinutes}m ago)';
            } else {
              sensorStatus = '${diff.inHours}h ago';
            }
          } catch (e) {
            sensorStatus = 'Latest reading available';
          }
        }
      }
    }

    return _buildSimplePredictionCard(
      theme, 
      scheme, 
      currentEnergy > 0 ? currentEnergy : 3.2, 
      predictedEnergy,
      currentEnergy > 0,
      sensorStatus,
    );
  }

  Widget _buildSimplePredictionCard(
    ThemeData theme,
    ColorScheme scheme,
    double currentUsage,
    double predictedUsage,
    bool hasLiveData,
    String sensorStatus,
  ) {
    // Calculate the difference
    final difference = predictedUsage - currentUsage;
    final percentChange = (difference / currentUsage * 100).abs();
    
    // Determine status and message
    String statusTitle;
    String statusMessage;
    Color statusColor;
    IconData statusIcon;
    
    if (difference > currentUsage * 0.2) {
      // Predicted is >20% higher - HIGH ALERT
      statusTitle = '⚠️ Look Out!';
      statusMessage = 'Energy usage will increase significantly in the next 5 minutes';
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
    } else if (difference > 0) {
      // Predicted is higher but moderate - CAUTION
      statusTitle = '📊 Going Well';
      statusMessage = 'Usage is expected to rise slightly. Everything is normal';
      statusColor = Colors.orange;
      statusIcon = Icons.trending_up;
    } else if (difference < 0) {
      // Predicted is lower - GOOD TREND
      statusTitle = '✅ Keep the Good Trend!';
      statusMessage = 'Great! Energy usage is decreasing. Keep it up!';
      statusColor = Colors.green;
      statusIcon = Icons.trending_down;
    } else {
      // About the same - STABLE
      statusTitle = '📊 Stable Usage';
      statusMessage = 'Energy consumption is steady';
      statusColor = Colors.blue;
      statusIcon = Icons.remove;
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.12),
              const Color(0xFFF8FBFF),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          statusMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF1F2937),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Current vs Predicted
            Row(
              children: [
                Expanded(
                  child: _buildValueBox(
                    theme,
                    'Current Usage',
                    '${currentUsage.toStringAsFixed(0)} W',
                    Colors.blue,
                    Icons.flash_on,
                    hasLiveData ? '📡 Live' : '⚠️ No Data',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildValueBox(
                    theme,
                    'Next 5 Min',
                    '${predictedUsage.toStringAsFixed(0)} W',
                    statusColor,
                    Icons.show_chart,
                    difference > 0 ? '+${percentChange.toStringAsFixed(0)}%' : '${percentChange.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Change Indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    difference > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    difference > 0
                        ? 'Usage will increase by ${difference.toStringAsFixed(0)} W'
                        : 'Usage will decrease by ${difference.abs().toStringAsFixed(0)} W',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            
            if (hasLiveData) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Based on live sensor data',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValueBox(
    ThemeData theme,
    String label,
    String value,
    Color color,
    IconData icon,
    String badge,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceChart(ThemeData theme, ColorScheme scheme) {
    if (_prediction == null) return const SizedBox.shrink();

    // Check if we have actual live sensor data
    final hasLiveData = _prediction!['has_live_sensor_data'] == true;
    
    if (!hasLiveData) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.signal_wifi_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Historical Trend Chart',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No live sensor data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Chart will display when sensor is connected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Get sensor reading if available
    final sensorReading = _prediction!['latest_sensor_reading'];
    if (sensorReading == null) {
      return const SizedBox.shrink();
    }

    final yhat = _prediction!['yhat'] as num? ?? 0;
    final yhatLower = _prediction!['yhat_lower'] as num? ?? 0;
    final yhatUpper = _prediction!['yhat_upper'] as num? ?? 0;

    // Clamp negatives to zero to avoid showing negative power
    final predictedPower = max(0.0, yhat.toDouble());
    final lowerBound = max(0.0, yhatLower.toDouble());
    final upperBound = max(0.0, yhatUpper.toDouble());
    
    // Create data points: lower, predicted, upper
    final spots = [
      FlSpot(0, lowerBound),
      FlSpot(1, predictedPower),
      FlSpot(2, upperBound),
    ];

    final maxValue = [predictedPower, upperBound, lowerBound].reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue <= 0 ? 10.0 : maxValue;
    final maxY = safeMax * 1.2;
    final minY = 0.0;
    final yInterval = max(10.0, (maxY / 4));

    return Card(
      color: const Color(0xFF0F172A),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Prediction Confidence Range',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.circle, size: 8, color: Color(0xFF16A34A)),
                      SizedBox(width: 6),
                      Text(
                        'Live Data',
                        style: TextStyle(
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: const Color(0xFF2A3142),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toStringAsFixed(0)}W',
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('Lower', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600));
                          if (value == 1) return const Text('Predicted', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600));
                          if (value == 2) return const Text('Upper', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600));
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: Colors.transparent,
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          const colors = [
                            Color(0xFFF59E0B), // amber lower
                            Color(0xFF0EA5E9), // blue predicted
                            Color(0xFFEF4444), // red upper
                          ];
                          final c = colors[index.clamp(0, 2)];
                          return FlDotCirclePainter(
                            radius: 9,
                            color: c,
                            strokeWidth: 2.5,
                            strokeColor: const Color(0xFF0B1220),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  minX: -0.4,
                  maxX: 2.4,
                  minY: minY,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          String label = 'Value';
                          if (spot.x == 0) label = 'Lower bound';
                          if (spot.x == 1) label = 'Predicted';
                          if (spot.x == 2) label = 'Upper bound';
                          return LineTooltipItem(
                            '$label\n${spot.y.toStringAsFixed(1)} W',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shows lower, predicted, and upper bounds for the next 5 minutes',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildTimelineChart(ThemeData theme, ColorScheme scheme) {
    if (_prediction == null) return const SizedBox.shrink();
    
    // Check if we have actual live sensor data
    final hasLiveData = _prediction!['has_live_sensor_data'] == true;
    
    if (!hasLiveData) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.signal_wifi_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Confidence Interval',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No live sensor data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Chart will display when sensor is connected',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final yhat = _prediction!['yhat'] as num? ?? 0;
    final yhatLower = _prediction!['yhat_lower'] as num? ?? 0;
    final yhatUpper = _prediction!['yhat_upper'] as num? ?? 0;
    
    final predicted = yhat.toDouble();
    final lower = yhatLower.toDouble();
    final upper = yhatUpper.toDouble();
    
    // Calculate confidence percentage
    final range = upper - lower;
    final confidence = range > 0 ? ((predicted - lower) / range * 100).clamp(0, 100) : 50.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Prediction Confidence Range',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Live Data',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceEvenly,
                  maxY: upper * 1.15,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label;
                        switch (groupIndex) {
                          case 0:
                            label = 'Lower Bound';
                            break;
                          case 1:
                            label = 'Predicted';
                            break;
                          case 2:
                            label = 'Upper Bound';
                            break;
                          default:
                            label = '';
                        }
                        return BarTooltipItem(
                          '$label\n${rod.toY.toStringAsFixed(1)}W',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
                          const titles = ['Lower\nBound', 'Predicted\nValue', 'Upper\nBound'];
                          if (value.toInt() < titles.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                titles[value.toInt()],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: upper / 4,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toStringAsFixed(0)}W',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: upper / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                      left: BorderSide(color: Colors.grey.shade400, width: 1),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: lower,
                          color: Colors.orange.shade400,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: predicted,
                          color: EnergyColorScheme.primaryBlue,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: upper,
                          color: Colors.red.shade400,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EnergyColorScheme.infoTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.insights, size: 20, color: EnergyColorScheme.infoTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The prediction will likely fall within this range with ${confidence.toStringAsFixed(0)}% confidence',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: EnergyColorScheme.infoTeal,
                        fontWeight: FontWeight.w500,
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


  Widget _buildPredictionCard(ThemeData theme, ColorScheme scheme) {
    final yhat = _prediction!['yhat'] as num? ?? _prediction!['predicted_energy'] as num? ?? 0;
    final yhatLower = _prediction!['yhat_lower'] as num? ?? _prediction!['lower_bound'] as num? ?? 0;
    final yhatUpper = _prediction!['yhat_upper'] as num? ?? _prediction!['upper_bound'] as num? ?? 0;
    
    final predictedEnergy = (yhat as num).toDouble();
    final lowerBound = (yhatLower as num).toDouble();
    final upperBound = (yhatUpper as num).toDouble();
    final timestamp = _prediction!['timestamp'] as String;

    // Determine status color based on predicted value
    Color statusColor = Colors.green;
    String status = 'Normal';
    IconData statusIcon = Icons.check_circle;

    if (predictedEnergy > 5.0) {
      statusColor = Colors.red;
      status = 'High Usage';
      statusIcon = Icons.warning;
    } else if (predictedEnergy > 3.5) {
      statusColor = Colors.orange;
      status = 'Moderate';
      statusIcon = Icons.info;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [statusColor.withOpacity(0.1), statusColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Predicted Usage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  predictedEnergy.toStringAsFixed(2),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'kWh',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBoundValue('Lower', lowerBound, Colors.blue),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.shade300,
                      ),
                      _buildBoundValue('Upper', upperBound, Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Forecast time: ${_formatTime(timestamp)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoundValue(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            'kWh',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizationChart(ThemeData theme, ColorScheme scheme) {
    if (_prediction == null) return const SizedBox.shrink();

    final yhat = _prediction!['yhat'] as num? ?? _prediction!['predicted_energy'] as num? ?? 0;
    final yhatLower = _prediction!['yhat_lower'] as num? ?? _prediction!['lower_bound'] as num? ?? 0;
    final yhatUpper = _prediction!['yhat_upper'] as num? ?? _prediction!['upper_bound'] as num? ?? 0;
    
    final predictedEnergy = (yhat as num).toDouble();
    final lowerBound = (yhatLower as num).toDouble();
    final upperBound = (yhatUpper as num).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prediction Range Visualization',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: upperBound * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return const Text('Lower\nBound', textAlign: TextAlign.center, style: TextStyle(fontSize: 10));
                            case 1:
                              return const Text('Predicted\nValue', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold));
                            case 2:
                              return const Text('Upper\nBound', textAlign: TextAlign.center, style: TextStyle(fontSize: 10));
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: lowerBound,
                          color: Colors.blue.shade400,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: predictedEnergy,
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade700],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: upperBound,
                          color: Colors.red.shade400,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.blue.shade400, 'Lower Bound'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.green.shade600, 'Predicted'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.red.shade400, 'Upper Bound'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(ThemeData theme, ColorScheme scheme) {
    final generatedAt = _prediction!['generated_at'] as String;
    
    // Extract live sensor data if available
    dynamic latestSensor = _prediction!['latest_sensor_reading'];
    double voltage = 0;
    double current = 0;
    double power = 0;
    double powerFactor = 0;
    bool hasSensorData = false;
    
    if (latestSensor != null && latestSensor is Map) {
      voltage = (latestSensor['value'] as num?)?.toDouble() ?? 0;
      current = (latestSensor['current'] as num?)?.toDouble() ?? 0;
      power = (latestSensor['power'] as num?)?.toDouble() ?? 0;
      powerFactor = (latestSensor['power_factor'] as num?)?.toDouble() ?? 0;
      hasSensorData = power > 0;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prediction Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.timeline, 'Horizon', '15 minutes', theme),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.model_training, 'Model', 'Prophet (Facebook)', theme),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.update, 'Generated At', _formatTime(generatedAt), theme),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.psychology, 'Confidence', 'High', theme),
            
            // Show live sensor data if available
            if (hasSensorData) ...[
              const SizedBox(height: 24),
              Divider(color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Live Sensor Data (ESP32)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: EnergyColorScheme.successGreen,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.electric_bolt, 
                    size: 20, 
                    color: EnergyColorScheme.warningOrange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Power',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Text(
                    '${power.toStringAsFixed(1)} W',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (voltage > 0)
                Row(
                  children: [
                    Icon(Icons.electrical_services, 
                      size: 20, 
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Voltage',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Text(
                      '${voltage.toStringAsFixed(1)} V',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (voltage > 0) const SizedBox(height: 8),
              if (current > 0)
                Row(
                  children: [
                    Icon(Icons.power, 
                      size: 20, 
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Current',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Text(
                      '${current.toStringAsFixed(2)} A',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (current > 0) const SizedBox(height: 8),
              if (powerFactor > 0)
                Row(
                  children: [
                    Icon(Icons.tune, 
                      size: 20, 
                      color: Colors.purple.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Power Factor',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Text(
                      '${powerFactor.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasSensorData 
                        ? 'Predictions use live ESP32 sensor data updated every 60 seconds'
                        : 'Predictions update every 5 minutes automatically',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
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

  Widget _buildDetailRow(IconData icon, String label, String value, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
