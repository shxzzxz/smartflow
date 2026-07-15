import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/update/app_update_info.dart';
import 'package:smartflow/core/update/app_update_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.shxzz.smartflow/app_update');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('polls the system download until the APK is available', () async {
    final calls = <MethodCall>[];
    var statusRequestCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'startApkDownload':
              return 42;
            case 'getApkDownloadStatus':
              statusRequestCount += 1;
              if (statusRequestCount == 1) {
                return <String, Object?>{
                  'status': 'running',
                  'receivedBytes': 25,
                  'totalBytes': 100,
                };
              }
              return <String, Object?>{
                'status': 'successful',
                'receivedBytes': 100,
                'totalBytes': 100,
                'filePath': r'D:\updates\smartflow.apk',
              };
          }
          return null;
        });

    final progress = <double?>[];
    final result = await const AppUpdatePlatform(
      downloadPollInterval: Duration.zero,
    ).downloadApk(
      const AppUpdatePackage(
        abi: 'arm64-v8a',
        url: 'https://example.com/smartflow.apk',
        androidVersionCode: 32,
      ),
      versionName: '0.4.0 beta',
      onProgress: (value) => progress.add(value.fraction),
    );

    expect(result.downloadId, 42);
    expect(result.file.path, r'D:\updates\smartflow.apk');
    expect(progress, [0.25, 1.0]);
    expect(calls.map((call) => call.method), [
      'startApkDownload',
      'getApkDownloadStatus',
      'getApkDownloadStatus',
    ]);
    expect(calls.first.arguments, {
      'url': 'https://example.com/smartflow.apk',
      'fileName': 'smartflow-0.4.0_beta-arm64-v8a.apk',
    });
  });

  test('reports a failed system download', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return switch (call.method) {
            'startApkDownload' => 7,
            'getApkDownloadStatus' => <String, Object?>{
              'status': 'failed',
              'reason': 1006,
              'receivedBytes': 0,
              'totalBytes': -1,
            },
            _ => null,
          };
        });

    final future = const AppUpdatePlatform(
      downloadPollInterval: Duration.zero,
    ).downloadApk(
      const AppUpdatePackage(
        abi: 'arm64-v8a',
        url: 'https://example.com/smartflow.apk',
        androidVersionCode: 32,
      ),
      versionName: '0.4.0',
    );

    await expectLater(
      future,
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'downloadFailed',
        ),
      ),
    );
  });
}
