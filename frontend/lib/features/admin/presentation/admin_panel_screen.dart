import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/api/master_repository.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/models/master_data.dart';
import '../../../core/theme/app_colors.dart';
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

    return AppScaffold(
      currentIndex: 3,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(staffProvider);
            ref.invalidate(treatmentsProvider);
            ref.invalidate(medicationsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              Text(
                'Admin Management',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Manage clinic staff, treatments, medications, and access roles.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                title: 'Staff Management',
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
                  return _staffTable(context, ref, staff);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 840;
                  final treatments = _MasterColumn(
                    header: _SectionHeader(
                      title: 'Treatments',
                      action: TextButton.icon(
                        onPressed: () => _showTreatmentSheet(context, ref),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add Treatment'),
                      ),
                    ),
                    body: _SectionBody<List<TreatmentMaster>>(
                      state: treatmentsState,
                      onRetry: () => ref.invalidate(treatmentsProvider),
                      builder: (items) => _treatmentGrid(context, ref, items),
                    ),
                  );
                  final medications = _MasterColumn(
                    header: _SectionHeader(
                      title: 'Medications',
                      action: TextButton.icon(
                        onPressed: () => _showMedicationSheet(context, ref),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add Medication'),
                      ),
                    ),
                    body: _SectionBody<List<MedicationMaster>>(
                      state: medicationsState,
                      onRetry: () => ref.invalidate(medicationsProvider),
                      builder: (items) => _medicationList(context, ref, items),
                    ),
                  );
                  if (stack) {
                    return Column(
                      children: [
                        treatments,
                        const SizedBox(height: AppSpacing.xl),
                        medications,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: treatments),
                      const SizedBox(width: 32),
                      Expanded(child: medications),
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

  Widget _staffTable(
    BuildContext context,
    WidgetRef ref,
    List<StaffMember> staff,
  ) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              children: staff
                  .map(
                    (member) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceAccent,
                        foregroundColor: AppColors.accentDeep,
                        child: Text(_initials(member.name)),
                      ),
                      title: Text(member.name),
                      subtitle: Text(
                        member.jobTitle?.isNotEmpty == true
                            ? member.jobTitle!
                            : member.role,
                      ),
                      trailing: IconButton(
                        onPressed: () =>
                            _showStaffSheet(context, ref, member: member),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  )
                  .toList(),
            );
          }

          return Column(
            children: [
              Container(
                color: AppColors.surfaceMuted,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('MEMBER')),
                    Expanded(flex: 2, child: Text('ROLE')),
                    Expanded(flex: 3, child: Text('SCHEDULE')),
                    SizedBox(width: 95, child: Text('STATUS')),
                    SizedBox(width: 150, child: Text('ACTIONS')),
                  ],
                ),
              ),
              for (var index = 0; index < staff.length; index++) ...[
                _StaffRow(
                  member: staff[index],
                  onEdit: () =>
                      _showStaffSheet(context, ref, member: staff[index]),
                  onPin: () => _showPinResetSheet(context, ref, staff[index]),
                  onDeactivate: staff[index].isActive
                      ? () => _deactivateStaff(context, ref, staff[index])
                      : null,
                ),
                if (index < staff.length - 1) const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _treatmentGrid(
    BuildContext context,
    WidgetRef ref,
    List<TreatmentMaster> items,
  ) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.medical_services_outlined,
        message: 'No treatments found.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (item) => SizedBox(
                  width: constraints.maxWidth < 420
                      ? constraints.maxWidth
                      : width,
                  height: 166,
                  child: AppCard(
                    onTap: () =>
                        _showTreatmentSheet(context, ref, treatment: item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.medical_services_outlined,
                            color: AppColors.info,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if ((item.description ?? '').isNotEmpty)
                          Text(
                            item.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _medicationList(
    BuildContext context,
    WidgetRef ref,
    List<MedicationMaster> items,
  ) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.medication_outlined,
        message: 'No medications found.',
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: items
            .map(
              (item) => ListTile(
                leading: Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                title: Text(item.name),
                subtitle: Text(
                  [item.defaultDosage, item.description]
                      .whereType<String>()
                      .where((value) => value.isNotEmpty)
                      .join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  onPressed: () =>
                      _showMedicationSheet(context, ref, medication: item),
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
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
    final emailController = TextEditingController(text: member?.email ?? '');
    final mobileController = TextEditingController(text: member?.mobile ?? '');
    final jobTitleController = TextEditingController(
      text: member?.jobTitle ?? '',
    );
    final scheduleController = TextEditingController(
      text: member?.schedule ?? '',
    );
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
              AppTextField(controller: emailController, label: 'Email'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: mobileController,
                label: 'Phone Number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: jobTitleController,
                label: 'Job Title / Speciality',
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: scheduleController,
                label: 'Schedule',
                hint: 'e.g. Mon - Fri, 08:00 - 17:00',
              ),
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
                      'Enter a valid 4 digit PIN.',
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
                              email: emailController.text.trim().isEmpty
                                  ? null
                                  : emailController.text.trim(),
                              mobile: mobileController.text.trim().isEmpty
                                  ? null
                                  : mobileController.text.trim(),
                              jobTitle: jobTitleController.text.trim().isEmpty
                                  ? null
                                  : jobTitleController.text.trim(),
                              schedule: scheduleController.text.trim().isEmpty
                                  ? null
                                  : scheduleController.text.trim(),
                            )
                      : await ref
                            .read(adminRepositoryProvider)
                            .updateStaff(
                              id: member.id,
                              name: nameController.text.trim(),
                              role: role,
                              isActive: isActive,
                              email: emailController.text.trim().isEmpty
                                  ? null
                                  : emailController.text.trim(),
                              mobile: mobileController.text.trim().isEmpty
                                  ? null
                                  : mobileController.text.trim(),
                              jobTitle: jobTitleController.text.trim().isEmpty
                                  ? null
                                  : jobTitleController.text.trim(),
                              schedule: scheduleController.text.trim().isEmpty
                                  ? null
                                  : scheduleController.text.trim(),
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
                  SnackService.showError(context, 'Enter a valid 4 digit PIN.');
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

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.member,
    required this.onEdit,
    required this.onPin,
    required this.onDeactivate,
  });

  final StaffMember member;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
    final roleLabel = member.jobTitle?.isNotEmpty == true
        ? member.jobTitle!
        : member.role == 'admin'
        ? 'Administrator'
        : 'Clinical Staff';
    final schedule = (member.schedule ?? '').isNotEmpty
        ? member.schedule!
        : member.lastLoginAt == null
        ? 'Schedule not set'
        : 'Last login ${DateFormatter.dateTime(member.lastLoginAt!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.surfaceAccent,
                  foregroundColor: AppColors.accentDeep,
                  child: Text(initials),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              roleLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(schedule, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 95,
            child: AppBadge(label: member.isActive ? 'Active' : 'Inactive'),
          ),
          SizedBox(
            width: 150,
            child: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  tooltip: 'Edit staff',
                  constraints: const BoxConstraints.tightFor(
                    width: 42,
                    height: 42,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Reset PIN',
                  constraints: const BoxConstraints.tightFor(
                    width: 42,
                    height: 42,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onPin,
                  icon: const Icon(Icons.pin_outlined),
                ),
                IconButton(
                  tooltip: 'Deactivate',
                  constraints: const BoxConstraints.tightFor(
                    width: 42,
                    height: 42,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onDeactivate,
                  icon: const Icon(Icons.person_off_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterColumn extends StatelessWidget {
  const _MasterColumn({required this.header, required this.body});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: AppSpacing.md),
        body,
      ],
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
