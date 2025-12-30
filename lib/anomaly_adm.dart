import 'package:flutter/material.dart';
import 'services/notifier.dart';

class Anomaly extends StatelessWidget {
  const Anomaly({super.key});

  // Sample data simulating the anomaly report list
  final List<Map<String, dynamic>> anomalies = const [
    {'time': 'Dec 10, 11:30 PM', 'event': 'AC run time exceeded threshold (7 kWh)', 'severity': 'High'},
    {'time': 'Dec 08, 08:15 AM', 'event': 'Usage spike during non-occupancy hours', 'severity': 'Medium'},
    {'time': 'Nov 25, 02:00 PM', 'event': 'Voltage fluctuation detected (Device 302)', 'severity': 'Low'},
    {'time': 'Nov 20, 06:00 PM', 'event': 'Occupancy mismatch (Lights left on)', 'severity': 'Medium'},
    {'time': 'Nov 15, 09:00 PM', 'event': 'PIR sensor reported offline status', 'severity': 'High'},
  ];

  // Define the consistent dark header color
  static const _headerColor = Color(0xFF1B2A3B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomaly Report'),
        // --- MODIFIED: Changed background color to the specified dark blue ---
        backgroundColor: _headerColor,
        // --- END MODIFIED ---
        foregroundColor: Colors.white,
        // --- MODIFIED: Added IconButton to AppBar actions ---
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            tooltip: 'Download Anomaly Log',
            onPressed: () => AppNotifier.showInfo(context, 'Downloading Anomaly Log (CSV)...'),
          ),
        ],
        // --- END MODIFIED ---
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
               
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: anomalies.length,
              itemBuilder: (context, index) {
                final anomaly = anomalies[index];
                Color severityColor;
                switch (anomaly['severity']) {
                  case 'High':
                    severityColor = Colors.red.shade600;
                    break;
                  case 'Medium':
                    severityColor = Colors.orange.shade600;
                    break;
                  default:
                    severityColor = Colors.grey.shade600;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.error_outline, color: severityColor, size: 30),
                    title: Text(anomaly['event'].toString(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('Time: ${anomaly['time']}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(anomaly['severity'].toString(), style: TextStyle(color: severityColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}