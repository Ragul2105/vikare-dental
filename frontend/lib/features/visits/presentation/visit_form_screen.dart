import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/api/master_repository.dart';
import '../../../core/api/api_response.dart';
import '../../../core/models/master_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/responsive_split_row.dart';
import '../../../core/widgets/snack_service.dart';
import '../../patients/presentation/patient_detail_screen.dart';
import '../../patients/domain/patient_models.dart';
import '../data/visit_repository.dart';
import '../domain/visit_models.dart';

final visitDetailProvider = FutureProvider.family<Visit, String>((
  ref,
  visitId,
) async {
  final result = await ref.read(visitRepositoryProvider).getVisit(visitId);
  return result.unwrap();
});

class VisitFormScreen extends ConsumerStatefulWidget {
  const VisitFormScreen({super.key, required this.patientId, this.visitId});

  final String patientId;
  final String? visitId;

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends ConsumerState<VisitFormScreen> {
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _followUpNotesController = TextEditingController();
  final _treatmentSearchController = TextEditingController();
  final _medicationSearchController = TextEditingController();
  final _imagePicker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();

  DateTime _visitDate = DateTime.now();
  DateTime? _followUpDate;
  bool _followUpRequired = false;
  bool _submitting = false;
  bool _didPopulate = false;
  bool _speechReady = false;
  TextEditingController? _listeningController;
  String _dictationBase = '';
  final Set<String> _selectedTreatmentIds = <String>{};
  final Set<String> _selectedMedicationIds = <String>{};
  final Map<String, TextEditingController> _dosageControllers =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _quantityControllers =
      <String, TextEditingController>{};
  final List<XFile> _newPhotos = <XFile>[];
  final List<TextEditingController> _captionControllers =
      <TextEditingController>[];

  @override
  void dispose() {
    _diagnosisController.dispose();
    _notesController.dispose();
    _followUpNotesController.dispose();
    _treatmentSearchController.dispose();
    _medicationSearchController.dispose();
    _speech.cancel();
    for (final controller in _dosageControllers.values) {
      controller.dispose();
    }
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _captionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final treatmentsState = ref.watch(treatmentsProvider);
    final medicationsState = ref.watch(medicationsProvider);
    final visitId = widget.visitId;

    if (visitId == null) {
      return _buildBody(context, null, treatmentsState, medicationsState);
    }

    final visitState = ref.watch(visitDetailProvider(visitId));
    return visitState.when(
      loading: () => const Scaffold(body: AppLoading()),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Visit')),
        body: AppErrorView(
          message: error is AppError ? error.message : 'Failed to load visit.',
          onRetry: () => ref.invalidate(visitDetailProvider(visitId)),
        ),
      ),
      data: (visit) {
        if (!_didPopulate) {
          _didPopulate = true;
          _visitDate = visit.visitDate;
          _diagnosisController.text = visit.diagnosis ?? '';
          _notesController.text = visit.notes ?? '';
          _followUpRequired = visit.followUpRequired;
          _followUpDate = visit.followUpDate;
          _followUpNotesController.text = visit.followUpNotes ?? '';
          _selectedTreatmentIds.addAll(
            visit.treatments.map((item) => item.treatmentId),
          );
          _selectedMedicationIds.addAll(
            visit.medications.map((item) => item.medicationId),
          );
          for (final medication in visit.medications) {
            _dosageControllers[medication.medicationId] = TextEditingController(
              text: medication.dosage,
            );
            _quantityControllers[medication.medicationId] =
                TextEditingController(text: medication.quantity.toString());
          }
        }
        return _buildBody(context, visit, treatmentsState, medicationsState);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    Visit? existingVisit,
    AsyncValue<List<TreatmentMaster>> treatmentsState,
    AsyncValue<List<MedicationMaster>> medicationsState,
  ) {
    final isEditing = existingVisit != null;

    final patient = ref
        .watch(patientDetailBundleProvider(widget.patientId))
        .asData
        ?.value
        .patient;
    return AppScaffold(
      currentIndex: 1,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Text(
                isEditing ? 'Edit Visit' : 'Record New Visit',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const Spacer(),
              if (existingVisit != null)
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/patients/${widget.patientId}/visits/${existingVisit.id}/prescription',
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _PatientVisitHeader(patient: patient),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 900;
              final main = Column(
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Visit Details',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 150,
                              child: AppTextField(
                                label: 'Visit date',
                                readOnly: true,
                                controller: TextEditingController(
                                  text: DateFormatter.shortDate(_visitDate),
                                ),
                                onTap: _pickDate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        AppTextField(
                          controller: _diagnosisController,
                          label: 'Diagnosis',
                          suffixIcon: _speechButton(_diagnosisController),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _notesController,
                          label: 'Visit Notes / Problem Description',
                          hint:
                              "Describe the patient's symptoms, clinical observations, or preliminary diagnosis...",
                          maxLines: 6,
                          suffixIcon: _speechButton(_notesController),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Clinical Interventions',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Treatments Provided',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        treatmentsState.when(
                          loading: () => const AppLoading(),
                          error: (error, _) => AppErrorView(
                            message: error is AppError
                                ? error.message
                                : 'Failed to load treatments.',
                            onRetry: () => ref.invalidate(treatmentsProvider),
                          ),
                          data: _buildTreatmentSelector,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Prescribed Medications',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        medicationsState.when(
                          loading: () => const AppLoading(),
                          error: (error, _) => AppErrorView(
                            message: error is AppError
                                ? error.message
                                : 'Failed to load medications.',
                            onRetry: () => ref.invalidate(medicationsProvider),
                          ),
                          data: _buildMedicationSelector,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event_repeat_outlined,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Follow-up Plan',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Text(
                              'Required?',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Switch.adaptive(
                              value: _followUpRequired,
                              onChanged: (value) =>
                                  setState(() => _followUpRequired = value),
                            ),
                          ],
                        ),
                        if (_followUpRequired) ...[
                          const SizedBox(height: 14),
                          ResponsiveSplitRow(
                            children: [
                              AppTextField(
                                label: 'Target Date',
                                readOnly: true,
                                controller: TextEditingController(
                                  text: _followUpDate == null
                                      ? ''
                                      : DateFormatter.shortDate(_followUpDate!),
                                ),
                                onTap: _pickFollowUpDate,
                              ),
                              AppTextField(
                                controller: _followUpNotesController,
                                label: 'Next Step Notes',
                                hint: 'e.g. Check healing progress...',
                                suffixIcon: _speechButton(
                                  _followUpNotesController,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
              final side = Column(
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.add_a_photo_outlined,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Attachments',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            border: Border.all(color: const Color(0xFF8DE8DA)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.upload_file_rounded,
                                color: Color(0xFF45D8C1),
                                size: 34,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Drop X-rays or Photos here',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _pickPhoto(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Camera'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _pickPhoto(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Gallery'),
                            ),
                          ],
                        ),
                        if (_newPhotos.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildPhotoPreviewGrid(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      children: [
                        AppButton(
                          label: isEditing
                              ? 'Save Visit Record'
                              : 'Save Visit Record',
                          icon: Icons.save_outlined,
                          isLoading: _submitting,
                          onPressed: _submitting
                              ? null
                              : () => _submit(existingVisit),
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Cancel Entry',
                          variant: AppButtonVariant.outlined,
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              if (stack) {
                return Column(
                  children: [main, const SizedBox(height: 20), side],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: main),
                  const SizedBox(width: 22),
                  Expanded(child: side),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentSelector(List<TreatmentMaster> treatments) {
    final query = _treatmentSearchController.text.trim().toLowerCase();
    final filtered =
        treatments
            .where(
              (treatment) =>
                  query.isEmpty || treatment.name.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) {
            final aSelected = _selectedTreatmentIds.contains(a.id);
            final bSelected = _selectedTreatmentIds.contains(b.id);
            if (aSelected == bSelected) return a.name.compareTo(b.name);
            return aSelected ? -1 : 1;
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PeachSearchBar(
          controller: _treatmentSearchController,
          hint: 'Search treatments...',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: filtered
              .map(
                (treatment) => FilterChip(
                  label: Text(treatment.name),
                  selected: _selectedTreatmentIds.contains(treatment.id),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTreatmentIds.add(treatment.id);
                      } else {
                        _selectedTreatmentIds.remove(treatment.id);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMedicationSelector(List<MedicationMaster> medications) {
    final query = _medicationSearchController.text.trim().toLowerCase();
    final filtered =
        medications
            .where(
              (medication) =>
                  query.isEmpty ||
                  medication.name.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) {
            final aSelected = _selectedMedicationIds.contains(a.id);
            final bSelected = _selectedMedicationIds.contains(b.id);
            if (aSelected == bSelected) return a.name.compareTo(b.name);
            return aSelected ? -1 : 1;
          });
    return Column(
      children: [
        _PeachSearchBar(
          controller: _medicationSearchController,
          hint: 'Search medications...',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        ...filtered.map(
          (medication) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _selectedMedicationIds.contains(medication.id),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(medication.name),
                    subtitle: medication.defaultDosage == null
                        ? null
                        : Text('Suggested: ${medication.defaultDosage}'),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _selectedMedicationIds.add(medication.id);
                          _dosageControllers.putIfAbsent(
                            medication.id,
                            () => TextEditingController(
                              text: medication.defaultDosage ?? '',
                            ),
                          );
                          _quantityControllers.putIfAbsent(
                            medication.id,
                            () => TextEditingController(text: '1'),
                          );
                        } else {
                          _selectedMedicationIds.remove(medication.id);
                        }
                      });
                    },
                  ),
                  if (_selectedMedicationIds.contains(medication.id)) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ResponsiveSplitRow(
                      flexes: const [2, 1],
                      children: [
                        AppTextField(
                          controller: _dosageControllers[medication.id],
                          label: 'Dosage',
                          suffixIcon: _speechButton(
                            _dosageControllers[medication.id]!,
                          ),
                        ),
                        AppTextField(
                          controller: _quantityControllers[medication.id],
                          label: 'Quantity',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPreviewGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _newPhotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final file = _newPhotos[index];
        return AppCard(
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Image.file(
                    File(file.path),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _captionControllers[index],
                hint: 'Caption',
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => setState(() {
                    _newPhotos.removeAt(index);
                    _captionControllers.removeAt(index).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: _visitDate,
    );
    if (result != null) {
      setState(() => _visitDate = result);
    }
  }

  Future<void> _pickFollowUpDate() async {
    final result = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
    );
    if (result != null) {
      setState(() => _followUpDate = result);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_newPhotos.length >= 10) {
      SnackService.showWarning(context, 'A visit can have at most 10 photos.');
      return;
    }

    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1920,
    );
    if (file == null) {
      return;
    }

    setState(() {
      _newPhotos.add(file);
      _captionControllers.add(TextEditingController());
    });
  }

  Widget _speechButton(TextEditingController controller) {
    final listening = identical(_listeningController, controller);
    return IconButton(
      tooltip: listening ? 'Stop dictation' : 'Dictate with speech',
      icon: Icon(
        listening ? Icons.mic_rounded : Icons.mic_none_rounded,
        color: listening ? AppColors.error : AppColors.info,
      ),
      onPressed: () => _toggleDictation(controller),
    );
  }

  Future<void> _toggleDictation(TextEditingController controller) async {
    if (identical(_listeningController, controller)) {
      await _speech.stop();
      if (mounted) setState(() => _listeningController = null);
      return;
    }

    if (!_speechReady) {
      final available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _listeningController = null);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _listeningController = null);
          SnackService.showError(
            context,
            'Speech input stopped: ${error.errorMsg}',
          );
        },
      );
      if (!available) {
        if (mounted) {
          SnackService.showError(
            context,
            'Speech recognition is not available on this device.',
          );
        }
        return;
      }
      _speechReady = true;
    }

    _dictationBase = controller.text.trim();
    setState(() => _listeningController = controller);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      ),
      onResult: (result) {
        final words = result.recognizedWords.trim();
        final combined = [
          if (_dictationBase.isNotEmpty) _dictationBase,
          if (words.isNotEmpty) words,
        ].join(' ');
        controller
          ..text = combined
          ..selection = TextSelection.collapsed(offset: combined.length);
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _submit(Visit? existingVisit) async {
    setState(() => _submitting = true);

    final medicationItems = _selectedMedicationIds
        .map(
          (id) => VisitMedicationItemPayload(
            medicationId: id,
            dosage: _dosageControllers[id]?.text.trim().isEmpty ?? true
                ? 'As directed'
                : _dosageControllers[id]!.text.trim(),
            quantity:
                int.tryParse(_quantityControllers[id]?.text.trim() ?? '') ?? 1,
          ),
        )
        .toList();

    final repository = ref.read(visitRepositoryProvider);
    final response = existingVisit == null
        ? await repository.createVisit(
            VisitCreatePayload(
              patientId: widget.patientId,
              visitDate: _visitDate,
              diagnosis: _diagnosisController.text.trim().isEmpty
                  ? null
                  : _diagnosisController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              treatmentIds: _selectedTreatmentIds.toList(),
              medicationItems: medicationItems,
              followUpRequired: _followUpRequired,
              followUpDate: _followUpRequired ? _followUpDate : null,
              followUpNotes: _followUpNotesController.text.trim().isEmpty
                  ? null
                  : _followUpNotesController.text.trim(),
            ),
          )
        : await repository.updateVisit(
            existingVisit.id,
            VisitUpdatePayload(
              diagnosis: _diagnosisController.text.trim().isEmpty
                  ? null
                  : _diagnosisController.text.trim(),
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              treatmentIds: _selectedTreatmentIds.toList(),
              medicationItems: medicationItems,
              followUpRequired: _followUpRequired,
              followUpDate: _followUpRequired ? _followUpDate : null,
              followUpNotes: _followUpNotesController.text.trim().isEmpty
                  ? null
                  : _followUpNotesController.text.trim(),
            ),
          );

    if (!mounted) {
      return;
    }
    final navigator = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await response.when(
      success: (visit) async {
        if (_newPhotos.isNotEmpty) {
          final captions = _captionControllers
              .map((controller) => controller.text)
              .toList();
          final photoResponse = await repository.uploadPhotos(
            visitId: visit.id,
            files: _newPhotos,
            captions: captions,
          );
          photoResponse.whenOrNull(
            error: (error) => SnackService.showWarning(
              context,
              'Visit saved, but photo upload failed: ${error.message}',
            ),
          );
        }

        ref.invalidate(patientDetailBundleProvider(widget.patientId));
        ref.invalidate(visitDetailProvider(visit.id));
        scaffoldMessenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                existingVisit == null ? 'Visit created.' : 'Visit updated.',
              ),
            ),
          );
        navigator.go('/patients/${widget.patientId}/visits/${visit.id}');
      },
      error: (error) async {
        SnackService.showError(context, error.message);
      },
    );

    if (mounted) {
      setState(() => _submitting = false);
    }
  }
}

class _PatientVisitHeader extends StatelessWidget {
  const _PatientVisitHeader({required this.patient});

  final Patient? patient;

  @override
  Widget build(BuildContext context) {
    final lastVisit = patient?.lastVisitDate == null
        ? 'No previous visit'
        : DateFormatter.shortDate(patient!.lastVisitDate!);
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 760;
          final identity = Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient?.name ?? 'Patient',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    Text(
                      '${patient?.patientUid ?? ''}  •  ${patient?.age ?? '—'}y / ${patient?.gender ?? '—'}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          );
          final details = Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _HeaderMetric(label: 'LAST VISIT', value: lastVisit),
              _HeaderMetric(
                label: 'LAST DOCTOR',
                value: patient?.doctorName ?? '—',
              ),
              _HeaderMetric(label: 'PHONE', value: patient?.mobile ?? '—'),
              _HeaderMetric(
                label: 'MEDICAL HISTORY',
                value: patient?.medicalHistory?.isNotEmpty == true
                    ? patient!.medicalHistory!
                    : '—',
              ),
              _HeaderMetric(
                label: 'CURRENT MEDICINES',
                value: patient?.currentMedications?.isNotEmpty == true
                    ? patient!.currentMedications!
                    : '—',
              ),
              if ((patient?.allergies ?? '').isNotEmpty)
                _HeaderMetric(
                  label: 'ALLERGIES',
                  value: patient!.allergies!,
                  alert: true,
                ),
            ],
          );
          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: AppSpacing.md),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: details),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    this.alert = false,
  });

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 130, maxWidth: 240),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: alert ? AppColors.error : AppColors.textPrimary,
            fontWeight: alert ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _PeachSearchBar extends StatelessWidget {
  const _PeachSearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded),
      filled: true,
      fillColor: const Color(0xFFFFF1E8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: Color(0xFFFFCCAD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: Color(0xFFFFB98E), width: 1.4),
      ),
    ),
  );
}
