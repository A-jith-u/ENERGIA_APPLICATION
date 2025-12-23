import 'package:flutter/material.dart';

class DashboardScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<BottomNavigationBarItem> bottomNavItems;
  final Function(int) onBottomNavTapped;
  final int currentIndex;
  final Widget? floatingActionButton;
  final List<Widget>? actions; // <<< ADDED actions parameter >>>

  const DashboardScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.bottomNavItems,
    required this.onBottomNavTapped,
    required this.currentIndex,
    this.floatingActionButton,
    this.actions, // <<< ADDED actions to constructor >>>
  });

  @override
  State<DashboardScaffold> createState() => _DashboardScaffoldState();
}

class _DashboardScaffoldState extends State<DashboardScaffold> {
  // Removed the hardcoded _logout function

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.actions, // <<< NOW USES PASSED ACTIONS >>>
        // Setting automaticallyImplyLeading to false prevents the back button
        // from showing up automatically, addressing your request.
        automaticallyImplyLeading: false, 
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