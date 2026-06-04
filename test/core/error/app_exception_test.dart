import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_error_code.dart';
import 'package:smartflow/core/error/app_exception.dart';

void main() {
  group('AppException', () {
    test('uses default message from error code', () {
      final exception = BusinessException(_TestErrorCode.sample);

      expect(exception.message, 'Default message.');
    });

    test('uses default message when specialized message is null', () {
      final exception = BusinessException(_TestErrorCode.sample, message: null);

      expect(exception.message, 'Default message.');
    });

    test('uses specialized message when provided', () {
      final exception = BusinessException(
        _TestErrorCode.sample,
        message: 'Specialized message.',
      );

      expect(exception.message, 'Specialized message.');
    });

    test('exposes code from error code', () {
      final exception = BusinessException(_TestErrorCode.sample);

      expect(exception.code, 'test.sample');
    });

    test('keeps cause and stack trace', () {
      final cause = Exception('database failed');
      final stackTrace = StackTrace.current;
      final exception = InfrastructureException(
        _TestErrorCode.sample,
        cause: cause,
        stackTrace: stackTrace,
      );

      expect(exception.cause, same(cause));
      expect(exception.stackTrace, same(stackTrace));
    });
  });
}

enum _TestErrorCode implements AppErrorCode {
  sample;

  @override
  String get code => 'test.sample';

  @override
  String get defaultMessage => 'Default message.';
}
