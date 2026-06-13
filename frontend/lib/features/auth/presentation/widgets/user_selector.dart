import 'package:flutter/material.dart';

import '../../../../core/models/user.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class UserSelector extends StatelessWidget {
  const UserSelector({
    super.key,
    required this.users,
    required this.selectedUser,
    required this.onSelect,
  });

  final List<UserSummary> users;
  final UserSummary? selectedUser;
  final ValueChanged<UserSummary> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 440;
        final crossAxisCount = constraints.maxWidth >= 640 ? 2 : 1;
        final mainAxisExtent = isCompact
            ? 116.0
            : crossAxisCount == 1
            ? 132.0
            : 164.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            final selected = selectedUser?.id == user.id;

            return AppCard(
              padding: EdgeInsets.zero,
              onTap: () => onSelect(user),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  color: selected
                      ? AppColors.surfaceAccent
                      : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: isCompact
                    ? Row(
                        children: [
                          _UserAvatar(user: user, selected: selected),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _UserDetails(user: user, compact: true),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.accent,
                            ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _UserAvatar(user: user, selected: selected),
                          _UserDetails(user: user, compact: false),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, required this.selected});

  final UserSummary user;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: selected ? AppColors.accent : AppColors.surfaceMuted,
      foregroundColor: selected ? Colors.white : AppColors.accentDeep,
      child: Text(
        user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _UserDetails extends StatelessWidget {
  const _UserDetails({required this.user, required this.compact});

  final UserSummary user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          user.name,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          user.role == 'admin' ? 'Doctor / Admin' : 'Clinic Staff',
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
