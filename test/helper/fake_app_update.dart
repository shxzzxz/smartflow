import 'dart:async';
import 'dart:io';

import 'package:smartflow/application/shared/update_channel_store.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/app_update_info.dart';
import 'package:smartflow/core/update/app_update_platform.dart';
import 'package:smartflow/core/update/app_update_service.dart';

AppUpdateInfo fakeAppUpdateInfo({
  AppUpdateChannel channel = AppUpdateChannel.beta,
  int versionCode = 101,
}) => AppUpdateInfo(
  channel: channel,
  versionName: '0.9.13',
  buildNumber: 101,
  universalApk: AppUpdateUniversalApk(
    url: 'https://example.com/universal.apk',
    androidVersionCode: versionCode,
  ),
  releaseUrl: 'https://example.com/release',
  required: false,
  notes: '修复已知问题',
  packages: [
    AppUpdatePackage(
      abi: 'arm64-v8a',
      url: 'https://example.com/update.apk',
      androidVersionCode: versionCode,
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
  Future<void> verifyDownloadedApk(File file, AppUpdatePackage package) async {
    verifications++;
    if (onVerify case final verify?) {
      await verify(file, package);
    } else {
      await super.verifyDownloadedApk(file, package);
    }
  }
}

class FakeAppUpdatePlatform extends AppUpdatePlatform {
  AppVersionInfo version = const AppVersionInfo(
    versionName: '0.9.12',
    buildNumber: 100,
  );
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
  Future<List<String>> getSupportedAbis() async => abis;

  @override
  Future<AppUpdateDownloadResult> downloadApk(
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
  Future<void> removeApkDownload(int downloadId) async {
    removedDownloads.add(downloadId);
  }

  @override
  Future<void> installApk(String filePath) async {
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
