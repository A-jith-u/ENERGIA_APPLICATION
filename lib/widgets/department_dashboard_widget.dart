import 'package:flutter/material.dart';
import 'package:energia/models/user_role_model.dart';
import 'package:energia/services/department_customization_service.dart';

/// Customized dashboard layout based on user's department and role
class DepartmentDashboard extends StatefulWidget {
  final EnhancedUser user;
  final Widget Function(BuildContext) contentBuilder;

  const DepartmentDashboard({
    super.key,
    required this.user,
    required this.contentBuilder,
  });

  @override
  State<DepartmentDashboard> createState() => _DepartmentDashboardState();
}

class _DepartmentDashboardState extends State<DepartmentDashboard> {
  late DepartmentCustomizationService _customizationService;
  final int _selectedMenuIndex = 0;

  @override
  void initState() {
    super.initState();
    _customizationService = DepartmentCustomizationService();
  }

  @override
  Widget build(BuildContext context) {
    final features = _customizationService.getDashboardFeatures(
      widget.user.role,
      widget.user.department,
    );
    final menuItems = _customizationService.getDepartmentMenuItems(
      widget.user.department,
      widget.user.role,
    );

    return Scaffold(
      appBar: _buildDepartmentAppBar(context),
      drawer: _buildDepartmentDrawer(menuItems, context),
      body: Row(
        children: [
          // Sidebar for larger screens
          if (MediaQuery.of(context).size.width > 800)
            _buildSidebar(menuItems, context),
          // Main content
          Expanded(
            child: widget.contentBuilder(context),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildDepartmentAppBar(BuildContext context) {
    final deptColor = departmentColors[widget.user.department] ?? Colors.blue;

    return AppBar(
      backgroundColor: deptColor,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            departmentNames[widget.user.department] ?? 'Dashboard',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.user.getDisplayTitle(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Colors.white70,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              widget.user.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(List<DepartmentMenuItem> menuItems, BuildContext context) {
    final deptColor = departmentColors[widget.user.department] ?? Colors.blue;

    return Container(
      width: 280,
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: deptColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    departmentIcons[widget.user.department],
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    departmentNames[widget.user.department] ?? 'Department',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.user.role.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._buildSidebarItems(menuItems, context),
            const SizedBox(height: 32),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSidebarItems(
    List<DepartmentMenuItem> items,
    BuildContext context,
  ) {
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, item.route),
              icon: Icon(item.icon, size: 20),
              label: Text(item.title),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: item.color,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  Widget _buildDrawer(List<DepartmentMenuItem> menuItems, BuildContext context) {
    final deptColor = departmentColors[widget.user.department] ?? Colors.blue;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: deptColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  departmentIcons[widget.user.department],
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  departmentNames[widget.user.department] ?? 'Department',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...menuItems.map(
            (item) => ListTile(
              leading: Icon(item.icon, color: item.color),
              title: Text(item.title),
              onTap: () => Navigator.pushNamed(context, item.route),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentDrawer(
    List<DepartmentMenuItem> menuItems,
    BuildContext context,
  ) {
    return _buildDrawer(menuItems, context);
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton.icon(
        onPressed: () => _logout(context),
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/role_selection');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

/// Department-themed card widget for displaying information
class DepartmentCard extends StatelessWidget {
  final Department department;
  final String title;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const DepartmentCard({
    super.key,
    required this.department,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deptColor = departmentColors[department] ?? Colors.blue;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: _buildCardContent(deptColor),
            )
          : _buildCardContent(deptColor),
    );
  }

  Widget _buildCardContent(Color deptColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: deptColor.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                departmentIcons[department],
                color: deptColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: deptColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}

/// Department-themed metric display widget
class DepartmentMetric extends StatelessWidget {
  final Department department;
  final String label;
  final String value;
  final String unit;
  final IconData icon;

  const DepartmentMetric({
    super.key,
    required this.department,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final deptColor = departmentColors[department] ?? Colors.blue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: deptColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: deptColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: deptColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: deptColor,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
