import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import '../../../core/api/base_repository.dart';
import '../domain/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.read(apiClientProvider)),
);

final staffProvider = FutureProvider<List<StaffMember>>((ref) async {
  final result = await ref.read(adminRepositoryProvider).listStaff();
  return result.unwrap();
});

final activityLogsProvider = FutureProvider<List<ActivityLogItem>>((ref) async {
  final result = await ref.read(adminRepositoryProvider).listActivityLogs();
  return result.unwrap();
});

class AdminRepository extends BaseRepository {
  AdminRepository(super.dio);

  Future<ApiResponse<List<StaffMember>>> listStaff() =>
      safeCall<List<StaffMember>>(
        call: () => dio.get(ApiEndpoints.staff),
        parser: (data) {
          final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
          return items
              .map((item) => StaffMember.fromJson(item as Map<String, dynamic>))
              .toList(growable: false);
        },
      );

  Future<ApiResponse<StaffMember>> createStaff({
    required String name,
    required String role,
    required String pin,
    String? email,
    String? mobile,
    String? jobTitle,
    String? schedule,
  }) => safeCall<StaffMember>(
    call: () => dio.post(
      ApiEndpoints.staff,
      data: {
        'name': name,
        'role': role,
        'pin': pin,
        'email': email,
        'mobile': mobile,
        'job_title': jobTitle,
        'schedule': schedule,
      },
    ),
    parser: (data) => StaffMember.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<StaffMember>> updateStaff({
    required String id,
    required String name,
    required String role,
    required bool isActive,
    String? email,
    String? mobile,
    String? jobTitle,
    String? schedule,
  }) => safeCall<StaffMember>(
    call: () => dio.patch(
      ApiEndpoints.staffMember(id),
      data: {
        'name': name,
        'role': role,
        'is_active': isActive,
        'email': email,
        'mobile': mobile,
        'job_title': jobTitle,
        'schedule': schedule,
      },
    ),
    parser: (data) => StaffMember.fromJson(data as Map<String, dynamic>),
  );

  Future<ApiResponse<void>> deactivateStaff(String id) =>
      safeVoidCall(call: () => dio.delete(ApiEndpoints.staffMember(id)));

  Future<ApiResponse<void>> resetPin(String id, String newPin) => safeVoidCall(
    call: () =>
        dio.post(ApiEndpoints.staffResetPin(id), data: {'new_pin': newPin}),
  );

  Future<ApiResponse<List<ActivityLogItem>>> listActivityLogs() =>
      safeCall<List<ActivityLogItem>>(
        call: () => dio.get(
          ApiEndpoints.activityLogs,
          queryParameters: const {'page': 1, 'page_size': 20},
        ),
        parser: (data) {
          final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
          return items
              .map(
                (item) =>
                    ActivityLogItem.fromJson(item as Map<String, dynamic>),
              )
              .toList(growable: false);
        },
      );
}
