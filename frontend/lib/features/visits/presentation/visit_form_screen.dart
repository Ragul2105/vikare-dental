import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/master_repository.dart';
import '../../../core/api/api_response.dart';
import '../../../core/models/master_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/responsive_split_row.dart';
import '../../../core/widgets/snack_service.dart';
import '../../patients/presentation/patient_detail_screen.dart';
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
  final _imagePicker = ImagePicker();

  DateTime _visitDate = DateTime.now();
  bool _submitting = false;
  bool _didPopulate = false;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Visit' : 'New Visit'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: () => context.push(
                '/patients/${widget.patientId}/visits/${existingVisit.id}',
              ),
              icon: const Icon(Icons.visibility_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            AppTextField(
              label: 'Visit date',
              readOnly: true,
              controller: TextEditingController(
                text: DateFormatter.shortDate(_visitDate),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(controller: _diagnosisController, label: 'Diagnosis'),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _notesController,
              label: 'Visit notes',
              maxLines: 6,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Treatments', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.xl),
            Text('Medications', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
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
            const SizedBox(height: AppSpacing.xl),
            Text('Photos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Attach up to 10 visit photos. Existing photos stay on the visit unless removed from the detail screen.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
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
            const SizedBox(height: AppSpacing.md),
            if (_newPhotos.isNotEmpty) _buildPhotoPreviewGrid(),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: isEditing ? 'Save visit' : 'Create visit',
              isLoading: _submitting,
              onPressed: _submitting ? null : () => _submit(existingVisit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentSelector(List<TreatmentMaster> treatments) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: treatments
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
    );
  }

  Widget _buildMedicationSelector(List<MedicationMaster> medications) {
    return Column(
      children: medications
          .map(
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
          )
          .toList(),
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
