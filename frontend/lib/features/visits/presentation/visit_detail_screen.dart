import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/snack_service.dart';
import '../data/visit_repository.dart';
import '../domain/visit_models.dart';
import 'visit_form_screen.dart';
import '../../patients/presentation/patient_detail_screen.dart';

class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({
    super.key,
    required this.patientId,
    required this.visitId,
  });

  final String patientId;
  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitState = ref.watch(visitDetailProvider(visitId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Detail'),
        actions: [
          IconButton(
            onPressed: () =>
                context.push('/patients/$patientId/visits/$visitId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: () => context.push(
              '/patients/$patientId/visits/$visitId/prescription',
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: visitState.when(
          loading: () => const AppLoading(),
          error: (error, _) => AppErrorView(
            message: error is AppError
                ? error.message
                : 'Failed to load visit.',
            onRetry: () => ref.invalidate(visitDetailProvider(visitId)),
          ),
          data: (visit) => ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormatter.shortDate(visit.visitDate),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    if ((visit.diagnosis ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Diagnosis',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        visit.diagnosis!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if ((visit.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        visit.notes!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Treatments', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              if (visit.treatments.isEmpty)
                const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No treatments recorded.'),
                  ),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: visit.treatments
                      .map(
                        (treatment) => AppBadge(label: treatment.treatmentName),
                      )
                      .toList(),
                ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Medications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              if (visit.medications.isEmpty)
                const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No medications recorded.'),
                  ),
                )
              else
                ...visit.medications.map(
                  (medication) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication.medicationName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${medication.dosage} • Qty ${medication.quantity}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionHeader(
                title: 'Photos',
                action: TextButton.icon(
                  onPressed: () =>
                      context.push('/patients/$patientId/visits/$visitId/edit'),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (visit.photos.isEmpty)
                const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No photos uploaded.'),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visit.photos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final photo = visit.photos[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          child: InkWell(
                            onTap: () => _openPhoto(context, photo),
                            child: CachedNetworkImage(
                              imageUrl: photo.photoUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              onPressed: () =>
                                  _deletePhoto(context, ref, photo.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if ((photo.caption ?? '').isNotEmpty)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              color: Colors.black45,
                              child: Text(
                                photo.caption!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePhoto(
    BuildContext context,
    WidgetRef ref,
    String photoId,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete photo',
      message: 'Remove this visit photo?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) {
      return;
    }

    final result = await ref
        .read(visitRepositoryProvider)
        .deletePhoto(visitId, photoId);
    if (!context.mounted) {
      return;
    }
    result.when(
      success: (_) {
        ref.invalidate(visitDetailProvider(visitId));
        ref.invalidate(patientDetailBundleProvider(patientId));
        SnackService.showSuccess(context, 'Photo deleted.');
      },
      error: (error) => SnackService.showError(context, error.message),
    );
  }

  Future<void> _openPhoto(BuildContext context, VisitPhoto photo) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: photo.photoUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
