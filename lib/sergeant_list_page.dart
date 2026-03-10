import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/api.dart' as api;
import 'services/user_lists.dart';
import 'services/notifier.dart';

class SergeantListPage extends StatefulWidget {
  const SergeantListPage({super.key});

  @override
  State<SergeantListPage> createState() => _SergeantListPageState();
}

class _SergeantListPageState extends State<SergeantListPage> {
  List<Map<String, dynamic>> _allSergeants = [];
  bool _isLoading = false;
  String? _errorMessage;

  final _searchController = TextEditingController();
  String _selectedStatus = 'All';
  List<Map<String, dynamic>> _filteredSergeants = [];

  @override
  void initState() {
    super.initState();
    // Subscribe to shared sergeants list
    UserListsStore.instance.sergeants.addListener(_onSergeantsChanged);
    // Initialize from cached store for instant display
    _allSergeants = List<Map<String, dynamic>>.from(UserListsStore.instance.sergeants.value);
    _filteredSergeants = List.from(_allSergeants);
    // Refresh in background
    _loadSergeants();
  }

  void _onSergeantsChanged() {
    if (!mounted) return;
    setState(() {
      _allSergeants = List<Map<String, dynamic>>.from(UserListsStore.instance.sergeants.value);
      _filteredSergeants = _allSergeants.where((sergeant) {
        final name = sergeant['name']?.toString().toLowerCase() ?? '';
        final email = sergeant['email']?.toString().toLowerCase() ?? '';
        final searchLower = _searchController.text.toLowerCase();

        final matchesSearch = _searchController.text.isEmpty ||
            name.contains(searchLower) ||
            email.contains(searchLower);

        final isActive = sergeant['is_active'] == true;
        final matchesStatus = _selectedStatus == 'All' ||
            (_selectedStatus == 'Active' && isActive) ||
            (_selectedStatus == 'Inactive' && !isActive);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Future<void> _loadSergeants() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await api.getSergeants();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load sergeants: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    UserListsStore.instance.sergeants.removeListener(_onSergeantsChanged);
    super.dispose();
  }

  void _filterData() {
    if (!mounted) return;
    setState(() {
      _filteredSergeants = _allSergeants.where((sergeant) {
        final name = sergeant['name']?.toString().toLowerCase() ?? '';
        final email = sergeant['email']?.toString().toLowerCase() ?? '';
        final searchLower = _searchController.text.toLowerCase();
        
        final matchesSearch = _searchController.text.isEmpty ||
            name.contains(searchLower) ||
            email.contains(searchLower);
        
        final isActive = sergeant['is_active'] == true;
        final matchesStatus = _selectedStatus == 'All' ||
            (_selectedStatus == 'Active' && isActive) ||
            (_selectedStatus == 'Inactive' && !isActive);
        
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sergeants'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor: theme.appBarTheme.backgroundColor ?? scheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? scheme.onSurface,
        elevation: theme.appBarTheme.elevation ?? 0,
        actions: [
          TextButton(
            onPressed: _loadSergeants,
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
                              onPressed: _loadSergeants,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _buildSergeantsList(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildSergeantsList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Security Personnel',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${_filteredSergeants.length} ${_filteredSergeants.length == 1 ? 'sergeant' : 'sergeants'}',
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
          ],
        ),
        const SizedBox(height: 24),
        
        // Sergeants List
        Expanded(
          child: _filteredSergeants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.security_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No sergeants found',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _filteredSergeants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sergeant = _filteredSergeants[index];
                    return _buildSergeantCard(sergeant, theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSergeantCard(Map<String, dynamic> sergeant, ThemeData theme) {
    final name = sergeant['name']?.toString() ?? 'Unknown';
    final email = sergeant['email']?.toString() ?? 'No email';
    final phone = sergeant['phone']?.toString() ?? 'No phone';
    final sergeantId = sergeant['sergeant_id']?.toString() ?? '';
    final isActive = sergeant['is_active'] == true;
    final lastLogin = sergeant['last_login'];
    final createdAt = sergeant['created_at'];

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
            builder: (_) => _SergeantDetailDialog(sergeant: sergeant),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: isActive ? Colors.purple.shade100 : Colors.grey.shade300,
                child: Icon(
                  Icons.security,
                  color: isActive ? Colors.purple.shade700 : Colors.grey.shade600,
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
              
              // Action icon
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SergeantDetailDialog extends StatelessWidget {
  final Map<String, dynamic> sergeant;

  const _SergeantDetailDialog({required this.sergeant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = sergeant['name']?.toString() ?? 'Unknown';
    final email = sergeant['email']?.toString() ?? 'No email';
    final phone = sergeant['phone']?.toString() ?? 'No phone';
    final sergeantId = sergeant['sergeant_id']?.toString() ?? '';
    final isActive = sergeant['is_active'] == true;
    final lastLogin = sergeant['last_login'];
    final createdAt = sergeant['created_at'];

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
          Icon(Icons.security, color: Colors.purple.shade700),
          const SizedBox(width: 8),
          Text('Sergeant Details'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(icon: Icons.badge, label: 'Sergeant ID', value: sergeantId),
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
