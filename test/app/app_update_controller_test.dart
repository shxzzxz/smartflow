import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/app_update_providers.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/app_update_info.dart';
import 'package:smartflow/core/update/app_update_platform.dart';
import 'package:smartflow/core/update/app_version_info.dart';

import '../helper/fake_app_update.dart';

void main() {
  late ProviderContainer container;
  late AppUpdateController controller;
  late FakeAppUpdatePlatform platform;
  late FakeUpdateChannelStore store;
  late Map<AppUpdateChannel, FakeAppUpdateService> services;
  late Directory directory;
  late File apk;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('smartflow-app-update-');
    apk = File('${directory.path}${Platform.pathSeparator}update.apk');
    await apk.writeAsBytes([1, 2, 3, 4]);
    platform = FakeAppUpdatePlatform();
    store = FakeUpdateChannelStore();
    services = {
      for (final channel in AppUpdateChannel.values)
        channel: FakeAppUpdateService(fakeAppUpdateInfo(channel: channel)),
    };
    container = ProviderContainer(
      overrides: [
        appUpdatesSupportedProvider.overrideWithValue(true),
        appUpdatePlatformProvider.overrideWithValue(platform),
        appVersionReaderProvider.overrideWithValue(platform),
        updateChannelStoreProvider.overrideWithValue(store),
        for (final entry in services.entries)
          appUpdateServiceProvider(entry.key).overrideWithValue(entry.value),
      ],
    );
    controller = container.read(appUpdateControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await apk.delete();
    await directory.delete();
  });

  test('startup checks the saved channel once and waits for consent', () async {
    store.code = 'dev';
    await controller.checkAtStartup();
    final state = container.read(appUpdateControllerProvider);

    expect(state.channel, AppUpdateChannel.dev);
    expect(state.pendingUpdate?.versionName, '0.9.13');
    expect(services[AppUpdateChannel.dev]!.fetches, 1);
    expect(services[AppUpdateChannel.beta]!.fetches, 0);
    expect(platform.downloadedUrls, isEmpty);

    controller.takeUpdatePrompt();
    await controller.checkAtStartup();
    expect(services[AppUpdateChannel.dev]!.fetches, 1);
    expect(container.read(appUpdateControllerProvider).pendingUpdate, isNull);
  });

  for (final startup in [true, false]) {
    test(
      '${startup ? 'startup' : 'manual'} check ignores the same release of a universal or debug APK',
      () async {
        store.code = 'dev';
        platform.version = const AppVersionInfo(
          versionName: '0.9.13-dev.2',
          buildNumber: 89,
        );
        platform.androidVersionCode = 89;
        platform.abis = const ['x86_64', 'arm64-v8a'];
        services[AppUpdateChannel.dev]!.info = AppUpdateInfo.fromJson({
          'channel': 'dev',
          'versionName': '0.9.13-dev.2',
          'buildNumber': 89,
          'universalApk': {
            'url': 'https://example.com/universal.apk',
            'androidVersionCode': 89,
          },
          'apks': [
            {
              'abi': 'arm64-v8a',
              'url': 'https://example.com/arm64.apk',
              'androidVersionCode': 2089,
            },
            {
              'abi': 'x86_64',
              'url': 'https://example.com/x86_64.apk',
              'androidVersionCode': 4089,
            },
          ],
        });

        if (startup) {
          await controller.checkAtStartup();
        } else {
          await controller.checkForUpdate();
        }
        final state = container.read(appUpdateControllerProvider);

        expect(state.pendingUpdate, isNull);
        expect(state.hasCheckedLatest, isTrue);
        expect(state.message, startup ? null : '当前已是最新版本');
        expect(services[AppUpdateChannel.dev]!.fetches, 1);
        expect(platform.downloadedUrls, isEmpty);
      },
    );
  }

  test('unreadable installation metadata can be retried', () async {
    platform.androidVersionCode = 0;
    await controller.checkAtStartup();
    expect(container.read(appUpdateControllerProvider).pendingUpdate, isNull);
    expect(
      container.read(appUpdateControllerProvider).hasCheckedLatest,
      isFalse,
    );
    expect(container.read(appUpdateControllerProvider).message, isNull);

    await controller.checkForUpdate();
    expect(controller.takeMessage(), '检查更新失败，请稍后重试');

    platform.androidVersionCode = 100;
    await controller.checkForUpdate();
    expect(
      container.read(appUpdateControllerProvider).pendingUpdate,
      isNotNull,
    );
    expect(services[AppUpdateChannel.beta]!.fetches, 3);
  });

  test(
    'a new release without a usable package is not reported as latest',
    () async {
      platform.abis = const ['x86_64'];

      await controller.checkForUpdate();
      final state = container.read(appUpdateControllerProvider);

      expect(state.pendingUpdate, isNull);
      expect(state.hasCheckedLatest, isFalse);
      expect(controller.takeMessage(), '发现新版本，但当前设备暂无可用安装包');
    },
  );

  test('an unsupported updater skips requests at both entry points', () async {
    final otherContainer = ProviderContainer(
      overrides: [
        appUpdatePlatformProvider.overrideWithValue(
          const AppUpdatePlatform.unsupported(),
        ),
        appVersionReaderProvider.overrideWithValue(platform),
        updateChannelStoreProvider.overrideWithValue(store),
        appUpdateServiceProvider(
          AppUpdateChannel.beta,
        ).overrideWithValue(services[AppUpdateChannel.beta]!),
      ],
    );
    addTearDown(otherContainer.dispose);
    final otherController = otherContainer.read(
      appUpdateControllerProvider.notifier,
    );

    await otherController.checkAtStartup();
    await otherController.checkForUpdate();

    expect(services[AppUpdateChannel.beta]!.fetches, 0);
    expect(otherController.takeMessage(), '当前平台暂不支持应用内更新');
  });

  test(
    'startup remains quiet when current, while manual checking reports it',
    () async {
      services[AppUpdateChannel.beta]!.info = fakeAppUpdateInfo(
        buildNumber: 100,
      );
      await controller.checkAtStartup();
      expect(
        container.read(appUpdateControllerProvider).hasCheckedLatest,
        isTrue,
      );
      expect(container.read(appUpdateControllerProvider).message, isNull);

      await controller.checkForUpdate();
      expect(controller.takeMessage(), '当前已是最新版本');
      expect(platform.downloadedUrls, isEmpty);
    },
  );

  test(
    'startup failures are quiet and a manual retry reports failure',
    () async {
      services[AppUpdateChannel.beta]!.fetchError = const FormatException();
      await controller.checkAtStartup();
      expect(container.read(appUpdateControllerProvider).message, isNull);
      expect(container.read(appUpdateControllerProvider).isChecking, isFalse);

      await controller.checkForUpdate();
      expect(controller.takeMessage(), '检查更新失败，请稍后重试');
      expect(container.read(appUpdateControllerProvider).isChecking, isFalse);
    },
  );

  test(
    'overlapping startup and manual checks do not issue two requests',
    () async {
      final result = Completer<AppUpdateInfo>();
      services[AppUpdateChannel.beta]!.manifestResult = result;
      final startup = controller.checkAtStartup();
      await Future<void>.delayed(Duration.zero);
      await controller.checkForUpdate();
      expect(services[AppUpdateChannel.beta]!.fetches, 1);

      result.complete(fakeAppUpdateInfo());
      await startup;
      expect(
        container.read(appUpdateControllerProvider).pendingUpdate,
        isNotNull,
      );
      expect(platform.downloadedUrls, isEmpty);
    },
  );

  test(
    'accepted download reports progress and verifies before installation',
    () async {
      await controller.checkAtStartup();
      final update = controller.takeUpdatePrompt()!;
      final work = controller.downloadUpdate(update);
      await controller.downloadUpdate(update);
      platform.reportProgress(25, 100);
      expect(platform.downloadedUrls, hasLength(1));
      expect(
        container.read(appUpdateControllerProvider).downloadProgress?.fraction,
        0.25,
      );
      expect(platform.installationPaths, isEmpty);

      platform.downloadResult.complete(
        AppUpdateDownloadResult(downloadId: 42, file: apk),
      );
      await work;
      expect(services[AppUpdateChannel.beta]!.verifications, 1);
      expect(
        container.read(appUpdateControllerProvider).downloadStatus,
        AppUpdateDownloadStatus.readyToInstall,
      );
      expect(platform.installationPaths, isEmpty);

      await controller.installDownloadedUpdate();
      expect(platform.installationPaths, [apk.path]);
      expect(
        container.read(appUpdateControllerProvider).downloadStatus,
        AppUpdateDownloadStatus.downloaded,
      );
    },
  );

  test('a corrupt APK is removed and never offered for installation', () async {
    await apk.writeAsBytes([4, 3, 2, 1]);
    await controller.checkAtStartup();
    final work = controller.downloadUpdate(controller.takeUpdatePrompt()!);
    platform.downloadResult.complete(
      AppUpdateDownloadResult(downloadId: 42, file: apk),
    );
    await work;
    await controller.installDownloadedUpdate();

    expect(platform.removedDownloads, [42]);
    expect(platform.installationPaths, isEmpty);
    expect(container.read(appUpdateControllerProvider).canInstall, isFalse);
    expect(controller.takeMessage(), '下载失败，请稍后重试');
  });

  test(
    'installation failure can retry the verified file without downloading',
    () async {
      await controller.checkAtStartup();
      final work = controller.downloadUpdate(controller.takeUpdatePrompt()!);
      platform.downloadResult.complete(
        AppUpdateDownloadResult(downloadId: 42, file: apk),
      );
      await work;
      platform.installError = PlatformException(code: 'installFailed');
      await controller.installDownloadedUpdate();
      expect(controller.takeMessage(), '安装失败，请稍后重试');
      expect(container.read(appUpdateControllerProvider).canInstall, isTrue);

      platform.installError = null;
      await controller.installDownloadedUpdate();
      expect(platform.installationPaths, [apk.path, apk.path]);
      expect(platform.downloadedUrls, hasLength(1));
    },
  );

  test(
    'changing channel persists it and clears the previous update prompt',
    () async {
      await controller.checkAtStartup();
      await controller.setChannel(AppUpdateChannel.stable);
      expect(store.code, 'stable');
      expect(container.read(appUpdateControllerProvider).pendingUpdate, isNull);

      await controller.checkForUpdate();
      expect(services[AppUpdateChannel.stable]!.fetches, 1);
      expect(
        container.read(appUpdateControllerProvider).pendingUpdate?.channel,
        AppUpdateChannel.stable,
      );
    },
  );
}
