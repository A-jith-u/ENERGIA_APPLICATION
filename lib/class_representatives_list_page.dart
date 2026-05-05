import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/api.dart' as api;
import 'services/user_lists.dart';
import 'services/notifier.dart';
import 'services/pdf_export.dart';

class DetailedClassRepresentativesPage extends StatefulWidget {
  const DetailedClassRepresentativesPage({super.key});

  @override
  State<DetailedClassRepresentativesPage> createState() => _DetailedClassRepresentativesPageState();
}

class _DetailedClassRepresentativesPageState extends State<DetailedClassRepresentativesPage> {
  List<Map<String, dynamic>> _allClassReps = [];
  bool _isLoading = false;
  String? _errorMessage;

  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  List<Map<String, dynamic>> _filteredClassReps = [];

  @override
  void initState() {
    super.initState();
    // Subscribe to shared class representatives list
    UserListsStore.instance.classReps.addListener(_onClassRepsChanged);
    // Initialize from cached store for instant display
    _allClassReps = List<Map<String, dynamic>>.from(UserListsStore.instance.classReps.value);
    _filteredClassReps = List.from(_allClassReps);
    // Refresh in background
    _loadClassReps();
  }

  void _onClassRepsChanged() {
    if (!mounted) return;
    setState(() {
      _allClassReps = List<Map<String, dynamic>>.from(UserListsStore.instance.classReps.value);
      _filteredClassReps = _allClassReps.where((classRep) {
        final name = classRep['name']?.toString().toLowerCase() ?? '';
        final email = classRep['email']?.toString().toLowerCase() ?? '';
        final searchLower = _searchController.text.toLowerCase();

        final matchesSearch = _searchController.text.isEmpty ||
            name.contains(searchLower) ||
            email.contains(searchLower);

        final lastLogin = classRep['last_login']?.toString();
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
        final matchesStatus = _selectedStatus == 'All' ||
            (_selectedStatus == 'Active' && isActive) ||
            (_selectedStatus == 'Inactive' && !isActive);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _loadClassReps() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await api.getClassRepresentatives();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load class representatives: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    UserListsStore.instance.classReps.removeListener(_onClassRepsChanged);
    super.dispose();
  }

  void _filterData() {
    if (!mounted) return;
    setState(() {
      _filteredClassReps = _allClassReps.where((classRep) {
        final name = classRep['name']?.toString().toLowerCase() ?? '';
        final email = classRep['email']?.toString().toLowerCase() ?? '';
        final searchLower = _searchController.text.toLowerCase();
        
        final matchesSearch = _searchController.text.isEmpty ||
            name.contains(searchLower) ||
            email.contains(searchLower);
        
        final lastLogin = classRep['last_login']?.toString();
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
        final matchesStatus = _selectedStatus == 'All' ||
            (_selectedStatus == 'Active' && isActive) ||
            (_selectedStatus == 'Inactive' && !isActive);
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _exportToPdf() async {
    if (_filteredClassReps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No class representatives to export')),
      );
      return;
    }

    const headers = ['Name', 'KTU ID', 'Email', 'Phone', 'Class', 'Status', 'Last Login', 'Joined Date'];
    final rows = _filteredClassReps.map((classRep) {
      final ktuId = classRep['ktu_id']?.toString() ?? 'N/A';
      final phone = classRep['phone']?.toString() ?? 'N/A';
      final lastLogin = classRep['last_login']?.toString();
      final isActive = lastLogin != null
          ? (DateTime.now().difference(DateTime.parse(lastLogin)) <= const Duration(days: 30))
          : false;
      final lastLoginStr = lastLogin != null
          ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(lastLogin))
          : 'Never';
      final createdStr = classRep['created_at']?.toString();
      final createdDate = createdStr != null
          ? DateFormat('MMM d, yyyy').format(DateTime.parse(createdStr))
          : 'N/A';

      return [
        classRep['name']?.toString() ?? 'Unknown',
        ktuId,
        classRep['email']?.toString() ?? 'N/A',
        phone,
        classRep['class']?.toString() ?? 'N/A',
        isActive ? 'Active' : 'Inactive',
        lastLoginStr,
        createdDate,
      ];
    }).toList();

    await exportTablePdfAutoSave(
      'Class Representatives List',
      headers,
      rows,
      subtitle: 'Exported on ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Class Representatives'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor: theme.appBarTheme.backgroundColor ?? scheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? scheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 0,
        actions: [
          TextButton(
            onPressed: _loadClassReps,
            child: const Text('Reload'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                            const SizedBox(height: 16),
                            Text(_errorMessage!, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadClassReps,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildClassRepsList(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildClassRepsList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Class Representatives',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${_filteredClassReps.length} ${_filteredClassReps.length == 1 ? 'representative' : 'representatives'}',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
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
        
        // Class Representatives List
        Expanded(
          child: _filteredClassReps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No class representatives found',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _filteredClassReps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final classRep = _filteredClassReps[index];
                    return _buildClassRepCard(classRep, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildClassRepCard(Map<String, dynamic> classRep, ThemeData theme) {
    final name = classRep['name']?.toString() ?? 'Unknown';
    final email = classRep['email']?.toString() ?? 'No email';
    final phone = classRep['phone']?.toString() ?? 'No phone';
    final repId = classRep['ktu_id']?.toString() ??
      classRep['class_representative_id']?.toString() ??
      classRep['id']?.toString() ?? '';
      final lastLogin = classRep['last_login']?.toString();
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
    
    final createdAt = classRep['created_at'];

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
            builder: (_) => _ClassRepDetailDialog(classRep: classRep),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: isActive ? Colors.orange.shade100 : Colors.grey.shade300,
                child: Icon(
                  Icons.school,
                  color: isActive ? Colors.orange.shade700 : Colors.grey.shade600,
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isActive ? Colors.green.shade900 : Colors.red.shade900,
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
                    tooltip: 'Delete representative',
                    onPressed: () {
                      _confirmDeleteClassRep(context, classRep);
                    },
                  ),
                  // Chevron to indicate more details
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteClassRep(BuildContext context, Map<String, dynamic> classRep) {
    final name = classRep['name']?.toString() ?? 'Unknown';
    final repId = classRep['class_representative_id']?.toString() ?? classRep['id']?.toString() ?? '';
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Class Representative'),
        content: Text('Are you sure you want to delete $name ($repId)?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteClassRep(context, classRep);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClassRep(BuildContext context, Map<String, dynamic> classRep) async {
    try {
      final repId = classRep['class_representative_id']?.toString() ?? classRep['id']?.toString() ?? '';
      
      // Optimistic update: remove from list immediately
      final indexToRemove = _allClassReps.indexWhere((r) => 
          r['class_representative_id'] == repId || r['id'] == repId);
      if (indexToRemove != -1) {
        final removedRep = _allClassReps[indexToRemove];
        
        if (mounted) {
          setState(() {
            _allClassReps.removeAt(indexToRemove);
            _filterData(); // Update filtered list
          });
        }
        
        AppNotifier.showSuccess(context, 'Class representative removed from this list');
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(context, 'Failed to delete representative: $e');
      }
    }
  }
}

class _ClassRepDetailDialog extends StatelessWidget {
  final Map<String, dynamic> classRep;

  const _ClassRepDetailDialog({required this.classRep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = classRep['name']?.toString() ?? 'Unknown';
    final email = classRep['email']?.toString() ?? 'No email';
    final phone = classRep['phone']?.toString() ?? 'No phone';
    final repId = classRep['ktu_id']?.toString() ??
      classRep['class_representative_id']?.toString() ??
      classRep['id']?.toString() ?? '';
    final lastLogin = classRep['last_login']?.toString();
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
    final createdAt = classRep['created_at'];

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
          Icon(Icons.person, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Text('Class Representative Details'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(icon: Icons.badge, label: 'Rep ID', value: repId),
            _DetailRow(icon: Icons.person, label: 'Name', value: name),
            _DetailRow(icon: Icons.email, label: 'Email', value: email),
            _DetailRow(icon: Icons.phone, label: 'Phone', value: phone),
            const Divider(),
            _DetailRow(
              icon: Icons.verified_user, 
              label: 'Status', 
              value: isActive ? 'Active' : 'Inactive',
              valueColor: isActive ? Colors.green.shade700 : Colors.red.shade700,
            ),
            _DetailRow(icon: Icons.login, label: 'Last Login', value: formatDate(lastLogin)),
            _DetailRow(icon: Icons.calendar_today, label: 'Created', value: formatDate(createdAt)),
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
