/// Exceptions and error handling
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  AppException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code,
    originalException: originalException,
  );
}

class AuthenticationException extends AppException {
  AuthenticationException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code ?? 'AUTH_FAILED',
    originalException: originalException,
  );
}

class ValidationException extends AppException {
  ValidationException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code ?? 'VALIDATION_ERROR',
    originalException: originalException,
  );
}

class DatabaseException extends AppException {
  DatabaseException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code ?? 'DATABASE_ERROR',
    originalException: originalException,
  );
}

class LocationException extends AppException {
  LocationException({
    required String message,
    String? code,
    dynamic originalException,
  }) : super(
    message: message,
    code: code ?? 'LOCATION_ERROR',
    originalException: originalException,
  );
}
