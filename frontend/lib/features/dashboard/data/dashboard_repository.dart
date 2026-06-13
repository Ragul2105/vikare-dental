import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import '../../../core/api/base_repository.dart';
import '../../../core/cache/hive_cache.dart';
import '../domain/dashboard_models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.read(apiClientProvider)),
);

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  const cacheKey = 'dashboard_summary';

  try {
    final result = await ref.read(dashboardRepositoryProvider).getSummary();
    return result.when(
      success: (summary) {
        HiveCache.putString(cacheKey, jsonEncode(summary.toJson()));
        return summary;
      },
      error: (error) => throw error,
    );
  } catch (_) {
    final cached = HiveCache.getString(cacheKey);
    if (cached != null) {
      return DashboardSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
    rethrow;
  }
});

class DashboardRepository extends BaseRepository {
  DashboardRepository(super.dio);

  Future<ApiResponse<DashboardSummary>> getSummary() =>
      safeCall<DashboardSummary>(
        call: () => dio.get(ApiEndpoints.dashboardSummary),
        parser: (data) =>
            DashboardSummary.fromJson(data as Map<String, dynamic>),
      );
}
