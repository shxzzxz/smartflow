import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/update/android/android_app_update_platform.dart';
import 'package:smartflow/core/update/android/android_app_update_package.dart';
import 'package:smartflow/core/update/app_update_info.dart';
import 'package:smartflow/core/update/app_update_platform.dart';
import 'package:smartflow/core/update/app_version_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.shxzz.smartflow/app_update');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'reads the release build separately from the Android package code',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'getVersionInfo' => <String, Object?>{
                'versionName': '0.9.13-dev.2',
                'buildNumber': 89,
              },
              'getAndroidVersionCode' => 2089,
              _ => null,
            };
          });

      const platform = AndroidAppUpdatePlatform();
      final version = await const AppVersionReader().getVersionInfo();

      expect(version.versionName, '0.9.13-dev.2');
      expect(version.buildNumber, 89);
      expect(await platform.getAndroidVersionCode(), 2089);
    },
  );

  test('unsupported platforms advertise no in-app updater', () {
    expect(const AppUpdatePlatform.unsupported().supported, isFalse);
  });

  for (final scenario in const [
    (
      name: 'selects the first compatible split package',
      abis: ['x86_64', 'arm64-v8a'],
      currentCode: 2020,
      expectedCode: 2031,
    ),
    (
      name: 'a universal package can be covered by a split package',
      abis: ['arm64-v8a'],
      currentCode: 31,
      expectedCode: 2031,
    ),
    (
      name: 'the installed split is not offered again',
      abis: ['arm64-v8a'],
      currentCode: 2031,
      expectedCode: null,
    ),
    (
      name: 'a lower package code cannot cover the installed package',
      abis: ['arm64-v8a'],
      currentCode: 4020,
      expectedCode: null,
    ),
    (
      name: 'an unsupported ABI does not fall back to the universal APK',
      abis: ['armeabi-v7a'],
      currentCode: 20,
      expectedCode: null,
    ),
  ]) {
    test(scenario.name, () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'getSupportedAbis' => scenario.abis,
              'getAndroidVersionCode' => scenario.currentCode,
              _ => null,
            };
          });
      final update = AppUpdateInfo.fromJson({
        'channel': 'beta',
        'versionName': '0.3.0',
        'buildNumber': 31,
        'universalApk': {
          'url': 'https://example.com/universal.apk',
          'androidVersionCode': 31,
        },
        'apks': [
          {
            'abi': 'arm64-v8a',
            'url': 'https://example.com/arm64.apk',
            'androidVersionCode': 2031,
          },
        ],
      });

      final package = await const AndroidAppUpdatePlatform().prepareUpdate(
        update,
      );

      expect(package?.androidVersionCode, scenario.expectedCode);
    });
  }

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
    final result =
        await const AndroidAppUpdatePlatform(
          downloadPollInterval: Duration.zero,
        ).downloadPackage(
          const AndroidAppUpdatePackage(
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

    final future =
        const AndroidAppUpdatePlatform(
          downloadPollInterval: Duration.zero,
        ).downloadPackage(
          const AndroidAppUpdatePackage(
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
