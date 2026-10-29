import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color canvas = Color(0xFFF6F8FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5FA);
  static const Color surfaceAccent = Color(0xFFEAF5FD);
  static const Color border = Color(0xFFDDE5EF);

  static const Color accent = Color(0xFF62B7F4);
  static const Color accentDeep = Color(0xFF287FB7);
  static const Color highlight = Color(0xFF83D6F6);
  static const Color info = Color(0xFF4AAAF0);

  static const Color success = Color(0xFF22B8A7);
  static const Color warning = Color(0xFFF4B740);
  static const Color error = Color(0xFFE34850);

  static const Color textPrimary = Color(0xFF111B31);
  static const Color textMuted = Color(0xFF60718D);
  static const Color textSoft = Color(0xFF91A1BA);

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
