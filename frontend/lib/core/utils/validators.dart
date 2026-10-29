class Validators {
  Validators._();

  static String? requiredText(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? mobile(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Mobile number is required';
    }
    final pattern = RegExp(r'^\+?[0-9]{10,15}$');
    if (!pattern.hasMatch(trimmed)) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  static String? pin(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length != 4) {
      return 'PIN must be exactly 4 digits';
    }
    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      return 'PIN must contain digits only';
    }
    return null;
  }

  static int? parseOptionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }
}
