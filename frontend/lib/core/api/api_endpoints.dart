class ApiEndpoints {
  ApiEndpoints._();

  static const String authUsers = '/auth/users';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';

  static const String patients = '/patients';
  static String patient(String id) => '/patients/$id';
  static String patientVisits(String id) => '/patients/$id/visits';

  static const String appointments = '/appointments';
  static String appointment(String id) => '/appointments/$id';

  static const String visits = '/visits';
  static String visit(String id) => '/visits/$id';
  static String visitPhotos(String id) => '/visits/$id/photos';
  static String visitPhoto(String visitId, String photoId) =>
      '/visits/$visitId/photos/$photoId';
  static String prescription(String visitId) => '/visits/$visitId/prescription';

  static const String dashboardSummary = '/dashboard/summary';

  static const String staff = '/staff';
  static String staffMember(String id) => '/staff/$id';
  static String staffResetPin(String id) => '/staff/$id/reset-pin';
  static const String activityLogs = '/activity-logs';

  static const String treatments = '/treatments';
  static String treatment(String id) => '/treatments/$id';
  static const String medications = '/medications';
  static String medication(String id) => '/medications/$id';
}
