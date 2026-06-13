import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../features/auth/domain/auth_models.dart';
import '../auth/auth_controller.dart';
import '../auth/token_storage.dart';
import '../config/app_config.dart';
import 'api_endpoints.dart';
import 'api_response.dart';

final publicApiClientProvider = Provider<Dio>(
  (ref) => _buildDio(ref, useAuth: false),
);

final apiClientProvider = Provider<Dio>((ref) => _buildDio(ref, useAuth: true));

Dio _buildDio(Ref ref, {required bool useAuth}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(_ErrorInterceptor());

  if (useAuth) {
    dio.interceptors.add(_RetryInterceptor(dio));
    dio.interceptors.add(_AuthInterceptor(ref));
  }

  if (kDebugMode) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestBody: true,
        requestHeader: false,
        responseBody: true,
        responseHeader: false,
        compact: true,
      ),
    );
  }

  return dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null && options.extra['skipAuth'] != true) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode ?? 0;
    final alreadyRetried =
        err.requestOptions.extra['retried_after_refresh'] == true;
    final skipRefresh = err.requestOptions.extra['skipRefresh'] == true;

    if (statusCode == 401 && !alreadyRetried && !skipRefresh) {
      final refreshed = await _refreshTokens();
      if (refreshed != null) {
        await _ref
            .read(authControllerProvider.notifier)
            .applyTokenPair(refreshed);
        err.requestOptions.extra['retried_after_refresh'] = true;
        err.requestOptions.headers['Authorization'] =
            'Bearer ${refreshed.accessToken}';

        try {
          final dio = _ref.read(apiClientProvider);
          final response = await dio.fetch<dynamic>(err.requestOptions);
          handler.resolve(response);
          return;
        } on DioException {
          // Fall through to the normalized error handler.
        }
      } else {
        await _ref
            .read(authControllerProvider.notifier)
            .handleSessionExpired(
              message: 'Session expired. Please log in again.',
            );
      }
    }

    handler.next(err);
  }

  Future<TokenPair?> _refreshTokens() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null) {
      return null;
    }

    final dio = _ref.read(publicApiClientProvider);
    try {
      final response = await dio.post<dynamic>(
        ApiEndpoints.authRefresh,
        data: {'refresh_token': refreshToken},
        options: Options(extra: const {'skipRefresh': true, 'skipAuth': true}),
      );

      return TokenPair.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode ?? 0;
    final alreadyRetried =
        err.requestOptions.extra['retried_server_error'] == true;

    if (statusCode >= 500 && !alreadyRetried) {
      await Future<void>.delayed(const Duration(milliseconds: 750));
      err.requestOptions.extra['retried_server_error'] = true;
      try {
        final response = await _dio.fetch<dynamic>(err.requestOptions);
        handler.resolve(response);
        return;
      } on DioException {
        // Fall through to the error normalizer.
      }
    }

    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    AppError appError;

    if (response != null) {
      final data = response.data;
      appError = AppError(
        errorCode: data is Map<String, dynamic>
            ? data['error_code']?.toString() ?? 'HTTP_ERROR'
            : 'HTTP_ERROR',
        message: data is Map<String, dynamic>
            ? data['message']?.toString() ??
                  _fallbackMessage(response.statusCode ?? 0)
            : _fallbackMessage(response.statusCode ?? 0),
        statusCode: response.statusCode,
        details: data is Map<String, dynamic> ? data['details'] : null,
      );
    } else if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      appError = const AppError(
        errorCode: 'TIMEOUT',
        message: 'Request timed out. Please try again.',
      );
    } else if (err.type == DioExceptionType.connectionError) {
      appError = const AppError(
        errorCode: 'NO_CONNECTION',
        message: 'No internet connection.',
      );
    } else {
      appError = AppError(
        errorCode: 'UNKNOWN',
        message: err.message ?? 'An unexpected error occurred.',
      );
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appError,
        message: appError.message,
      ),
    );
  }

  String _fallbackMessage(int statusCode) => switch (statusCode) {
    400 => 'Bad request.',
    401 => 'Session expired. Please log in again.',
    403 => 'Access denied.',
    404 => 'Resource not found.',
    409 => 'Conflict detected.',
    422 => 'Please check your input and try again.',
    429 => 'Too many requests. Please slow down.',
    _ => 'Something went wrong. Please try again.',
  };
}
