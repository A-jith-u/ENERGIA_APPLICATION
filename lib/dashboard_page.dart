import 'services/notifier.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'analysis_graph_page.dart'; 
import 'anomaly_viewer_page.dart';
import 'role_selection_page.dart';
import 'dashboard_scaffold.dart'; // Ensure this is imported
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert'; // Fixes 'jsonEncode'
import 'package:http/http.dart' as http; // Fixes 'http'
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _index = 0;

  // Dynamic titles based on the selected tab
  final List<String> _titles = [
    'CR Dashboard - CS-201',
    'Consumption Analysis',
    'Recent Alerts',
    'My Profile',
  ];

  void _performLogout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return DashboardScaffold(
      title: _titles[_index],
      currentIndex: _index,
      onBottomNavTapped: (index) => setState(() => _index = index),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
          onPressed: _performLogout,
        ),
      ],
      bottomNavItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Home', 
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics_outlined),
          activeIcon: Icon(Icons.analytics),
          label: 'Analysis',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          activeIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildPage(_index, colorScheme),
      ),
    );
  }

  Widget _buildPage(int index, ColorScheme scheme) {
    switch (index) {
      case 0:
        return _WelcomeSection(scheme: scheme);
      case 1:
        return _ReportsSection(scheme: scheme);
      case 2:
        return _AlertsSection(scheme: scheme);
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
      _emailController.text = data['username'] ?? '';   // Actual email address
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
      Uri.parse('http://localhost:8000/auth/update-profile'),
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
      Uri.parse('http://localhost:8000/auth/change-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _ktuIdController.text, // Backend identifies by KTU ID
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
          child: CircleAvatar(radius: 50, backgroundColor: widget.scheme.primaryContainer, 
               child: Icon(Icons.person, size: 50, color: widget.scheme.primary)),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
        _buildProfileField(Icons.email, 'Email', _emailController, enabled: false), // Email usually fixed
        _buildProfileField(Icons.badge, 'KTU ID', _ktuIdController, enabled: false),
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
    // Logic to call /auth/change-password
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
        builder: (ctx, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Update your account password',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          icon: Icon(showCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showCurrent = !showCurrent),
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
                          icon: Icon(showNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showNew = !showNew),
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
                          icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showConfirm = !showConfirm),
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
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
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
                          onPressed: isLoading ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: isLoading ? null : () async {
                            // Validate inputs locally first
                            if (currentPassController.text.isEmpty) {
                              AppNotifier.showError(context, "Please enter current password");
                              return;
                            }
                            if (newPassController.text.isEmpty) {
                              AppNotifier.showError(context, "Please enter new password");
                              return;
                            }
                            if (newPassController.text.length < 8) {
                              AppNotifier.showError(context, "Password must be at least 8 characters");
                              return;
                            }
                            if (newPassController.text != confirmPassController.text) {
                              AppNotifier.showError(context, "New passwords do not match");
                              return;
                            }
                            
                            setState(() => isLoading = true);
                            
                            try {
                              // Perform API Call to /auth/change-password
                              final response = await http.post(
                                Uri.parse('http://localhost:8000/auth/change-password'),
                                headers: {'Content-Type': 'application/json'},
                                body: jsonEncode({
                                  'username': _ktuIdController.text, // Using KTU ID as identifier
                                  'current_password': currentPassController.text,
                                  'new_password': newPassController.text,
                                }),
                              );

                              if (response.statusCode == 200) {
                                Navigator.pop(context);
                                AppNotifier.showSuccess(context, "Password changed successfully!");
                              } else {
                                setState(() => isLoading = false);
                                AppNotifier.showError(context, "Incorrect current password");
                              }
                            } catch (e) {
                              setState(() => isLoading = false);
                              AppNotifier.showError(context, "Failed to change password. Please try again.");
                            }
                          },
                          icon: isLoading 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check),
                          label: Text(isLoading ? 'Updating...' : 'Update Password'),
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

  Widget _buildProfileField(IconData icon, String label, TextEditingController controller, {bool enabled = true}) {
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

  const _ProfileInfoTile({required this.icon, required this.label, required this.value});

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
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ... Keep existing _WelcomeSection, _ReportsSection, _AlertsSection, etc. ...

// --- WELCOME SECTION ---

class _WelcomeSection extends StatelessWidget {
  final ColorScheme scheme;
  const _WelcomeSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                      scheme.primary.withOpacity(0.9),
                      scheme.primaryContainer.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
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
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.lightGreenAccent,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Welcome to CS-201! 💡',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monitor real-time consumption and check your alerts here.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 30),

        // 2. Key Live Statistics (Current Usage)
        Text(
          'Live Usage Data (CS-201)',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        Wrap(
          spacing: 18,
          runSpacing: 18,
          alignment: WrapAlignment.center,
          children: const [
            _StatCard(label: 'Current Usage', value: '4.2 kW', icon: Icons.flash_on, color: Colors.orange),
            _StatCard(label: 'Today\'s Peak', value: '6.8 kW', icon: Icons.trending_up_outlined, color: Colors.red),
            _StatCard(label: 'Efficiency', value: '87%', icon: Icons.eco, color: Colors.green),
            _StatCard(label: 'Daily Goal', value: '28.7/30 kWh', icon: Icons.track_changes, color: Colors.blue),
          ],
        ),

        const SizedBox(height: 40),

       
      ],
    );
  }
}


// --- Alerts Section (CR Receives Alerts) ---

class _AlertsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _AlertsSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Recent Alerts (CS-201)',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Notifications about unusual energy usage in your assigned classroom.',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        // Scoped alerts to CR's location (CS-201)
        _buildAlertCard(context, 'High Usage Alert', 'CS-201: AC running after 6 PM. Usage: 5.2 kW.', Icons.power_outlined, Colors.red.shade400, '2h ago'),
        _buildAlertCard(context, 'Anomaly Detected', 'CS-201: Projector left on overnight (Occupancy Mismatch).', Icons.lightbulb_outline, Colors.amber.shade600, '1d ago'),
        _buildAlertCard(context, 'Sensor Offline', 'CS-201 PIR Sensor is not responding.', Icons.sensors_off_outlined, Colors.grey.shade500, '3d ago'),
      ],
    );
  }

  Widget _buildAlertCard(BuildContext context, String title, String subtitle, IconData icon, Color color, String time) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: color)),
        subtitle: Text(subtitle),
        trailing: Text(time, style: theme.textTheme.bodySmall),
        onTap: () {
          // Placeholder for alert details
        },
      ),
    );
  }
}

