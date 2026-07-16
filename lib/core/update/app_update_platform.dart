import 'dart:io';

import 'package:flutter/services.dart';

import 'app_update_info.dart';

class AppUpdatePlatform {
  const AppUpdatePlatform({
    this.downloadPollInterval = const Duration(milliseconds: 500),
  });

  final Duration downloadPollInterval;

  static const MethodChannel _channel = MethodChannel(
    'com.shxzz.smartflow/app_update',
  );

  Future<AppVersionInfo> getVersionInfo() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'getVersionInfo',
    );
    if (result == null) {
      throw StateError('Missing app version info.');
    }

    final versionName = result['versionName'];
    final buildNumber = result['buildNumber'];

    return AppVersionInfo(
      versionName: versionName is String ? versionName : '',
      buildNumber:
          buildNumber is int
              ? buildNumber
              : int.tryParse(buildNumber.toString()) ?? 0,
    );
  }

  Future<List<String>> getSupportedAbis() async {
    final result = await _channel.invokeListMethod<String>('getSupportedAbis');
    return result ?? const [];
  }

  Future<AppUpdateDownloadResult> downloadApk(
    AppUpdatePackage package, {
    required String versionName,
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    final safeVersionName = versionName.replaceAll(
      RegExp('[^A-Za-z0-9._-]'),
      '_',
    );
    final downloadIdValue = await _channel
        .invokeMethod<Object?>('startApkDownload', {
          'url': package.url,
          'fileName': 'smartflow-$safeVersionName-${package.abi}.apk',
        });
    final downloadId = switch (downloadIdValue) {
      int value => value,
      num value => value.toInt(),
      _ => throw StateError('Missing APK download ID.'),
    };

    while (true) {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getApkDownloadStatus',
        {'downloadId': downloadId},
      );
      if (result == null) {
        throw StateError('Missing APK download status.');
      }

      final receivedBytes = _readInt(result['receivedBytes']);
      final totalBytesValue = _readInt(result['totalBytes']);
      onProgress?.call(
        AppUpdateDownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytesValue > 0 ? totalBytesValue : null,
        ),
      );

      switch (result['status']) {
        case 'successful':
          final filePath = result['filePath'];
          if (filePath is! String || filePath.isEmpty) {
            throw StateError('Missing downloaded APK path.');
          }
          return AppUpdateDownloadResult(
            downloadId: downloadId,
            file: File(filePath),
          );
        case 'failed':
          throw PlatformException(
            code: 'downloadFailed',
            message: 'APK download failed: ${result['reason']}.',
          );
      }

      await Future<void>.delayed(downloadPollInterval);
    }
  }

  Future<void> removeApkDownload(int downloadId) async {
    await _channel.invokeMethod<void>('removeApkDownload', {
      'downloadId': downloadId,
    });
  }

  Future<void> installApk(String filePath) async {
    await _channel.invokeMethod<void>('installApk', {'filePath': filePath});
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
  }
}

class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({required this.downloadId, required this.file});

  final int downloadId;
  final File file;
}
