import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/infrastructure/intake/recognition/platform_payment_screenshot.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/capture_picker');
  late FilePickerPlatform original;
  setUp(() {
    original = FilePickerPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    FilePickerPlatform.instance = original;
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
  test(
    'registers a picked image then uses the same OCR handle as sharing',
    () async {
      final picker = _Picker(
        _ImageFile([
          Uint8List.fromList([1, 2, 3]),
        ], 3),
      );
      FilePickerPlatform.instance = picker;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'prepareImage') {
          expect((call.arguments as Map)['bytes'], [1, 2, 3]);
          return {'id': 'selected'};
        }
        expect(call.method, 'recognizeShare');
        expect(call.arguments, {'id': 'selected'});
        return {'blocks': []};
      });
      final platform = PlatformPaymentScreenshot(channel: channel);
      addTearDown(platform.dispose);
      final id = await platform.pickImage();
      expect(id, 'selected');
      expect(picker.type, FileType.image);
      expect(await platform.recognize(id!), isEmpty);
    },
  );
  test('cancellation invokes no native image operation', () async {
    FilePickerPlatform.instance = _Picker(null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('Cancelled selection invoked native OCR'),
    );
    final platform = PlatformPaymentScreenshot(channel: channel);
    addTearDown(platform.dispose);
    expect(await platform.pickImage(), isNull);
  });
  test(
    'picker failures keep exception type and original stack safely',
    () async {
      final failure = const FormatException(
        'private filename and account text',
      );
      final sourceStack = StackTrace.fromString(
        'package:file_picker/file_picker.dart 12:3 pickFile',
      );
      FilePickerPlatform.instance = _Picker(
        null,
        failure: failure,
        failureStack: sourceStack,
      );
      final platform = PlatformPaymentScreenshot(channel: channel);
      addTearDown(platform.dispose);
      await expectLater(
        platform.pickImage(),
        throwsA(
          isA<InfrastructureException>()
              .having(
                (error) => error.code,
                'code',
                'capture.image_pick_failed',
              )
              .having(
                (error) => error.cause,
                'exception type',
                failure.runtimeType,
              )
              .having(
                (error) => error.stackTrace.toString(),
                'original stack',
                sourceStack.toString(),
              ),
        ),
      );
    },
  );

  test(
    'native registration failures preserve safe platform diagnostics',
    () async {
      FilePickerPlatform.instance = _Picker(
        _ImageFile([
          Uint8List.fromList([1, 2, 3]),
        ], 3),
      );
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) async {
        throw PlatformException(
          code: 'capture.busy',
          message: 'private filename and account text',
          details: '/private/payment.png',
        );
      });
      final platform = PlatformPaymentScreenshot(channel: channel);
      addTearDown(platform.dispose);
      await expectLater(
        platform.pickImage(),
        throwsA(
          isA<InfrastructureException>()
              .having(
                (error) => error.code,
                'code',
                'capture.image_pick_failed',
              )
              .having((error) => error.stackTrace, 'stack', isNotNull)
              .having(
                (error) => error.cause,
                'safe cause',
                isA<PlatformException>()
                    .having(
                      (error) => error.code,
                      'platform code',
                      'capture.busy',
                    )
                    .having((error) => error.message, 'message', isNull)
                    .having((error) => error.details, 'details', isNull),
              ),
        ),
      );
    },
  );
  test(
    'known oversized images are rejected before reading or native registration',
    () async {
      final file = _ImageFile(const [], 20 * 1024 * 1024 + 1);
      FilePickerPlatform.instance = _Picker(file);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => fail('Oversized image reached the native channel'),
      );
      final platform = PlatformPaymentScreenshot(channel: channel);
      addTearDown(platform.dispose);
      await expectLater(
        platform.pickImage(),
        throwsA(
          isA<InfrastructureException>().having(
            (e) => e.code,
            'code',
            'capture.invalid_image',
          ),
        ),
      );
      expect(file.reads, 0);
    },
  );
  test(
    'unknown image lengths still enforce the byte limit while streaming',
    () async {
      final file = _ImageFile([
        Uint8List(11 * 1024 * 1024),
        Uint8List(10 * 1024 * 1024),
      ], null);
      FilePickerPlatform.instance = _Picker(file);
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => fail('Oversized streamed image reached native OCR'),
      );
      final platform = PlatformPaymentScreenshot(channel: channel);
      addTearDown(platform.dispose);
      await expectLater(
        platform.pickImage(),
        throwsA(
          isA<InfrastructureException>().having(
            (e) => e.code,
            'code',
            'capture.invalid_image',
          ),
        ),
      );
    },
  );
}

class _Picker extends FilePickerPlatform {
  _Picker(this.file, {this.failure, this.failureStack});
  final PlatformFile? file;
  final Exception? failure;
  final StackTrace? failureStack;
  FileType? type;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    this.type = type;
    if (failure != null) return Future.error(failure!, failureStack);
    return file;
  }
}

final class _ImageFile extends PlatformFile {
  _ImageFile(this.chunks, this.reportedLength);
  final List<Uint8List> chunks;
  final int? reportedLength;
  int reads = 0;
  @override
  String get name => 'fixture.png';
  @override
  Uri get uri => Uri.parse('memory:fixture');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int? lengthSync() => reportedLength;
  @override
  Future<int?> length() async => reportedLength;
  @override
  Future<Uint8List> readAsBytes() async {
    final builder = BytesBuilder();
    for (final chunk in chunks) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  Stream<Uint8List> readAsByteStream() async* {
    reads++;
    for (final chunk in chunks) {
      yield chunk;
    }
  }
}
