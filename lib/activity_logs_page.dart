// ignore_for_file: deprecated_member_use, file_names, unused_field, unused_local_variable
import 'package:flutter/material.dart';
import 'package:energia/services/api.dart' as api;
import 'dart:async';

/// Full-page activity logs viewer
class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  State<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  int _currentPage = 0;
  final int _itemsPerPage = 15; // Reduced from 20 to reduce payload and lag
  int _totalItems = 0;
  final String _selectedFilter = 'all';
  String _selectedStatus = 'all';
  int _selectedDays = 7;
  int _retryCount = 0;
  final int _maxRetries = 1;

  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadActivityLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadActivityLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _retryCount = 0;
    await _loadActivityLogsWithRetry();
  }

  Future<void> _loadActivityLogsWithRetry() async {
    try {
      final logs = await api
          .getActivityLogs(limit: _itemsPerPage, days: _selectedDays)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              throw TimeoutException('Activity logs request timed out');
            },
          );

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _totalItems = logs.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      // Retry logic with exponential backoff
      if (_retryCount < _maxRetries && e is TimeoutException) {
        _retryCount++;
        final backoffSeconds = (2 * _retryCount);
        debugPrint(
          '[Activity Logs] Timeout retry $_retryCount/$_maxRetries after ${backoffSeconds}s...',
        );
        await Future.delayed(Duration(seconds: backoffSeconds));
        if (mounted) {
          await _loadActivityLogsWithRetry();
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          String errorMsg = 'Error loading logs: $e';
          if (e is TimeoutException && _retryCount >= _maxRetries) {
            errorMsg =
                'The activity logs server is not responding. Please try again in a few moments.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  DateTime? _parseTimestamp(String timestamp) {
    if (timestamp.isEmpty) return null;

    final hasTz = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(timestamp);
    final normalized =
        timestamp.contains('T') ? timestamp : timestamp.replaceFirst(' ', 'T');

    final iso = hasTz ? normalized : '${normalized}Z';
    return DateTime.tryParse(iso)?.toLocal();
  }

  String _getTimeAgo(String timestamp) {
    try {
      final logTime = _parseTimestamp(timestamp);
      if (logTime == null) return 'unknown';

      final now = DateTime.now();
      final difference = now.difference(logTime);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return logTime.toString().split(' ')[0];
      }
    } catch (e) {
      return 'unknown';
    }
  }

  IconData _getActionIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'data_submission':
        return Icons.assignment_turned_in;
      case 'report_generation':
        return Icons.assessment;
      case 'alert':
        return Icons.warning;
      case 'warning':
        return Icons.info;
      case 'user_creation':
        return Icons.person_add;
      case 'user_deletion':
        return Icons.person_remove;
      default:
        return Icons.history;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'failure':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerLow,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Days filter
                  DropdownButton<int>(
                    value: _selectedDays,
                    items: [
                      const DropdownMenuItem(value: 1, child: Text('Last 24h')),
                      const DropdownMenuItem(
                        value: 7,
                        child: Text('Last 7 days'),
                      ),
                      const DropdownMenuItem(
                        value: 30,
                        child: Text('Last 30 days'),
                      ),
                      const DropdownMenuItem(
                        value: 90,
                        child: Text('Last 90 days'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDays = value;
                          _currentPage = 0;
                        });
                        _loadActivityLogs();
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  // Status filter
                  DropdownButton<String>(
                    value: _selectedStatus,
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Status'),
                      ),
                      const DropdownMenuItem(
                        value: 'success',
                        child: Text('Success'),
                      ),
                      const DropdownMenuItem(
                        value: 'failure',
                        child: Text('Failure'),
                      ),
                      const DropdownMenuItem(
                        value: 'warning',
                        child: Text('Warning'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStatus = value);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  // Pull down anywhere in the list to refresh
                  ElevatedButton(
                    onPressed: _loadActivityLogs,
                    child: const Text('Reload'),
                  ),
                ],
              ),
            ),
          ),
          // Logs list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadActivityLogs,
              child:
                  _isLoading
                      ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ],
                      )
                      : _logs.isEmpty
                      ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 240,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No activity logs found',
                                    style: theme.textTheme.bodyLarge,
                                  ),
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
                      : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final userName = log['user_name'] ?? 'Unknown User';
                          final action =
                              log['action_description'] ?? 'Unknown action';
                          final timestamp = log['timestamp'] ?? '';
                          final actionType = log['action_type'] ?? 'activity';
                          final status = log['status'] ?? 'success';
                          final department = log['department'];

                          return Card(
                            elevation: 1,
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getActionIcon(actionType),
                                  color: _getStatusColor(status),
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                userName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    action,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                            status,
                                          ).withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _getStatusColor(status),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (department != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            department,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Text(
                                _getTimeAgo(timestamp),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
