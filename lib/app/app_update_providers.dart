import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../core/update/android/android_app_update_platform.dart';
import '../core/update/app_update_channel.dart';
import '../core/update/app_update_info.dart';
import '../core/update/app_update_platform.dart';
import '../core/update/app_update_service.dart';
import '../core/update/app_version_info.dart';
import '../core/update/app_version_reader.dart';
import 'provider.dart';

final appUpdatesSupportedProvider = Provider<bool>(
  (ref) => ref.watch(appUpdatePlatformProvider).supported,
);

final appUpdatePlatformProvider = Provider<AppUpdatePlatform>(
  (ref) => Platform.isAndroid
      ? const AndroidAppUpdatePlatform()
      : const AppUpdatePlatform.unsupported(),
);

final appVersionReaderProvider = Provider<AppVersionReader>(
  (ref) => const AppVersionReader(),
);

final appUpdateServiceProvider =
    Provider.family<AppUpdateService, AppUpdateChannel>((ref, channel) {
      const override = String.fromEnvironment('SMARTFLOW_UPDATE_URL');
      const baseUrl = String.fromEnvironment(
        'SMARTFLOW_UPDATE_BASE_URL',
        defaultValue: AppUpdateService.defaultManifestBaseUrl,
      );
      return AppUpdateService(
        manifestUri: override.trim().isNotEmpty
            ? Uri.parse(override.trim())
            : AppUpdateService.manifestUriForChannel(channel, baseUrl: baseUrl),
        expectedChannel: channel,
      );
    });

final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateState>(
      AppUpdateController.new,
    );

enum AppUpdateDownloadStatus {
  idle,
  downloading,
  readyToInstall,
  installing,
  downloaded,
}

class AppUpdateState {
  const AppUpdateState({
    this.versionInfo,
    required this.channel,
    this.isInitialized = false,
    this.isChecking = false,
    this.isSavingChannel = false,
    this.hasCheckedLatest = false,
    this.pendingUpdate,
    this.downloadStatus = AppUpdateDownloadStatus.idle,
    this.downloadProgress,
    this.message,
  });

  final AppVersionInfo? versionInfo;
  final AppUpdateChannel channel;
  final bool isInitialized;
  final bool isChecking;
  final bool isSavingChannel;
  final bool hasCheckedLatest;
  final AppUpdateInfo? pendingUpdate;
  final AppUpdateDownloadStatus downloadStatus;
  final AppUpdateDownloadProgress? downloadProgress;
  final String? message;

  bool get isBusy =>
      isChecking ||
      isSavingChannel ||
      downloadStatus == AppUpdateDownloadStatus.downloading ||
      downloadStatus == AppUpdateDownloadStatus.installing;

  bool get canInstall =>
      downloadStatus == AppUpdateDownloadStatus.readyToInstall ||
      downloadStatus == AppUpdateDownloadStatus.downloaded;

