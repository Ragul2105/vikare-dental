import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/india_time.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/responsive_split_row.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/snack_service.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../auth/presentation/pin_login_screen.dart';
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
  final _patientSearchController = TextEditingController();
  final _patientFocusNode = FocusNode();
  final _newPatientMobileController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController(text: '30');

  String? _patientId;
  String? _patientName;
  String? _practitionerId;
  DateTime _selectedDate = IndiaTime.dateOnly(IndiaTime.now());
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(IndiaTime.now());
  String _status = 'scheduled';
  bool _submitting = false;
  bool _didPopulate = false;
  bool _isNewPatientDraft = false;

  @override
  void dispose() {
    _patientSearchController.dispose();
    _patientFocusNode.dispose();
    _newPatientMobileController.dispose();
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
          _patientSearchController.text = appointment.patientName ?? '';
          _selectedDate = IndiaTime.dateOnly(appointment.scheduledAt);
          _selectedTime = TimeOfDay.fromDateTime(appointment.scheduledAt);
          _durationController.text = appointment.durationMinutes.toString();
          _reasonController.text = appointment.reason ?? '';
          _notesController.text = appointment.notes ?? '';
          _status = appointment.status;
          _practitionerId = appointment.assignedPractitionerId;
        }
        return _buildBody(context, appointment);
      },
    );
  }

  Widget _buildBody(BuildContext context, Appointment? existingAppointment) {
    final isEditing = existingAppointment != null;
    final patientsState = ref.watch(appointmentPatientOptionsProvider);
    final practitionersState = ref.watch(authUsersProvider);

    return AppScaffold(
      currentIndex: 2,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Text(
                  isEditing ? 'Edit Appointment' : 'Add Appointment',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 900;
                final editor = Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appointment Details',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          if (isEditing)
                            AppTextField(
                              label: 'Patient Name',
                              readOnly: true,
                              controller: TextEditingController(
                                text: _patientName ?? 'Patient',
                              ),
                              prefixIcon: const Icon(Icons.person_outline),
                            )
                          else
                            patientsState.when(
                              loading: () => const AppLoading(),
                              error: (error, _) => AppErrorView(
                                message: error is AppError
                                    ? error.message
                                    : 'Failed to load patient list.',
                                onRetry: () => ref.invalidate(
                                  appointmentPatientOptionsProvider,
                                ),
                              ),
                              data: (patients) => _patientLookupField(patients),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          ResponsiveSplitRow(
                            children: [
                              AppTextField(
                                controller: _reasonController,
                                label: 'Reason for Visit',
                                hint: 'Routine checkup',
                              ),
                              practitionersState.when(
                                loading: () => const AppLoading(),
                                error: (error, _) => AppErrorView(
                                  message: error is AppError
                                      ? error.message
                                      : 'Failed to load practitioners.',
                                  onRetry: () =>
                                      ref.invalidate(authUsersProvider),
                                ),
                                data: (users) =>
                                    DropdownButtonFormField<String>(
                                      initialValue: _practitionerId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Assigned Practitioner',
                                      ),
                                      items: users
                                          .map(
                                            (user) => DropdownMenuItem(
                                              value: user.id,
                                              child: Text(
                                                '${user.name} (${user.role})',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) => setState(
                                        () => _practitionerId = value,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _notesController,
                            label: 'Clinical Notes & Requests',
                            hint:
                                'Mention concerns, allergies, or previous treatment details...',
                            maxLines: 5,
                          ),
                          if (isEditing) ...[
                            const SizedBox(height: AppSpacing.md),
                            _statusField(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Select Slot',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ResponsiveSplitRow(
                            children: [
                              AppTextField(
                                label: 'Date',
                                readOnly: true,
                                controller: TextEditingController(
                                  text: DateFormatter.shortDate(_selectedDate),
                                ),
                                suffixIcon: const Icon(Icons.calendar_today),
                                onTap: _pickDate,
                              ),
                              AppTextField(
                                label: 'Time',
                                readOnly: true,
                                controller: TextEditingController(
                                  text: _selectedTime.format(context),
                                ),
                                suffixIcon: const Icon(Icons.access_time),
                                onTap: _pickTime,
                              ),
                              AppTextField(
                                controller: _durationController,
                                label: 'Duration (minutes)',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final parsed = int.tryParse(value ?? '');
                                  if (parsed == null ||
                                      parsed < 5 ||
                                      parsed > 480) {
                                    return 'Use 5–480 minutes';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final summary = _AppointmentSummary(
                  date: _selectedDate,
                  time: _selectedTime,
                  duration: _durationController.text,
                  submitLabel: isEditing
                      ? 'Save Appointment'
                      : 'Schedule Appointment',
                  isSubmitting: _submitting,
                  onSubmit: _submitting
                      ? null
                      : () => _submit(existingAppointment),
                  onCancel: () => context.canPop()
                      ? context.pop()
                      : context.go('/appointments'),
                );
                if (stack) {
                  return Column(
                    children: [editor, const SizedBox(height: 24), summary],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: editor),
                    const SizedBox(width: 24),
                    SizedBox(width: 304, child: summary),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statusField() => DropdownButtonFormField<String>(
    initialValue: _status,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Status'),
    items: const [
      DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
      DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
      DropdownMenuItem(value: 'completed', child: Text('Completed')),
      DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
      DropdownMenuItem(value: 'no_show', child: Text('No Show')),
    ],
    onChanged: (value) => setState(() => _status = value ?? 'scheduled'),
  );

  Widget _patientLookupField(List<Patient> patients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<Patient>(
          textEditingController: _patientSearchController,
          focusNode: _patientFocusNode,
          displayStringForOption: (patient) => patient.name,
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return patients.take(8);
            return patients
                .where(
                  (patient) =>
                      patient.name.toLowerCase().contains(query) ||
                      patient.patientUid.toLowerCase().contains(query) ||
                      patient.mobile.contains(query),
                )
                .take(8);
          },
          onSelected: (patient) {
            setState(() {
              _patientId = patient.id;
              _patientName = patient.name;
              _isNewPatientDraft = false;
              _newPatientMobileController.clear();
            });
          },
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) =>
                  TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Patient Name',
                      hintText: 'Start typing a patient name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (_patientId != null) return null;
                      if ((value ?? '').trim().isEmpty) {
                        return 'Please enter a patient name';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final normalized = value.trim().toLowerCase();
                      final exact = patients
                          .where(
                            (patient) =>
                                patient.name.trim().toLowerCase() == normalized,
                          )
                          .firstOrNull;
                      setState(() {
                        _patientId = exact?.id;
                        _patientName = value.trim();
                        _isNewPatientDraft =
                            value.trim().isNotEmpty && exact == null;
                      });
                    },
                  ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 240,
                  maxWidth: 520,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final patient = options.elementAt(index);
                    return ListTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: Text(patient.name),
                      subtitle: Text(
                        '${patient.patientUid} • ${patient.mobile}',
                      ),
                      onTap: () => onSelected(patient),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (_isNewPatientDraft) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E8),
              border: Border.all(color: const Color(0xFFFFCCAD)),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add "${_patientSearchController.text.trim()}" as a new patient for this appointment.',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _newPatientMobileController,
                  label: 'Phone number for WhatsApp reminders',
                  hint: '+91 00000 00000',
                  keyboardType: TextInputType.phone,
                  validator: Validators.mobile,
                ),
              ],
            ),
          ),
        ],
      ],
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

    var patientId = _patientId;
    final patientName = _patientSearchController.text.trim();
    if (existingAppointment == null &&
        patientId == null &&
        patientName.isEmpty) {
      SnackService.showError(context, 'Please select or enter a patient.');
      return;
    }

    setState(() => _submitting = true);
    if (existingAppointment == null && patientId == null) {
      final mobileError = Validators.mobile(_newPatientMobileController.text);
      if (mobileError != null) {
        SnackService.showError(context, mobileError);
        setState(() => _submitting = false);
        return;
      }
      final patientResult = await ref
          .read(patientRepositoryProvider)
          .createPatient(
            PatientPayload(
              name: patientName,
              mobile: _newPatientMobileController.text.trim(),
              whatsappEnabled: true,
            ),
          );
      if (!mounted) return;
      final patient = patientResult.when(
        success: (created) => created,
        error: (error) {
          SnackService.showError(context, error.message);
          return null;
        },
      );
      if (patient == null) {
        setState(() => _submitting = false);
        return;
      }
      patientId = patient.id;
      ref.invalidate(appointmentPatientOptionsProvider);
    }

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
              assignedPractitionerId: _practitionerId,
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
              assignedPractitionerId: _practitionerId,
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

class _AppointmentSummary extends StatelessWidget {
  const _AppointmentSummary({
    required this.date,
    required this.time,
    required this.duration,
    required this.submitLabel,
    required this.isSubmitting,
    required this.onSubmit,
    required this.onCancel,
  });

  final DateTime date;
  final TimeOfDay time;
  final String duration;
  final String submitLabel;
  final bool isSubmitting;
  final VoidCallback? onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.accentDeep,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDeep.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointment Summary',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 26),
          _SummaryLine(
            icon: Icons.calendar_today_outlined,
            label: 'PROPOSED DATE',
            value: DateFormatter.fullDate(date),
          ),
          const SizedBox(height: 22),
          _SummaryLine(
            icon: Icons.access_time_outlined,
            label: 'TIMING',
            value:
                '${time.format(context)} • ${duration.trim().isEmpty ? '30' : duration} min',
          ),
          const SizedBox(height: 28),
          Divider(color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 16),
          AppButton(
            label: submitLabel,
            isLoading: isSubmitting,
            onPressed: onSubmit,
            variant: AppButtonVariant.secondary,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.highlight, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.highlight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
