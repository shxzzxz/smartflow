import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../app_update_info.dart';
import '../app_update_platform.dart';
import 'android_app_update_package.dart';

final _logger = Logger('core.update');

class AndroidAppUpdatePlatform extends AppUpdatePlatform {
  const AndroidAppUpdatePlatform({
    this.downloadPollInterval = const Duration(milliseconds: 500),
  });

  final Duration downloadPollInterval;

  static const MethodChannel _channel = MethodChannel(
    'com.shxzz.smartflow/app_update',
  );

  @override
  bool get supported => true;

  @override
  Future<AndroidAppUpdatePackage?> prepareUpdate(AppUpdateInfo update) async {
    final package = _resolvePackage(update, await getSupportedAbis());
    if (package == null) return null;
    final versionCode = await getAndroidVersionCode();
    if (versionCode <= 0) {
      throw PlatformException(
        code: 'versionUnavailable',
        message: 'Cannot read the installed package version.',
      );
    }
    return package.androidVersionCode > versionCode ? package : null;
  }

  AndroidAppUpdatePackage? _resolvePackage(
    AppUpdateInfo update,
    List<String> supportedAbis,
  ) {
    final normalizedAbis = supportedAbis
        .map((abi) => abi.trim())
        .where((abi) => abi.isNotEmpty);
    for (final abi in normalizedAbis) {
      for (final package
          in update.packages.whereType<AndroidAppUpdatePackage>()) {
        if (package.abi == abi) return package;
      }
    }
    return null;
  }

  Future<int> getAndroidVersionCode() async {
    final value = await _channel.invokeMethod<Object?>('getAndroidVersionCode');
    return value is int ? value : int.tryParse(value.toString()) ?? 0;
  }

  Future<List<String>> getSupportedAbis() async {
    final result = await _channel.invokeListMethod<String>('getSupportedAbis');
    return result ?? const [];
  }

  @override
  Future<AppUpdateDownloadResult> downloadPackage(
    AppUpdatePackage package, {
    required String versionName,
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    if (package is! AndroidAppUpdatePackage) {
      throw PlatformException(
        code: 'unsupportedPackage',
        message: 'The selected package is not an Android package.',
      );
    }
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
    _logger.info(
      'APK download started: version=$versionName, abi=${package.abi}.',
    );

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
          _logger.info('APK download completed: $filePath');
          return AppUpdateDownloadResult(
            downloadId: downloadId,
            file: File(filePath),
          );
        case 'failed':
          _logger.warning('APK download failed: ${result['reason']}.');
          throw PlatformException(
            code: 'downloadFailed',
            message: 'APK download failed: ${result['reason']}.',
          );
      }

      await Future<void>.delayed(downloadPollInterval);
    }
  }

  @override
  Future<void> removeDownload(int downloadId) async {
    await _channel.invokeMethod<void>('removeApkDownload', {
      'downloadId': downloadId,
    });
  }

  @override
  Future<void> installPackage(String filePath) async {
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
