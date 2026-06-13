import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/snack_service.dart';
import '../data/patient_repository.dart';
import '../domain/patient_models.dart';
import 'patient_list_screen.dart';

class _PatientDetailBundle {
  const _PatientDetailBundle({required this.patient, required this.visits});

  final Patient patient;
  final List<PatientVisitSummary> visits;
}

final patientDetailBundleProvider =
    FutureProvider.family<_PatientDetailBundle, String>((ref, patientId) async {
      final repository = ref.read(patientRepositoryProvider);
      final patientResult = await repository.getPatient(patientId);
      final visitResult = await repository.listVisits(patientId);

      return _PatientDetailBundle(
        patient: patientResult.unwrap(),
        visits: visitResult.unwrap(),
      );
    });

class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(patientDetailBundleProvider(patientId));
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Detail'),
        actions: [
          IconButton(
            onPressed: () => context.push('/patients/$patientId/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
          if (authState.user?.role == 'admin')
            IconButton(
              onPressed: () => _deletePatient(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/patients/$patientId/visits/new'),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('New Visit'),
      ),
      body: SafeArea(
        child: detailState.when(
          loading: () => const AppLoading(),
          error: (error, _) => AppErrorView(
            message: error is AppError
                ? error.message
                : 'Failed to load patient detail.',
            onRetry: () =>
                ref.invalidate(patientDetailBundleProvider(patientId)),
          ),
          data: (bundle) => ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.patient.name,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${bundle.patient.patientUid}  •  ${bundle.patient.mobile}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (bundle.patient.gender != null)
                          AppBadge(label: bundle.patient.gender!),
                        if (bundle.patient.age != null)
                          AppBadge(label: '${bundle.patient.age} yrs'),
                        AppBadge(
                          label: bundle.patient.whatsappEnabled
                              ? 'WhatsApp on'
                              : 'WhatsApp off',
                        ),
                      ],
                    ),
                    if ((bundle.patient.address ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Address',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        bundle.patient.address!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if ((bundle.patient.medicalHistory ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Medical History',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        bundle.patient.medicalHistory!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    if ((bundle.patient.allergies ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Allergies',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        bundle.patient.allergies!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSectionHeader(
                title: 'Visit history',
                action: AppButton(
                  label: 'Add Visit',
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () =>
                      context.push('/patients/$patientId/visits/new'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (bundle.visits.isEmpty)
                const AppCard(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No visits recorded yet.'),
                  ),
                )
              else
                ...bundle.visits.map(
                  (visit) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      onTap: () => context.push(
                        '/patients/$patientId/visits/${visit.id}',
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stackBadge = constraints.maxWidth < 420;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (stackBadge) ...[
                                Text(
                                  DateFormatter.shortDate(visit.visitDate),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if ((visit.diagnosis ?? '').isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  AppBadge(label: visit.diagnosis!),
                                ],
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormatter.shortDate(
                                          visit.visitDate,
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    if ((visit.diagnosis ?? '').isNotEmpty)
                                      AppBadge(label: visit.diagnosis!),
                                  ],
                                ),
                              if ((visit.notes ?? '').isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  visit.notes!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: [
                                  AppBadge(label: '${visit.photoCount} photos'),
                                  AppBadge(
                                    label: '${visit.treatmentCount} treatments',
                                  ),
                                  AppBadge(
                                    label: '${visit.medicationCount} meds',
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePatient(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _DeleteReasonDialog(),
    );

    if (reason == null || reason.trim().length < 5) {
      return;
    }

    final result = await ref
        .read(patientRepositoryProvider)
        .deletePatient(patientId, reason.trim());
    result.when(
      success: (_) {
        ref.invalidate(patientListProvider);
        ref.invalidate(patientDetailBundleProvider(patientId));
        if (context.mounted) {
          SnackService.showSuccess(context, 'Patient deleted.');
          context.pop();
        }
      },
      error: (error) {
        if (context.mounted) {
          SnackService.showError(context, error.message);
        }
      },
    );
  }
}

class _DeleteReasonDialog extends StatefulWidget {
  const _DeleteReasonDialog();

  @override
  State<_DeleteReasonDialog> createState() => _DeleteReasonDialogState();
}

class _DeleteReasonDialogState extends State<_DeleteReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Delete Patient'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Reason',
          hintText: 'Why is this patient being deleted?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
