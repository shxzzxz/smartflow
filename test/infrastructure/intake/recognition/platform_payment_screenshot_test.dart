import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/feature/shared/view_model/action_guard.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/infrastructure/intake/recognition/platform_payment_screenshot.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/capture_intake');
  final messenger = binding.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'receives the startup share and a subsequent running-app share',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'takeInitialShare');
        return {'id': 'cold-share'};
      });
      final platform = PlatformPaymentScreenshot(channel: channel);
      addTearDown(platform.dispose);
      expect((await platform.takeInitialShare())!.id, 'cold-share');
      final next = platform.shares.first;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sharedImage', {'id': 'warm-share'}),
        ),
        (_) {},
      );
      expect((await next).id, 'warm-share');
    },
  );

  test(
    'preserves OCR output and records complete diagnostics at INFO',
    () async {
      final previousLevel = Logger.root.level;
      Logger.root.level = Level.INFO;
      addTearDown(() => Logger.root.level = previousLevel);
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord
          .where((record) => record.loggerName == 'infra.intake.recognition')
          .listen(records.add);
      addTearDown(subscription.cancel);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'recognizeShare');
        expect(call.arguments, {'id': 'share'});
        return {
          'loadTimeMs': 12,
          'totalTimeMs': 34,
          'imagePath': '/private/image.png',
          'imageBytes': [1, 2, 3],
          'blocks': [
            {
              'text': '-18.60',
              'confidence': 0.98,
              'left': 40,
              'top': 120,
              'right': 300,
              'bottom': 190,
            },
          ],
        };
      });
      final platform = PlatformPaymentScreenshot(channel: channel);
      addTearDown(platform.dispose);
      final blocks = await platform.recognize('share');
      expect(blocks.single.text, '-18.60');
      expect(blocks.single.height, 70);
      expect(blocks.single.confidence, 0.98);
      final output = records.singleWhere(
        (record) => record.message.startsWith('Screenshot OCR output: '),
      );
      expect(output.level, Level.INFO);
      final payload =
          jsonDecode(output.message.substring('Screenshot OCR output: '.length))
              as Map<String, dynamic>;
      expect(payload['imageId'], 'share');
      final nativeResult = payload['result'] as Map<String, dynamic>;
      expect(nativeResult['loadTimeMs'], 12);
      expect(nativeResult['totalTimeMs'], 34);
      expect((nativeResult['blocks'] as List).single, {
        'text': '-18.60',
        'confidence': 0.98,
        'left': 40,
        'top': 120,
        'right': 300,
        'bottom': 190,
      });
      expect(output.message, isNot(contains('/private/image.png')));
      expect(nativeResult, isNot(contains('imageBytes')));
    },
  );

  test('nonfinite OCR diagnostics do not interrupt recognition', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'blocks': [
          {
            'text': '示例文字',
            'confidence': double.nan,
            'left': 20,
            'top': 30,
            'right': 120,
            'bottom': 60,
          },
        ],
      },
    );
    final platform = PlatformPaymentScreenshot(channel: channel);
    addTearDown(platform.dispose);
    final blocks = await platform.recognize('share');
    expect(blocks.single.text, '示例文字');
    expect(blocks.single.confidence.isNaN, isTrue);
  });

  test('maps platform failure without exposing exception details', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'capture.ocr_failed',
        message: 'private image path and transaction',
      );
    });
    final platform = PlatformPaymentScreenshot(channel: channel);
    addTearDown(platform.dispose);
    await expectLater(
      platform.recognize('share'),
      throwsA(
        isA<InfrastructureException>()
            .having((error) => error.code, 'code', 'capture.ocr_failed')
            .having(
              (error) => error.message,
              'safe message',
              isNot(contains('private')),
            ),
      ),
    );
  });

  for (final operation in ['recognize', 'takeInitialShare']) {
    test(
      '$operation keeps safe platform diagnostics and original stack',
      () async {
        final sourceStack = StackTrace.fromString(
          'package:flutter/services/platform_channel.dart 27:3 invokeMethod',
        );
        final channel = _FailingChannel(
          PlatformException(
            code: 'capture.runtime_unavailable',
            message: 'private screenshot and payment details',
            details: {'path': '/private/payment.png', 'amount': '123.45'},
            stacktrace: '/private/native/payment.png',
          ),
          sourceStack,
        );
        final platform = PlatformPaymentScreenshot(channel: channel);
        addTearDown(platform.dispose);
        final result = operation == 'recognize'
            ? platform.recognize('share')
            : platform.takeInitialShare();
        await expectLater(
          result,
          throwsA(
            isA<InfrastructureException>()
                .having(
                  (error) => error.code,
                  'application code',
                  operation == 'recognize'
                      ? 'capture.ocr_failed'
                      : 'capture.image_unavailable',
                )
                .having(
                  (error) => error.stackTrace.toString(),
                  'original stack',
                  sourceStack.toString(),
                )
                .having(
                  (error) => error.cause,
                  'safe cause',
                  isA<PlatformException>()
                      .having(
                        (error) => error.code,
                        'platform code',
                        'capture.runtime_unavailable',
                      )
                      .having((error) => error.message, 'message', isNull)
                      .having((error) => error.details, 'details', isNull)
                      .having(
                        (error) => error.stacktrace,
                        'native stack',
                        isNull,
                      ),
                ),
          ),
        );
      },
    );
  }

  test(
    'action logging keeps platform diagnostics without image contents',
    () async {
      final sourceStack = StackTrace.fromString(
        'package:flutter/services/platform_channel.dart 27:3 invokeMethod',
      );
      final platform = PlatformPaymentScreenshot(
        channel: _FailingChannel(
          PlatformException(
            code: 'capture.ocr_failed',
            message: 'private account and payment 123.45',
            details: '/private/payment.png',
            stacktrace: '/private/native/payment.png',
          ),
          sourceStack,
        ),
      );
      addTearDown(platform.dispose);
      final logger = Logger.detached('test.capture.failure');
      final records = <LogRecord>[];
      final subscription = logger.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final outcome = await guardUiAction(
        logger,
        'Recognize screenshot',
        () => platform.recognize('share'),
      );
      expect(outcome, isA<UiActionFailure>());
      expect(records, hasLength(1));
      expect(records.single.message, contains('capture.ocr_failed'));
      expect(records.single.error.toString(), contains('PlatformException'));
      expect(records.single.error.toString(), contains('capture.ocr_failed'));
      expect(records.single.stackTrace.toString(), sourceStack.toString());
      final logged = '${records.single.error}\n${records.single.stackTrace}';
      expect(logged, isNot(contains('private')));
      expect(logged, isNot(contains('123.45')));
    },
  );

  test('non-Android startup does not invoke a native share channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('Unsupported platform invoked channel'),
    );
    final platform = PlatformPaymentScreenshot(channel: channel);
    addTearDown(platform.dispose);
    expect(await platform.takeInitialShare(), isNull);
  });
}

class _FailingChannel extends MethodChannel {
  _FailingChannel(this.error, this.sourceStack) : super('test/capture_failure');

  final PlatformException error;
  final StackTrace sourceStack;

  @override
  Future<Map<K, V>?> invokeMapMethod<K, V>(
    String method, [
    dynamic arguments,
  ]) => Future.error(error, sourceStack);
}
