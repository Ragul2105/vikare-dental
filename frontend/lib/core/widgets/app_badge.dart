import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = status ?? label;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.statusBackground(effectiveStatus),
        border: Border.all(color: AppColors.statusBorder(effectiveStatus)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _displayLabel(label, effectiveStatus),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.statusColor(effectiveStatus),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _displayLabel(String rawLabel, String effectiveStatus) {
    final normalized = effectiveStatus.toLowerCase();
    if (_isAppointmentStatus(normalized)) {
      return normalized
          .split('_')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' ');
    }
    return rawLabel;
  }

  bool _isAppointmentStatus(String value) => switch (value) {
    'scheduled' ||
    'in_progress' ||
    'completed' ||
    'cancelled' ||
    'no_show' => true,
    _ => false,
  };
}
