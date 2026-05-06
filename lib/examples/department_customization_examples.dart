// ignore_for_file: deprecated_member_use, unused_field, file_names
import 'package:flutter/material.dart';
import 'package:energia/models/user_role_model.dart';
import 'package:energia/services/department_auth_service.dart';
import 'package:energia/services/department_customization_service.dart';
import 'package:energia/widgets/department_dashboard_widget.dart';

/// EXAMPLE: Enhanced Coordinator Login with Department Support
/// This shows how to integrate the new department-based system
class EnhancedCoordinatorLoginPage extends StatefulWidget {
  const EnhancedCoordinatorLoginPage({super.key});

  @override
  State<EnhancedCoordinatorLoginPage> createState() =>
      _EnhancedCoordinatorLoginPageState();
}

class _EnhancedCoordinatorLoginPageState
    extends State<EnhancedCoordinatorLoginPage> {
  late DepartmentAuthService _authService;
  late DepartmentCustomizationService _customizationService;

  final _coordinatorIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = DepartmentAuthService();
    _customizationService = DepartmentCustomizationService();
  }

  @override
  void dispose() {
    _coordinatorIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.loginCoordinator(
        coordinatorId: _coordinatorIdController.text.trim(),
        password: _passwordController.text,
      );

      if (result.success && result.user != null) {
        // Login successful, navigate to department-customized dashboard
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/enhanced_coordinator_dashboard',
            arguments: result.user,
          );
        }
      } else {
        setState(() {
          _errorMessage = result.message ?? 'Login failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Technical Coordinator Login'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Icon(Icons.engineering, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Technical Coordinator\nDepartment Access',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Login with your department-assigned credentials',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 40),
            // Coordinator ID Field
            TextField(
              controller: _coordinatorIdController,
              decoration: InputDecoration(
                labelText: 'Coordinator ID',
                hintText: 'e.g., CCSE001',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabled: !_isLoading,
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            // Password Field
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabled: !_isLoading,
              ),
              obscureText: true,
              enabled: !_isLoading,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ],
            const SizedBox(height: 32),
            // Login Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
            const SizedBox(height: 16),
            // Demo Credentials Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo Credentials:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCredentialInfo(
                    'Computer Science',
                    'CCSE001',
                    'Coord@123',
                  ),
                  const SizedBox(height: 8),
                  _buildCredentialInfo('Electrical', 'CELE001', 'Coord@123'),
                  const SizedBox(height: 8),
                  _buildCredentialInfo('Mechanical', 'CMECH01', 'Coord@123'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialInfo(String dept, String id, String pwd) {
    return Text(
      '$dept: $id / $pwd',
      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
    );
  }
}

/// EXAMPLE: Enhanced Coordinator Dashboard with Department Customization
class EnhancedCoordinatorDashboard extends StatefulWidget {
  final EnhancedUser user;

  const EnhancedCoordinatorDashboard({super.key, required this.user});

  @override
  State<EnhancedCoordinatorDashboard> createState() =>
      _EnhancedCoordinatorDashboardState();
}

class _EnhancedCoordinatorDashboardState
    extends State<EnhancedCoordinatorDashboard> {
  late DepartmentCustomizationService _customizationService;

  @override
  void initState() {
    super.initState();
    _customizationService = DepartmentCustomizationService();
  }

  @override
  Widget build(BuildContext context) {
    // Get dashboard features for this user's role and department
    final features = _customizationService.getDashboardFeatures(
      widget.user.role,
      widget.user.department,
    );

    // Get metrics to display
    final metrics = _customizationService.getMetricsForRole(
      widget.user.role,
      widget.user.department,
    );

    return DepartmentDashboard(
      user: widget.user,
      contentBuilder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: 24),

              // Department Overview Card
              DepartmentCard(
                department: widget.user.department,
                title: '${departmentNames[widget.user.department]} Overview',
                child: Text(
                  'Welcome to your department dashboard. You have access to ${features.length} features and ${metrics.length} key metrics.',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),

              // Key Metrics Grid
              Text(
                'Key Metrics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  final metric = metrics[index];
                  return DepartmentMetric(
                    department: widget.user.department,
                    label: metric.title,
                    value: '--',
                    unit: metric.unit,
                    icon: metric.icon,
                  );
                },
              ),
              const SizedBox(height: 32),

              // Available Features Section
              Text(
                'Available Features',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        feature.icon,
                        color: departmentColors[widget.user.department],
                      ),
                      title: Text(feature.title),
                      subtitle: Text(feature.description),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        // Navigate to feature
                        // Navigator.pushNamed(context, feature.route);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Opening ${feature.title}...'),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            departmentColors[widget.user.department] ?? Colors.blue,
            (departmentColors[widget.user.department] ?? Colors.blue)
                .withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${widget.user.name}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.user.getDisplayTitle(),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// EXAMPLE: Route Configuration
/// Add these routes to your main.dart
void exampleRouteConfiguration() {
  // In your material app routes:
  // routes: {
  //   '/enhanced_coordinator_login': (context) =>
  //       const EnhancedCoordinatorLoginPage(),
  //   '/enhanced_coordinator_dashboard': (context) {
  //     final user = ModalRoute.of(context)?.settings.arguments as EnhancedUser?;
  //     if (user == null) {
  //       return const Scaffold(
  //         body: Center(child: Text('Error: User not found')),
  //       );
  //     }
  //     return EnhancedCoordinatorDashboard(user: user);
  //   },
  // }
}

/// EXAMPLE: Department-Specific Menu Implementation
class DepartmentSpecificMenuExample extends StatelessWidget {
  final EnhancedUser user;

  const DepartmentSpecificMenuExample({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    late DepartmentCustomizationService customizationService;
    customizationService = DepartmentCustomizationService();

    final menuItems = customizationService.getDepartmentMenuItems(
      user.department,
      user.role,
    );

    return ListView(
      children:
          menuItems.map((item) {
            return Card(
              color: item.color.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(item.icon, color: item.color),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: item.color,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.pushNamed(context, item.route);
                },
              ),
            );
          }).toList(),
    );
  }
}

/// EXAMPLE: Feature Access Check
class FeatureAccessExample extends StatelessWidget {
  final EnhancedUser user;
  final String featureName;

  const FeatureAccessExample({
    super.key,
    required this.user,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    final hasAccess = user.canAccessFeature(featureName);

    if (!hasAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to access this feature.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink(); // Feature content would go here
  }
}
