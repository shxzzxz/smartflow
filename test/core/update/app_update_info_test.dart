import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/android/android_app_update_package.dart';
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
      final packages = info.packages.cast<AndroidAppUpdatePackage>();
      expect(packages.first.abi, 'arm64-v8a');
      expect(packages.first.sha256, 'abcdef');
      expect(packages.first.size, 123);
      expect(packages.first.androidVersionCode, 2031);
      expect(packages.last.androidVersionCode, 1031);
    });

    test('compares the shared release build number', () {
      final info = AppUpdateInfo.fromJson(_manifest(apks: [_arm64Package()]));

      expect(info.hasNewerBuild(20), isTrue);
      expect(info.hasNewerBuild(31), isFalse);
      expect(info.hasNewerBuild(32), isFalse);
    });

    test('compares release builds above the ABI offset unit', () {
      final info = AppUpdateInfo.fromJson(
        _manifest(
          buildNumber: 1031,
          apks: [_arm64Package(androidVersionCode: 3031)],
        ),
      );

      expect(info.hasNewerBuild(1020), isTrue);
      expect(info.hasNewerBuild(1031), isFalse);
      expect(info.hasNewerBuild(1032), isFalse);
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

Map<String, Object?> _manifest({
  int buildNumber = 31,
  List<Map<String, Object?>> apks = const [],
}) {
  return {
    'channel': 'dev',
    'versionName': '0.3.0-dev.2',
    'buildNumber': buildNumber,
    'universalApk': {
      'url': 'https://example.com/smartflow.apk',
      'sha256': '123456',
      'size': 456,
      'androidVersionCode': buildNumber,
    },
    'releaseUrl': '',
    'apks': apks,
  };
}

Map<String, Object?> _arm64Package({int androidVersionCode = 2031}) {
  return {
    'abi': 'arm64-v8a',
    'url': 'https://example.com/smartflow-arm64.apk',
    'androidVersionCode': androidVersionCode,
  };
}
