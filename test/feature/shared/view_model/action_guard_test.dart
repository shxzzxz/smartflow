import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/core/error/app_error_code.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/feature/shared/view_model/action_guard.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  group('action guards', () {
    test('logs handled business failures as warnings', () async {
      final logger = Logger.detached('test.action_guard.business');
      final records = <LogRecord>[];
      final subscription = logger.onRecord.listen(records.add);
      addTearDown(subscription.cancel);

      final outcome = await guardUiAction<void>(
        logger,
        'Account save',
        () async => throw BusinessException(_TestErrorCode.business),
      );

      expect(outcome, isA<UiActionFailure<void>>());
      expect(records, hasLength(1));
      expect(records.single.level, Level.WARNING);
      expect(records.single.message, 'Account save failed [test.business].');
      expect(records.single.error, isA<BusinessException>());
    });

    test(
      'logs infrastructure failures as severe with the original cause',
      () async {
        final logger = Logger.detached('test.action_guard.infrastructure');
        final records = <LogRecord>[];
        final subscription = logger.onRecord.listen(records.add);
        addTearDown(subscription.cancel);
        final cause = StateError('storage unavailable');
        final stackTrace = StackTrace.fromString('original stack');

        final outcome = await guardSubmit(
          logger,
          'Account submit',
          () async => throw InfrastructureException(
            _TestErrorCode.infrastructure,
            cause: cause,
            stackTrace: stackTrace,
          ),
        );

        expect(outcome, isA<SubmitFailure>());
        expect(records, hasLength(1));
        expect(records.single.level, Level.SEVERE);
        expect(records.single.error, same(cause));
        expect(records.single.stackTrace, same(stackTrace));
      },
    );
  });
}

enum _TestErrorCode implements AppErrorCode {
  business,
  infrastructure;

  @override
  String get code => 'test.$name';

  @override
  String get defaultMessage => 'Test failure.';
}
