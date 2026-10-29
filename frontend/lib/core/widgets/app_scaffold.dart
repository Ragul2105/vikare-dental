import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../theme/app_colors.dart';

class ScreenSize {
  ScreenSize._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 860;
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
    'Patient Records',
    Icons.folder_shared_outlined,
    Icons.folder_shared_rounded,
    '/patients',
  ),
  _NavDestination(
    'Appointments',
    Icons.calendar_month_outlined,
    Icons.calendar_month_rounded,
    '/appointments',
  ),
  _NavDestination(
    'Admin',
    Icons.settings_outlined,
    Icons.settings_rounded,
    '/admin',
  ),
];

class AppScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (ScreenSize.isTablet(context)) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: Row(
          children: [
            _ClinicSidebar(currentIndex: currentIndex),
            Expanded(
              child: Column(
                children: [
                  const _ClinicHeader(),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          const SafeArea(bottom: false, child: _ClinicHeader(compact: true)),
          Expanded(child: body),
        ],
      ),
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

class _ClinicSidebar extends ConsumerWidget {
  const _ClinicSidebar({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 255,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFD),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 18, 28),
              child: _BrandMark(),
            ),
            ...List.generate(_destinations.length, (index) {
              final item = _destinations[index];
              final selected = index == currentIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: selected
                      ? AppColors.surfaceAccent
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go(item.route),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: selected
                                ? AppColors.accent
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? item.activeIcon : item.icon,
                            size: 21,
                            color: selected
                                ? AppColors.info
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: selected
                                      ? AppColors.info
                                      : AppColors.textMuted,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/appointments/new'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Appointment'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(indent: 16, endIndent: 16),
            Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.textMuted,
                ),
                title: const Text('Logout'),
                textColor: AppColors.textMuted,
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/images/vikare-logo.jpeg',
            width: 42,
            height: 42,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VIKARE',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.info,
                letterSpacing: 0.7,
              ),
            ),
            Text(
              'Dental clinic',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _ClinicHeader extends ConsumerWidget {
  const _ClinicHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Container(
      height: compact ? 64 : 80,
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (compact)
            const Expanded(child: _BrandMark())
          else ...[
            const Spacer(),
            SizedBox(
              width: 260,
              height: 40,
              child: TextField(
                onSubmitted: (_) => context.go('/patients'),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search_rounded),
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accent),
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 34, color: AppColors.border),
          const SizedBox(width: 20),
          if (!compact) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user?.name ?? 'Clinic user',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  (user?.role ?? 'staff').toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.info,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.surfaceAccent,
            foregroundColor: AppColors.accentDeep,
            child: Text(
              (user?.name.isNotEmpty ?? false)
                  ? user!.name.characters.first.toUpperCase()
                  : 'V',
            ),
          ),
        ],
      ),
    );
  }
}
