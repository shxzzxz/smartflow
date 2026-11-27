import 'dart:async';
import 'dart:io';

import 'package:smartflow/application/shared/update_channel_store.dart';
import 'package:smartflow/core/update/android/android_app_update_platform.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/android/android_app_update_package.dart';
import 'package:smartflow/core/update/app_update_info.dart';
import 'package:smartflow/core/update/app_update_platform.dart';
import 'package:smartflow/core/update/app_update_service.dart';
import 'package:smartflow/core/update/app_version_info.dart';
import 'package:smartflow/core/update/app_version_reader.dart';

AppUpdateInfo fakeAppUpdateInfo({
  AppUpdateChannel channel = AppUpdateChannel.beta,
  int buildNumber = 101,
  int? androidVersionCode,
}) => AppUpdateInfo(
  channel: channel,
  versionName: '0.9.13',
  buildNumber: buildNumber,
  universalApk: AppUpdateUniversalApk(
    url: 'https://example.com/universal.apk',
    androidVersionCode: androidVersionCode ?? buildNumber,
  ),
  releaseUrl: 'https://example.com/release',
  required: false,
  notes: '修复已知问题',
  packages: [
    AndroidAppUpdatePackage(
      abi: 'arm64-v8a',
      url: 'https://example.com/update.apk',
      androidVersionCode: androidVersionCode ?? buildNumber,
      size: 4,
      sha256:
          '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    ),
  ],
);

class FakeAppUpdateService extends AppUpdateService {
  FakeAppUpdateService(this.info)
    : super(manifestUri: Uri.parse('https://example.com/update.json'));

  AppUpdateInfo info;
  int fetches = 0;
  int verifications = 0;
  Exception? fetchError;
  Completer<AppUpdateInfo>? manifestResult;
  Future<void> Function(File, AppUpdatePackage)? onVerify;

  @override
  Future<AppUpdateInfo> fetchUpdateInfo() async {
    fetches++;
    if (fetchError != null) throw fetchError!;
    return manifestResult?.future ?? Future.value(info);
  }

  @override
  Future<void> verifyDownloadedPackage(
    File file,
    AppUpdatePackage package,
  ) async {
    verifications++;
    if (onVerify case final verify?) {
      await verify(file, package);
    } else {
      await super.verifyDownloadedPackage(file, package);
    }
  }
}

class FakeAppUpdatePlatform extends AndroidAppUpdatePlatform
    implements AppVersionReader {
  AppVersionInfo version = const AppVersionInfo(
    versionName: '0.9.12',
    buildNumber: 100,
  );
  int androidVersionCode = 100;
  List<String> abis = const ['arm64-v8a'];
  Completer<AppUpdateDownloadResult> downloadResult = Completer();
  Exception? installError;
  final downloadedUrls = <String>[];
  final removedDownloads = <int>[];
  final installationPaths = <String>[];
  void Function(AppUpdateDownloadProgress)? _onProgress;

  @override
  Future<AppVersionInfo> getVersionInfo() async => version;

  @override
  Future<int> getAndroidVersionCode() async => androidVersionCode;

  @override
  Future<List<String>> getSupportedAbis() async => abis;

  @override
  Future<AppUpdateDownloadResult> downloadPackage(
    AppUpdatePackage package, {
    required String versionName,
    void Function(AppUpdateDownloadProgress)? onProgress,
  }) {
    downloadedUrls.add(package.url);
    _onProgress = onProgress;
    return downloadResult.future;
  }

  void reportProgress(int receivedBytes, int totalBytes) {
    _onProgress?.call(
      AppUpdateDownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
      ),
    );
  }

  @override
  Future<void> removeDownload(int downloadId) async {
    removedDownloads.add(downloadId);
  }

  @override
  Future<void> installPackage(String filePath) async {
    installationPaths.add(filePath);
    if (installError != null) throw installError!;
  }
}

class FakeUpdateChannelStore implements UpdateChannelStore {
  FakeUpdateChannelStore([this.code]);

  String? code;

  @override
  Future<String?> readUpdateChannel() async => code;

  @override
  Future<void> saveUpdateChannel(String code) async => this.code = code;
}
