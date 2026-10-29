import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'handwriting_input_sheet.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.obscureText = false,
    this.onTap,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.enableHandwriting = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final bool obscureText;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;

  /// Shows a stylus handwriting pad on eligible fields. Numeric/phone keyboards,
  /// obscured (PIN), read-only, and controller-less fields are auto-excluded.
  final bool enableHandwriting;

  bool get _handwritingEligible {
    if (!enableHandwriting || controller == null || readOnly || obscureText) {
      return false;
    }
    return switch (keyboardType) {
      TextInputType.number ||
      TextInputType.phone ||
      TextInputType.datetime => false,
      _ => true,
    };
  }

  Future<void> _openHandwriting(BuildContext context) async {
    final result = await showHandwritingInputSheet(context, title: label);
    if (result == null || result.isEmpty) return;
    final field = controller!;
    final base = field.text.trim();
    final combined = [
      if (base.isNotEmpty) base,
      result.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    field
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);
    onChanged?.call(combined);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      readOnly: readOnly,
      obscureText: obscureText,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: _buildSuffix(context),
        prefixIcon: prefixIcon,
      ),
    );
  }

  Widget? _buildSuffix(BuildContext context) {
    final handwritingButton = _handwritingEligible
        ? IconButton(
            tooltip: 'Write with stylus',
            icon: const Icon(Icons.draw_rounded, color: AppColors.info),
            onPressed: () => _openHandwriting(context),
          )
        : null;

    if (handwritingButton == null) return suffixIcon;
    if (suffixIcon == null) return handwritingButton;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [handwritingButton, suffixIcon!],
    );
  }
}
