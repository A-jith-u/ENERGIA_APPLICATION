import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisGraphPage extends StatelessWidget {
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

  // Helper method to get the titles widget based on the graph type
  // --- MODIFIED: Added color parameter for white text ---
  Widget getBottomTitles(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.white); // Text color changed to white
    String text;

    if (type == 'Monthly') {
      // Monthly Graph: X-axis shows Month Labels (simulated for last 12 months)
      final monthIndex = value.toInt();
      switch (monthIndex) {
        case 0: text = 'Jan'; break;
        case 1: text = 'Feb'; break;
        case 2: text = 'Mar'; break;
        case 3: text = 'Apr'; break;
        case 4: text = 'May'; break;
        case 5: text = 'Jun'; break;
        case 6: text = 'Jul'; break;
        case 7: text = 'Aug'; break;
        case 8: text = 'Sep'; break;
        case 9: text = 'Oct'; break;
        case 10: text = 'Nov'; break;
        case 11: text = 'Dec'; break;
        default: text = ''; break;
      }
    } else {
      // Daily Graph: X-axis shows Date Labels (simulated for last 30 days)
      final dateIndex = value.toInt();
      final date = 30 - dateIndex; // Simulating dates 1 through 30 backwards
      text = date.toString();
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(text, style: style),
    );
  }
  // --- END MODIFIED ---

  // Helper function to generate sample data relevant to the type
  List<FlSpot> getSpots() {
    if (type == 'Monthly') {
      // Data for last 12 months (Index 0 = Jan, Index 11 = Dec)
      return const [
        FlSpot(0, 150), FlSpot(1, 165), FlSpot(2, 140), FlSpot(3, 180),
        FlSpot(4, 155), FlSpot(5, 175), FlSpot(6, 190), FlSpot(7, 210), // Summer peaks
        FlSpot(8, 185), FlSpot(9, 160), FlSpot(10, 145), FlSpot(11, 150),
      ];
    } else {
      // Data for last 30 days (Index 0 = 30 days ago, Index 29 = Today)
      // Simulating a more detailed, fluctuating daily usage profile
      return List.generate(30, (i) => FlSpot(i.toDouble(), 3.0 + (i % 7) * 0.5 + (i % 3) * 0.1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = getSpots();
    final xAxisCount = type == 'Monthly' ? 12 : 30; // Total number of points
    
    // Width calculation for horizontal scrolling: 
    final chartWidth = xAxisCount * (type == 'Monthly' ? 70.0 : 40.0); 

    final yUnit = type == 'Monthly' ? 'kWh' : 'kW';
    final yMax = type == 'Monthly' ? 250.0 : 7.0; // Adjusted max Y for monthly simulation

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
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
            
            const SizedBox(height: 30),
            
            // --- Horizontal Scroll View for the Graph ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth, // Set the width needed for scrolling
                height: 300,
                child: LineChart(
                  LineChartData(
                    // --- MODIFIED: Grid and Border colors for better contrast against dark fill area ---
                    gridData: FlGridData(
                      show: true, 
                      drawVerticalLine: false, 
                      horizontalInterval: yMax / 5, 
                      checkToShowHorizontalLine: (value) => true,
                      getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white30, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        // Axis name color changed to white
                        axisNameWidget: Text(yUnit, style: theme.textTheme.labelMedium?.copyWith(color: Colors.white)),
                        sideTitles: SideTitles(
                          showTitles: true, 
                          reservedSize: 40,
                          // Axis labels color changed to white
                          getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0), style: theme.textTheme.bodySmall?.copyWith(color: Colors.white))
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        axisNameSize: 20,
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1, // Show every label
                          getTitlesWidget: getBottomTitles, // Uses the function modified above
                        ),
                      ),
                    ),
                    // Border color changed to white30 (similar to grid)
                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.white30)),
                    // --- END MODIFIED ---
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        // Curve color: White
                        color: Colors.white, 
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          // Area color still uses the dynamic 'color' property passed to the widget
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.3), color.withOpacity(0.0)], 
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
            // --- End Horizontal Scroll View ---

            const SizedBox(height: 30),
            
            const SizedBox(height: 10),
           
          ],
        ),
      ),
    );
  }
}