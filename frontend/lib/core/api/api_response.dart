class AppError implements Exception {
  const AppError({
    required this.errorCode,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String errorCode;
  final String message;
  final int? statusCode;
  final dynamic details;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 422;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => (statusCode ?? 0) >= 500;

  @override
  String toString() => 'AppError($errorCode, $statusCode): $message';
}

abstract class ApiResponse<T> {
  const ApiResponse();

  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) error,
  });

  R? whenOrNull<R>({
    R Function(T data)? success,
    R Function(AppError error)? error,
  });
}

class ApiSuccess<T> extends ApiResponse<T> {
  const ApiSuccess(this.data);

  final T data;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) error,
  }) => success(data);

  @override
  R? whenOrNull<R>({
    R Function(T data)? success,
    R Function(AppError error)? error,
  }) => success?.call(data);
}

class ApiFailure<T> extends ApiResponse<T> {
  const ApiFailure(this.errorValue);

  final AppError errorValue;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(AppError error) error,
  }) => error(errorValue);

  @override
  R? whenOrNull<R>({
    R Function(T data)? success,
    R Function(AppError error)? error,
  }) => error?.call(errorValue);
}

extension ApiResponseX<T> on ApiResponse<T> {
  T unwrap() => when(success: (data) => data, error: (error) => throw error);
}
