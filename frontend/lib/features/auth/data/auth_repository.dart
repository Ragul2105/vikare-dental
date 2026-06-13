import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_response.dart';
import '../../../core/api/base_repository.dart';
import '../../../core/models/user.dart';
import '../domain/auth_models.dart';

class AuthRepository extends BaseRepository {
  AuthRepository(super.dio);

  Future<ApiResponse<List<UserSummary>>> listUsers() =>
      safeCall<List<UserSummary>>(
        call: () => dio.get(ApiEndpoints.authUsers),
        parser: (data) {
          final items = (data['items'] as List<dynamic>? ?? const <dynamic>[]);
          return items
              .map((item) => UserSummary.fromJson(item as Map<String, dynamic>))
              .toList(growable: false);
        },
      );

  Future<ApiResponse<TokenPair>> login(String userId, String pin) =>
      safeCall<TokenPair>(
        call: () => dio.post(
          ApiEndpoints.authLogin,
          data: {'user_id': userId, 'pin': pin},
        ),
        parser: (data) => TokenPair.fromJson(data as Map<String, dynamic>),
      );

  Future<ApiResponse<TokenPair>> refresh(String refreshToken) =>
      safeCall<TokenPair>(
        call: () => dio.post(
          ApiEndpoints.authRefresh,
          data: {'refresh_token': refreshToken},
        ),
        parser: (data) => TokenPair.fromJson(data as Map<String, dynamic>),
      );
}
