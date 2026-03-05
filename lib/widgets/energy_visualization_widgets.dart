import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// ============================================================================
/// UNIFIED ENERGY VISUALIZATION WIDGET LIBRARY
/// Provides consistent, reusable chart components for all user types
/// ============================================================================

// Color Scheme for Energy Visualizations
class EnergyColorScheme {
  static const primaryBlue = Color(0xFF005BBB);
  static const darkHeader = Color(0xFF1B2A3B);
  static const successGreen = Color(0xFF4CAF50);
  static const warningOrange = Color(0xFFFFA726);
  static const criticalRed = Color(0xFFEF5350);
  static const infoTeal = Color(0xFF26C6DA);
  
  static List<Color> get chartGradient => [
    const Color(0xFF005BBB),
    const Color(0xFF0288D1),
    const Color(0xFF29B6F6),
  ];
  
  static Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return criticalRed;
      case 'medium':
      case 'warning':
        return warningOrange;
      case 'info':
      case 'low':
        return infoTeal;
      default:
        return successGreen;
    }
  }
}

/// ============================================================================
/// LIVE ENERGY METER - Real-time single device/room display
/// ============================================================================
class LiveEnergyMeter extends StatelessWidget {
  final double currentPower; // in kW
  final double maxCapacity; // in kW
  final String label;
  final String? status;
  final bool showTrend;
  final double? trendPercentage;
  final VoidCallback? onTap;

  const LiveEnergyMeter({
    super.key,
    required this.currentPower,
    required this.maxCapacity,
    required this.label,
    this.status,
    this.showTrend = true,
    this.trendPercentage,
    this.onTap,
  });

