import 'package:flutter/material.dart';
import 'widgets/recommendation_widgets.dart';

class RecommendationsPage extends StatefulWidget {
  final String? userToken;

  const RecommendationsPage({super.key, this.userToken});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  String _filterPriority = 'all';
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Recommendations'),
        backgroundColor: const Color(0xFF1B2A3B),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                if (value.startsWith('priority_')) {
                  _filterPriority = value.replaceFirst('priority_', '');
                } else if (value.startsWith('type_')) {
                  _filterType = value.replaceFirst('type_', '');
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'priority_all',
                child: Text('All Priorities'),
              ),
              const PopupMenuItem(
                value: 'priority_critical',
                child: Text('Critical Only'),
              ),
              const PopupMenuItem(
                value: 'priority_high',
                child: Text('High Priority'),
              ),
              const PopupMenuItem(
                value: 'priority_medium',
                child: Text('Medium Priority'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'type_all',
                child: Text('All Types'),
              ),
              const PopupMenuItem(
                value: 'type_immediate',
                child: Text('Immediate Actions'),
              ),
              const PopupMenuItem(
                value: 'type_preventive',
                child: Text('Preventive'),
              ),
              const PopupMenuItem(
                value: 'type_optimization',
                child: Text('Optimization'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.surfaceContainerLowest, scheme.surfaceContainerHigh],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filter chips
              if (_filterPriority != 'all' || _filterType != 'all') ...[
                Wrap(
                  spacing: 8,
                  children: [
                    if (_filterPriority != 'all')
                      FilterChip(
                        label: Text('Priority: $_filterPriority'),
                        onSelected: (_) => setState(() => _filterPriority = 'all'),
                        selected: true,
                      ),
                    if (_filterType != 'all')
                      FilterChip(
                        label: Text('Type: $_filterType'),
                        onSelected: (_) => setState(() => _filterType = 'all'),
                        selected: true,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Recommendations list
              RecommendationsList(
                userToken: widget.userToken,
                showHeader: true,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
