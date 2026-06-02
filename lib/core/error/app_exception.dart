import 'app_error_code.dart';

class AppException implements Exception {
  AppException(AppErrorCode errorCode, {String? message, this.cause})
    : code = errorCode.code,
      message = message ?? errorCode.defaultMessage;

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

final class BusinessException extends AppException {
  BusinessException(super.errorCode, {super.message, super.cause});
}

final class CallException extends AppException {
  CallException(super.errorCode, {super.message, super.cause});
}
