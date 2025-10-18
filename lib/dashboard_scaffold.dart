import 'package:flutter/material.dart';

class DashboardScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<BottomNavigationBarItem> bottomNavItems;
  final Function(int) onBottomNavTapped;
  final int currentIndex;
  final Widget? floatingActionButton;

  const DashboardScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.bottomNavItems,
    required this.onBottomNavTapped,
    required this.currentIndex,
    this.floatingActionButton,
  });

  @override
  State<DashboardScaffold> createState() => _DashboardScaffoldState();
}

class _DashboardScaffoldState extends State<DashboardScaffold> {
  void _logout(BuildContext context) {
    // Clear user session, etc.
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        items: widget.bottomNavItems,
        currentIndex: widget.currentIndex,
        onTap: widget.onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
