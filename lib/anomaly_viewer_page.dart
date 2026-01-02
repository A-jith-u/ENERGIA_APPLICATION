import 'package:flutter/material.dart';
import 'widgets/energy_visualization_widgets.dart';

class AnomalyViewerPage extends StatelessWidget {
  const AnomalyViewerPage({super.key});

  // Sample data simulating the anomaly report list
  final List<Map<String, dynamic>> anomalies = const [
    {'time': 'Dec 10, 11:30 PM', 'event': 'AC run time exceeded threshold (7 kWh)', 'severity': 'High', 'location': 'CS-Lab 1', 'type': 'Consumption'},
    {'time': 'Dec 08, 08:15 AM', 'event': 'Usage spike during non-occupancy hours', 'severity': 'Medium', 'location': 'CS-201', 'type': 'Anomaly'},
    {'time': 'Nov 25, 02:00 PM', 'event': 'Voltage fluctuation detected (Device 302)', 'severity': 'Low', 'location': 'Server Room', 'type': 'Hardware'},
    {'time': 'Nov 20, 06:00 PM', 'event': 'Occupancy mismatch (Lights left on)', 'severity': 'Medium', 'location': 'CS-Lab 2', 'type': 'Occupancy'},
    {'time': 'Nov 15, 09:00 PM', 'event': 'PIR sensor reported offline status', 'severity': 'High', 'location': 'CS-Lab 3', 'type': 'Sensor'},
  ];

  // Define the consistent dark header color
  static const _headerColor = Color(0xFF1B2A3B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly Detection Report'),
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Anomalies',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${anomalies.length}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Critical Issues',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '2',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Recent Detected Anomalies',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Anomaly List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: anomalies.map((anomaly) {
                return AnomalyAlertCard(
                  timestamp: anomaly['time'].toString(),
                  event: anomaly['event'].toString(),
                  severity: anomaly['severity'].toString(),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // Statistics Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anomaly Distribution by Type',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDistributionRow('Consumption', 2, Colors.orange),
                        const SizedBox(height: 12),
                        _buildDistributionRow('Occupancy', 1, Colors.blue),
                        const SizedBox(height: 12),
                        _buildDistributionRow('Sensor', 1, Colors.red),
                        const SizedBox(height: 12),
                        _buildDistributionRow('Hardware', 1, Colors.purple),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String label, int count, Color color) {
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(label),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}