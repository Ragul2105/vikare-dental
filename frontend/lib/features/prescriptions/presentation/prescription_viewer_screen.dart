import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/api/api_response.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/snack_service.dart';
import '../data/prescription_repository.dart';

final prescriptionProvider =
    FutureProvider.family<PrescriptionDocument?, String>((ref, visitId) async {
      final result = await ref
          .read(prescriptionRepositoryProvider)
          .get(visitId);
      return result.when(
        success: (document) => document,
        error: (error) {
          if (error.isNotFound) {
            return null;
          }
          throw error;
        },
      );
    });

class PrescriptionViewerScreen extends ConsumerWidget {
  const PrescriptionViewerScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prescriptionProvider(visitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Prescription')),
      body: state.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorView(
          message: error is AppError
              ? error.message
              : 'Failed to load prescription.',
          onRetry: () => ref.invalidate(prescriptionProvider(visitId)),
        ),
        data: (document) {
          if (document == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 56),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No prescription PDF has been generated yet.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: 240,
                      child: AppButton(
                        label: 'Generate PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPressed: () => _generate(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SfPdfViewer.network(document.pdfUrl);
        },
      ),
      floatingActionButton: state.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _generate(context, ref),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Regenerate'),
            ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(prescriptionRepositoryProvider)
        .generate(visitId);
    if (!context.mounted) {
      return;
    }
    result.when(
      success: (_) {
        ref.invalidate(prescriptionProvider(visitId));
        SnackService.showSuccess(context, 'Prescription generated.');
      },
      error: (error) => SnackService.showError(context, error.message),
    );
  }
}
