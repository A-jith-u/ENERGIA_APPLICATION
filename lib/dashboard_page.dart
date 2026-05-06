// ignore_for_file: deprecated_member_use, avoid_print, file_names, unused_element, unused_field, unused_local_variable, use_build_context_synchronously

import 'services/notifier.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'analysis_graph_page.dart';
import 'anomaly_viewer_page.dart';
import 'role_selection_page.dart';
import 'dashboard_scaffold.dart'; // Ensure this is imported
import 'prediction_page.dart';
import 'prediction_comparison_page.dart';
import 'widgets/recommendation_widgets.dart';
import 'widgets/energy_visualization_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert'; // Fixes 'jsonEncode'
import 'package:http/http.dart' as http; // Fixes 'http'
import 'dart:async';
import 'alert_reminder_service.dart';
import 'dart:math';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _index = 0;
  String? _authToken;
  String? _userEmail;
  String? _department; // decoded from JWT, used to filter anomaly alerts
  String? _assignedRoomId; // decoded from JWT, used to scope class-rep data

  // ── Badge notification state ───────────────────────────────────────────────
  List<Map<String, dynamic>> _anomalies = [];
  Timer? _badgePollingTimer;
  late AlertReminderService _reminderService;
  int _badgeCount = 0;

  static const List<String> _baseUrls = [
    'http://127.0.0.1:5000', // Windows desktop app
    'http://localhost:5000', // fallback
    'http://10.0.2.2:5000', // Android emulator
    'http://192.168.160.1:5000', // physical device (update to your machine IP)
  ];

  final List<String> _titles = [
    'CR Dashboard',
    'Consumption Analysis',
    'Recent Alerts',
    'My Profile',
  ];

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
    // Badge polling every 8 seconds
    _badgePollingTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _pollForNewAnomalies(),
    );
    // ── In-app reminder service ──────────────────────────────────────────
    _reminderService = AlertReminderService(
      contextGetter: () => context,
      onBadgeUpdate: (count) {
        if (mounted) setState(() => _badgeCount = count);
      },
      onResolve: (alertId) => _resolveAlertById(alertId),
      onViewAlerts: () {
        if (mounted) setState(() => _index = 2);
        _fetchAnomalies();
      },
    );
  }

  @override
  void dispose() {
    _badgePollingTimer?.cancel();
    _reminderService.dispose();
    super.dispose();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      try {
        final decoded = JwtDecoder.decode(token);
        setState(() {
          _authToken = token;
          _userEmail = decoded['username'] as String?;
          _department = decoded['department'] as String?;
          _assignedRoomId = decoded['assigned_room_id'] as String?;
        });
      } catch (_) {
        setState(() => _authToken = token);
      }
    }
    // Seed seen IDs so pre-existing alerts don't fire badge on first open
    await _fetchAnomalies(seedSeen: true);
  }

  String _anomalyKey(Map<String, dynamic> a) {
    final id = a['id'] ?? a['_id'];
    if (id != null) return id.toString();
    return '${a['device_id']}_${a['timestamp']}';
  }

  Future<void> _fetchAnomalies({bool seedSeen = false}) async {
    for (final base in _baseUrls) {
      try {
        var url = '$base/anomalies';
        final query = <String>[];
        if (_department != null && _department!.isNotEmpty) {
          query.add('department=${Uri.encodeComponent(_department!)}');
        }
        if (_assignedRoomId != null && _assignedRoomId!.isNotEmpty) {
          query.add('room_id=${Uri.encodeComponent(_assignedRoomId!)}');
        }
        if (query.isNotEmpty) {
          url += '?${query.join('&')}';
        }
        final headers = {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        };
        final resp = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final raw = body is List ? body : (body['anomalies'] as List? ?? []);
          final fetched = List<Map<String, dynamic>>.from(
            raw.whereType<Map<String, dynamic>>(),
          );
          if (!mounted) return;
          setState(() {
            _anomalies = fetched;
          });
          _reminderService.syncAlerts(fetched);
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _pollForNewAnomalies() async {
    for (final base in _baseUrls) {
      try {
        var url = '$base/anomalies';
        final query = <String>[];
        if (_department != null && _department!.isNotEmpty) {
          query.add('department=${Uri.encodeComponent(_department!)}');
        }
        if (_assignedRoomId != null && _assignedRoomId!.isNotEmpty) {
          query.add('room_id=${Uri.encodeComponent(_assignedRoomId!)}');
        }
        if (query.isNotEmpty) {
          url += '?${query.join('&')}';
        }
        final headers = {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        };
        final resp = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final raw = body is List ? body : (body['anomalies'] as List? ?? []);
          final fetched = List<Map<String, dynamic>>.from(
            raw.whereType<Map<String, dynamic>>(),
          );
          if (!mounted) return;
          setState(() {
            _anomalies = fetched;
          });
          _reminderService.syncAlerts(fetched);
          if (_index == 2) _reminderService.clearBadge();
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void _clearAlertBadge() {
    if (!mounted) return;
    _reminderService.clearBadge();
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_outlined),
        activeIcon: Icon(Icons.dashboard),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.analytics_outlined),
        activeIcon: Icon(Icons.analytics),
        label: 'Analysis',
      ),
      BottomNavigationBarItem(
        icon: _CRBadgeIcon(
          icon: Icons.notifications_outlined,
          count: _badgeCount,
        ),
        activeIcon: _CRBadgeIcon(icon: Icons.notifications, count: _badgeCount),
        label: 'Alerts',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  Future<void> _resolveAlertById(dynamic alertId) async {
    for (final base in _baseUrls) {
      try {
        final r = await http
            .put(
              Uri.parse('$base/anomalies/$alertId/resolve'),
              headers: {'Content-Type': 'application/json'},
              body: '{"status":"resolved"}',
            )
            .timeout(const Duration(seconds: 8));
        if (r.statusCode == 200 || r.statusCode == 204) {
          await _fetchAnomalies();
          _clearAlertBadge();
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void _performLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _refreshCurrentPage() async {
    if (_index == 2) {
      await _fetchAnomalies();
      _clearAlertBadge();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DashboardScaffold(
      title: _titles[_index],
      currentIndex: _index,
      onBottomNavTapped: (index) {
        setState(() => _index = index);
        if (index == 2) {
          _fetchAnomalies();
          _clearAlertBadge();
        }
      },
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: _performLogout,
        ),
      ],
      bottomNavItems: _buildNavItems(),
      body: RefreshIndicator(
        onRefresh: _refreshCurrentPage,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildPage(_index, colorScheme),
        ),
      ),
    );
  }

  Widget _buildPage(int index, ColorScheme scheme) {
    switch (index) {
      case 0:
        return _WelcomeSection(
          scheme: scheme,
          assignedRoomId: _assignedRoomId,
          authToken: _authToken,
        );
      case 1:
        return _ReportsSection(scheme: scheme, userToken: _authToken);
      case 2:
        return _CRAlertsSection(
          anomalies: _anomalies,
          department: _department,
          roomId: _assignedRoomId,
          userEmail: _userEmail,
          authToken: _authToken,
          baseUrls: _baseUrls,
          onRefresh: () async {
            await _fetchAnomalies();
            _clearAlertBadge();
          },
        );
      case 3:
        return _ProfileSection(scheme: scheme);
      default:
        return const SizedBox.shrink();
    }
  }
}

// --- NEW PROFILE SECTION ---

/*class _ProfileSection extends StatelessWidget {
  final ColorScheme scheme;
  const _ProfileSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Profile Image Header
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.person, size: 55, color: scheme.primary),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  backgroundColor: scheme.primary,
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    onPressed: () {}, // Trigger image picker logic
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Personal Details
        Text('Personal Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _ProfileInfoTile(icon: Icons.badge_outlined, label: 'Name', value: 'John Doe'),
        _ProfileInfoTile(icon: Icons.email_outlined, label: 'Email', value: 'john.doe@university.edu'),
        _ProfileInfoTile(icon: Icons.school_outlined, label: 'Role', value: 'Class Representative'),
        
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        // Settings / Security
        Text('Security', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withOpacity(0.4),
          child: ListTile(
            leading: Icon(Icons.lock_outline, color: scheme.primary),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to password change screen
            },
          ),
        ),
      ],
    );
  }
}*/

class _ProfileSection extends StatefulWidget {
  final ColorScheme scheme;
  const _ProfileSection({required this.scheme});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

/*class _ProfileSectionState extends State<_ProfileSection> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController; // Optional, can be empty or added to DB
  late TextEditingController _ktuIdController;
  late TextEditingController _yearController;

  @override
  void initState() {
    super.initState();
    // Initialize empty; data will be loaded in _loadUserData
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController(text: '+91 9876543210');
    _ktuIdController = TextEditingController();
    _yearController = TextEditingController();
    
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token != null && !JwtDecoder.isExpired(token)) {
      Map<String, dynamic> data = JwtDecoder.decode(token);
      
      setState(() {
        _nameController.text = data['username'] ?? '';
        _ktuIdController.text = data['ktu_id'] ?? '';
        _yearController.text = data['year'] != null ? "Year ${data['year']}" : '';
        // Constructing a dummy email from username
        _emailController.text = "${data['username']?.toString().toLowerCase() ?? 'user'}@university.edu";
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ktuIdController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 55,
            backgroundColor: widget.scheme.primaryContainer,
            child: Icon(Icons.person, size: 55, color: widget.scheme.primary),
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = !_isEditing),
              icon: Icon(_isEditing ? Icons.check : Icons.edit, size: 18),
              label: Text(_isEditing ? 'Save' : 'Edit'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildProfileField(Icons.badge_outlined, 'Full Name', _nameController),
        _buildProfileField(Icons.fingerprint, 'KTU ID', _ktuIdController),
        _buildProfileField(Icons.calendar_today, 'Year of Study', _yearController),
        
        const SizedBox(height: 20),
        Text('Contact Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildProfileField(Icons.email_outlined, 'Email Address', _emailController),
        _buildProfileField(Icons.phone_outlined, 'Phone Number', _phoneController),
        
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 12),

        Text('Security', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: widget.scheme.surfaceContainerHighest.withOpacity(0.4),
          child: ListTile(
            leading: Icon(Icons.lock_outline, color: widget.scheme.primary),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { /* Future: Navigate to ChangePasswordPage */ },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileField(IconData icon, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: _isEditing ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: _isEditing 
              ? TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    border: const UnderlineInputBorder(),
                    contentPadding: EdgeInsets.zero,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(controller.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}*/
class _ProfileSectionState extends State<_ProfileSection> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _ktuIdController;
  late TextEditingController _yearController;
  late TextEditingController _deptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _ktuIdController = TextEditingController();
    _yearController = TextEditingController();
    _deptController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null && !JwtDecoder.isExpired(token)) {
      Map<String, dynamic> data = JwtDecoder.decode(token);
      setState(() {
        _nameController.text = data['name'] ?? 'Not Set'; // Real name from JWT
        _emailController.text = data['username'] ?? ''; // Actual email address
        _ktuIdController.text = data['ktu_id'] ?? '';
        _yearController.text = data['year']?.toString() ?? '';
        _deptController.text = data['department'] ?? '';
      });
    }
  }

  // Ensure these imports are at the top of the file!
  // import 'dart:convert';
  // import 'package:http/http.dart' as http;

  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Call the update-profile API
      final response = await http.post(
        Uri.parse('http://localhost:5000/update-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'ktu_id': _ktuIdController.text,
          'name': _nameController.text,
          'department': _deptController.text,
          'year': _yearController.text,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resp = jsonDecode(response.body);
        final String? newToken = resp['access_token'];
        if (newToken != null && newToken.isNotEmpty) {
          await prefs.setString('auth_token', newToken);
          // Reload controllers from refreshed JWT so UI reflects immediately
          await _loadUserData();
        }
        AppNotifier.showSuccess(context, "Profile updated!");
        setState(() => _isEditing = false);
      } else {
        throw Exception("Update failed");
      }
    } catch (e) {
      AppNotifier.showError(context, "Error: $e");
    }
  }

  Future<void> _updatePassword(String currentP, String newP) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _ktuIdController.text,
          'current_password': currentP,
          'new_password': newP,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context);
        AppNotifier.showSuccess(context, "Password updated successfully!");
      } else {
        AppNotifier.showError(context, "Incorrect current password");
      }
    } catch (e) {
      AppNotifier.showError(context, "Server error");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: widget.scheme.primaryContainer,
            child: Icon(Icons.person, size: 50, color: widget.scheme.primary),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Personal Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                if (_isEditing) {
                  _saveProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 18),
              label: Text(_isEditing ? 'Save' : 'Edit'),
            ),
          ],
        ),
        _buildProfileField(Icons.person, 'Full Name', _nameController),
        _buildProfileField(
          Icons.email,
          'Email',
          _emailController,
          enabled: false,
        ), // Email usually fixed
        _buildProfileField(
          Icons.badge,
          'KTU ID',
          _ktuIdController,
          enabled: false,
        ),
        _buildProfileField(Icons.business, 'Department', _deptController),
        _buildProfileField(Icons.calendar_month, 'Year', _yearController),

        const SizedBox(height: 20),
        const Divider(),
        ListTile(
          leading: Icon(Icons.lock_reset, color: widget.scheme.primary),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showPasswordDialog(),
        ),
      ],
    );
  }

  // Inside _ProfileSectionState

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Future<void> _handleChangePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      AppNotifier.showError(context, "New passwords do not match");
      return;
    }

    try {
      // Logic to call /change-password
      // Pass _ktuIdController.text as 'username' to the backend
      AppNotifier.showSuccess(context, "Password updated!");
      Navigator.pop(context); // Close dialog
    } catch (e) {
      AppNotifier.showError(context, "Incorrect current password");
    }
  }

  void _showPasswordDialog() {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool showCurrent = false;
        bool showNew = false;
        bool showConfirm = false;
        bool isLoading = false;

        return StatefulBuilder(
          builder:
              (ctx, setState) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: widget.scheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.lock_reset,
                                  color: widget.scheme.onPrimaryContainer,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Change Password',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Update your account password',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),

                          // Form Fields
                          TextFormField(
                            controller: currentPassController,
                            obscureText: !showCurrent,
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              hintText: 'Enter your current password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showCurrent
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed:
                                    () => setState(
                                      () => showCurrent = !showCurrent,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: newPassController,
                            obscureText: !showNew,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              hintText: 'Enter your new password',
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showNew
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed:
                                    () => setState(() => showNew = !showNew),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: confirmPassController,
                            obscureText: !showConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              hintText: 'Re-enter your new password',
                              prefixIcon: const Icon(Icons.lock_clock),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed:
                                    () => setState(
                                      () => showConfirm = !showConfirm,
                                    ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Info Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Password must be at least 8 characters long',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed:
                                    isLoading
                                        ? null
                                        : () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed:
                                    isLoading
                                        ? null
                                        : () async {
                                          // Validate inputs locally first
                                          if (currentPassController
                                              .text
                                              .isEmpty) {
                                            AppNotifier.showError(
                                              context,
                                              "Please enter current password",
                                            );
                                            return;
                                          }
                                          if (newPassController.text.isEmpty) {
                                            AppNotifier.showError(
                                              context,
                                              "Please enter new password",
                                            );
                                            return;
                                          }
                                          if (newPassController.text.length <
                                              8) {
                                            AppNotifier.showError(
                                              context,
                                              "Password must be at least 8 characters",
                                            );
                                            return;
                                          }
                                          if (newPassController.text !=
                                              confirmPassController.text) {
                                            AppNotifier.showError(
                                              context,
                                              "New passwords do not match",
                                            );
                                            return;
                                          }

                                          setState(() => isLoading = true);

                                          try {
                                            // Perform API Call to /change-password
                                            final response = await http.post(
                                              Uri.parse(
                                                'http://localhost:5000/change-password',
                                              ),
                                              headers: {
                                                'Content-Type':
                                                    'application/json',
                                              },
                                              body: jsonEncode({
                                                'username':
                                                    _ktuIdController
                                                        .text, // Using KTU ID as identifier
                                                'current_password':
                                                    currentPassController.text,
                                                'new_password':
                                                    newPassController.text,
                                              }),
                                            );

                                            if (response.statusCode == 200) {
                                              Navigator.pop(context);
                                              AppNotifier.showSuccess(
                                                context,
                                                "Password changed successfully!",
                                              );
                                            } else {
                                              setState(() => isLoading = false);
                                              AppNotifier.showError(
                                                context,
                                                "Incorrect current password",
                                              );
                                            }
                                          } catch (e) {
                                            setState(() => isLoading = false);
                                            AppNotifier.showError(
                                              context,
                                              "Failed to change password. Please try again.",
                                            );
                                          }
                                        },
                                icon:
                                    isLoading
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.check),
                                label: Text(
                                  isLoading ? 'Updating...' : 'Update Password',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _buildProfileField(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        enabled: _isEditing && enabled,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          labelText: label,
          border: _isEditing ? const OutlineInputBorder() : InputBorder.none,
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ... Keep existing _WelcomeSection, _ReportsSection, _AlertsSection, etc. ...

// --- WELCOME SECTION ---

class _WelcomeSection extends StatefulWidget {
  final ColorScheme scheme;
  final String? assignedRoomId;
  final String? authToken;

  const _WelcomeSection({
    required this.scheme,
    this.assignedRoomId,
    this.authToken,
  });

  @override
  State<_WelcomeSection> createState() => _WelcomeSectionState();
}

class _WelcomeSectionState extends State<_WelcomeSection> {
  // Treat raw sensor reading as W, convert to kW only for display/widgets.
  double _currentPowerW = 0;
  double _peakTodayW = 0;
  double _dailyTotalKwh = 0;

  // Live sensor readings
  double _currentEnergyWh = 0;
  double _currentVoltageV = 0;
  double _currentCurrentA = 0;
  double _currentFrequencyHz = 0;
  double _currentPowerFactorPf = 0;

  List<FlSpot> _livePowerSeriesKw = [];
  List<DateTime> _liveDataTimestamps = [];
  bool _isLoading = true;
  String _status = 'Loading...';
  bool _liveDataAvailable = false;
  DateTime? _lastDataUpdate;
  Timer? _refreshTimer;
  String? _preferredBaseUrl;

  String _canonicalDeviceIdForRoom(String roomId) {
    final normalized = roomId.trim().toUpperCase();
    if (normalized == 'CS-201') return 'ESP32-CS-C201';
    return roomId.trim();
  }

  String get _roomDeviceId =>
      (widget.assignedRoomId == null || widget.assignedRoomId!.trim().isEmpty)
          ? 'CS-201'
          : _canonicalDeviceIdForRoom(widget.assignedRoomId!);

  // Getter for power in kW
  double get _currentPowerKw => _currentPowerW / 1000.0;

  @override
  void initState() {
    super.initState();
    _loadLiveData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadLiveData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLiveData() async {
    try {
      final List<String> defaultCandidates = [
        // Desktop/local first for fastest startup.
        'http://localhost:5000',
        'http://127.0.0.1:5000',
        'http://localhost:5000',
        'http://192.168.1.25:5000',
        'http://10.0.2.2:5000',
      ];

      // Try last successful backend first to avoid repeated timeout chains.
      final List<String> apiCandidates = [
        if (_preferredBaseUrl != null) _preferredBaseUrl!,
        ...defaultCandidates.where((u) => u != _preferredBaseUrl),
      ];

      for (final baseUrl in apiCandidates) {
        try {
          // Fetch room-specific readings first for faster and relevant data.
          final roomUri = Uri.parse(
            '$baseUrl/sensor-data?limit=36&device_id=${Uri.encodeComponent(_roomDeviceId)}',
          );

          // Build headers with authorization token
          final headers = {
            'Content-Type': 'application/json',
            if (widget.authToken != null)
              'Authorization': 'Bearer ${widget.authToken}',
          };

          // Use a smaller timeout to keep UI responsive even when a host is down.
          final finalResponse = await http
              .get(roomUri, headers: headers)
              .timeout(
                const Duration(seconds: 4),
                onTimeout: () {
                  throw TimeoutException('Request timed out');
                },
              );

          if (finalResponse.statusCode != 200) continue;

          final data = jsonDecode(finalResponse.body);
          final readings = (data['data'] as List?) ?? [];

          if (readings.isEmpty) {
            // No sensor data in database
            continue;
          }

          // Cache fastest working backend.
          _preferredBaseUrl = baseUrl;

          // API returns latest-first; reverse so chart goes oldest->newest (left to right)
          final ordered = readings.reversed.toList();

          double peakW = 0;
          double totalKwh = 0;
          final List<FlSpot> spotsKw = [];
          final List<DateTime> timestamps = [];

          // Process all readings for chart with anomaly filtering
          for (int i = 0; i < ordered.length; i++) {
            final r = ordered[i] as Map<String, dynamic>;

            // Get power value from sensor reading
            final powerW =
                (r['power'] as num?)?.toDouble() ??
                (r['value'] as num?)?.toDouble() ??
                0.0;

            // Skip anomalous readings (likely sensor errors)
            // Normal classroom power usage: 0-10,000W (10kW)
            if (powerW < 0 || powerW > 10000) {
              debugPrint(
                '⚠️ Filtered anomalous reading: ${powerW}W at index $i',
              );
              continue;
            }

            peakW = max(peakW, powerW);
            totalKwh += (powerW / 1000.0) * (1.0 / 60.0);
            spotsKw.add(FlSpot(spotsKw.length.toDouble(), powerW / 1000.0));

            // Extract timestamp for this reading
            DateTime readingTime = DateTime.now();
            try {
              final ts = r['timestamp'] ?? r['created_at'] ?? r['ds'];
              if (ts != null) {
                readingTime = DateTime.parse(ts.toString());
              }
            } catch (e) {
              debugPrint('Error parsing reading timestamp: $e');
            }
            timestamps.add(readingTime);
          }

          // Get latest reading (first item since API returns latest-first)
          final latest = readings.first as Map<String, dynamic>;
          final latestW =
              (latest['power'] as num?)?.toDouble() ??
              (latest['value'] as num?)?.toDouble() ??
              0.0;

          // Parse timestamp from latest reading
          DateTime? latestTime;
          try {
            final ts = latest['timestamp'] ?? latest['created_at'];
            if (ts != null) {
              latestTime = DateTime.parse(ts.toString());
            }
          } catch (e) {
            debugPrint('Error parsing timestamp: $e');
            latestTime = DateTime.now();
          }

          // Check if data is fresh (within last 5 minutes)
          final dataAge =
              latestTime != null
                  ? DateTime.now().difference(latestTime).inMinutes
                  : 999;
          final isDataFresh = dataAge < 5;

          // Extract all sensor fields from latest reading
          final latestEnergy = (latest['energy'] as num?)?.toDouble() ?? 0.0;
          final latestVoltage = (latest['voltage'] as num?)?.toDouble() ?? 0.0;
          final latestCurrent = (latest['current'] as num?)?.toDouble() ?? 0.0;
          final latestFrequency =
              (latest['frequency'] as num?)?.toDouble() ?? 0.0;
          final latestPowerFactor =
              (latest['power_factor'] as num?)?.toDouble() ?? 0.0;

          // Determine status based on freshness and power level
          String statusMsg;
          if (!isDataFresh) {
            statusMsg = 'Stale Data (${dataAge}m old)';
          } else if (latestW < 1.0) {
            statusMsg = 'Connected • No Load';
          } else if (latestW < 100) {
            statusMsg = 'Low Usage';
          } else {
            statusMsg = 'Active Usage';
          }

          // If we have data, it's "live" - use it as-is
          if (!mounted) return;
          setState(() {
            _currentPowerW = latestW;
            _peakTodayW = peakW;
            _dailyTotalKwh = totalKwh;
            _livePowerSeriesKw = spotsKw;
            _liveDataTimestamps = timestamps;
            _isLoading = false;
            _liveDataAvailable = isDataFresh; // Only show as live if fresh
            _lastDataUpdate = latestTime ?? DateTime.now();
            _status = statusMsg;

            // Update sensor readings
            _currentEnergyWh = latestEnergy;
            _currentVoltageV = latestVoltage;
            _currentCurrentA = latestCurrent;
            _currentFrequencyHz = latestFrequency;
            _currentPowerFactorPf = latestPowerFactor;
          });
          debugPrint(
            '✅ Latest sensor data loaded - Power: ${latestW.toStringAsFixed(1)}W, Energy: ${latestEnergy.toStringAsFixed(2)}Wh',
          );
          return;
        } catch (e) {
          debugPrint('Error with backend: $e');
          continue;
        }
      }

      // No data available from any backend
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _liveDataAvailable = false;
        _status = 'No sensor data available';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _liveDataAvailable = false;
        _status = 'Error loading data';
      });
    }
  }

  Widget _buildSensorCard(
    ThemeData theme,
    String title,
    String mainValue,
    String subValue,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mainValue,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSensorData =
        _livePowerSeriesKw.isNotEmpty || _lastDataUpdate != null;

    final currentKw = _currentPowerW / 1000.0;
    final peakKw = _peakTodayW / 1000.0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 1. Prominent Welcome Card
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1000),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.scheme.primary.withOpacity(0.9),
                      widget.scheme.primaryContainer.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.scheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Energy Guardian',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _liveDataAvailable
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.radio_button_on,
                                size: 10,
                                color:
                                    _liveDataAvailable
                                        ? Colors.greenAccent
                                        : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _liveDataAvailable
                                    ? '📡 Live'
                                    : '⚠️ No Live Data',
                                style: TextStyle(
                                  color:
                                      _liveDataAvailable
                                          ? Colors.greenAccent
                                          : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome to $_roomDeviceId! 💡',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isLoading
                          ? 'Loading live data...'
                          : _liveDataAvailable
                          ? _currentPowerW < 1.0
                              ? 'ESP32 Connected • No Load Detected (${_currentPowerW.toStringAsFixed(1)} W)'
                              : 'Live power: ${currentKw.toStringAsFixed(3)} kW (${_currentPowerW.toStringAsFixed(0)} W)'
                          : _status.contains('Stale')
                          ? 'Last reading: ${_currentPowerW.toStringAsFixed(0)} W ($_status)'
                          : 'No live readings available',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    if (_lastDataUpdate != null && _liveDataAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Updated: ${_lastDataUpdate!.hour}:${_lastDataUpdate!.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 30),

        // 2. Live Energy Meters for Room
        Text(
          'Live Usage Data',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Real-time sensor readings in card format
        if (hasSensorData)
          Row(
            children: [
              Expanded(
                child: _buildSensorCard(
                  theme,
                  'Power',
                  '${_currentPowerW.toStringAsFixed(0)} W',
                  '${(_currentPowerW / 1000).toStringAsFixed(2)} kW',
                  Icons.flash_on,
                  EnergyColorScheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSensorCard(
                  theme,
                  'Energy',
                  '${_currentEnergyWh.toStringAsFixed(1)} Wh',
                  '${(_currentEnergyWh / 1000).toStringAsFixed(3)} kWh',
                  Icons.battery_charging_full,
                  Colors.green.shade600,
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.signal_wifi_off,
                  size: 48,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No Live Sensor Data',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sensor is not connected or offline',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadLiveData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Quick stats (use correct units)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child:
                hasSensorData
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statTile(
                          theme,
                          'Peak Today',
                          '${peakKw.toStringAsFixed(2)} kW',
                          Icons.trending_up,
                          EnergyColorScheme.warningOrange,
                        ),
                        _statTile(
                          theme,
                          'Daily Total',
                          '${_dailyTotalKwh.toStringAsFixed(2)} kWh',
                          Icons.bar_chart,
                          EnergyColorScheme.primaryBlue,
                        ),
                        _statTile(
                          theme,
                          'Status',
                          _status,
                          Icons.info,
                          _statusColor,
                        ),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          _status.contains('Stale')
                              ? Icons.warning_amber_rounded
                              : Icons.wifi_off_rounded,
                          size: 48,
                          color:
                              _status.contains('Stale')
                                  ? Colors.orange.shade400
                                  : Colors.red.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _status.contains('Stale')
                              ? 'Stale Data Warning'
                              : 'No Live Readings Available',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                _status.contains('Stale')
                                    ? Colors.orange.shade400
                                    : Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status.contains('Stale')
                              ? 'Sensor data is outdated - $_status'
                              : 'Sensor not connected or offline',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadLiveData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
          ),
        ),
        const SizedBox(height: 40),

        // Live Power Graph with proper scaling
        if (_livePowerSeriesKw.isNotEmpty)
          _buildLivePowerGraph()
        else if (!_isLoading)
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.signal_wifi_off,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No Live Power Data',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Color get _statusColor {
    if (!_liveDataAvailable) return Colors.red;
    return _currentPowerW > 0 ? Colors.orange : Colors.green;
  }

  String _formatTimeDiff(Duration diff) {
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  Widget _statTile(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLivePowerGraph() {
    if (_livePowerSeriesKw.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate chart dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final chartWidth = screenWidth - 40;

    // Convert kW back to Watts for Y-axis display
    List<FlSpot> powerSeriesW =
        _livePowerSeriesKw.map((spot) {
          return FlSpot(spot.x, spot.y * 1000);
        }).toList();

    // Fixed Y-axis scale: 0W, 40W, 80W, 120W, 160W
    const double yMax = 160.0;
    const double yInterval = 40.0;

    // Get timestamps for X-axis
    List<DateTime> timestamps = [];
    if (_liveDataTimestamps.isNotEmpty) {
      timestamps = _liveDataTimestamps;
    }

    // Calculate X-axis interval (show every Nth timestamp to avoid crowding)
    final xInterval = max(1, (powerSeriesW.length ~/ 6));

    return Container(
      width: chartWidth,
      height: 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              'Power Consumption Trend',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ),

          // Chart - Horizontally scrollable
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: max(
                  screenWidth - 48,
                  (powerSeriesW.length * 20).toDouble(),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: const Color(0xFF2A3142),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                          interval:
                              max(1, (powerSeriesW.length ~/ 8)).toDouble(),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= timestamps.length) {
                              return const SizedBox.shrink();
                            }
                            final time = timestamps[index];
                            final formatted = DateFormat(
                              'h:mm:ss a',
                            ).format(time);
                            return Transform.translate(
                              offset: const Offset(0, 8),
                              child: Text(
                                formatted,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '${value.toStringAsFixed(0)}W',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: max(1, (powerSeriesW.length - 1).toDouble()),
                    minY: 0,
                    maxY: yMax,
                    lineBarsData: [
                      LineChartBarData(
                        spots: powerSeriesW,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.4),
                              const Color(0xFF10B981).withOpacity(0.1),
                              const Color(0xFF10B981).withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        color: const Color(0xFF10B981),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor:
                            (touchedSpot) => const Color(0xFF1F2937),
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        tooltipBorder: const BorderSide(
                          color: Color(0xFF10B981),
                          width: 1.5,
                        ),
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            final index = barSpot.x.toInt();
                            final time =
                                index >= 0 && index < timestamps.length
                                    ? DateFormat(
                                      'h:mm:ss a',
                                    ).format(timestamps[index])
                                    : '';
                            return LineTooltipItem(
                              '${barSpot.y.toStringAsFixed(1)} W\n$time',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                      handleBuiltInTouches: true,
                    ),
                  ), // end LineChartData
                ), // end LineChart
              ), // end SizedBox
            ), // end SingleChildScrollView
          ), // end Expanded
          // Legend/Info with current values
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Current: ${(_currentPowerW).toStringAsFixed(0)} W (${_currentPowerKw.toStringAsFixed(2)} kW)',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate appropriate Y-axis interval for clean scale (in Watts) with equal spacing
  double _calculateWattAxisInterval(double maxY) {
    // Determine the order of magnitude
    if (maxY <= 500) return 100; // 100W intervals
    if (maxY <= 1000) return 200; // 200W intervals
    if (maxY <= 2000) return 400; // 400W intervals
    if (maxY <= 5000) return 1000; // 1000W (1kW) intervals
    if (maxY <= 10000) return 2000; // 2000W (2kW) intervals
    return 5000; // 5000W (5kW) intervals
  }

  Widget _buildConsumptionChart() {
    final peakKw = (_peakTodayW / 1000.0);
    return ResponsiveLineChart(
      spots: _livePowerSeriesKw,
      title: 'Live Power (last ${_livePowerSeriesKw.length} readings)',
      unit: 'kW',
      maxY: max(1.0, (peakKw * 1.2)).clamp(1.0, 20.0),
      isMonthly: false,
      lineColor: EnergyColorScheme.primaryBlue,
    );
  }
}

// --- Alerts Section (CR Receives Alerts) ---

// ─────────────────────────────────────────────────────────────────────────────
// Live CR Alerts Section — mirrors coordinator_dashboard alert functionality
// ─────────────────────────────────────────────────────────────────────────────

class _CRAlertsSection extends StatefulWidget {
  final List<Map<String, dynamic>> anomalies;
  final String? department;
  final String? roomId;
  final String? userEmail;
  final String? authToken;
  final List<String> baseUrls;
  final Future<void> Function() onRefresh;

  const _CRAlertsSection({
    required this.anomalies,
    required this.baseUrls,
    required this.onRefresh,
    this.authToken,
    this.department,
    this.roomId,
    this.userEmail,
  });

  @override
  State<_CRAlertsSection> createState() => _CRAlertsSectionState();
}

class _CRAlertsSectionState extends State<_CRAlertsSection> {
  late List<Map<String, dynamic>> _localAnomalies;
  final Set<dynamic> _resolvingIds = {};
  Map<String, Map<String, dynamic>> _notificationsByRoom = {};
  Timer? _selfRefreshTimer;

  @override
  void initState() {
    super.initState();
    _localAnomalies = List<Map<String, dynamic>>.from(widget.anomalies);
    // Independent 8-second self-refresh keeps list current even without polling
    _selfRefreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _selfFetch();
    });
  }

  @override
  void dispose() {
    _selfRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_CRAlertsSection old) {
    super.didUpdateWidget(old);
    if (old.anomalies != widget.anomalies) {
      setState(() {
        _localAnomalies =
            widget.anomalies
                .where((a) => !_resolvingIds.contains(a['id'] ?? a['_id']))
                .toList();
      });
    }
  }

  Future<void> _selfFetch() async {
    for (final base in widget.baseUrls) {
      try {
        var url = '$base/anomalies';
        final query = <String>[];
        if (widget.department != null && widget.department!.isNotEmpty) {
          query.add('department=${Uri.encodeComponent(widget.department!)}');
        }
        if (widget.roomId != null && widget.roomId!.isNotEmpty) {
          query.add('room_id=${Uri.encodeComponent(widget.roomId!)}');
        }
        if (query.isNotEmpty) {
          url += '?${query.join('&')}';
        }
        final headers = {
          'Content-Type': 'application/json',
          if (widget.authToken != null)
            'Authorization': 'Bearer ${widget.authToken}',
        };
        final resp = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final raw = body is List ? body : (body['anomalies'] as List? ?? []);
          final fetched = List<Map<String, dynamic>>.from(
            raw.whereType<Map<String, dynamic>>(),
          );

          Map<String, Map<String, dynamic>> notifsByRoom = {};
          final email = widget.userEmail?.trim() ?? '';
          if (email.isNotEmpty ||
              (widget.department != null && widget.department!.isNotEmpty)) {
            try {
              String notifUrl = '$base/notify/notifications?limit=100';
              if (email.isNotEmpty) {
                notifUrl += '&email=${Uri.encodeComponent(email)}';
              } else {
                notifUrl +=
                    '&department=${Uri.encodeComponent(widget.department!)}';
              }
              final notifResp = await http
                  .get(
                    Uri.parse(notifUrl),
                    headers: {'Content-Type': 'application/json'},
                  )
                  .timeout(const Duration(seconds: 6));
              if (notifResp.statusCode == 200) {
                final notifBody =
                    jsonDecode(notifResp.body) as Map<String, dynamic>;
                final notifications = notifBody['notifications'] as List? ?? [];
                for (final n in notifications) {
                  final roomId =
                      (n['room_id'] ?? n['device_id'] ?? '').toString().trim();
                  if (roomId.isEmpty) continue;
                  final mapN = n as Map<String, dynamic>;
                  notifsByRoom[roomId] = mapN;
                  notifsByRoom[roomId.toUpperCase()] = mapN;
                  final bareRoom = roomId.replaceFirst(
                    RegExp(r'^ESP32-', caseSensitive: false),
                    '',
                  );
                  if (bareRoom.isNotEmpty) {
                    notifsByRoom[bareRoom] = mapN;
                    notifsByRoom[bareRoom.toUpperCase()] = mapN;
                    notifsByRoom['ESP32-$bareRoom'] = mapN;
                    notifsByRoom['ESP32-${bareRoom.toUpperCase()}'] = mapN;
                  }
                }
              }
            } catch (_) {
              // Best effort only.
            }
          }

          if (!mounted) return;
          setState(() {
            _localAnomalies =
                fetched
                    .where((a) => !_resolvingIds.contains(a['id'] ?? a['_id']))
                    .toList();
            _notificationsByRoom = notifsByRoom;
          });
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Widget _buildAlertMessageContent(Map<String, dynamic> alert) {
    final roomId =
        (alert['room_id'] ?? alert['device_id'] ?? '').toString().trim();
    final notification =
        _notificationsByRoom[roomId] ??
        _notificationsByRoom[roomId.toUpperCase()];
    final theme = Theme.of(context);

    if (notification != null) {
      final title = (notification['title'] ?? '').toString();
      final message = (notification['message'] ?? '').toString();
      final notifPowerRaw = notification['power'];
      final notifPower =
          notifPowerRaw is num
              ? notifPowerRaw.toDouble()
              : double.tryParse('${notifPowerRaw ?? ''}');
      final rawPower = alert['power'];
      final anomalyPower =
          rawPower is num
              ? rawPower.toDouble()
              : double.tryParse('${rawPower ?? ''}');
      final powerText =
          notifPower != null
              ? '${notifPower.toStringAsFixed(1)}W'
              : (anomalyPower != null
                  ? '${anomalyPower.toStringAsFixed(1)}W'
                  : 'N/A');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (title.isNotEmpty) const SizedBox(height: 4),
          if (message.isNotEmpty)
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
                height: 1.35,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          if (message.isNotEmpty) const SizedBox(height: 4),
          Text(
            'Power: $powerText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alert Type: ${((alert['occupancy'] ?? 0) is num && (alert['occupancy'] as num) <= 0) ? 'Usage without occupancy' : 'High/unrecognized usage'}. '
          'Severity: ${((alert['power'] ?? 0) is num && (alert['power'] as num) > 3000) ? 'HIGH' : 'MEDIUM'}. '
          'Stage: live monitoring.',
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'Recommendation: Check the room immediately, reduce unnecessary load, and mark resolved after confirmation.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          'Power: ${alert['power']}W  |  Occupancy: ${alert['occupancy']}  |  Score: ${alert['score']}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Future<void> _resolveAlert(int index) async {
    final alert = _localAnomalies[index];
    final alertId = alert['id'] ?? alert['_id'];

    // No ID — just remove locally
    if (alertId == null) {
      setState(() => _localAnomalies.removeAt(index));
      return;
    }

    setState(() => _resolvingIds.add(alertId));
    bool success = false;

    for (final base in widget.baseUrls) {
      try {
        // Try PUT resolve first
        final put = await http
            .put(
              Uri.parse('$base/anomalies/$alertId/resolve'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'status': 'resolved'}),
            )
            .timeout(const Duration(seconds: 8));
        if (put.statusCode == 200 || put.statusCode == 204) {
          success = true;
          break;
        }
        // Fallback to DELETE
        final del = await http
            .delete(
              Uri.parse('$base/anomalies/$alertId'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 8));
        if (del.statusCode == 200 ||
            del.statusCode == 204 ||
            del.statusCode == 404) {
          success = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }

    if (!mounted) return;

    if (success) {
      setState(() {
        _resolvingIds.remove(alertId);
        _localAnomalies.removeWhere((a) => (a['id'] ?? a['_id']) == alertId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Alert resolved successfully.'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      setState(() => _resolvingIds.remove(alertId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Could not reach server. Try again.')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () {
              final retryIndex = _localAnomalies.indexWhere(
                (a) => (a['id'] ?? a['_id']) == alertId,
              );
              if (retryIndex >= 0) _resolveAlert(retryIndex);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dept = widget.department ?? 'Department';

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Text(
            '$dept Anomaly Alerts',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Live anomaly detections from department sensors',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // ── Empty state ──────────────────────────────────────────────────
          if (_localAnomalies.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: Colors.green.withOpacity(0.55),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No anomaly alerts detected',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All sensors are operating normally',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          // ── Alert cards ──────────────────────────────────────────────────
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localAnomalies.length,
              itemBuilder: (context, i) {
                final alert = _localAnomalies[i];
                final alertId = alert['id'] ?? alert['_id'];
                final isResolving = _resolvingIds.contains(alertId);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Icon ──────────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: CircleAvatar(
                            backgroundColor: Colors.red.withOpacity(0.12),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            ),
                          ),
                        ),

                        // ── Text info ─────────────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Anomaly in ${alert['room_id'] ?? alert['device_id'] ?? 'Unknown room'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildAlertMessageContent(alert),
                            ],
                          ),
                        ),

                        // ── Resolve button ────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(left: 6, right: 8),
                          child: ElevatedButton.icon(
                            onPressed:
                                isResolving ? null : () => _resolveAlert(i),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isResolving
                                      ? Colors.green.withOpacity(0.5)
                                      : Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.green.withOpacity(
                                0.5,
                              ),
                              disabledForegroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            icon:
                                isResolving
                                    ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Icon(Icons.check, size: 16),
                            label: Text(
                              isResolving ? 'Resolving...' : 'Resolve',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Red badge overlay for the Alerts nav item
// ─────────────────────────────────────────────────────────────────────────────

class _CRBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  const _CRBadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            top: -6,
            right: -8,
            child: AnimatedScale(
              scale: count > 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.elasticOut,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.45),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Old static _AlertsSection (replaced by _CRAlertsSection above) ────────────
class _AlertsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _AlertsSection({required this.scheme});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// --- Reports Section (CR Views Consumption Analysis/Graphs) ---

class _ReportsSection extends StatelessWidget {
  final ColorScheme scheme;
  final String? userToken;
  const _ReportsSection({required this.scheme, required this.userToken});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Smart Dashboard Header
        Text(
          'Smart Dashboard',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 16),

        // Recommendations Section
        RecommendationsList(
          userToken: userToken,
          showHeader: true,
          maxItems: 3,
        ),
        const SizedBox(height: 32),

        // AI-Powered Prediction - Featured at top
        _buildPredictionTile(
          context,
          '⚡ Energy Usage Prediction',
          'AI forecast for next 15 minutes using Prophet model.',
          Icons.insights,
          Colors.purple.shade600,
        ),

        // ✅ New compare page tile
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: Icon(Icons.compare_arrows, color: Colors.indigo.shade600),
            title: const Text('Compare Prediction vs Live (5 min)'),
            subtitle: const Text(
              'Check how accurate the 5-minute forecast is for CS-201.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => const PredictionComparisonPage(roomName: 'CS-201'),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 32),

        Text(
          'Consumption Analysis',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'View detailed consumption graphs and anomaly reports for CS-201.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),

        // Monthly Consumption Graph (Interactive View)
        _buildGraphTile(
          context,
          'Monthly Consumption Trend',
          'View total energy usage over the last 30 days.',
          Icons.calendar_month_outlined,
          Colors.blue.shade600,
          'Monthly',
        ),
        // Daily Consumption Graph (Interactive View)
        _buildGraphTile(
          context,
          'Daily Usage Profile',
          'View hourly consumption breakdown for today.',
          Icons.today_outlined,
          Colors.green.shade600,
          'Daily',
        ),
        // Anomaly Report Viewer (No Download for CR)
        _buildAnomalyReportTile(
          context,
          'Detailed Anomaly Report',
          'List of all triggered alerts and exceptions.',
          Icons.warning_amber_rounded,
          Colors.amber.shade700,
        ),
      ],
    );
  }

  Widget _buildGraphTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String type,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AnalysisGraphPage(
                    title: '$type Consumption Graph',
                    type: type,
                    color: color,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.show_chart_outlined,
                size: 24,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnomalyReportTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AnomalyViewerPage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.visibility_outlined,
                size: 24,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PredictionPage(authToken: userToken),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnergyUsageChart extends StatelessWidget {
  final bool isDark;
  const _EnergyUsageChart({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 6,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${value.toInt()}h',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 1.5),
              FlSpot(2, 1.8),
              FlSpot(4, 1.4),
              FlSpot(6, 2.5),
              FlSpot(8, 2.2),
              FlSpot(10, 3.5),
              FlSpot(12, 3.8),
              FlSpot(14, 3.0),
              FlSpot(16, 2.5),
              FlSpot(18, 4.1),
              FlSpot(20, 3.2),
              FlSpot(22, 2.8),
              FlSpot(23.9, 2.7),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.4),
                  theme.colorScheme.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minX: 0,
        maxX: 24,
        minY: 0,
        maxY: 5,
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String tip;
  final IconData icon;
  const _TipCard({required this.tip, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.secondary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(tip)),
          ],
        ),
      ),
    );
  }
}
