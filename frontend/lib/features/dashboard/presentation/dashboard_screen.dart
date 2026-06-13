import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/snack_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final user = ref.watch(authControllerProvider).user;

    return AppScaffold(
      currentIndex: 0,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(user?.name),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormatter.fullDate(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.go('/patients'),
                          icon: const Icon(Icons.people_alt_outlined),
                          label: const Text('Patients'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => context.go('/appointments'),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Calendar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _logout(context, ref),
                          icon: const Icon(Icons.logout_outlined),
                          label: const Text('Logout'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              dashboardState.when(
                loading: () =>
                    const SizedBox(height: 280, child: AppLoadingList()),
                error: (error, _) => AppErrorView(
                  message: error is AppError
                      ? error.message
                      : 'Failed to load dashboard.',
                  onRetry: () => ref.invalidate(dashboardProvider),
                ),
                data: (summary) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _StatCard(
                          label: 'Today\'s appointments',
                          value: '${summary.appointmentsToday}',
                          icon: Icons.event_available_rounded,
                          color: AppColors.accent,
                        ),
                        _StatCard(
                          label: 'Total patients',
                          value: '${summary.totalPatients}',
                          icon: Icons.people_alt_rounded,
                          color: AppColors.success,
                        ),
                        _StatCard(
                          label: 'Active staff',
                          value: '${summary.totalStaff}',
                          icon: Icons.badge_outlined,
                          color: AppColors.highlight,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Today\'s schedule',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (summary.appointments.isEmpty)
                      const AppCard(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Text('No appointments scheduled for today.'),
                        ),
                      )
                    else
                      ...summary.appointments.map(
                        (appointment) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AppCard(
                            onTap: () => context.go('/appointments'),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final stackBadge = constraints.maxWidth < 420;
                                final timePill = Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAccent,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    DateFormatter.time(appointment.scheduledAt),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(color: AppColors.accentDeep),
                                  ),
                                );
                                final details = Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appointment.patientName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if ((appointment.reason ?? '')
                                        .isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        appointment.reason!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ],
                                );
                                final badge = AppBadge(
                                  label: appointment.status,
                                );

                                if (stackBadge) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          timePill,
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(child: details),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      badge,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    timePill,
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(child: details),
                                    const SizedBox(width: AppSpacing.sm),
                                    badge,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return name == null || name.isEmpty ? greeting : '$greeting, $name';
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Log out',
      message: 'End the current session on this device?',
      confirmLabel: 'Log out',
    );
    if (!confirmed) {
      return;
    }

    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) {
      SnackService.showSuccess(context, 'Logged out.');
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
