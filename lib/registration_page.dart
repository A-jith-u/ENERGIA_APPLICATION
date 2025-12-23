import 'dart:ui';

import 'package:flutter/material.dart';
import 'services/api.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _yearController = TextEditingController();
  final _kluIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rePasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isRePasswordVisible = false;
  String? _errorMessage;
  
  String? _selectedDepartment;
  String? _selectedYear;
  
  final List<String> _departments = ['CSE', 'ECE', 'EEE', 'IT', 'RA', 'ME'];
  final List<String> _years = ['1', '2', '3', '4'];

  void _register() {
    if (_formKey.currentState?.validate() != true) return;
    _performRegistration();
  }

  Future<void> _performRegistration() async {
    final name = _nameController.text.trim();
    final ktuId = _kluIdController.text.trim();
    final password = _passwordController.text;
    final department = _selectedDepartment;
    final year = _selectedYear;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      await register(ktuId, password, role: 'student', ktuId: ktuId, name: name, department: department, year: year);
      Navigator.of(context).pop(); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration Successful for $name')),
      );
      Navigator.pop(context); // Go back to login
    } catch (e) {
      Navigator.of(context).pop(); // Close progress dialog
      setState(() {
        _errorMessage = e is ApiError ? e.message : 'Registration failed: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _goBack() {
    Navigator.pop(context); // Goes back to Login Page
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: colorScheme.onSurface.withOpacity(0.1),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 42,
                                  backgroundColor: colorScheme.primary.withOpacity(.15),
                                  child: Icon(Icons.school, size: 44, color: colorScheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Create Student Account',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Register to access campus resources',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                            ),
                            const SizedBox(height: 28),
                            if (_errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildField(
                                    controller: _nameController,
                                    label: 'Student Name',
                                    icon: Icons.person_outline,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Enter name';
                                      if (v.trim().length < 3) return 'Too short';
                                      return null;
                                    },
                                  ),
                                  _gap(),
                                  _buildDropdownField(
                                    value: _selectedDepartment,
                                    label: 'Department',
                                    icon: Icons.apartment_outlined,
                                    items: _departments,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDepartment = value;
                                      });
                                    },
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Select department';
                                      return null;
                                    },
                                  ),
                                  _gap(),
                                  _buildDropdownField(
                                    value: _selectedYear,
                                    label: 'Year of Study',
                                    icon: Icons.calendar_today_outlined,
                                    items: _years,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedYear = value;
                                      });
                                    },
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Select year';
                                      return null;
                                    },
                                  ),
                                  _gap(),
                                  _buildField(
                                    controller: _kluIdController,
                                    label: 'KTU ID',
                                    icon: Icons.badge_outlined,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Enter ID';
                                      if (!RegExp(r'^[A-Za-z0-9_-]{4,}$').hasMatch(v)) return 'Invalid ID';
                                      return null;
                                    },
                                  ),
                                  _gap(),
                                  _buildField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    obscure: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Enter password';
                                      if (v.length < 6) return 'Min 6 chars';
                                      if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add a number';
                                      if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add an uppercase';
                                      return null;
                                    },
                                  ),
                                  _gap(),
                                  _buildField(
                                    controller: _rePasswordController,
                                    label: 'Re-type Password',
                                    icon: Icons.lock_reset_outlined,
                                    obscure: true,
                                    isRePassword: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Re-type password';
                                      if (v != _passwordController.text) return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 34),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _goBack,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: const Text('Back'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _register,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: const Text('Register'),
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 16);

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    bool isRePassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure && (isRePassword ? !_isRePasswordVisible : !_isPasswordVisible),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                  (isRePassword ? _isRePasswordVisible : _isPasswordVisible)
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    if (isRePassword) {
                      _isRePasswordVisible = !_isRePasswordVisible;
                    } else {
                      _isPasswordVisible = !_isPasswordVisible;
                    }
                  });
                },
              )
            : null,
      ),
    );
  }
  
  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
