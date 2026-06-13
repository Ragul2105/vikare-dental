import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onSubmit,
    this.canSubmit = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onSubmit;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const mainAxisSpacing = AppSpacing.sm;
        const crossAxisSpacing = AppSpacing.sm;
        final itemWidth = (constraints.maxWidth - (crossAxisSpacing * 2)) / 3;
        final itemHeight = (constraints.maxHeight - (mainAxisSpacing * 3)) / 4;
        final childAspectRatio = itemHeight > 0
            ? (itemWidth / itemHeight).clamp(0.85, 1.85).toDouble()
            : 1.0;

        return GridView.count(
          crossAxisCount: 3,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: childAspectRatio,
          children: [
            ...'123456789'
                .split('')
                .map(
                  (digit) =>
                      _PinButton(label: digit, onTap: () => onDigit(digit)),
                ),
            _PinButton(
              icon: Icons.check_rounded,
              onTap: canSubmit ? onSubmit : null,
              accent: true,
            ),
            _PinButton(label: '0', onTap: () => onDigit('0')),
            _PinButton(icon: Icons.backspace_outlined, onTap: onDelete),
          ],
        );
      },
    );
  }
}

class _PinButton extends StatelessWidget {
  const _PinButton({
    this.label,
    this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: accent ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: accent ? AppColors.accent : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          alignment: Alignment.center,
          child: label != null
              ? Text(
                  label!,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: accent ? Colors.white : AppColors.textPrimary,
                  ),
                )
              : Icon(
                  icon,
                  color: enabled
                      ? (accent ? Colors.white : AppColors.textPrimary)
                      : AppColors.textSoft,
                ),
        ),
      ),
    );
  }
}
