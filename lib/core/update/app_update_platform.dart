import 'dart:io';

import 'package:flutter/services.dart';

import 'app_update_info.dart';

abstract class AppUpdatePlatform {
  const AppUpdatePlatform();

  const factory AppUpdatePlatform.unsupported() = _UnsupportedAppUpdatePlatform;

  bool get supported;

  Future<AppUpdatePackage?> prepareUpdate(AppUpdateInfo update);

  Future<AppUpdateDownloadResult> downloadPackage(
    AppUpdatePackage package, {
    required String versionName,
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  });

  Future<void> removeDownload(int downloadId);

  Future<void> installPackage(String filePath);
}

class _UnsupportedAppUpdatePlatform extends AppUpdatePlatform {
  const _UnsupportedAppUpdatePlatform();

  @override
  bool get supported => false;

  PlatformException _unsupported() => PlatformException(
    code: 'unsupportedPlatform',
    message: 'In-app updates are not supported on this platform.',
  );

  @override
  Future<AppUpdatePackage?> prepareUpdate(AppUpdateInfo update) async {
    throw _unsupported();
  }

  @override
  Future<AppUpdateDownloadResult> downloadPackage(
    AppUpdatePackage package, {
    required String versionName,
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    throw _unsupported();
  }

  @override
  Future<void> removeDownload(int downloadId) async {
    throw _unsupported();
  }

  @override
  Future<void> installPackage(String filePath) async {
    throw _unsupported();
  }
}

class AppUpdateDownloadResult {
  const AppUpdateDownloadResult({required this.downloadId, required this.file});

  final int downloadId;
  final File file;
}
