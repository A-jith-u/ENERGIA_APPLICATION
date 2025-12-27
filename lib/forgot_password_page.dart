import 'package:flutter/material.dart';
import 'dart:ui';
import 'services/api.dart';
import 'services/notifier.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  int _step = 1; // 1: request, 2: confirm
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  Future<void> _requestOtp() async {
    if (!_formKeyStep1.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await requestPasswordReset(_usernameController.text.trim());
      setState(() {
        _step = 2;
      });
      AppNotifier.showSuccess(context, 'OTP sent. It expires in 5 minutes.');
    } catch (e) {
      final msg = e is ApiError ? e.message : 'Reset request failed: ${e.toString()}';
      AppNotifier.showError(context, msg);
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _confirmReset() async {
    if (!_formKeyStep2.currentState!.validate()) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      AppNotifier.showError(context, 'Passwords do not match');
      return;
    }
    setState(() => _submitting = true);
    try {
      await confirmPasswordReset(
        _usernameController.text.trim(),
        _otpController.text.trim(),
        _newPasswordController.text,
      );
      AppNotifier.showSuccess(context, 'Password updated. Please log in.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e is ApiError ? e.message : 'Reset failed: ${e.toString()}';
      AppNotifier.showError(context, msg);
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
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
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: colorScheme.primary.withOpacity(.15),
                                child: Icon(Icons.lock_reset, size: 46, color: colorScheme.primary),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Reset Password',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _step == 1
                                    ? 'Request an OTP to your registered email'
                                    : 'Enter the OTP and set a new password',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 28),
                              _step == 1 ? _buildStep1(colorScheme) : _buildStep2(colorScheme),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _submitting ? null : () => Navigator.pop(context),
                                      child: const Text('Back to Login'),
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
          if (_submitting)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStep1(ColorScheme colorScheme) {
    return Form(
      key: _formKeyStep1,
      child: Column(
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'KTU ID / Email',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your identifier';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _requestOtp,
                  child: const Text('Send OTP'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ColorScheme colorScheme) {
    return Form(
      key: _formKeyStep2,
      child: Column(
        children: [
          TextFormField(
            controller: _otpController,
            decoration: const InputDecoration(
              labelText: 'OTP',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter the OTP';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Re-enter new password';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => setState(() => _step = 1),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _confirmReset,
                  child: const Text('Confirm Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
