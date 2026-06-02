import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_error_code.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  group('UiError', () {
    test('builds from AppException code and message', () {
      final exception = BusinessException(
        _TestErrorCode.sample,
        message: 'Visible message.',
      );

      final error = UiError.fromException(exception);

      expect(error.code, 'test.ui_error');
      expect(error.message, 'Visible message.');
    });
  });
}

enum _TestErrorCode implements AppErrorCode {
  sample;

  @override
  String get code => 'test.ui_error';

  @override
  String get defaultMessage => 'Default visible message.';
}
