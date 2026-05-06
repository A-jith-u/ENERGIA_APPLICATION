// ignore_for_file: deprecated_member_use, file_names, unused_element, unused_local_variable
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/api.dart' as api;
import 'services/user_lists.dart';
import 'services/notifier.dart';
import 'services/pdf_export.dart';

class DetailedCoordinatorsPage extends StatefulWidget {
  const DetailedCoordinatorsPage({super.key});

  @override
  State<DetailedCoordinatorsPage> createState() =>
      _DetailedCoordinatorsPageState();
}

class _DetailedCoordinatorsPageState extends State<DetailedCoordinatorsPage> {
  List<Map<String, dynamic>> _allCoordinators = [];
  bool _isLoading = false;
  String? _errorMessage;

  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  List<Map<String, dynamic>> _filteredCoordinators = [];

  @override
  void initState() {
    super.initState();
    // Subscribe to shared coordinators list
    UserListsStore.instance.coordinators.addListener(_onCoordinatorsChanged);
    // Initialize from cached store for instant display
    _allCoordinators = List<Map<String, dynamic>>.from(
      UserListsStore.instance.coordinators.value,
    );
    _filteredCoordinators = List.from(_allCoordinators);
    // Refresh in background
    _loadCoordinators();
  }

  void _onCoordinatorsChanged() {
    if (!mounted) return;
    setState(() {
      _allCoordinators = List<Map<String, dynamic>>.from(
        UserListsStore.instance.coordinators.value,
      );
      _filteredCoordinators =
          _allCoordinators.where((coordinator) {
            final name = coordinator['name']?.toString().toLowerCase() ?? '';
            final email = coordinator['email']?.toString().toLowerCase() ?? '';
            final searchLower = _searchController.text.toLowerCase();

            final matchesSearch =
                _searchController.text.isEmpty ||
                name.contains(searchLower) ||
                email.contains(searchLower);

            final lastLogin = coordinator['last_login']?.toString();
            bool isActiveFromLogin() {
              if (lastLogin == null) return false;
              try {
                final date = DateTime.parse(lastLogin);
                return DateTime.now().difference(date) <=
                    const Duration(days: 30);
              } catch (_) {
                return false;
              }
            }

            final isActive = isActiveFromLogin();
            final matchesStatus =
                _selectedStatus == 'All' ||
                (_selectedStatus == 'Active' && isActive) ||
                (_selectedStatus == 'Inactive' && !isActive);

            return matchesSearch && matchesStatus;
          }).toList();
    });
  }

