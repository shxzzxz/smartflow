import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../scripts/generate_update_manifest.dart' as generator;

void main() {
  test(
    'generates manifest with universal asset and split APK version codes',
    () async {
      final temp = await Directory.systemTemp.createTemp('smartflow_manifest_');
      addTearDown(() => temp.delete(recursive: true));

      final assetDir = Directory('${temp.path}/dist')..createSync();
      final outputDir = Directory('${temp.path}/public');
      final metadata = File('${temp.path}/output-metadata.json');

      File(
        '${assetDir.path}/smartflow-0.3.0-dev.2.apk',
      ).writeAsStringSync('universal');
      File(
        '${assetDir.path}/smartflow-0.3.0-dev.2-arm64-v8a.apk',
      ).writeAsStringSync('arm64');
      File(
        '${assetDir.path}/smartflow-0.3.0-dev.2-armeabi-v7a.apk',
      ).writeAsStringSync('arm');

      metadata.writeAsStringSync(
        jsonEncode({
          'elements': [
            {
              'filters': [
                {'filterType': 'ABI', 'value': 'armeabi-v7a'},
              ],
              'versionCode': 1031,
              'outputFile': 'app-armeabi-v7a-release.apk',
            },
            {
              'filters': [
                {'filterType': 'ABI', 'value': 'arm64-v8a'},
              ],
              'versionCode': 2031,
              'outputFile': 'app-arm64-v8a-release.apk',
            },
          ],
        }),
      );

      await generator.main([
        '--channel',
        'dev',
        '--version-name',
        '0.3.0-dev.2',
        '--version-code',
        '31',
        '--tag',
        'v0.3.0-dev.2',
        '--repository',
        'shxzzxz/smartflow',
        '--asset-dir',
        assetDir.path,
        '--apk-metadata',
        metadata.path,
        '--output-dir',
        outputDir.path,
      ]);

      final manifest =
          jsonDecode(
                File('${outputDir.path}/update-dev.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final universalApk = manifest['universalApk'] as Map<String, Object?>;
      final apks = manifest['apks'] as List<Object?>;
      final arm64 = apks.cast<Map<String, Object?>>().singleWhere(
        (apk) => apk['abi'] == 'arm64-v8a',
      );
      final arm = apks.cast<Map<String, Object?>>().singleWhere(
        (apk) => apk['abi'] == 'armeabi-v7a',
      );

      expect(manifest['buildNumber'], 31);
      expect(universalApk['androidVersionCode'], 31);
      expect(arm64['androidVersionCode'], 2031);
      expect(arm['androidVersionCode'], 1031);
      expect(manifest.containsKey('apkUrl'), isFalse);
      expect(manifest.containsKey('versionCode'), isFalse);
    },
  );
}
