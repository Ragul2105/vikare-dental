import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
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
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _medicalHistory = TextEditingController();
  final _currentMedications = TextEditingController();
  final _allergies = TextEditingController();
  final _hospitalReason = TextEditingController();
  final _pastDentalHistory = TextEditingController();
  final Set<String> _flags = {};

  String? _gender;
  String? _bloodType;
  bool _wasHospitalized = false;
  DateTime? _hospitalizationDate;
  bool _submitting = false;
  bool _didPopulate = false;

  static const _clinicalFlags = [
    'Gastritis',
    'Sinusitis',
    'Pregnant',
    'Fainting',
    'Smoking',
    'Tobacco / Betel nut',
    'Alcohol',
    'Clenching / Bruxism',
  ];

  @override
  void dispose() {
    for (final controller in [
      _name,
      _mobile,
      _age,
      _address,
      _medicalHistory,
      _currentMedications,
      _allergies,
      _hospitalReason,
      _pastDentalHistory,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.patientId;
    if (id == null) return _buildPage(null);
    final state = ref.watch(patientDetailBundleProvider(id));
    return state.when(
      loading: () => const AppScaffold(currentIndex: 1, body: AppLoading()),
      error: (error, _) => AppScaffold(
        currentIndex: 1,
        body: AppErrorView(
          message: error is AppError
              ? error.message
              : 'Failed to load patient.',
          onRetry: () => ref.invalidate(patientDetailBundleProvider(id)),
        ),
      ),
      data: (bundle) {
        if (!_didPopulate) {
          _didPopulate = true;
          final patient = bundle.patient;
          _name.text = patient.name;
          _mobile.text = patient.mobile;
          _age.text = patient.age?.toString() ?? '';
          _address.text = patient.address ?? '';
          _medicalHistory.text = patient.medicalHistory ?? '';
          _currentMedications.text = patient.currentMedications ?? '';
          _allergies.text = patient.allergies ?? '';
          _hospitalReason.text = patient.hospitalizationReason ?? '';
          _pastDentalHistory.text = patient.pastDentalHistory ?? '';
          _flags.addAll(patient.clinicalFlags);
          _gender = patient.gender;
          _bloodType = patient.bloodType;
          _wasHospitalized = patient.wasHospitalized;
          _hospitalizationDate = patient.hospitalizationDate;
        }
        return _buildPage(bundle.patient);
      },
    );
  }

  Widget _buildPage(Patient? existingPatient) {
    final isEditing = existingPatient != null;
    return AppScaffold(
      currentIndex: 1,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/patients'),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('BACK TO RECORDS'),
                    ),
                    Text(
                      isEditing ? 'Edit Patient' : 'Add New Patient',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a comprehensive digital health record for a new visitor.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.person_add_alt_1_outlined,
                            title: 'Patient Identity & Contact',
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                ResponsiveSplitRow(
                                  children: [
                                    AppTextField(
                                      controller: _name,
                                      label: 'Full Name',
                                      hint: 'e.g. Johnathan Doe',
                                      validator: (value) =>
                                          Validators.requiredText(
                                            value,
                                            label: 'Name',
                                          ),
                                    ),
                                    AppTextField(
                                      controller: _mobile,
                                      label: 'Phone Number',
                                      hint: '+91 00000 00000',
                                      keyboardType: TextInputType.phone,
                                      validator: Validators.mobile,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                ResponsiveSplitRow(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: _gender,
                                      decoration: const InputDecoration(
                                        labelText: 'Gender',
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Male',
                                          child: Text('Male'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Female',
                                          child: Text('Female'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Other',
                                          child: Text('Other'),
                                        ),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _gender = value),
                                    ),
                                    AppTextField(
                                      controller: _age,
                                      label: 'Age',
                                      hint: 'Age in years',
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                ResponsiveSplitRow(
                                  children: [
                                    AppTextField(
                                      controller: _address,
                                      label: 'Residential Address',
                                      hint: 'Street name, City, Zip Code',
                                      maxLines: 2,
                                    ),
                                    DropdownButtonFormField<String>(
                                      initialValue: _bloodType,
                                      decoration: const InputDecoration(
                                        labelText: 'Blood Type',
                                      ),
                                      items:
                                          [
                                                'A+',
                                                'A-',
                                                'B+',
                                                'B-',
                                                'AB+',
                                                'AB-',
                                                'O+',
                                                'O-',
                                              ]
                                              .map(
                                                (value) => DropdownMenuItem(
                                                  value: value,
                                                  child: Text(value),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) =>
                                          setState(() => _bloodType = value),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 18),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: _SectionTitle(
                                    icon: Icons.medical_information_outlined,
                                    title: 'Clinical Overview',
                                    embedded: true,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                ResponsiveSplitRow(
                                  children: [
                                    AppTextField(
                                      controller: _medicalHistory,
                                      label: 'Medical History',
                                      hint:
                                          'Conditions, surgeries, treatments...',
                                      maxLines: 3,
                                    ),
                                    AppTextField(
                                      controller: _currentMedications,
                                      label: 'Current Medications',
                                      hint:
                                          'Medicines currently being taken...',
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                ResponsiveSplitRow(
                                  children: [
                                    AppTextField(
                                      controller: _allergies,
                                      label: 'Allergies',
                                      hint: 'Medications, materials, food...',
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 18,
                                  runSpacing: 4,
                                  children: _clinicalFlags
                                      .map(
                                        (flag) => SizedBox(
                                          width: 170,
                                          child: CheckboxListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            value: _flags.contains(flag),
                                            title: Text(
                                              flag.toUpperCase(),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium,
                                            ),
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            onChanged: (checked) => setState(
                                              () => checked == true
                                                  ? _flags.add(flag)
                                                  : _flags.remove(flag),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Have you ever been admitted in hospital',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _wasHospitalized,
                                      onChanged: (value) => setState(
                                        () => _wasHospitalized = value,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (_wasHospitalized)
                                      OutlinedButton.icon(
                                        onPressed: _pickHospitalDate,
                                        icon: const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          _hospitalizationDate == null
                                              ? 'When?'
                                              : DateFormatter.shortDate(
                                                  _hospitalizationDate!,
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ResponsiveSplitRow(
                                  children: [
                                    AppTextField(
                                      controller: _hospitalReason,
                                      label: 'Reason',
                                      maxLines: 3,
                                    ),
                                    AppTextField(
                                      controller: _pastDentalHistory,
                                      label: 'Past dental history',
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                                const Divider(),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => context.go('/patients'),
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 18),
                                    SizedBox(
                                      width: 170,
                                      child: AppButton(
                                        label: isEditing
                                            ? 'Save Changes'
                                            : 'Save Patient',
                                        icon: Icons.save_outlined,
                                        isLoading: _submitting,
                                        onPressed: _submitting
                                            ? null
                                            : () => _submit(existingPatient),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6FF),
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.accentDeep,
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Patient data is encrypted and handled in compliance with medical privacy regulations.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickHospitalDate() async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      initialDate: _hospitalizationDate ?? DateTime.now(),
    );
    if (value != null) setState(() => _hospitalizationDate = value);
  }

  Future<void> _submit(Patient? existingPatient) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final payload = PatientPayload(
      name: _name.text.trim(),
      mobile: _mobile.text.trim(),
      age: Validators.parseOptionalInt(_age.text),
      gender: _gender,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      medicalHistory: _medicalHistory.text.trim().isEmpty
          ? null
          : _medicalHistory.text.trim(),
      currentMedications: _currentMedications.text.trim().isEmpty
          ? null
          : _currentMedications.text.trim(),
      allergies: _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
      bloodType: _bloodType,
      clinicalFlags: _flags.toList(),
      wasHospitalized: _wasHospitalized,
      hospitalizationDate: _wasHospitalized ? _hospitalizationDate : null,
      hospitalizationReason: _hospitalReason.text.trim().isEmpty
          ? null
          : _hospitalReason.text.trim(),
      pastDentalHistory: _pastDentalHistory.text.trim().isEmpty
          ? null
          : _pastDentalHistory.text.trim(),
      whatsappEnabled: true,
    );
    final repository = ref.read(patientRepositoryProvider);
    final result = existingPatient == null
        ? await repository.createPatient(payload)
        : await repository.updatePatient(existingPatient.id, payload);
    if (!mounted) return;
    result.when(
      success: (patient) {
        ref.invalidate(patientListProvider);
        ref.invalidate(patientDetailBundleProvider(patient.id));
        SnackService.showSuccess(
          context,
          existingPatient == null ? 'Patient created.' : 'Patient updated.',
        );
        context.go('/patients/${patient.id}');
      },
      error: (error) => SnackService.showError(context, error.message),
    );
    if (mounted) setState(() => _submitting = false);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.embedded = false,
  });
  final IconData icon;
  final String title;
  final bool embedded;
  @override
  Widget build(BuildContext context) => Padding(
    padding: embedded
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    child: Row(
      children: [
        Icon(icon, color: AppColors.info),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}
