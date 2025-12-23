// Student login UI page. Performs simple username/password login against
// the backend `/auth/login` endpoint and stores the JWT token locally.
// Uses `lib/services/api.dart` for HTTP requests and `SharedPreferences` for persistence.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'registration_page.dart';
import 'services/api.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  _StudentLoginPageState createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _selectedDepartment;
  String? _errorMessage;
  
  final List<String> _departments = ['CSE', 'ECE', 'EEE', 'IT', 'RA', 'ME'];

  void _login() {
    if (_formKey.currentState?.validate() != true) return;
    _performLogin();
  }

  Future<void> _performLogin() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final token = await login(name, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      Navigator.of(context).pop();
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      Navigator.of(context).pop();
      setState(() {
        _errorMessage = e is ApiError ? e.message : 'Login failed: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
                constraints: const BoxConstraints(maxWidth: 500),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Hero(
                              tag: 'avatar',
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: colorScheme.primary.withOpacity(.15),
                                child: Icon(Icons.school, size: 46, color: colorScheme.primary),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Campus Login',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Access your student dashboard',
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
                                    label: 'Student Name / ID',
                                    icon: Icons.person_outline,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Enter your student name or ID';
                                      if (v.trim().length < 3) return 'Too short';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
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
                                  const SizedBox(height: 18),
                                  _buildField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    obscure: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Enter password';
                                      if (v.length < 6) return 'Min 6 characters';
                                      final hasNum = v.contains(RegExp(r'[0-9]'));
                                      if (!hasNum) return 'Include a number';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    child: const Text('Login'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => RegistrationPage()),
                                      );
                                    },
                                    child: const Text('New user? Register'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                // Navigate back to the main role selection page
                                Navigator.pushReplacementNamed(context, '/role_selection');
                              },
                              child: const Text('Back to Role Selection'),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text('Forgot Password?'),
                              ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure && !_isPasswordVisible,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
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