  Color get _powerColor {
    final percentage = (currentPower / maxCapacity) * 100;
    if (percentage >= 80) return EnergyColorScheme.criticalRed;
    if (percentage >= 60) return EnergyColorScheme.warningOrange;
    return EnergyColorScheme.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (currentPower / maxCapacity) * 100;
    
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceContainer,
                theme.colorScheme.surface,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with label and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (status != null)
                          Text(
                            status!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showTrend && trendPercentage != null)
                    Row(
                      children: [
                        Icon(
                          trendPercentage! > 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: trendPercentage! > 0
                              ? EnergyColorScheme.criticalRed
                              : EnergyColorScheme.successGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trendPercentage!.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: trendPercentage! > 0
                                ? EnergyColorScheme.criticalRed
                                : EnergyColorScheme.successGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Current Power Display - Raw sensor value in Watts
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currentPower.toStringAsFixed(2),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _powerColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Watts (W)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _powerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Capacity: ${maxCapacity.toStringAsFixed(2)} Watts',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),

              // Progress Bar with Label
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usage Level',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 12,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(_powerColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${percentage.toStringAsFixed(1)}% of capacity',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
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

/// ============================================================================
/// RESPONSIVE LINE CHART - Multi-period energy consumption
/// ============================================================================
class ResponsiveLineChart extends StatelessWidget {
  final List<FlSpot> spots;
  final String title;
  final String unit;
  final double maxY;
  final bool isMonthly;
  final Color lineColor;
  final VoidCallback? onRefresh;

  const ResponsiveLineChart({
    super.key,
    required this.spots,
    required this.title,
    this.unit = 'kWh',
    required this.maxY,
    this.isMonthly = false,
    this.lineColor = const Color(0xFF005BBB),
    this.onRefresh,
  });

  String _getLabel(double value) {
    if (isMonthly) {
      final monthIndex = value.toInt();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return monthIndex < months.length ? months[monthIndex] : '';
    } else {
      // Live views: index 0 is most recent, roughly 1-minute spacing; show wall-clock time in 12-hour format.
      final minutesAgo = value.toInt();
      final timestamp = DateTime.now().subtract(Duration(minutes: minutesAgo));
      return DateFormat('h:mm a').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive dimensions
    final chartWidth = isMonthly
        ? (screenWidth - 60) * 1.2
        : (screenWidth - 60);
    const chartHeight = 300.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      if (spots.isEmpty)
                        Text(
                          'No data available',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          isMonthly
                              ? 'Monthly trend (${spots.length} months)'
                              : 'Last ${spots.length} readings • Unit: $unit',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (spots.isNotEmpty && !isMonthly)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 8),
                        const SizedBox(width: 4),
                        Text(
                          '📡 Live Data',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (spots.isEmpty && !isMonthly)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.red, size: 8),
                        const SizedBox(width: 4),
                        Text(
                          '⚠️ No Data',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    tooltip: 'Refresh data',
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Chart or No Data Message
            if (spots.isEmpty)
              SizedBox(
                height: chartHeight,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 48,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Live Readings Available',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sensor is not connected or offline',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: chartHeight,
                  child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 5,
                      getDrawingHorizontalLine: (value) =>
                          const FlLine(color: Colors.grey, strokeWidth: 0.5),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        axisNameWidget: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            unit,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toStringAsFixed(0),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameWidget: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            isMonthly
                                ? 'Month'
                                : 'Time (newest on left)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                          interval: isMonthly ? 1 : 5,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _getLabel(value),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                            color: Colors.grey.shade300, width: 1),
                        left: BorderSide(
                            color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: lineColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: lineColor,
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              lineColor.withOpacity(0.3),
                              lineColor.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    minX: spots.first.x,
                    maxX: spots.last.x,
                    minY: 0,
                    maxY: maxY,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// ROOM GRID VISUALIZATION - Multiple rooms with live status
/// ============================================================================
class RoomEnergyGrid extends StatelessWidget {
  final List<Map<String, dynamic>> rooms;
  final void Function(String roomId)? onRoomTap;

  const RoomEnergyGrid({
    super.key,
    required this.rooms,
    this.onRoomTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return RoomEnergyCard(
          roomName: room['name'] as String,
          currentUsage: room['usage'] as double,
          maxCapacity: room['capacity'] as double,
          status: room['status'] as String?,
          onTap: () => onRoomTap?.call(room['id'] as String? ?? room['name'] as String),
        );
      },
    );
  }
}

/// ============================================================================
/// ROOM ENERGY CARD - Individual room visualization
/// ============================================================================
class RoomEnergyCard extends StatelessWidget {
  final String roomName;
  final double currentUsage;
  final double maxCapacity;
  final String? status;
  final VoidCallback? onTap;

  const RoomEnergyCard({
    super.key,
    required this.roomName,
    required this.currentUsage,
    required this.maxCapacity,
    this.status,
    this.onTap,
  });

  Color get _usageColor {
    final percentage = (currentUsage / maxCapacity) * 100;
    if (percentage >= 80) return EnergyColorScheme.criticalRed;
    if (percentage >= 60) return EnergyColorScheme.warningOrange;
    return EnergyColorScheme.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (currentUsage / maxCapacity) * 100;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              top: BorderSide(color: _usageColor, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Room Name
              Text(
                roomName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (status != null)
                Text(
                  status!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),

              // Usage Display - Raw sensor value in Watts
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    currentUsage.toStringAsFixed(2),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: _usageColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'W',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _usageColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Mini Progress Bar with label
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usage %',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(_usageColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade700,
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

/// ============================================================================
/// BAR CHART - Comparative energy usage
/// ============================================================================
class ComparativeBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final String title;
  final String unit;
  final double maxY;

  const ComparativeBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.title,
    this.unit = 'kWh',
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: Colors.grey, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          labels[value.toInt()],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.grey.shade300, width: 1),
                      left: BorderSide(
                          color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  barGroups: List.generate(
                    values.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: values[index],
                          color: EnergyColorScheme.primaryBlue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  maxY: maxY,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// ANOMALY ALERT CARD - Display detected anomalies
/// ============================================================================
class AnomalyAlertCard extends StatelessWidget {
  final String timestamp;
  final String event;
  final String severity;
  final VoidCallback? onTap;

  const AnomalyAlertCard({
    super.key,
    required this.timestamp,
    required this.event,
    required this.severity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = EnergyColorScheme.getSeverityColor(severity);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: severityColor.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_rounded, color: severityColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timestamp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  severity,
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// PREDICTION CARD - Display energy predictions
/// ============================================================================
class PredictionCard extends StatelessWidget {
  final double predictedUsage;
  final double currentUsage;
  final String timeframe;
  final double confidence;
  final bool liveDataAvailable;
  final String sensorStatus;

  const PredictionCard({
    super.key,
    required this.predictedUsage,
    required this.currentUsage,
    required this.timeframe,
    required this.confidence,
    this.liveDataAvailable = false,
    this.sensorStatus = 'No data',
  });

  Color get _confidenceColor {
    final validConfidence = confidence.clamp(0.0, 1.0);
    if (validConfidence >= 0.8) return EnergyColorScheme.successGreen;
    if (validConfidence >= 0.6) return EnergyColorScheme.warningOrange;
    return EnergyColorScheme.criticalRed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difference = predictedUsage - currentUsage;
    final percentDifference = (difference / currentUsage * 100);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              EnergyColorScheme.infoTeal.withOpacity(0.1),
              EnergyColorScheme.primaryBlue.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy Prediction',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Next $timeframe',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (liveDataAvailable) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: EnergyColorScheme.successGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radio_button_on, 
                              size: 10,
                              color: EnergyColorScheme.successGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sensorStatus,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: EnergyColorScheme.successGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Icon(Icons.trending_up, color: EnergyColorScheme.infoTeal),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current (Live)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currentUsage.toStringAsFixed(2),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'W',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: Colors.grey.shade400),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Predicted ($timeframe)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          predictedUsage.toStringAsFixed(2),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: difference > 0
                                ? EnergyColorScheme.criticalRed
                                : EnergyColorScheme.successGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'W',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: difference > 0
                                ? EnergyColorScheme.criticalRed
                                : EnergyColorScheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          difference > 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: difference > 0
                              ? EnergyColorScheme.criticalRed
                              : EnergyColorScheme.successGreen,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${percentDifference.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: difference > 0
                                ? EnergyColorScheme.criticalRed
                                : EnergyColorScheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Confidence',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.grey.shade300,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: confidence.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                color: _confidenceColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(confidence.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _confidenceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// DONUT CHART - Energy distribution
/// ============================================================================
class EnergyDistributionDonut extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final String title;

  const EnergyDistributionDonut({
    super.key,
    required this.labels,
    required this.values,
    required this.title,
  });

  List<Color> get chartColors => [
    const Color(0xFF005BBB),
    const Color(0xFF0288D1),
    const Color(0xFF29B6F6),
    const Color(0xFF42A5F5),
    const Color(0xFF64B5F6),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: List.generate(
                    labels.length,
                    (index) => PieChartSectionData(
                      value: values[index],
                      color: chartColors[index % chartColors.length],
                      title: '${(values[index] / values.reduce((a, b) => a + b) * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      radius: 60,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend
            Column(
              children: List.generate(
                labels.length,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color:
                              chartColors[index % chartColors.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          labels[index],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Text(
                        '${values[index].toStringAsFixed(1)} kWh',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
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
}

/// ============================================================================
/// STAT ROW - Display key metrics
/// ============================================================================
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color? color;

  const StatRow({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor = color ?? EnergyColorScheme.primaryBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: displayColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: displayColor, size: 24),
          ),
          const SizedBox(width: 16),
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
                  '$value $unit',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
