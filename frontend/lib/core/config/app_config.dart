class AppConfig {
  AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 2);

  static const int autoLogoutMinutes = 10;
  static const int maxPhotosPerVisit = 10;

  static const bool inventoryAddonEnabled = bool.fromEnvironment(
    'INVENTORY_ADDON',
    defaultValue: false,
  );

  static Uri get baseUri => Uri.parse(baseUrl);

  static String get origin => '${baseUri.scheme}://${baseUri.authority}';

  static String resolveUrl(String value) {
    if (value.isEmpty) {
      return value;
    }

    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      return value;
    }

    return value.startsWith('/') ? '$origin$value' : '$origin/$value';
  }
}
