import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/app_update_info.dart';

void main() {
  group('AppUpdateInfo', () {
    test('parses update manifest', () {
      final info = AppUpdateInfo.fromJson({
        'channel': 'beta',
        'versionName': '0.3.0-dev.2',
        'buildNumber': 31,
        'universalApk': {
          'url': 'https://example.com/smartflow.apk',
          'sha256': 'ABCDEF',
          'size': '456',
          'androidVersionCode': 31,
        },
        'releaseUrl':
            'https://github.com/shxzzxz/smartflow/releases/tag/v0.3.0-dev.2',
        'required': false,
        'notes': 'SmartFlow 0.3.0-dev.2 开发渠道版本。',
      });

      expect(info.channel, AppUpdateChannel.beta);
      expect(info.versionName, '0.3.0-dev.2');
      expect(info.buildNumber, 31);
      expect(info.universalApk.url, 'https://example.com/smartflow.apk');
      expect(info.universalApk.sha256, 'abcdef');
      expect(info.universalApk.size, 456);
      expect(info.universalApk.androidVersionCode, 31);
      expect(info.required, isFalse);
      expect(info.notes, 'SmartFlow 0.3.0-dev.2 开发渠道版本。');
    });

    test('parses split APK packages with Android version codes', () {
      final info = AppUpdateInfo.fromJson({
        'channel': 'dev',
        'versionName': '0.3.0-dev.2',
        'buildNumber': 31,
        'universalApk': {
          'url': 'https://example.com/smartflow.apk',
          'androidVersionCode': 31,
        },
        'releaseUrl': '',
        'apks': [
          {
            'abi': 'arm64-v8a',
            'url': 'https://example.com/smartflow-arm64.apk',
            'sha256': 'ABCDEF',
            'size': 123,
            'androidVersionCode': 2031,
          },
          {
            'abi': 'armeabi-v7a',
            'url': 'https://example.com/smartflow-arm.apk',
            'androidVersionCode': '1031',
          },
        ],
      });

      expect(info.packages, hasLength(2));
      expect(info.packages.first.abi, 'arm64-v8a');
      expect(info.packages.first.sha256, 'abcdef');
      expect(info.packages.first.size, 123);
      expect(info.packages.first.androidVersionCode, 2031);
      expect(info.packages.last.androidVersionCode, 1031);
    });

    test('resolves package by supported ABI without universal fallback', () {
      final info = AppUpdateInfo.fromJson(_manifest(apks: [_arm64Package()]));

      expect(
        info.resolvePackage(['x86_64', 'arm64-v8a'])?.url,
        'https://example.com/smartflow-arm64.apk',
      );
      expect(info.resolvePackage(['armeabi-v7a']), isNull);
    });

    test('compares installable update by matching split APK versionCode', () {
      final info = AppUpdateInfo.fromJson(_manifest(apks: [_arm64Package()]));

      expect(
        info.hasInstallableUpdate(
          currentAndroidVersionCode: 2020,
          supportedAbis: ['arm64-v8a'],
        ),
        isTrue,
      );
      expect(
        info.hasInstallableUpdate(
          currentAndroidVersionCode: 2031,
          supportedAbis: ['arm64-v8a'],
        ),
        isFalse,
      );
      expect(
        info.hasInstallableUpdate(
          currentAndroidVersionCode: 20,
          supportedAbis: ['x86_64'],
        ),
        isFalse,
      );
    });

    test('rejects incomplete manifest', () {
      expect(
        () => AppUpdateInfo.fromJson({
          'channel': 'beta',
          'versionName': '0.3.0-dev.2',
          'buildNumber': 31,
        }),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _manifest({List<Map<String, Object?>> apks = const []}) {
  return {
    'channel': 'dev',
    'versionName': '0.3.0-dev.2',
    'buildNumber': 31,
    'universalApk': {
      'url': 'https://example.com/smartflow.apk',
      'sha256': '123456',
      'size': 456,
      'androidVersionCode': 31,
    },
    'releaseUrl': '',
    'apks': apks,
  };
}

Map<String, Object?> _arm64Package() {
  return {
    'abi': 'arm64-v8a',
    'url': 'https://example.com/smartflow-arm64.apk',
    'androidVersionCode': 2031,
  };
}
