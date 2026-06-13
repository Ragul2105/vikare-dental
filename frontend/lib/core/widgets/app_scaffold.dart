import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class ScreenSize {
  ScreenSize._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 720;
}

class _NavDestination {
  const _NavDestination(this.label, this.icon, this.activeIcon, this.route);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}

const _destinations = <_NavDestination>[
  _NavDestination(
    'Dashboard',
    Icons.dashboard_outlined,
    Icons.dashboard_rounded,
    '/dashboard',
  ),
  _NavDestination(
    'Patients',
    Icons.people_outline_rounded,
    Icons.people_rounded,
    '/patients',
  ),
  _NavDestination(
    'Calendar',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
    '/appointments',
  ),
  _NavDestination('Admin', Icons.tune_outlined, Icons.tune_rounded, '/admin'),
];

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.body,
    this.floatingActionButton,
  });

  final int currentIndex;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (ScreenSize.isTablet(context)) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        floatingActionButton: floatingActionButton,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) =>
                  context.go(_destinations[index].route),
              extended: MediaQuery.sizeOf(context).width >= 1000,
              destinations: _destinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.activeIcon),
                      label: Text(destination.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_destinations[index].route),
        items: _destinations
            .map(
              (destination) => BottomNavigationBarItem(
                icon: Icon(destination.icon),
                activeIcon: Icon(destination.activeIcon),
                label: destination.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