  Future<void> _loadCoordinators() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await api.getCoordinators();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load coordinators: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    UserListsStore.instance.coordinators.removeListener(_onCoordinatorsChanged);
    super.dispose();
  }

  void _filterData() {
    if (!mounted) return;
    setState(() {
      _filteredCoordinators =
          _allCoordinators.where((coordinator) {
            final name = coordinator['name']?.toString().toLowerCase() ?? '';
            final email = coordinator['email']?.toString().toLowerCase() ?? '';
            final searchLower = _searchController.text.toLowerCase();

            final matchesSearch =
                _searchController.text.isEmpty ||
                name.contains(searchLower) ||
                email.contains(searchLower);
            final lastLogin = coordinator['last_login']?.toString();
            bool isActiveFromLogin() {
              if (lastLogin == null) return false;
              try {
                final date = DateTime.parse(lastLogin);
                return DateTime.now().difference(date) <=
                    const Duration(days: 30);
              } catch (_) {
                return false;
              }
            }

            final isActive = isActiveFromLogin();
            final matchesStatus =
                _selectedStatus == 'All' ||
                (_selectedStatus == 'Active' && isActive) ||
                (_selectedStatus == 'Inactive' && !isActive);

            return matchesSearch && matchesStatus;
          }).toList();
    });
  }

  Future<void> _exportToPdf() async {
    if (_filteredCoordinators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No coordinators to export')),
      );
      return;
    }

    const headers = [
      'Name',
      'Email',
      'Phone',
      'Department',
      'Status',
      'Last Login',
      'Joined Date',
    ];
    final rows =
        _filteredCoordinators.map((coordinator) {
          final phone = coordinator['phone']?.toString() ?? 'N/A';
          final lastLogin = coordinator['last_login']?.toString();
          final isActive =
              lastLogin != null
                  ? (DateTime.now().difference(DateTime.parse(lastLogin)) <=
                      const Duration(days: 30))
                  : false;
          final lastLoginStr =
              lastLogin != null
                  ? DateFormat(
                    'MMM d, yyyy h:mm a',
                  ).format(DateTime.parse(lastLogin))
                  : 'Never';
          final createdStr = coordinator['created_at']?.toString();
          final createdDate =
              createdStr != null
                  ? DateFormat('MMM d, yyyy').format(DateTime.parse(createdStr))
                  : 'N/A';

          return [
            coordinator['name']?.toString() ?? 'Unknown',
            coordinator['email']?.toString() ?? 'N/A',
            phone,
            coordinator['department']?.toString() ?? 'N/A',
            isActive ? 'Active' : 'Inactive',
            lastLoginStr,
            createdDate,
          ];
        }).toList();

    await exportTablePdfAutoSave(
      'Coordinators List',
      headers,
      rows,
      subtitle:
          'Exported on ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Coordinators'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor: theme.appBarTheme.backgroundColor ?? scheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? scheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 0,
        actions: [
          TextButton(onPressed: _loadCoordinators, child: const Text('Reload')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadCoordinators,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : _buildCoordinatorsList(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinatorsList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Department Coordinators',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_filteredCoordinators.length} ${_filteredCoordinators.length == 1 ? 'coordinator' : 'coordinators'}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),

        // Search and Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                ),
                onChanged: (_) => _filterData(),
              ),
            ),
            const SizedBox(width: 16),
            DropdownMenu<String>(
              initialSelection: _selectedStatus,
              label: const Text('Status'),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'All', label: 'All'),
                DropdownMenuEntry(value: 'Active', label: 'Active'),
                DropdownMenuEntry(value: 'Inactive', label: 'Inactive'),
              ],
              onSelected: (value) {
                if (value != null) {
                  setState(() => _selectedStatus = value);
                  _filterData();
                }
              },
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _exportToPdf,
              icon: const Icon(Icons.download),
              label: const Text('Download PDF'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Coordinators List
        Expanded(
          child:
              _filteredCoordinators.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No coordinators found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.separated(
                    itemCount: _filteredCoordinators.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final coordinator = _filteredCoordinators[index];
                      return _buildCoordinatorCard(coordinator, theme);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildCoordinatorCard(
    Map<String, dynamic> coordinator,
    ThemeData theme,
  ) {
    final name = coordinator['name']?.toString() ?? 'Unknown';
    final email = coordinator['email']?.toString() ?? 'No email';
    final phone = coordinator['phone']?.toString() ?? 'No phone';
    final coordinatorId =
        coordinator['coordinator_id']?.toString() ??
        coordinator['id']?.toString() ??
        '';
    final lastLogin = coordinator['last_login']?.toString();
    bool isActiveFromLogin() {
      if (lastLogin == null) return false;
      try {
        final date = DateTime.parse(lastLogin);
        return DateTime.now().difference(date) <= const Duration(days: 30);
      } catch (_) {
        return false;
      }
    }

    final isActive = isActiveFromLogin();
    final createdAt = coordinator['created_at'];

    String formatDate(String? dateStr) {
      if (dateStr == null) return 'Never';
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('MMM d, yyyy h:mm a').format(date);
      } catch (e) {
        return 'Invalid date';
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Show detail dialog
          showDialog(
            context: context,
            builder: (_) => _CoordinatorDetailDialog(coordinator: coordinator),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    isActive ? Colors.blue.shade100 : Colors.grey.shade300,
                child: Icon(
                  Icons.person,
                  color: isActive ? Colors.blue.shade700 : Colors.grey.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isActive
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete coordinator',
                    onPressed: () {
                      _confirmDeleteCoordinator(context, coordinator);
                    },
                  ),
                  // Chevron to indicate more details
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCoordinator(
    BuildContext context,
    Map<String, dynamic> coordinator,
  ) {
    final name = coordinator['name']?.toString() ?? 'Unknown';
    final coordinatorId =
        coordinator['coordinator_id']?.toString() ??
        coordinator['id']?.toString() ??
        '';

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Coordinator'),
            content: Text(
              'Are you sure you want to delete $name ($coordinatorId)?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _deleteCoordinator(context, coordinator);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteCoordinator(
    BuildContext context,
    Map<String, dynamic> coordinator,
  ) async {
    try {
      final coordinatorId =
          coordinator['coordinator_id']?.toString() ??
          coordinator['id']?.toString() ??
          '';

      // Optimistic update: remove from list immediately
      final indexToRemove = _allCoordinators.indexWhere(
        (c) => c['coordinator_id'] == coordinatorId || c['id'] == coordinatorId,
      );
      if (indexToRemove != -1) {
        final removedCoordinator = _allCoordinators[indexToRemove];

        if (mounted) {
          setState(() {
            _allCoordinators.removeAt(indexToRemove);
            _filterData(); // Update filtered list
          });
        }

        AppNotifier.showSuccess(context, 'Coordinator removed from this list');
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Failed to delete coordinator: $e');
      }
    }
  }
}

class _CoordinatorDetailDialog extends StatelessWidget {
  final Map<String, dynamic> coordinator;

  const _CoordinatorDetailDialog({required this.coordinator});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = coordinator['name']?.toString() ?? 'Unknown';
    final email = coordinator['email']?.toString() ?? 'No email';
    final phone = coordinator['phone']?.toString() ?? 'No phone';
    final coordinatorId =
        coordinator['coordinator_id']?.toString() ??
        coordinator['id']?.toString() ??
        '';
    final lastLogin = coordinator['last_login']?.toString();
    bool isActiveFromLogin() {
      if (lastLogin == null) return false;
      try {
        final date = DateTime.parse(lastLogin);
        return DateTime.now().difference(date) <= const Duration(days: 30);
      } catch (_) {
        return false;
      }
    }

    final isActive = isActiveFromLogin();
    final createdAt = coordinator['created_at'];

    String formatDate(String? dateStr) {
      if (dateStr == null) return 'Never';
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('MMM d, yyyy h:mm a').format(date);
      } catch (e) {
        return 'Invalid date';
      }
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Text('Coordinator Details'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(
              icon: Icons.badge,
              label: 'Coordinator ID',
              value: coordinatorId,
            ),
            _DetailRow(icon: Icons.person, label: 'Name', value: name),
            _DetailRow(icon: Icons.email, label: 'Email', value: email),
            _DetailRow(icon: Icons.phone, label: 'Phone', value: phone),
            const Divider(),
            _DetailRow(
              icon: Icons.verified_user,
              label: 'Status',
              value: isActive ? 'Active' : 'Inactive',
              valueColor:
                  isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
            _DetailRow(
              icon: Icons.login,
              label: 'Last Login',
              value: formatDate(lastLogin),
            ),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Created',
              value: formatDate(createdAt),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