// --- Reports Section (CR Views Consumption Analysis/Graphs) ---

class _ReportsSection extends StatelessWidget {
  final ColorScheme scheme;
  const _ReportsSection({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Consumption Analysis',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'View detailed consumption graphs and anomaly reports for CS-201.',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
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

  Widget _buildGraphTile(BuildContext context, String title, String subtitle, IconData icon, Color color, String type) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to new page for graph visualization
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysisGraphPage(
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
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.show_chart_outlined, size: 24, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnomalyReportTile(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navigate to new page for anomaly list visualization
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AnomalyViewerPage(),
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
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              // CR cannot download, so we use a view icon
              const Icon(Icons.visibility_outlined, size: 24, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}


// --- Helper Classes (Standard Helpers) ---

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
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 6,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text('${value.toInt()}h', style: theme.textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 1.5), FlSpot(2, 1.8), FlSpot(4, 1.4), FlSpot(6, 2.5),
              FlSpot(8, 2.2), FlSpot(10, 3.5), FlSpot(12, 3.8), FlSpot(14, 3.0),
              FlSpot(16, 2.5), FlSpot(18, 4.1), FlSpot(20, 3.2), FlSpot(22, 2.8),
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
            Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Text(tip)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: 160,
      height: 140, // Increased height to prevent overflow
      child: Card(
        elevation: 2,
        shadowColor: Colors.transparent,
        color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced padding slightly
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 24, color: color), // Reduced icon size slightly
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}