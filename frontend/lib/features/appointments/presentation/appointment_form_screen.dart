import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/india_time.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/responsive_split_row.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/snack_service.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../patients/data/patient_repository.dart';
import '../../patients/domain/patient_models.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_models.dart';
import 'appointment_calendar_screen.dart';

final appointmentPatientOptionsProvider = FutureProvider<List<Patient>>((
  ref,
) async {
  final result = await ref
      .read(patientRepositoryProvider)
      .listPatients(pageSize: 100);
  return result.unwrap().items;
});

final appointmentDetailProvider = FutureProvider.family<Appointment, String>((
  ref,
  appointmentId,
) async {
  final result = await ref
      .read(appointmentRepositoryProvider)
      .getAppointment(appointmentId);
  return result.unwrap();
});

class AppointmentFormScreen extends ConsumerStatefulWidget {
  const AppointmentFormScreen({super.key, this.appointmentId});

  final String? appointmentId;

  @override
  ConsumerState<AppointmentFormScreen> createState() =>
      _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController(text: '30');

  String? _patientId;
  String? _patientName;
  DateTime _selectedDate = IndiaTime.dateOnly(IndiaTime.now());
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(IndiaTime.now());
  String _status = 'scheduled';
  bool _submitting = false;
  bool _didPopulate = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentId = widget.appointmentId;
    if (appointmentId == null) {
      return _buildBody(context, null);
    }

    final appointmentState = ref.watch(
      appointmentDetailProvider(appointmentId),
    );
    return appointmentState.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Appointment')),
        body: AppErrorView(
          message: error is AppError
              ? error.message
              : 'Failed to load appointment.',
          onRetry: () =>
              ref.invalidate(appointmentDetailProvider(appointmentId)),
        ),
      ),
      data: (appointment) {
        if (!_didPopulate) {
          _didPopulate = true;
          _patientId = appointment.patientId;
          _patientName = appointment.patientName;
          _selectedDate = IndiaTime.dateOnly(appointment.scheduledAt);
          _selectedTime = TimeOfDay.fromDateTime(appointment.scheduledAt);
          _durationController.text = appointment.durationMinutes.toString();
          _reasonController.text = appointment.reason ?? '';
          _notesController.text = appointment.notes ?? '';
          _status = appointment.status;
        }
        return _buildBody(context, appointment);
      },
    );
  }

  Widget _buildBody(BuildContext context, Appointment? existingAppointment) {
    final isEditing = existingAppointment != null;
    final patientsState = ref.watch(appointmentPatientOptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Appointment' : 'New Appointment'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              if (isEditing)
                AppTextField(
                  label: 'Patient',
                  readOnly: true,
                  controller: TextEditingController(
                    text: _patientName ?? 'Patient',
                  ),
                )
              else
                patientsState.when(
                  loading: () => const AppLoading(),
                  error: (error, _) => AppErrorView(
                    message: error is AppError
                        ? error.message
                        : 'Failed to load patient list.',
                    onRetry: () =>
                        ref.invalidate(appointmentPatientOptionsProvider),
                  ),
                  data: (patients) => DropdownButtonFormField<String>(
                    initialValue: _patientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Patient'),
                    validator: (value) =>
                        value == null ? 'Please select a patient' : null,
                    items: patients
                        .map(
                          (patient) => DropdownMenuItem<String>(
                            value: patient.id,
                            child: Text(
                              '${patient.name} • ${patient.patientUid}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _patientId = value),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              ResponsiveSplitRow(
                children: [
                  AppTextField(
                    label: 'Date',
                    readOnly: true,
                    controller: TextEditingController(
                      text: DateFormatter.shortDate(_selectedDate),
                    ),
                    onTap: _pickDate,
                  ),
                  AppTextField(
                    label: 'Time',
                    readOnly: true,
                    controller: TextEditingController(
                      text: _selectedTime.format(context),
                    ),
                    onTap: _pickTime,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _durationController,
                label: 'Duration in minutes',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 5 || parsed > 480) {
                    return 'Enter a duration between 5 and 480 minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              if (isEditing) ...[
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(
                      value: 'scheduled',
                      child: Text('Scheduled'),
                    ),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                    DropdownMenuItem(value: 'no_show', child: Text('No Show')),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'scheduled'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(controller: _reasonController, label: 'Reason'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _notesController,
                label: 'Notes',
                maxLines: 5,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: isEditing ? 'Save appointment' : 'Create appointment',
                isLoading: _submitting,
                onPressed: _submitting
                    ? null
                    : () => _submit(existingAppointment),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _selectedDate,
    );
    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (result != null) {
      setState(() => _selectedTime = result);
    }
  }

  Future<void> _submit(Appointment? existingAppointment) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final patientId = _patientId;
    if (existingAppointment == null && patientId == null) {
      SnackService.showError(context, 'Please select a patient.');
      return;
    }

    setState(() => _submitting = true);
    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final duration = int.parse(_durationController.text.trim());
    final repository = ref.read(appointmentRepositoryProvider);

    final result = existingAppointment == null
        ? await repository.createAppointment(
            AppointmentCreatePayload(
              patientId: patientId!,
              scheduledAt: scheduledAt,
              durationMinutes: duration,
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          )
        : await repository.updateAppointment(
            existingAppointment.id,
            AppointmentUpdatePayload(
              scheduledAt: scheduledAt,
              durationMinutes: duration,
              status: _status,
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(
          appointmentsForDayProvider(appointmentDayKey(scheduledAt)),
        );
        ref.invalidate(dashboardProvider);
        SnackService.showSuccess(
          context,
          existingAppointment == null
              ? 'Appointment created.'
              : 'Appointment updated.',
        );
        context.pop(true);
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

    if (mounted) {
      setState(() => _submitting = false);
    }
  }
}
