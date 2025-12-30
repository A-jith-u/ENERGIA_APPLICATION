import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Recommendation model
class Recommendation {
  final String id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String? action;
  final Map<String, dynamic> data;
  final String icon;
  final String timestamp;

  Recommendation({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.action,
    required this.data,
    required this.icon,
    required this.timestamp,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String,
      action: json['action'] as String?,
      data: json['data'] as Map<String, dynamic>? ?? {},
      icon: json['icon'] as String? ?? 'info',
      timestamp: json['timestamp'] as String,
    );
  }

  Color get priorityColor {
    switch (priority) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade700;
      case 'medium':
        return Colors.amber.shade700;
      case 'low':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  Color get backgroundColor {
    switch (priority) {
      case 'critical':
        return Colors.red.shade50;
      case 'high':
        return Colors.orange.shade50;
      case 'medium':
        return Colors.amber.shade50;
      case 'low':
        return Colors.blue.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData get iconData {
    switch (icon) {
      case 'warning':
        return Icons.warning;
      case 'bolt':
        return Icons.bolt;
      case 'power':
        return Icons.power;
      case 'trending_up':
        return Icons.trending_up;
      case 'show_chart':
        return Icons.show_chart;
      case 'nightlight':
        return Icons.nightlight_round;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'eco':
        return Icons.eco;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'check_circle':
        return Icons.check_circle;
      case 'sensors_off':
        return Icons.sensors_off;
      case 'person_add':
        return Icons.person_add;
      case 'person_off':
        return Icons.person_off;
      case 'warning_amber':
        return Icons.warning_amber;
      case 'summarize':
        return Icons.summarize;
      case 'compare_arrows':
        return Icons.compare_arrows;
      case 'meeting_room':
        return Icons.meeting_room;
      case 'assessment':
        return Icons.assessment;
      default:
        return Icons.info_outline;
    }
  }
}

/// Service to fetch recommendations
class RecommendationService {
  static const String baseUrl = 'http://localhost:8000/recommendations';

  static Future<List<Recommendation>> fetchRecommendations(String? token) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/recommendations'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List recList = data['recommendations'] as List;
        return recList.map((json) => Recommendation.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load recommendations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      return [];
    }
  }

  static Future<Map<String, int>> fetchRecommendationCount(String? token) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/recommendations/count'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'total': data['total'] as int? ?? 0,
          'critical': data['critical'] as int? ?? 0,
          'high': data['high'] as int? ?? 0,
          'medium': data['medium'] as int? ?? 0,
          'low': data['low'] as int? ?? 0,
        };
      }
    } catch (e) {
      print('Error fetching recommendation count: $e');
    }
    return {'total': 0, 'critical': 0, 'high': 0, 'medium': 0, 'low': 0};
  }
}

/// Widget to display a single recommendation card
class RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;
  final VoidCallback? onTap;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: recommendation.priorityColor.withOpacity(0.3),
              width: 1.5,
            ),
            color: recommendation.backgroundColor,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: recommendation.priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    recommendation.iconData,
                    color: recommendation.priorityColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              recommendation.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: recommendation.priorityColor,
                              ),
                            ),
                          ),
                          if (recommendation.priority == 'critical' ||
                              recommendation.priority == 'high')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: recommendation.priorityColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                recommendation.priority.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recommendation.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (recommendation.action != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 14,
                              color: recommendation.priorityColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              recommendation.action!,
                              style: TextStyle(
                                color: recommendation.priorityColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: recommendation.priorityColor,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget to display a compact recommendation list
class RecommendationsList extends StatefulWidget {
  final String? userToken;
  final bool showHeader;
  final int? maxItems;
  final VoidCallback? onSeeAllTap;

  const RecommendationsList({
    super.key,
    this.userToken,
    this.showHeader = true,
    this.maxItems,
    this.onSeeAllTap,
  });

  @override
  State<RecommendationsList> createState() => _RecommendationsListState();
}

class _RecommendationsListState extends State<RecommendationsList> {
  List<Recommendation> _recommendations = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
    // Auto-refresh every 3 minutes
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _fetchRecommendations(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recommendations = await RecommendationService.fetchRecommendations(
        widget.userToken,
      );
      
      if (mounted) {
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load recommendations';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayRecs = widget.maxItems != null
        ? _recommendations.take(widget.maxItems!).toList()
        : _recommendations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'Recommendations',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_recommendations.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_recommendations.length}',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.onSeeAllTap != null && _recommendations.length > 3)
                TextButton(
                  onPressed: widget.onSeeAllTap,
                  child: const Text('See All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        if (_isLoading && _recommendations.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_errorMessage != null && _recommendations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _fetchRecommendations,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_recommendations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'All good!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No recommendations at the moment',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...displayRecs.map((rec) => RecommendationCard(
                recommendation: rec,
                onTap: () => _showRecommendationDetails(context, rec),
              )),
      ],
    );
  }

  void _showRecommendationDetails(BuildContext context, Recommendation rec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: rec.priorityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      rec.iconData,
                      color: rec.priorityColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rec.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: rec.priorityColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rec.priority.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                rec.message,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (rec.action != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle action
                  },
                  icon: const Icon(Icons.touch_app),
                  label: Text(rec.action!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rec.priorityColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
              if (rec.data.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Additional Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...rec.data.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        Text(
                          entry.value.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
