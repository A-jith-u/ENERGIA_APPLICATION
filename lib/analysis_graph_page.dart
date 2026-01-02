import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/energy_visualization_widgets.dart';

class AnalysisGraphPage extends StatefulWidget {
  final String title;
  final String type; // 'Monthly' or 'Daily'
  final Color color;

  const AnalysisGraphPage({
    super.key,
    required this.title,
    required this.type,
    required this.color,
  });

  // Define the consistent dark header color (0xFF1B2A3B)
  static const _headerColor = Color(0xFF1B2A3B);

  @override
  State<AnalysisGraphPage> createState() => _AnalysisGraphPageState();
}

class _AnalysisGraphPageState extends State<AnalysisGraphPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getLabel(double value, bool isMonthly) {
    if (isMonthly) {
      final monthIndex = value.toInt();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return monthIndex < months.length ? months[monthIndex] : '';
    } else {
      return '${(value.toInt())}h';
    }
  }

  List<FlSpot> getSpots() {
    if (widget.type == 'Monthly') {
      // Data for last 12 months
      return const [
        FlSpot(0, 150), FlSpot(1, 165), FlSpot(2, 140), FlSpot(3, 180),
        FlSpot(4, 155), FlSpot(5, 175), FlSpot(6, 190), FlSpot(7, 210),
        FlSpot(8, 185), FlSpot(9, 160), FlSpot(10, 145), FlSpot(11, 150),
      ];
    } else {
      // Data for 24 hours
      return const [
        FlSpot(0, 1.5), FlSpot(1, 1.8), FlSpot(2, 1.4), FlSpot(3, 2.5),
        FlSpot(4, 2.2), FlSpot(5, 3.5), FlSpot(6, 3.8), FlSpot(7, 3.0),
        FlSpot(8, 2.5), FlSpot(9, 4.1), FlSpot(10, 3.2), FlSpot(11, 2.8),
        FlSpot(12, 4.5), FlSpot(13, 4.2), FlSpot(14, 3.9), FlSpot(15, 4.7),
        FlSpot(16, 4.4), FlSpot(17, 3.8), FlSpot(18, 4.1), FlSpot(19, 3.5),
        FlSpot(20, 3.2), FlSpot(21, 2.9), FlSpot(22, 2.5), FlSpot(23, 2.2),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = getSpots();
    final yUnit = widget.type == 'Monthly' ? 'kWh' : 'kW';
    final yMax = widget.type == 'Monthly' ? 250.0 : 5.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AnalysisGraphPage._headerColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          onTap: (index) {
            setState(() => _currentTab = index);
          },
          tabs: const [
            Tab(text: 'Line Chart'),
            Tab(text: 'Bar Chart'),
            Tab(text: 'Statistics'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consumption Profile (CS-201)',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.type == 'Monthly'
                  ? 'Historical consumption data over 12 months'
                  : 'Hourly consumption breakdown for today',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 30),
            
            // Tab View
            _buildTabContent(_currentTab, spots, yMax, yUnit, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex, List<FlSpot> spots, double yMax, String yUnit, ThemeData theme) {
    switch (tabIndex) {
      case 0:
        return _buildLineChart(spots, yMax, yUnit, theme);
      case 1:
        return _buildBarChart(spots, yMax, yUnit, theme);
      case 2:
        return _buildStatistics(spots, theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLineChart(List<FlSpot> spots, double yMax, String yUnit, ThemeData theme) {
    final chartWidth = widget.type == 'Monthly'
        ? (MediaQuery.of(context).size.width - 60) * 1.2
        : (MediaQuery.of(context).size.width - 60);

    return Column(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth,
                height: 300,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yMax / 5,
                      getDrawingHorizontalLine: (value) =>
                          const FlLine(color: Colors.grey, strokeWidth: 0.5),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(yUnit, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(0),
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: widget.type == 'Monthly' ? 1 : 3,
                          getTitlesWidget: (value, meta) => Text(
                            _getLabel(value, widget.type == 'Monthly'),
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                        left: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: widget.color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: widget.color,
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withOpacity(0.3),
                              widget.color.withOpacity(0.0),
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
                    maxY: yMax,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<FlSpot> spots, double yMax, String yUnit, ThemeData theme) {
    final labels = widget.type == 'Monthly'
        ? const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        : List.generate(24, (i) => '${i}h');
    
    final values = spots.map((spot) => spot.y).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bar Chart View',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: Colors.grey, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          labels[value.toInt() % labels.length],
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                      left: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  barGroups: List.generate(
                    values.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: values[index],
                          color: widget.color,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ),
                  maxY: yMax,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics(List<FlSpot> spots, ThemeData theme) {
    final values = spots.map((spot) => spot.y).toList();
    final total = values.fold<double>(0, (prev, curr) => prev + curr);
    final average = total / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);

    return Column(
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Energy Consumption Statistics',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                StatRow(
                  label: 'Total Consumption',
                  value: total.toStringAsFixed(1),
                  unit: widget.type == 'Monthly' ? 'kWh' : 'kWh',
                  icon: Icons.electric_bolt_outlined,
                  color: widget.color,
                ),
                const Divider(height: 24),
                StatRow(
                  label: 'Average Usage',
                  value: average.toStringAsFixed(2),
                  unit: widget.type == 'Monthly' ? 'kWh/month' : 'kWh/hour',
                  icon: Icons.trending_up_outlined,
                  color: Colors.blue,
                ),
                const Divider(height: 24),
                StatRow(
                  label: 'Peak Consumption',
                  value: max.toStringAsFixed(1),
                  unit: widget.type == 'Monthly' ? 'kWh' : 'kW',
                  icon: Icons.show_chart_outlined,
                  color: Colors.red,
                ),
                const Divider(height: 24),
                StatRow(
                  label: 'Minimum Usage',
                  value: min.toStringAsFixed(1),
                  unit: widget.type == 'Monthly' ? 'kWh' : 'kW',
                  icon: Icons.trending_down_outlined,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}