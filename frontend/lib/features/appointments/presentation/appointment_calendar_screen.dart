import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/india_time.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/snack_service.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_models.dart';

String appointmentDayKey(DateTime day) => IndiaTime.apiDate(day);

final appointmentsForDayProvider =
    FutureProvider.family<List<Appointment>, String>((ref, dayKey) async {
      final result = await ref
          .read(appointmentRepositoryProvider)
          .listAppointments(date: DateTime.parse(dayKey));
      return result.unwrap().items;
    });

class AppointmentCalendarScreen extends ConsumerStatefulWidget {
  const AppointmentCalendarScreen({super.key});

  @override
  ConsumerState<AppointmentCalendarScreen> createState() =>
      _AppointmentCalendarScreenState();
}

class _AppointmentCalendarScreenState
    extends ConsumerState<AppointmentCalendarScreen> {
  DateTime _focusedDay = IndiaTime.dateOnly(IndiaTime.now());
  DateTime _selectedDay = IndiaTime.dateOnly(IndiaTime.now());

  String get _selectedDayKey => appointmentDayKey(_selectedDay);

  @override
  Widget build(BuildContext context) {
    final appointmentsState = ref.watch(
      appointmentsForDayProvider(_selectedDayKey),
    );

    return AppScaffold(
      currentIndex: 2,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await context.push<bool>('/appointments/new');
          if (!mounted || changed != true) {
            return;
          }
          ref.invalidate(appointmentsForDayProvider(_selectedDayKey));
          ref.invalidate(dashboardProvider);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Appointment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Appointments',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAccent,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Monthly'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 920;
                  final calendar = AppCard(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar<dynamic>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2035),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, _selectedDay),
                      calendarFormat: CalendarFormat.month,
                      rowHeight: 72,
                      daysOfWeekHeight: 34,
                      onDaySelected: (selectedDay, focusedDay) => setState(() {
                        _selectedDay = IndiaTime.dateOnly(selectedDay);
                        _focusedDay = IndiaTime.dateOnly(focusedDay);
                      }),
                      onPageChanged: (focusedDay) => setState(
                        () => _focusedDay = IndiaTime.dateOnly(focusedDay),
                      ),
                      headerStyle: HeaderStyle(
                        titleTextStyle: Theme.of(context).textTheme.titleLarge!,
                        formatButtonVisible: false,
                        leftChevronIcon: const Icon(Icons.chevron_left_rounded),
                        rightChevronIcon: const Icon(
                          Icons.chevron_right_rounded,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        cellMargin: const EdgeInsets.all(1),
                        cellPadding: const EdgeInsets.all(6),
                        cellAlignment: Alignment.topLeft,
                        defaultTextStyle: Theme.of(
                          context,
                        ).textTheme.bodyMedium!,
                        weekendTextStyle: Theme.of(
                          context,
                        ).textTheme.bodyMedium!,
                        selectedDecoration: BoxDecoration(
                          color: AppColors.surfaceAccent,
                          border: Border.all(color: AppColors.accent),
                        ),
                        selectedTextStyle: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w700,
                            ),
                        todayDecoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          border: Border.all(color: AppColors.border),
                        ),
                        todayTextStyle: Theme.of(context).textTheme.bodyMedium!
                            .copyWith(color: AppColors.textPrimary),
                        outsideTextStyle: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: AppColors.textSoft),
                      ),
                    ),
                  );
                  final schedule = AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Today's Schedule",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    Text(
                                      DateFormatter.shortDate(_selectedDay),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              appointmentsState.when(
                                data: (items) =>
                                    AppBadge(label: '${items.length} Appts'),
                                loading: () => const SizedBox.shrink(),
                                error: (_, _) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () => ref.refresh(
                              appointmentsForDayProvider(
                                _selectedDayKey,
                              ).future,
                            ),
                            child: appointmentsState.when(
                              loading: () => const AppLoadingList(),
                              error: (error, _) => AppErrorView(
                                message: error is AppError
                                    ? error.message
                                    : 'Failed to load appointments.',
                                onRetry: () => ref.invalidate(
                                  appointmentsForDayProvider(_selectedDayKey),
                                ),
                              ),
                              data: (appointments) => appointments.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No appointments on this day.',
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: appointments.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (_, index) =>
                                          _AppointmentTile(
                                            appointment: appointments[index],
                                            onTap: () => _showDetail(
                                              context,
                                              appointments[index],
                                            ),
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (stack) {
                    return Column(
                      children: [
                        Expanded(child: calendar),
                        const SizedBox(height: 14),
                        SizedBox(height: 300, child: schedule),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 2, child: calendar),
                      const SizedBox(width: 22),
                      Expanded(child: schedule),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    Appointment appointment,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) => AppBottomSheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.patientName ?? 'Patient',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                DateFormatter.dateTime(appointment.scheduledAt),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppBadge(label: appointment.status),
              if ((appointment.reason ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Reason', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  appointment.reason!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              if ((appointment.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  appointment.notes!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _editAppointment(
                      context,
                      ref,
                      sheetContext,
                      appointment,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _changeStatus(context, ref, appointment, 'in_progress'),
                    icon: const Icon(Icons.timelapse_rounded),
                    label: const Text('In Progress'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _postponeAppointment(context, ref, appointment),
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: const Text('Postpone'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _cancelAppointment(context, ref, appointment),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _changeStatus(context, ref, appointment, 'no_show'),
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('No Show'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    String status,
  ) async {
    final result = await ref
        .read(appointmentRepositoryProvider)
        .updateAppointment(
          appointment.id,
          AppointmentUpdatePayload(status: status),
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {
        Navigator.of(context).pop();
        ref.invalidate(appointmentsForDayProvider(_selectedDayKey));
        ref.invalidate(dashboardProvider);
        SnackService.showSuccess(context, 'Appointment updated.');
      },
      error: (error) => SnackService.showError(context, error.message),
    );
  }

  Future<void> _cancelAppointment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel appointment',
      message:
          'Cancel this appointment for ${appointment.patientName ?? 'the patient'}?',
      confirmLabel: 'Cancel appointment',
    );
    if (!confirmed) {
      return;
    }

    final result = await ref
        .read(appointmentRepositoryProvider)
        .cancelAppointment(appointment.id);
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {
        Navigator.of(context).pop();
        ref.invalidate(appointmentsForDayProvider(_selectedDayKey));
        ref.invalidate(dashboardProvider);
        SnackService.showSuccess(context, 'Appointment cancelled.');
      },
      error: (error) => SnackService.showError(context, error.message),
    );
  }

  Future<void> _postponeAppointment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) async {
    final date = await showDatePicker(
      context: context,
      firstDate: IndiaTime.dateOnly(IndiaTime.now()),
      lastDate: DateTime(2035),
      initialDate:
          IndiaTime.dateOnly(
            appointment.scheduledAt,
          ).isBefore(IndiaTime.dateOnly(IndiaTime.now()))
          ? IndiaTime.dateOnly(IndiaTime.now())
          : IndiaTime.dateOnly(appointment.scheduledAt),
    );
    if (date == null || !context.mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(appointment.scheduledAt),
    );
    if (time == null || !context.mounted) {
      return;
    }

    final scheduledAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (scheduledAt.isBefore(IndiaTime.now())) {
      SnackService.showError(context, 'Choose a future time to postpone.');
      return;
    }

    final result = await ref
        .read(appointmentRepositoryProvider)
        .updateAppointment(
          appointment.id,
          AppointmentUpdatePayload(
            scheduledAt: scheduledAt,
            status: 'scheduled',
          ),
        );
    if (!context.mounted) {
      return;
    }
    result.when(
      success: (_) {
        Navigator.of(context).pop();
        ref.invalidate(appointmentsForDayProvider(_selectedDayKey));
        ref.invalidate(
          appointmentsForDayProvider(appointmentDayKey(scheduledAt)),
        );
        ref.invalidate(dashboardProvider);
        SnackService.showSuccess(context, 'Appointment postponed.');
      },
      error: (error) {
        if (error.isConflict) {
          SnackService.showError(
            context,
            'That time slot is already taken. Please choose another time.',
          );
        } else {
          SnackService.showError(context, error.message);
        }
      },
    );
  }

  Future<void> _editAppointment(
    BuildContext context,
    WidgetRef ref,
    BuildContext sheetContext,
    Appointment appointment,
  ) async {
    Navigator.of(sheetContext).pop();
    final changed = await context.push<bool>(
      '/appointments/${appointment.id}/edit',
    );
    if (!mounted || changed != true) {
      return;
    }

    ref.invalidate(appointmentsForDayProvider(_selectedDayKey));
    ref.invalidate(dashboardProvider);
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timePill = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceAccent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      alignment: Alignment.center,
      child: Text(
        DateFormatter.time(appointment.scheduledAt),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.accentDeep),
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appointment.patientName ?? 'Patient',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${appointment.durationMinutes} min',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if ((appointment.reason ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            appointment.reason!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );

    final badge = AppBadge(label: appointment.status);

    return AppCard(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackBadge = constraints.maxWidth < 430;

          if (stackBadge) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }
}
