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
    required super.message,
    super.code,
    super.originalException,
  });
}

class AuthenticationException extends AppException {
  AuthenticationException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'AUTH_FAILED',
  );
}

class ValidationException extends AppException {
  ValidationException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'VALIDATION_ERROR',
  );
}

class DatabaseException extends AppException {
  DatabaseException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'DATABASE_ERROR',
  );
}

class LocationException extends AppException {
  LocationException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'LOCATION_ERROR',
  );
}
