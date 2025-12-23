import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; 
// Import the target dashboard page
import 'adm_cspage.dart'; 

class Elect extends StatelessWidget {
  const Elect({super.key});

  // Sample data for Electrical Classrooms
  final List<Map<String, dynamic>> classrooms = const [
    {'name': 'EE-202', 'status': 'Active', 'usage_kw': 3.1, 'color': Colors.green},
    {'name': 'EE-404', 'status': 'Alert', 'usage_kw': 5.2, 'color': Colors.red},
    {'name': 'EE-Lab 1', 'status': 'Offline', 'usage_kw': 0.0, 'color': Colors.grey},
    {'name': 'EE-Seminar Hall', 'status': 'Optimal', 'usage_kw': 1.5, 'color': Colors.blue},
    {'name': 'EE-301', 'status': 'Moderate', 'usage_kw': 4.5, 'color': Colors.orange},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Electrical Classrooms'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Room-Level Energy Monitoring',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Detailed view of classrooms with real-time usage breakdown.',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          
          // 1. List of Classroom Cards (Simplified)
          ...classrooms.map((room) {
            return _ClassroomCard(
              name: room['name'] as String,
              status: room['status'] as String,
              usage: (room['usage_kw'] as double).toStringAsFixed(1) + ' kW',
              color: room['color'] as Color,
            );
          }).toList(),

          const SizedBox(height: 40),

          // 2. Aggregate Pie Chart (New Section)
          Text(
            'Energy Distribution Among Classrooms',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: _ClassroomEnergyDistributionChart(classrooms: classrooms),
          ),
        ],
      ),
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  final String name;
  final String status;
  final String usage;
  final Color color;

  const _ClassroomCard({
    required this.name,
    required this.status,
    required this.usage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2, // Matched admin card elevation
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12), // Matched admin card vertical spacing
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // ACTION: Navigate to the shared Admin/CR Dashboard page (Dash)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Dash()), 
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Reduced vertical padding for compact look
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Classroom Icon/Status
              Container(
                padding: const EdgeInsets.all(8), // Reduced padding
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.class_outlined, color: color, size: 28), // Adjusted size
              ),
              const SizedBox(width: 16),
              
              // 2. Name and Usage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), // Match ListTile style
                    ),
                    Text(
                      'Live: $usage',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              
              // 3. Status Tag (Compact and aligned right)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Matched admin tag padding
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      status,
                      style: theme.textTheme.bodyMedium?.copyWith(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Removed the extra Icon and spacing to maintain compact size
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassroomEnergyDistributionChart extends StatelessWidget {
  final List<Map<String, dynamic>> classrooms;

  const _ClassroomEnergyDistributionChart({required this.classrooms});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate total usage
    final totalUsage = classrooms.fold<double>(0, (sum, room) => sum + (room['usage_kw'] as double));

    // 2. Create PieChartSections
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];
    
    // Assign colors and create sections
    classrooms.asMap().forEach((index, room) {
      final usage = room['usage_kw'] as double;
      final name = room['name'] as String;
      final color = room['color'] as Color;
      final percentage = totalUsage > 0 ? (usage / totalUsage) * 100 : 0.0;
      
      // Only include sections with positive usage in the chart
      if (usage > 0) {
        sections.add(
          PieChartSectionData(
            value: usage,
            color: color,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: totalUsage > 0 ? null : null,
          ),
        );
      }
      
      // Create legend item regardless of usage
      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, color: color),
              const SizedBox(width: 8),
              Text(
                '$name (${usage.toStringAsFixed(1)} kW)',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    });

    if (totalUsage == 0) {
       sections.add(
          PieChartSectionData(
            value: 1.0,
            color: Colors.grey.shade300,
            title: '0%',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pie Chart
        SizedBox(
          width: 150,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 3,
              centerSpaceRadius: 0,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Total Live Usage: ${totalUsage.toStringAsFixed(1)} kW',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...legendItems,
            ],
          ),
        ),
      ],
    );
  }
}