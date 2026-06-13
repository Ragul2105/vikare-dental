import 'package:dio/dio.dart';

import 'api_response.dart';

abstract class BaseRepository {
  BaseRepository(this.dio);

  final Dio dio;

  Future<ApiResponse<T>> safeCall<T>({
    required Future<Response<dynamic>> Function() call,
    required T Function(dynamic data) parser,
  }) async {
    try {
      final response = await call();
      return ApiSuccess<T>(parser(response.data));
    } on DioException catch (exception) {
      final error = exception.error;
      if (error is AppError) {
        return ApiFailure<T>(error);
      }
      return ApiFailure<T>(
        AppError(
          errorCode: 'UNKNOWN',
          message: exception.message ?? 'An unexpected error occurred.',
          statusCode: exception.response?.statusCode,
        ),
      );
    } catch (exception) {
      return ApiFailure<T>(
        AppError(errorCode: 'UNKNOWN', message: exception.toString()),
      );
    }
  }

  Future<ApiResponse<void>> safeVoidCall({
    required Future<Response<dynamic>> Function() call,
  }) async {
    try {
      await call();
      return const ApiSuccess<void>(null);
    } on DioException catch (exception) {
      final error = exception.error;
      if (error is AppError) {
        return ApiFailure<void>(error);
      }
      return ApiFailure<void>(
        AppError(
          errorCode: 'UNKNOWN',
          message: exception.message ?? 'An unexpected error occurred.',
          statusCode: exception.response?.statusCode,
        ),
      );
    } catch (exception) {
      return ApiFailure<void>(
        AppError(errorCode: 'UNKNOWN', message: exception.toString()),
      );
    }
  }
}
