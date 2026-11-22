import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/app.dart';
import 'package:smartflow/app/capture_intake_provider.dart';
import 'package:smartflow/app/notification_providers.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/router.dart';
import 'package:smartflow/application/intake/intake_recognition_api.dart';
import 'package:smartflow/application/shared/task/app_task.dart';
import 'package:smartflow/application/shared/task/pull_task_scheduler.dart';
import 'package:smartflow/core/logging/app_log_file_sink.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';

import '../helper/fake_notification_delivery.dart';
import '../helper/memory_app_settings_store.dart';
import '../helper/test_app_database.dart';

class _Task implements AppTask {
  int runs = 0;

  @override
  String get key => 'notification.visibility';

  @override
  TaskRunPolicy get runPolicy => TaskRunPolicy.minInterval(Duration.zero);

  @override
  Future<AppTaskResult> run(DateTime now) async {
    runs++;
    return const AppTaskResult.completed();
  }
}

class _LogSink extends Mock implements AppLogFileSink {}

class _ImageSource implements SharedPaymentImageSource {
  @override
  Stream<SharedPaymentImage> get shares => const Stream.empty();

  @override
  Future<SharedPaymentImage?> takeInitialShare() async => null;
}

void main() {
  late bool previousDatabaseWarning;
  late ErrorWidgetBuilder previousErrorBuilder;
  setUp(() {
    previousDatabaseWarning =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    // Refreshes use distinct in-memory executors, so their overlap shares no data.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    previousErrorBuilder = ErrorWidget.builder;
  });
  tearDown(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        previousDatabaseWarning;
    ErrorWidget.builder = previousErrorBuilder;
  });
  setUpAll(() => registerFallbackValue(Duration.zero));

  Future<ProviderContainer> open(WidgetTester tester, _Task task) async {
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
            // Keep the production ownership: a database replacement also
            // replaces the tasks' scheduler.
            ref.watch(appDatabaseProvider);
            final scheduler = PullTaskScheduler(tasks: [task]);
            ref.onDispose(scheduler.dispose);
            return scheduler;
          }),
        ],
        child: const SmartFlowApp(),
      ),
    );
    final appState = tester.state(find.byType(SmartFlowApp));
    addTearDown(() async {
      // Also isolate the binding when exercising a failing dispose regression.
      tester.binding.removeObserver(appState as WidgetsBindingObserver);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SmartFlowApp)),
      listen: false,
    );
  }

  testWidgets('restoring data keeps foreground task execution active', (
    tester,
  ) async {
    final task = _Task();
    final container = await open(tester, task);
    expect(task.runs, 1);
    final original = container.read(foregroundTaskRunnerProvider);

    container.read(appDataRefreshProvider).refresh();
    await tester.pumpAndSettle();

    expect(container.read(foregroundTaskRunnerProvider), isNot(same(original)));
    expect(task.runs, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    ErrorWidget.builder = previousErrorBuilder;
    expect(tester.takeException(), isNull);
  });

  testWidgets('a replacement waits while backgrounded and starts on resume', (
    tester,
  ) async {
    final task = _Task();
    final container = await open(tester, task);
    expect(task.runs, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    container.read(appDataRefreshProvider).refresh();
    await tester.pumpAndSettle();
    expect(task.runs, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(task.runs, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    ErrorWidget.builder = previousErrorBuilder;
    expect(tester.takeException(), isNull);
  });
}
