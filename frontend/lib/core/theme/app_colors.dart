import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color canvas = Color(0xFFF5F1E8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFE8F0EA);
  static const Color surfaceAccent = Color(0xFFD8E8E4);
  static const Color border = Color(0xFFD7DDD6);

  static const Color accent = Color(0xFF0B5F58);
  static const Color accentDeep = Color(0xFF143B4A);
  static const Color highlight = Color(0xFFD89441);
  static const Color info = Color(0xFF2F6FBD);

  static const Color success = Color(0xFF34835B);
  static const Color warning = Color(0xFFC7902F);
  static const Color error = Color(0xFFD5544F);

  static const Color textPrimary = Color(0xFF17202B);
  static const Color textMuted = Color(0xFF62717C);
  static const Color textSoft = Color(0xFF8C99A3);

  static Color statusColor(String status) => switch (status.toLowerCase()) {
    'scheduled' => info,
    'in_progress' => warning,
    'completed' => success,
    'cancelled' => error,
    'no_show' => textSoft,
    _ => accentDeep,
  };

  static Color statusBackground(String status) =>
      statusColor(status).withValues(alpha: 0.14);

  static Color statusBorder(String status) =>
      statusColor(status).withValues(alpha: 0.3);
}
