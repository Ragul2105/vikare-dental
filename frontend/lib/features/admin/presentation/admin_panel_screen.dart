import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/api/master_repository.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/models/master_data.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/snack_service.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user?.role != 'admin') {
      return const Scaffold(
        body: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          message: 'Admin access required.',
        ),
      );
    }

    final staffState = ref.watch(staffProvider);
    final treatmentsState = ref.watch(treatmentsProvider);
    final medicationsState = ref.watch(medicationsProvider);
    final logsState = ref.watch(activityLogsProvider);

    return AppScaffold(
      currentIndex: 3,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(staffProvider);
            ref.invalidate(treatmentsProvider);
            ref.invalidate(medicationsProvider);
            ref.invalidate(activityLogsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Text(
                'Admin Panel',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Manage staff, treatment masters, medication masters, and recent activity.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                title: 'Staff',
                action: AppButton(
                  label: 'Add Staff',
                  icon: Icons.person_add_alt_1_rounded,
                  expanded: false,
                  onPressed: () => _showStaffSheet(context, ref),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionBody<List<StaffMember>>(
                state: staffState,
                onRetry: () => ref.invalidate(staffProvider),
                builder: (staff) {
                  if (staff.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.badge_outlined,
                      message: 'No staff members found.',
                    );
                  }
                  return Column(
                    children: staff
                        .map(
                          (member) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: AppCard(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final stack = constraints.maxWidth < 440;
                                  final identity = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        member.role == 'admin'
                                            ? 'Admin'
                                            : 'Staff',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  );
                                  final badge = AppBadge(
                                    label: member.isActive
                                        ? 'Active'
                                        : 'Inactive',
                                  );
                                  final actions = Wrap(
                                    spacing: AppSpacing.xs,
                                    children: [
                                      IconButton(
                                        onPressed: () => _showStaffSheet(
                                          context,
                                          ref,
                                          member: member,
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        onPressed: () => _showPinResetSheet(
                                          context,
                                          ref,
                                          member,
                                        ),
                                        icon: const Icon(Icons.pin_outlined),
                                      ),
                                      IconButton(
                                        onPressed: member.isActive
                                            ? () => _deactivateStaff(
                                                context,
                                                ref,
                                                member,
                                              )
                                            : null,
                                        icon: const Icon(
                                          Icons.person_off_outlined,
                                        ),
                                      ),
                                    ],
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (stack) ...[
                                        identity,
                                        const SizedBox(height: AppSpacing.sm),
                                        badge,
                                      ] else
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: identity),
                                            badge,
                                          ],
                                        ),
                                      const SizedBox(height: AppSpacing.md),
                                      if (stack) ...[
                                        Text(
                                          member.lastLoginAt == null
                                              ? 'No login recorded yet'
                                              : 'Last login ${DateFormatter.dateTime(member.lastLoginAt!)}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        actions,
                                      ] else
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                member.lastLoginAt == null
                                                    ? 'No login recorded yet'
                                                    : 'Last login ${DateFormatter.dateTime(member.lastLoginAt!)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ),
                                            actions,
                                          ],
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                title: 'Treatment Master',
                action: AppButton(
                  label: 'Add Treatment',
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () => _showTreatmentSheet(context, ref),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionBody<List<TreatmentMaster>>(
                state: treatmentsState,
                onRetry: () => ref.invalidate(treatmentsProvider),
                builder: (items) => _masterList(
                  context,
                  items: items
                      .map(
                        (item) => _MasterTileData(
                          id: item.id,
                          title: item.name,
                          subtitle: item.description ?? '',
                          isActive: item.isActive,
                          onEdit: () => _showTreatmentSheet(
                            context,
                            ref,
                            treatment: item,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                title: 'Medication Master',
                action: AppButton(
                  label: 'Add Medication',
                  icon: Icons.add_rounded,
                  expanded: false,
                  onPressed: () => _showMedicationSheet(context, ref),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SectionBody<List<MedicationMaster>>(
                state: medicationsState,
                onRetry: () => ref.invalidate(medicationsProvider),
                builder: (items) => _masterList(
                  context,
                  items: items
                      .map(
                        (item) => _MasterTileData(
                          id: item.id,
                          title: item.name,
                          subtitle: [item.defaultDosage, item.description]
                              .whereType<String>()
                              .where((value) => value.isNotEmpty)
                              .join(' • '),
                          isActive: item.isActive,
                          onEdit: () => _showMedicationSheet(
                            context,
                            ref,
                            medication: item,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const _SectionHeader(title: 'Recent Activity'),
              const SizedBox(height: AppSpacing.md),
              _SectionBody<List<ActivityLogItem>>(
                state: logsState,
                onRetry: () => ref.invalidate(activityLogsProvider),
                builder: (logs) {
                  if (logs.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.history_toggle_off_rounded,
                      message: 'No activity logs found.',
                    );
                  }
                  return Column(
                    children: logs
                        .map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: AppCard(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final stack = constraints.maxWidth < 480;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (stack) ...[
                                        Text(
                                          '${log.action} • ${log.entityType}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          DateFormatter.dateTime(log.createdAt),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ] else
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${log.action} • ${log.entityType}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.md,
                                            ),
                                            Text(
                                              DateFormatter.dateTime(
                                                log.createdAt,
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      if (log.entityId != null) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          'Entity: ${log.entityId}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                      if ((log.details ?? {}).isNotEmpty) ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                          log.details.toString(),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _masterList(
    BuildContext context, {
    required List<_MasterTileData> items,
  }) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.playlist_add_check_circle_outlined,
        message: 'No items found.',
      );
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stack = constraints.maxWidth < 440;
                    final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.subtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    );
                    final controls = Wrap(
                      spacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(label: item.isActive ? 'Active' : 'Inactive'),
                        IconButton(
                          onPressed: item.onEdit,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    );

                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          content,
                          const SizedBox(height: AppSpacing.sm),
                          controls,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: content),
                        const SizedBox(width: AppSpacing.md),
                        controls,
                      ],
                    );
                  },
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _deactivateStaff(
    BuildContext context,
    WidgetRef ref,
    StaffMember member,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Deactivate staff member',
      message: 'Deactivate ${member.name}?',
      confirmLabel: 'Deactivate',
    );
    if (!confirmed) {
      return;
    }
    final result = await ref
        .read(adminRepositoryProvider)
        .deactivateStaff(member.id);
    if (!context.mounted) {
      return;
    }
    result.when(
      success: (_) {
        ref.invalidate(staffProvider);
        SnackService.showSuccess(context, 'Staff member deactivated.');
      },
      error: (error) => SnackService.showError(context, error.message),
    );
  }

  void _showStaffSheet(
    BuildContext context,
    WidgetRef ref, {
    StaffMember? member,
  }) {
    final nameController = TextEditingController(text: member?.name ?? '');
    final pinController = TextEditingController();
    String role = member?.role ?? 'staff';
    bool isActive = member?.isActive ?? true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppBottomSheetBody(
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member == null ? 'Add Staff Member' : 'Edit Staff Member',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: nameController, label: 'Name'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) =>
                    setModalState(() => role = value ?? 'staff'),
              ),
              if (member == null) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: pinController,
                  label: 'PIN',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (value) => setModalState(() => isActive = value),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: member == null ? 'Create Staff Member' : 'Save Changes',
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    SnackService.showError(context, 'Name is required.');
                    return;
                  }
                  if (member == null &&
                      Validators.pin(pinController.text) != null) {
                    SnackService.showError(
                      context,
                      'Enter a valid 4 to 8 digit PIN.',
                    );
                    return;
                  }

                  final result = member == null
                      ? await ref
                            .read(adminRepositoryProvider)
                            .createStaff(
                              name: nameController.text.trim(),
                              role: role,
                              pin: pinController.text.trim(),
                            )
                      : await ref
                            .read(adminRepositoryProvider)
                            .updateStaff(
                              id: member.id,
                              name: nameController.text.trim(),
                              role: role,
                              isActive: isActive,
                            );

                  if (!context.mounted) {
                    return;
                  }
                  result.when(
                    success: (_) {
                      ref.invalidate(staffProvider);
                      Navigator.of(sheetContext).pop();
                      SnackService.showSuccess(context, 'Staff member saved.');
                    },
                    error: (error) =>
                        SnackService.showError(context, error.message),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPinResetSheet(
    BuildContext context,
    WidgetRef ref,
    StaffMember member,
  ) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppBottomSheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset PIN for ${member.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: pinController,
              label: 'New PIN',
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: confirmController,
              label: 'Confirm PIN',
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Reset PIN',
              onPressed: () async {
                if (pinController.text != confirmController.text) {
                  SnackService.showError(context, 'PIN values do not match.');
                  return;
                }
                if (Validators.pin(pinController.text) != null) {
                  SnackService.showError(
                    context,
                    'Enter a valid 4 to 8 digit PIN.',
                  );
                  return;
                }
                final result = await ref
                    .read(adminRepositoryProvider)
                    .resetPin(member.id, pinController.text.trim());
                if (!context.mounted) {
                  return;
                }
                result.when(
                  success: (_) {
                    Navigator.of(sheetContext).pop();
                    SnackService.showSuccess(context, 'PIN reset.');
                  },
                  error: (error) =>
                      SnackService.showError(context, error.message),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTreatmentSheet(
    BuildContext context,
    WidgetRef ref, {
    TreatmentMaster? treatment,
  }) {
    final nameController = TextEditingController(text: treatment?.name ?? '');
    final descriptionController = TextEditingController(
      text: treatment?.description ?? '',
    );
    bool isActive = treatment?.isActive ?? true;

    _showMasterSheet(
      context,
      title: treatment == null ? 'Add Treatment' : 'Edit Treatment',
      nameController: nameController,
      secondaryController: descriptionController,
      secondaryLabel: 'Description',
      isActive: isActive,
      onActiveChanged: (value) => isActive = value,
      onSubmit: () async {
        final repository = ref.read(masterRepositoryProvider);
        final result = treatment == null
            ? await repository.createTreatment(
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                isActive: isActive,
              )
            : await repository.updateTreatment(
                id: treatment.id,
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                isActive: isActive,
              );
        return result.when(
          success: (_) {
            ref.invalidate(treatmentsProvider);
            return null;
          },
          error: (error) => error.message,
        );
      },
    );
  }

  void _showMedicationSheet(
    BuildContext context,
    WidgetRef ref, {
    MedicationMaster? medication,
  }) {
    final nameController = TextEditingController(text: medication?.name ?? '');
    final descriptionController = TextEditingController(
      text: medication?.description ?? '',
    );
    final dosageController = TextEditingController(
      text: medication?.defaultDosage ?? '',
    );
    bool isActive = medication?.isActive ?? true;

    _showMasterSheet(
      context,
      title: medication == null ? 'Add Medication' : 'Edit Medication',
      nameController: nameController,
      secondaryController: descriptionController,
      tertiaryController: dosageController,
      secondaryLabel: 'Description',
      tertiaryLabel: 'Default dosage',
      isActive: isActive,
      onActiveChanged: (value) => isActive = value,
      onSubmit: () async {
        final repository = ref.read(masterRepositoryProvider);
        final result = medication == null
            ? await repository.createMedication(
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                defaultDosage: dosageController.text.trim().isEmpty
                    ? null
                    : dosageController.text.trim(),
                isActive: isActive,
              )
            : await repository.updateMedication(
                id: medication.id,
                name: nameController.text.trim(),
                description: descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
                defaultDosage: dosageController.text.trim().isEmpty
                    ? null
                    : dosageController.text.trim(),
                isActive: isActive,
              );
        return result.when(
          success: (_) {
            ref.invalidate(medicationsProvider);
            return null;
          },
          error: (error) => error.message,
        );
      },
    );
  }

  void _showMasterSheet(
    BuildContext context, {
    required String title,
    required TextEditingController nameController,
    required TextEditingController secondaryController,
    TextEditingController? tertiaryController,
    required String secondaryLabel,
    String? tertiaryLabel,
    required bool isActive,
    required ValueChanged<bool> onActiveChanged,
    required Future<String?> Function() onSubmit,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => AppBottomSheetBody(
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: nameController, label: 'Name'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: secondaryController,
                label: secondaryLabel,
              ),
              if (tertiaryController != null && tertiaryLabel != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: tertiaryController,
                  label: tertiaryLabel,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: isActive,
                onChanged: (value) =>
                    setModalState(() => onActiveChanged(value)),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save',
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) {
                    SnackService.showError(context, 'Name is required.');
                    return;
                  }
                  final errorMessage = await onSubmit();
                  if (!context.mounted) {
                    return;
                  }
                  if (errorMessage == null) {
                    Navigator.of(sheetContext).pop();
                    SnackService.showSuccess(context, 'Saved successfully.');
                  } else {
                    SnackService.showError(context, errorMessage);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title: title, action: action);
  }
}

class _SectionBody<T> extends StatelessWidget {
  const _SectionBody({
    required this.state,
    required this.builder,
    required this.onRetry,
  });

  final AsyncValue<T> state;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const SizedBox(height: 120, child: AppLoading()),
      error: (error, _) => AppErrorView(
        message: error is AppError ? error.message : 'Failed to load section.',
        onRetry: onRetry,
      ),
      data: builder,
    );
  }
}

class _MasterTileData {
  const _MasterTileData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onEdit,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onEdit;
}
