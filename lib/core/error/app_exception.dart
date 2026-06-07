import 'app_error_code.dart';

class AppException implements Exception {
  AppException(
    AppErrorCode errorCode, {
    String? message,
    this.cause,
    this.stackTrace,
  }) : code = errorCode.code,
       message = message ?? errorCode.defaultMessage;

  final String code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException($code): $message';
}

final class BusinessException extends AppException {
  BusinessException(
    super.errorCode, {
    super.message,
    super.cause,
    super.stackTrace,
  });
}

final class InfrastructureException extends AppException {
  InfrastructureException(
    super.errorCode, {
    super.message,
    super.cause,
    super.stackTrace,
  });
}
