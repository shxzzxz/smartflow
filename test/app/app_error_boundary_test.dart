import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/app/app_error_boundary.dart';

void main() {
  group('AppGlobalErrorHandler', () {
    testWidgets('logs Flutter framework errors and hides details in safe UI', (
      tester,
    ) async {
      final logger = Logger.detached('test.app.error');
      final records = <LogRecord>[];
      final subscription = logger.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final handler = AppGlobalErrorHandler(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        logger: logger,
        showDebugDetails: false,
      );
      final details = FlutterErrorDetails(
        exception: StateError('framework boom'),
        stack: StackTrace.fromString('framework stack'),
      );

      handler.handleFlutterError(details);
      await tester.pumpWidget(
        MaterialApp(home: handler.buildErrorWidget(details)),
      );

      expect(records, hasLength(1));
      expect(records.single.message, 'Flutter framework error.');
      expect(records.single.error, isA<StateError>());
      expect(find.text('页面出错了'), findsOneWidget);
      expect(find.textContaining('framework boom'), findsNothing);
    });

    testWidgets('debug fallback UI includes technical detail', (tester) async {
      final handler = AppGlobalErrorHandler(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        logger: Logger.detached('test.app.error.debug'),
        showDebugDetails: true,
      );
      final details = FlutterErrorDetails(
        exception: StateError('debug boom'),
        stack: StackTrace.fromString('debug stack'),
      );

      await tester.pumpWidget(
        MaterialApp(home: handler.buildErrorWidget(details)),
      );

      expect(find.textContaining('debug boom'), findsOneWidget);
    });

    testWidgets('logs async errors and shows global snackbar', (tester) async {
      final logger = Logger.detached('test.app.async');
      final records = <LogRecord>[];
      final subscription = logger.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final handler = AppGlobalErrorHandler(
        scaffoldMessengerKey: messengerKey,
        logger: logger,
      );

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      );

      final handled = handler.handlePlatformError(
        StateError('async boom'),
        StackTrace.fromString('async stack'),
      );
      await tester.pump();

      expect(handled, true);
      expect(records, hasLength(1));
      expect(records.single.message, 'Unhandled async error.');
      expect(records.single.error, isA<StateError>());
      expect(find.text('发生了未预期错误，请稍后重试'), findsOneWidget);
    });
  });
}
