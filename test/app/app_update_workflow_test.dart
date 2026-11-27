import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/app.dart';
import 'package:smartflow/app/app_update_providers.dart';
import 'package:smartflow/app/capture_intake_provider.dart';
import 'package:smartflow/app/notification_providers.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/router.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/application/shared/task/app_task.dart';
import 'package:smartflow/application/shared/task/pull_task_scheduler.dart';
import 'package:smartflow/core/logging/app_log_file_sink.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/app_update_info.dart';
import 'package:smartflow/core/update/app_update_platform.dart';

import '../helper/fake_app_update.dart';
import '../helper/fake_notification_delivery.dart';
import '../helper/memory_app_settings_store.dart';
import '../helper/test_app_database.dart';

class _LogSink extends Mock implements AppLogFileSink {}

class _NotificationTask implements AppTask {
  @override
  String get key => 'notification.visibility';

  @override
  TaskRunPolicy get runPolicy => TaskRunPolicy.minInterval(Duration.zero);

  @override
  Future<AppTaskResult> run(DateTime now) async =>
      const AppTaskResult.completed();
}

class _ImageSource implements SharedPaymentImageSource {
  @override
  Stream<SharedPaymentImage> get shares => const Stream.empty();

  @override
  Future<SharedPaymentImage?> takeInitialShare() async => null;
}

void main() {
  late ErrorWidgetBuilder previousErrorBuilder;
  late FakeAppUpdatePlatform platform;
  late FakeAppUpdateService service;

  setUpAll(() => registerFallbackValue(Duration.zero));
  setUp(() {
    previousErrorBuilder = ErrorWidget.builder;
    platform = FakeAppUpdatePlatform();
    service = FakeAppUpdateService(fakeAppUpdateInfo())
      ..onVerify = (file, package) async {};
  });
  tearDown(() => ErrorWidget.builder = previousErrorBuilder);

  Future<ProviderContainer> open(WidgetTester tester) async {
    // Keep completion callbacks in the widget test's asynchronous zone.
    platform.downloadResult = Completer<AppUpdateDownloadResult>();
    final logSink = _LogSink();
    when(
      () => logSink.applyRetention(
        maxFiles: any(named: 'maxFiles'),
        maxFileAge: any(named: 'maxFileAge'),
      ),
    ).thenAnswer((_) async {});
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    appRouter.go('/profile/notifications');
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          testAppDatabaseOverride(),
          appSettingsStoreProvider.overrideWithValue(
            const MemoryAppSettingsStore(),
          ),
          appLogFileSinkProvider.overrideWithValue(logSink),
          sharedPaymentImageSourceProvider.overrideWithValue(_ImageSource()),
          notificationDeliveryProvider.overrideWithValue(
            FakeNotificationDelivery(supported: false),
          ),
          pullTaskSchedulerProvider.overrideWith((ref) {
            final scheduler = PullTaskScheduler(tasks: [_NotificationTask()]);
            ref.onDispose(scheduler.dispose);
            return scheduler;
          }),
          appUpdatesSupportedProvider.overrideWithValue(true),
          appUpdatePlatformProvider.overrideWithValue(platform),
          appVersionReaderProvider.overrideWithValue(platform),
          updateChannelStoreProvider.overrideWithValue(
            FakeUpdateChannelStore(),
          ),
          appUpdateServiceProvider(
            AppUpdateChannel.beta,
          ).overrideWithValue(service),
        ],
        child: const SmartFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SmartFlowApp)),
      listen: false,
    );
  }

  Future<void> withApp(
    WidgetTester tester,
    Future<void> Function(ProviderContainer container) body,
  ) async {
    try {
      final container = await open(tester);
      await body(container);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      ErrorWidget.builder = previousErrorBuilder;
    }
  }

  testWidgets(
    'startup renders before checking and never downloads on decline',
    (tester) async {
      final manifest = Completer<AppUpdateInfo>();
      service.manifestResult = manifest;
      await withApp(tester, (container) async {
        expect(find.text('通知中心'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);

        manifest.complete(fakeAppUpdateInfo());
        await tester.pumpAndSettle();
        expect(find.text('发现新版本 0.9.13'), findsOneWidget);
        expect(platform.downloadedUrls, isEmpty);

        await tester.tap(find.text('稍后'));
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(service.fetches, 1);
        expect(platform.downloadedUrls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'download outlives the page and installs once after foregrounding',
    (tester) async {
      await withApp(tester, (container) async {
        await tester.tap(find.text('立即更新'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(platform.downloadedUrls, hasLength(1));

        appRouter.go('/profile/software-version');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        platform.reportProgress(25, 100);
        await tester.pump();
        expect(find.text('已下载 25%，可以继续使用应用'), findsOneWidget);
        appRouter.go('/profile/notifications');
        await tester.pumpAndSettle();
        expect(find.text('通知中心'), findsOneWidget);

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        final apk = File('test-update.apk');
        platform.downloadResult.complete(
          AppUpdateDownloadResult(downloadId: 42, file: apk),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(appUpdateControllerProvider).downloadStatus,
          AppUpdateDownloadStatus.readyToInstall,
        );
        expect(platform.installationPaths, isEmpty);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(service.verifications, 1);
        expect(platform.installationPaths, [apk.path]);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(platform.installationPaths, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('the version page can manually show the same update prompt', (
    tester,
  ) async {
    service.info = fakeAppUpdateInfo(buildNumber: 100);
    await withApp(tester, (container) async {
      expect(find.byType(AlertDialog), findsNothing);
      appRouter.go('/profile/software-version');
      await tester.pumpAndSettle();

      service.info = fakeAppUpdateInfo();
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(find.text('发现新版本 0.9.13'), findsOneWidget);
      expect(service.fetches, 2);
      expect(platform.downloadedUrls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('startup failure is silent and manual failure shows feedback', (
    tester,
  ) async {
    service.fetchError = const FormatException();
    await withApp(tester, (container) async {
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      appRouter.go('/profile/software-version');
      await tester.pumpAndSettle();

      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(find.text('检查更新失败，请稍后重试'), findsOneWidget);
      expect(platform.downloadedUrls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
