import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/app_update_info.dart';
import 'package:smartflow/core/update/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    test('uses GitHub Pages as the default manifest host', () {
      final uri = AppUpdateService.manifestUriForChannel(AppUpdateChannel.beta);

      expect(
        uri.toString(),
        'https://shxzzxz.github.io/smartflow/update-beta.json',
      );
    });

    test('accepts a downloaded APK with the expected size and hash', () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-update-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final apk = File('${directory.path}${Platform.pathSeparator}update.apk');
      final bytes = [1, 2, 3, 4];
      await apk.writeAsBytes(bytes);
      final service = AppUpdateService(
        manifestUri: Uri.parse('https://example.com/update.json'),
      );

      await service.verifyDownloadedApk(
        apk,
        AppUpdatePackage(
          abi: 'arm64-v8a',
          url: 'https://example.com/update.apk',
          androidVersionCode: 32,
          size: bytes.length,
          sha256: sha256.convert(bytes).toString(),
        ),
      );
    });

    test('rejects a downloaded APK with the wrong hash', () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-update-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final apk = File('${directory.path}${Platform.pathSeparator}update.apk');
      await apk.writeAsBytes([1, 2, 3, 4]);
      final service = AppUpdateService(
        manifestUri: Uri.parse('https://example.com/update.json'),
      );

      await expectLater(
        service.verifyDownloadedApk(
          apk,
          const AppUpdatePackage(
            abi: 'arm64-v8a',
            url: 'https://example.com/update.apk',
            androidVersionCode: 32,
            sha256:
                '0000000000000000000000000000000000000000000000000000000000000000',
          ),
        ),
        throwsFormatException,
      );
    });
  });
}
