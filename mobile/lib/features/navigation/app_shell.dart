import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../tracking/tracking_screen.dart';
import 'section_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _selectedIndex = ValueNotifier<int>(0);

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Ana Sayfa',
    ),
    NavigationDestination(
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment),
      label: 'Planım',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_awesome_outlined),
      selectedIcon: Icon(Icons.auto_awesome),
      label: 'AI',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: 'Takip',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Rehberim',
    ),
  ];

  @override
  void dispose() {
    _selectedIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => _navigatorKey.currentState!.pop(result),
    // Logout/expiry removes this shell and its entire protected route stack.
    child: Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        final user = widget.auth.user!;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => settings.name == '/profile'
              ? ProfileScreen(auth: widget.auth, user: user)
              : _mainScreen(context),
        );
      },
    ),
  );

  Widget _mainScreen(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _selectedIndex,
    builder: (context, index, _) => Scaffold(
      appBar: AppBar(
        title: Text(_destinations[index].label),
        actions: [
          if (index == 0)
            IconButton(
              tooltip: 'Profil ve Ayarlar',
              onPressed: () =>
                  _navigatorKey.currentState!.pushNamed('/profile'),
              icon: const Icon(Icons.account_circle_outlined),
            ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          HomeScreen(
            user: widget.auth.user!,
            onOpenPlan: () => _selectedIndex.value = 1,
            onOpenTracking: () => _selectedIndex.value = 3,
            onOpenAdvisors: () => _selectedIndex.value = 4,
          ),
          const MyPlanScreen(),
          const AIScreen(),
          TrackingScreen(api: widget.auth.api, active: index == 3),
          const MyAdvisorsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (selected) => _selectedIndex.value = selected,
        destinations: _destinations,
      ),
    ),
  );
}
