import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/responsive_split_row.dart';
import '../../../core/widgets/snack_service.dart';
import '../data/patient_repository.dart';
import '../domain/patient_models.dart';
import 'patient_detail_screen.dart';
import 'patient_list_screen.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  const PatientFormScreen({super.key, this.patientId});

  final String? patientId;

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _allergiesController = TextEditingController();

  bool _whatsappEnabled = true;
  bool _submitting = false;
  String? _gender;
  bool _didPopulate = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _medicalHistoryController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientId = widget.patientId;

    if (patientId == null) {
      return _buildScaffold(context, null);
    }

    final patientState = ref.watch(patientDetailBundleProvider(patientId));
    return patientState.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Patient')),
        body: AppErrorView(
          message: error is AppError
              ? error.message
              : 'Failed to load patient.',
          onRetry: () => ref.invalidate(patientDetailBundleProvider(patientId)),
        ),
      ),
      data: (bundle) {
        if (!_didPopulate) {
          _didPopulate = true;
          _nameController.text = bundle.patient.name;
          _mobileController.text = bundle.patient.mobile;
          _ageController.text = bundle.patient.age?.toString() ?? '';
          _addressController.text = bundle.patient.address ?? '';
          _medicalHistoryController.text = bundle.patient.medicalHistory ?? '';
          _allergiesController.text = bundle.patient.allergies ?? '';
          _gender = bundle.patient.gender;
          _whatsappEnabled = bundle.patient.whatsappEnabled;
        }
        return _buildScaffold(context, bundle.patient);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Patient? existingPatient) {
    final isEditing = existingPatient != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Patient' : 'New Patient')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              AppTextField(
                controller: _nameController,
                label: 'Patient name',
                validator: (value) =>
                    Validators.requiredText(value, label: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _mobileController,
                label: 'Mobile number',
                keyboardType: TextInputType.phone,
                validator: Validators.mobile,
              ),
              const SizedBox(height: AppSpacing.md),
              ResponsiveSplitRow(
                children: [
                  AppTextField(
                    controller: _ageController,
                    label: 'Age',
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _addressController,
                label: 'Address',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _medicalHistoryController,
                label: 'Medical history',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _allergiesController,
                label: 'Allergies',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('WhatsApp reminders enabled'),
                value: _whatsappEnabled,
                onChanged: (value) => setState(() => _whatsappEnabled = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: isEditing ? 'Save changes' : 'Create patient',
                isLoading: _submitting,
                onPressed: _submitting ? null : () => _submit(existingPatient),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(Patient? existingPatient) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    final payload = PatientPayload(
      name: _nameController.text.trim(),
      mobile: _mobileController.text.trim(),
      age: Validators.parseOptionalInt(_ageController.text),
      gender: _gender,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      medicalHistory: _medicalHistoryController.text.trim().isEmpty
          ? null
          : _medicalHistoryController.text.trim(),
      allergies: _allergiesController.text.trim().isEmpty
          ? null
          : _allergiesController.text.trim(),
      whatsappEnabled: _whatsappEnabled,
    );

    final repository = ref.read(patientRepositoryProvider);
    final result = existingPatient == null
        ? await repository.createPatient(payload)
        : await repository.updatePatient(existingPatient.id, payload);

    if (!mounted) {
      return;
    }

    result.when(
      success: (patient) {
        ref.invalidate(patientListProvider);
        ref.invalidate(patientDetailBundleProvider(patient.id));
        SnackService.showSuccess(
          context,
          existingPatient == null ? 'Patient created.' : 'Patient updated.',
        );
        if (existingPatient == null) {
          context.go('/patients/${patient.id}');
        } else {
          context.pop();
        }
      },
      error: (error) => SnackService.showError(context, error.message),
    );

    setState(() => _submitting = false);
  }
}
