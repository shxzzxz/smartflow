import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
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

  test('preserves recognized geometry and confidence for the parser', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recognizeShare');
      expect(call.arguments, {'id': 'share'});
      return {
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
