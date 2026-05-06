// ignore_for_file: deprecated_member_use, file_names, use_build_context_synchronously, unused_local_variable
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Ensure this matches your project structure
import 'services/notifier.dart'; // Ensure this matches your project structure

class AnomalyViewerPage extends StatefulWidget {
  const AnomalyViewerPage({super.key});

  @override
  State<AnomalyViewerPage> createState() => _AnomalyViewerPageState();
}

class _AnomalyViewerPageState extends State<AnomalyViewerPage> {
  // State variables
  List<dynamic> _anomalies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDepartmentAnomalies();
  }

  // Define the consistent dark header color
  static const _headerColor = Color(0xFF1B2A3B);

  Future<void> _fetchDepartmentAnomalies() async {
    final prefs = await SharedPreferences.getInstance();
    // Get the department saved during login
    final department = prefs.getString('user_department') ?? "";

    try {
      // Replace with your actual backend URL or use your Config class
      final response = await http.get(
        Uri.parse(
          'http://your-api-url:5000/coordinator/alerts?department=$department',
        ),
        headers: {'Authorization': 'Bearer ${prefs.getString('auth_token')}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _anomalies = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load anomalies');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      AppNotifier.showError(context, "Failed to load department alerts");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Anomalies'),
        backgroundColor: _headerColor,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchDepartmentAnomalies,
                child: Column(
                  children: [
                    // Header Summary Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: _headerColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'Total',
                            _anomalies.length.toString(),
                            Colors.white,
                          ),
                          _buildStatItem(
                            'High',
                            _countBySeverity('High'),
                            Colors.redAccent,
                          ),
                          _buildStatItem(
                            'Medium',
                            _countBySeverity('Medium'),
                            Colors.orangeAccent,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _anomalies.isEmpty
                              ? const Center(
                                child: Text(
                                  "No anomalies detected for your department",
                                ),
                              )
                              : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _anomalies.length,
                                itemBuilder: (context, index) {
                                  final anomaly = _anomalies[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange,
                                      ),
                                      title: Text(
                                        anomaly['description'] ??
                                            'Energy Anomaly',
                                      ),
                                      subtitle: Text(
                                        'Time: ${anomaly['timestamp']}',
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
    );
  }

  String _countBySeverity(String severity) {
    return _anomalies.where((a) => a['severity'] == severity).length.toString();
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
