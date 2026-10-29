import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/snack_service.dart';
import '../../appointments/data/appointment_repository.dart';
import '../../appointments/domain/appointment_models.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    return AppScaffold(
      currentIndex: 0,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: state.when(
          loading: () => const AppLoadingList(),
          error: (error, _) => AppErrorView(
            message: error is AppError
                ? error.message
                : 'Failed to load dashboard.',
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (summary) => ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Text(
                'Dashboard Overview',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * 22)) / columns;
                  return Wrap(
                    spacing: 22,
                    runSpacing: 18,
                    children: [
                      _StatCard(
                        width: width,
                        icon: Icons.groups_outlined,
                        label: 'Total Patients',
                        value: '${summary.totalPatients}',
                      ),
                      _StatCard(
                        width: width,
                        icon: Icons.event_available_outlined,
                        label: "Today's Appointments",
                        value: '${summary.appointmentsToday}',
                        note: '${summary.completedToday} completed',
                      ),
                      _StatCard(
                        width: width,
                        icon: Icons.medical_services_outlined,
                        label: 'Total Staff',
                        value: '${summary.totalStaff}',
                        note: 'Active clinic staff',
                      ),
                      _StatCard(
                        width: width,
                        icon: Icons.person_add_alt_outlined,
                        label: 'New Patients This Month',
                        value: '${summary.newPatientsThisMonth}',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Today's Schedule",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.go('/appointments'),
                            child: const Text('View Full Calendar'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    if (summary.appointments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('No appointments scheduled for today.'),
                      )
                    else ...[
                      const _ScheduleHeader(),
                      ...summary.appointments.map(
                        (item) => _ScheduleRow(
                          appointment: item,
                          onAction: (action) =>
                              _handleAction(context, ref, item, action),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 850;
                  final charts = [
                    Expanded(
                      child: _TrendCard(points: summary.appointmentTrend),
                    ),
                    Expanded(
                      child: _TreatmentCard(items: summary.topTreatments),
                    ),
                  ];
                  if (stacked) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 310,
                          child: _TrendCard(points: summary.appointmentTrend),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 310,
                          child: _TreatmentCard(items: summary.topTreatments),
                        ),
                      ],
                    );
                  }
                  return SizedBox(
                    height: 310,
                    child: Row(
                      children: [
                        charts[0],
                        const SizedBox(width: 28),
                        charts[1],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    DashboardAppointment item,
    String action,
  ) async {
    if (action == 'calendar') {
      context.go('/appointments');
      return;
    }
    if (action == 'cancel' || action == 'no_show') {
      final noShow = action == 'no_show';
      final confirmed = await ConfirmDialog.show(
        context,
        title: noShow ? 'Mark no-show' : 'Cancel appointment',
        message: noShow
            ? 'Mark ${item.patientName} as a no-show?'
            : 'Cancel ${item.patientName}\'s appointment?',
        confirmLabel: noShow ? 'Mark no-show' : 'Cancel appointment',
      );
      if (!confirmed) return;
      final repository = ref.read(appointmentRepositoryProvider);
      final result = noShow
          ? await repository.updateAppointment(
              item.id,
              const AppointmentUpdatePayload(status: 'no_show'),
            )
          : await repository.cancelAppointment(
              item.id,
              reason: 'Patient unable to attend',
            );
      if (!context.mounted) return;
      result.when(
        success: (_) {
          ref.invalidate(dashboardProvider);
          SnackService.showSuccess(
            context,
            noShow ? 'Appointment marked no-show.' : 'Appointment cancelled.',
          );
        },
        error: (error) => SnackService.showError(context, error.message),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 178,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.info, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.displayMedium),
            if (note != null)
              Text(note!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF0F4FC),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: const Row(
      children: [
        SizedBox(width: 128, child: _HeaderLabel('TIME')),
        Expanded(flex: 2, child: _HeaderLabel('PATIENT NAME')),
        Expanded(flex: 2, child: _HeaderLabel('REASON FOR VISIT')),
        SizedBox(width: 136, child: _HeaderLabel('STATUS')),
        SizedBox(width: 112, child: _HeaderLabel('ACTION')),
      ],
    ),
  );
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.visible,
    softWrap: false,
    style: Theme.of(context).textTheme.labelMedium,
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.appointment, required this.onAction});
  final DashboardAppointment appointment;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(DateFormatter.time(appointment.scheduledAt)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFDCEBFF),
                  child: Text(
                    appointment.patientName.characters
                        .take(2)
                        .join()
                        .toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    appointment.patientName,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(appointment.reason ?? 'Routine checkup'),
          ),
          SizedBox(width: 136, child: AppBadge(label: appointment.status)),
          SizedBox(
            width: 112,
            child: PopupMenuButton<String>(
              onSelected: onAction,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'calendar', child: Text('View calendar')),
                PopupMenuItem(value: 'no_show', child: Text('Mark no-show')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard({required this.points});
  final List<DashboardTrendPoint> points;

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Appointments Trend (Last 6 Months)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              'Monthly Stats',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 26),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                onHover: (event) {
                  if (widget.points.isEmpty) return;
                  final index = _nearestPointIndex(
                    event.localPosition.dx,
                    constraints.maxWidth,
                    widget.points.length,
                  );
                  if (index != _hoveredIndex) {
                    setState(() => _hoveredIndex = index);
                  }
                },
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (widget.points.isEmpty) return;
                    setState(
                      () => _hoveredIndex = _nearestPointIndex(
                        details.localPosition.dx,
                        constraints.maxWidth,
                        widget.points.length,
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        painter: _TrendPainter(
                          widget.points,
                          hoveredIndex: _hoveredIndex,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      if (_hoveredIndex != null &&
                          _hoveredIndex! < widget.points.length)
                        _TrendTooltip(
                          point: widget.points[_hoveredIndex!],
                          left: _pointX(
                            _hoveredIndex!,
                            constraints.maxWidth,
                            widget.points.length,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: widget.points
              .asMap()
              .entries
              .map(
                (entry) => Text(
                  entry.value.month.toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: entry.key == _hoveredIndex
                        ? AppColors.info
                        : AppColors.textMuted,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );

  int _nearestPointIndex(double dx, double width, int count) {
    if (count <= 1) return 0;
    final step = width / (count - 1);
    return (dx / step).round().clamp(0, count - 1);
  }

  double _pointX(int index, double width, int count) {
    if (count <= 1) return width / 2;
    return index * width / (count - 1);
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.points, {this.hoveredIndex});
  final List<DashboardTrendPoint> points;
  final int? hoveredIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final maxValue = math.max(
      1,
      points.map((item) => item.count).reduce(math.max),
    );
    final line = Paint()
      ..color = AppColors.accentDeep
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = AppColors.accent;
    final hoverDot = Paint()..color = AppColors.accentDeep;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : i * size.width / (points.length - 1);
      final y =
          size.height -
          ((points[i].count / maxValue) * (size.height - 22)) -
          10;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(
        Offset(x, y),
        i == hoveredIndex ? 6 : 4,
        i == hoveredIndex ? hoverDot : dot,
      );
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.hoveredIndex != hoveredIndex;
}

class _TrendTooltip extends StatelessWidget {
  const _TrendTooltip({required this.point, required this.left});

  final DashboardTrendPoint point;
  final double left;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 0,
    left: (left - 42).clamp(0.0, double.infinity).toDouble(),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '${point.month}: ${point.count}',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
    ),
  );
}

class _TreatmentCard extends StatelessWidget {
  const _TreatmentCard({required this.items});
  final List<DashboardTreatment> items;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.isEmpty
        ? 1
        : math.max(1, items.map((item) => item.count).reduce(math.max));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Top 5 Treatments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text('Frequency', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 22),
          if (items.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Treatment data will appear after visits are recorded.',
                ),
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        Text(
                          '${item.count}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.info),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LinearProgressIndicator(
                      value: item.count / maxValue,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.accent,
                      backgroundColor: const Color(0xFFE6EDF9),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
