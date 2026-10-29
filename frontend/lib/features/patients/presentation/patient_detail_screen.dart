import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_response.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snack_service.dart';
import '../data/patient_repository.dart';
import '../domain/patient_models.dart';
import 'patient_list_screen.dart';

class PatientDetailBundle {
  const PatientDetailBundle({required this.patient, required this.visits});
  final Patient patient;
  final List<PatientVisitSummary> visits;
}

final patientDetailBundleProvider =
    FutureProvider.family<PatientDetailBundle, String>((ref, patientId) async {
      final repository = ref.read(patientRepositoryProvider);
      return PatientDetailBundle(
        patient: (await repository.getPatient(patientId)).unwrap(),
        visits: (await repository.listVisits(patientId)).unwrap(),
      );
    });

class PatientDetailScreen extends ConsumerWidget {
  const PatientDetailScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientDetailBundleProvider(patientId));
    final isAdmin = ref.watch(authControllerProvider).user?.role == 'admin';
    return AppScaffold(
      currentIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/patients/$patientId/visits/new'),
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text('New Visit'),
      ),
      body: state.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppErrorView(
          message: error is AppError
              ? error.message
              : 'Failed to load patient detail.',
          onRetry: () => ref.invalidate(patientDetailBundleProvider(patientId)),
        ),
        data: (bundle) => ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFD9F2F0),
                  child: Text(
                    bundle.patient.name.characters.first.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.patient.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'ID: #${bundle.patient.patientUid}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push('/patients/$patientId/edit'),
                  icon: const Icon(Icons.edit_outlined),
                ),
                if (isAdmin)
                  IconButton(
                    onPressed: () => _deletePatient(context, ref),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'AGE / SEX',
                            value:
                                '${bundle.patient.age ?? '—'} / ${bundle.patient.gender?.characters.first ?? '—'}',
                          ),
                        ),
                        const VerticalDivider(),
                        Expanded(
                          child: _Metric(
                            label: 'PHONE',
                            value: bundle.patient.mobile,
                          ),
                        ),
                        const VerticalDivider(),
                        Expanded(
                          child: _Metric(
                            label: 'BLOOD TYPE',
                            value: bundle.patient.bloodType ?? '—',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ALERTS',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.warning_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if ((bundle.patient.allergies ?? '').isNotEmpty)
                              AppBadge(
                                label: '${bundle.patient.allergies} Allergy',
                              ),
                            ...bundle.patient.clinicalFlags.map(
                              (flag) => AppBadge(label: flag),
                            ),
                            if ((bundle.patient.allergies ?? '').isEmpty &&
                                bundle.patient.clinicalFlags.isEmpty)
                              const Text('No clinical alerts'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visit History',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    Text(
                      'Procedural timeline and clinical notes',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/patients/$patientId/visits/new'),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('New Visit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (bundle.visits.isEmpty)
              const AppCard(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No visits recorded yet.'),
                ),
              )
            else
              ...bundle.visits.asMap().entries.map(
                (entry) => _VisitHistoryCard(
                  visit: entry.value,
                  current: entry.key == 0,
                  onTap: () => context.push(
                    '/patients/$patientId/visits/${entry.value.id}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePatient(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteReasonDialog(),
    );
    if (reason == null || reason.trim().length < 5) return;
    final result = await ref
        .read(patientRepositoryProvider)
        .deletePatient(patientId, reason.trim());
    if (!context.mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(patientListProvider);
        SnackService.showSuccess(context, 'Patient deleted.');
        context.go('/patients');
      },
      error: (error) => SnackService.showError(context, error.message),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 7),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

class _VisitHistoryCard extends StatelessWidget {
  const _VisitHistoryCard({
    required this.visit,
    required this.current,
    required this.onTap,
  });
  final PatientVisitSummary visit;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18, left: 48),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        AppCard(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (current)
                Text(
                  'CURRENT VISIT',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.info),
                ),
              const SizedBox(height: 4),
              Text(
                visit.diagnosis?.isNotEmpty == true
                    ? visit.diagnosis!
                    : 'Clinical Visit',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                DateFormatter.shortDate(visit.visitDate),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if ((visit.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  visit.notes!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  AppBadge(label: '${visit.treatmentCount} treatments'),
                  AppBadge(label: '${visit.medicationCount} medications'),
                  AppBadge(label: '${visit.photoCount} attachments'),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: -48,
          top: 8,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: current
                ? AppColors.accent
                : const Color(0xFFE8EEF5),
            child: Icon(
              current
                  ? Icons.brightness_high_rounded
                  : Icons.medical_services_outlined,
              color: current ? Colors.white : AppColors.textMuted,
              size: 19,
            ),
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete Patient'),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Reason'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Delete'),
      ),
    ],
  );
}