  AppUpdateState copyWith({
    AppVersionInfo? versionInfo,
    AppUpdateChannel? channel,
    bool? isInitialized,
    bool? isChecking,
    bool? isSavingChannel,
    bool? hasCheckedLatest,
    AppUpdateInfo? pendingUpdate,
    bool clearPendingUpdate = false,
    AppUpdateDownloadStatus? downloadStatus,
    AppUpdateDownloadProgress? downloadProgress,
    bool clearProgress = false,
    String? message,
    bool clearMessage = false,
  }) {
    return AppUpdateState(
      versionInfo: versionInfo ?? this.versionInfo,
      channel: channel ?? this.channel,
      isInitialized: isInitialized ?? this.isInitialized,
      isChecking: isChecking ?? this.isChecking,
      isSavingChannel: isSavingChannel ?? this.isSavingChannel,
      hasCheckedLatest: hasCheckedLatest ?? this.hasCheckedLatest,
      pendingUpdate: clearPendingUpdate
          ? null
          : pendingUpdate ?? this.pendingUpdate,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: clearProgress
          ? null
          : downloadProgress ?? this.downloadProgress,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// Owns the update workflow for the entire app, including after a page closes.
class AppUpdateController extends Notifier<AppUpdateState> {
  static final _logger = Logger('app.update');
  Future<void>? _initialization;
  bool _startupChecked = false;
  AppUpdateInfo? _preparedUpdate;
  AppUpdatePackage? _preparedPackage;
  File? _downloadedPackage;

  @override
  AppUpdateState build() {
    return AppUpdateState(
      channel: AppUpdateChannel.fromCode(
        const String.fromEnvironment(
          'SMARTFLOW_UPDATE_CHANNEL',
          defaultValue: 'beta',
        ),
      ),
    );
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await Future.wait([_loadVersionInfo(), _loadChannel()]);
    if (ref.mounted) {
      state = state.copyWith(isInitialized: true);
    }
  }

  Future<void> _loadVersionInfo() async {
    try {
      final version = await ref.read(appVersionReaderProvider).getVersionInfo();
      if (ref.mounted) state = state.copyWith(versionInfo: version);
    } on Exception catch (error, stackTrace) {
      _logger.warning('Cannot read app version.', error, stackTrace);
      if (ref.mounted) {
        state = state.copyWith(
          versionInfo: const AppVersionInfo(
            versionName: '未知版本',
            buildNumber: 0,
          ),
        );
      }
    }
  }

  Future<void> _loadChannel() async {
    try {
      final code = await ref
          .read(updateChannelStoreProvider)
          .readUpdateChannel();
      if (ref.mounted && code != null) {
        state = state.copyWith(channel: AppUpdateChannel.fromCode(code));
      }
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'Cannot read update channel; using the build default.',
        error,
        stackTrace,
      );
    }
  }

  Future<void> checkAtStartup() async {
    if (_startupChecked || !ref.read(appUpdatesSupportedProvider)) return;
    _startupChecked = true;
    await checkForUpdate(silent: true);
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    if (state.isBusy || state.canInstall) return;
    if (!ref.read(appUpdatesSupportedProvider)) {
      if (!silent) {
        state = state.copyWith(message: '当前平台暂不支持应用内更新');
      }
      return;
    }
    final wasInitialized = state.isInitialized;
    _preparedUpdate = null;
    _preparedPackage = null;
    state = state.copyWith(
      isChecking: true,
      hasCheckedLatest: false,
      clearPendingUpdate: true,
      clearMessage: true,
    );
    try {
      await initialize();
      if (!ref.mounted) return;
      if (wasInitialized && (state.versionInfo?.buildNumber ?? 0) <= 0) {
        await _loadVersionInfo();
        if (!ref.mounted) return;
      }
      final version = state.versionInfo;
      if (version == null || version.buildNumber <= 0) {
        if (!silent) {
          state = state.copyWith(message: '暂时无法读取当前版本');
        }
        return;
      }

      final service = ref.read(appUpdateServiceProvider(state.channel));
      final update = await service.checkForUpdate(
        currentBuildNumber: version.buildNumber,
      );
      if (!ref.mounted) return;
      if (update == null) {
        state = state.copyWith(
          hasCheckedLatest: true,
          clearPendingUpdate: true,
          message: silent ? null : '当前已是最新版本',
        );
        return;
      }

      final package = await ref
          .read(appUpdatePlatformProvider)
          .prepareUpdate(update);
      if (!ref.mounted) return;
      if (package == null) {
        state = state.copyWith(
          clearPendingUpdate: true,
          message: silent ? null : '发现新版本，但当前设备暂无可用安装包',
        );
        return;
      }
      _preparedUpdate = update;
      _preparedPackage = package;
      state = state.copyWith(pendingUpdate: update);
    } on Exception catch (error, stackTrace) {
      _logger.log(
        silent ? Level.WARNING : Level.SEVERE,
        'Update check failed.',
        error,
        stackTrace,
      );
      if (ref.mounted && !silent) {
        state = state.copyWith(message: '检查更新失败，请稍后重试');
      }
    } finally {
      if (ref.mounted) state = state.copyWith(isChecking: false);
    }
  }

  Future<void> setChannel(AppUpdateChannel channel) async {
    if (!state.isInitialized || state.isBusy || channel == state.channel) {
      return;
    }
    state = state.copyWith(isSavingChannel: true, clearMessage: true);
    try {
      await ref
          .read(updateChannelStoreProvider)
          .saveUpdateChannel(channel.code);
      if (!ref.mounted) return;
      _downloadedPackage = null;
      _preparedUpdate = null;
      _preparedPackage = null;
      state = state.copyWith(
        channel: channel,
        hasCheckedLatest: false,
        clearPendingUpdate: true,
        downloadStatus: AppUpdateDownloadStatus.idle,
        clearProgress: true,
      );
    } on Exception catch (error, stackTrace) {
      _logger.severe('Cannot save update channel.', error, stackTrace);
      if (ref.mounted) {
        state = state.copyWith(message: '保存更新渠道失败，请稍后重试');
      }
    } finally {
      if (ref.mounted) state = state.copyWith(isSavingChannel: false);
    }
  }

  AppUpdateInfo? takeUpdatePrompt() {
    final update = state.pendingUpdate;
    if (update != null) state = state.copyWith(clearPendingUpdate: true);
    return update;
  }

  String? takeMessage() {
    final message = state.message;
    if (message != null) state = state.copyWith(clearMessage: true);
    return message;
  }

  Future<void> downloadUpdate(AppUpdateInfo update) async {
    if (state.isBusy || state.canInstall || update.channel != state.channel) {
      return;
    }
    final package = _preparedPackage;
    if (!identical(_preparedUpdate, update) || package == null) {
      state = state.copyWith(message: '当前设备暂无可用安装包');
      return;
    }
    final platform = ref.read(appUpdatePlatformProvider);
    final service = ref.read(appUpdateServiceProvider(update.channel));
    state = state.copyWith(
      downloadStatus: AppUpdateDownloadStatus.downloading,
      downloadProgress: const AppUpdateDownloadProgress(
        receivedBytes: 0,
        totalBytes: null,
      ),
      message: '已开始后台下载，可以继续使用应用',
    );
    try {
      final download = await platform.downloadPackage(
        package,
        versionName: update.versionName,
        onProgress: (progress) {
          if (ref.mounted) state = state.copyWith(downloadProgress: progress);
        },
      );
      try {
        await service.verifyDownloadedPackage(download.file, package);
      } on Exception {
        try {
          await platform.removeDownload(download.downloadId);
        } on Exception catch (error, stackTrace) {
          _logger.warning('Cannot discard invalid package.', error, stackTrace);
        }
        rethrow;
      }
      if (!ref.mounted) return;
      _downloadedPackage = download.file;
      state = state.copyWith(
        downloadStatus: AppUpdateDownloadStatus.readyToInstall,
        clearProgress: true,
      );
    } on Exception catch (error, stackTrace) {
      _logger.log(
        error is FormatException ? Level.WARNING : Level.SEVERE,
        'Package download or verification failed.',
        error,
        stackTrace,
      );
      if (ref.mounted) {
        state = state.copyWith(
          downloadStatus: AppUpdateDownloadStatus.idle,
          clearProgress: true,
          message: '下载失败，请稍后重试',
        );
      }
    }
  }

  Future<void> installDownloadedUpdate() async {
    final file = _downloadedPackage;
    if (file == null || !state.canInstall || state.isBusy) return;
    state = state.copyWith(
      downloadStatus: AppUpdateDownloadStatus.installing,
      clearMessage: true,
    );
    try {
      await ref.read(appUpdatePlatformProvider).installPackage(file.path);
    } on Exception catch (error, stackTrace) {
      _logger.severe('Cannot launch package installation.', error, stackTrace);
      if (ref.mounted) {
        state = state.copyWith(message: '安装失败，请稍后重试');
      }
    } finally {
      if (ref.mounted) {
        // Returning from the installer must not open it again automatically.
        state = state.copyWith(
          downloadStatus: AppUpdateDownloadStatus.downloaded,
        );
      }
    }
  }
}
