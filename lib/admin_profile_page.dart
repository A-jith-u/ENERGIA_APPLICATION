import 'package:flutter/material.dart';

import 'services/notifier.dart';
import 'services/admin_api.dart';

class AdminProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String token;

  const AdminProfilePage({
    super.key,
    required this.profile,
    required this.token,
  });

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  late Map<String, dynamic> _profile;

  @override
  void initState() {
    super.initState();
    _profile = Map.from(widget.profile);
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _profile['name']?.toString() ?? '');
    final emailController = TextEditingController(text: _profile['email']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, size: 24),
            SizedBox(width: 8),
            Text('Edit Profile'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();

              if (name.isEmpty || email.isEmpty) {
                AppNotifier.showError(context, 'Please fill all fields');
                return;
              }

              Navigator.pop(context);
              await _updateProfile(name, email);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, size: 24),
              SizedBox(width: 8),
              Text('Change Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: !showCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(showCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => showCurrent = !showCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(showNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => showNew = !showNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => showConfirm = !showConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final current = currentPasswordController.text;
                final newPass = newPasswordController.text;
                final confirm = confirmPasswordController.text;

                if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                  AppNotifier.showError(context, 'Please fill all fields');
                  return;
                }

                if (newPass != confirm) {
                  AppNotifier.showError(context, 'New passwords do not match');
                  return;
                }

                if (newPass.length < 6) {
                  AppNotifier.showError(context, 'Password must be at least 6 characters');
                  return;
                }

                Navigator.pop(context);
                await _changePassword(current, newPass);
              },
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile(String name, String email) async {
    try {
      await updateAdminProfile(widget.token, name: name, email: email);

      if (!mounted) return;
      setState(() {
        _profile['name'] = name;
        _profile['email'] = email;
      });

      AppNotifier.showSuccess(context, 'Profile updated successfully!');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.showError(context, 'Failed to update profile: ${e.toString()}');
    }
  }

  Future<void> _changePassword(String currentPassword, String newPassword) async {
    try {
      await changeAdminPassword(
        widget.token,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) return;
      AppNotifier.showSuccess(context, 'Password changed successfully!');
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      if (message.contains('401') || message.toLowerCase().contains('incorrect')) {
        AppNotifier.showError(context, 'Incorrect current password');
      } else {
        AppNotifier.showError(context, 'Failed to change password: $message');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _profile['name']?.toString() ?? 'Admin User';
    final adminId = _profile['admin_id']?.toString() ?? _profile['id']?.toString() ?? '-';
    final email = _profile['email']?.toString() ?? '-';
    final createdAt = _profile['created_at']?.toString() ?? '-';
    final isActiveRaw = _profile['is_active'];
    final isActive = isActiveRaw == null
      ? true
      : isActiveRaw == true ||
        isActiveRaw == 1 ||
        isActiveRaw.toString().toLowerCase() == 'true';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    adminId,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.admin_panel_settings,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'System Administrator',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Profile Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _ProfileDetailRow(
                            icon: Icons.person_outline,
                            label: 'Name',
                            value: name,
                          ),
                          const Divider(),
                          _ProfileDetailRow(
                            icon: Icons.badge_outlined,
                            label: 'Admin ID',
                            value: adminId,
                          ),
                          const Divider(),
                          _ProfileDetailRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: email,
                          ),
                          const Divider(),
                          _ProfileDetailRow(
                            icon: Icons.circle,
                            label: 'Account Status',
                            value: isActive ? 'Active' : 'Inactive',
                            valueColor: isActive ? Colors.green : Colors.red,
                          ),
                          const Divider(),
                          _ProfileDetailRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Created',
                            value: createdAt,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Text(
                    'Account Actions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.edit, color: theme.colorScheme.primary),
                          title: const Text('Edit Profile'),
                          subtitle: const Text('Update your name and email'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showEditProfileDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.lock_reset, color: theme.colorScheme.error),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showChangePasswordDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 24,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
