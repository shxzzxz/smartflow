import 'dart:async';

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
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';

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
  setUpAll(() => registerFallbackValue(Duration.zero));

  testWidgets('selection menu follows system language changes', (tester) async {
    final previousErrorBuilder = ErrorWidget.builder;
    final controller = TextEditingController(text: 'SmartFlow sample text');
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final logSink = _LogSink();
    when(
      () => logSink.applyRetention(
        maxFiles: any(named: 'maxFiles'),
        maxFileAge: any(named: 'maxFileAge'),
      ),
    ).thenAnswer((_) async {});

    try {
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
          ],
          child: const SmartFlowApp(),
        ),
      );
      await tester.pumpAndSettle();

      const scenarios = [
        (
          preferred: [Locale('zh', 'CN')],
          resolved: Locale('zh', 'CN'),
          copyLabel: '复制',
        ),
        (
          preferred: [Locale('en', 'GB')],
          resolved: Locale('en', 'GB'),
          copyLabel: 'Copy',
        ),
        (
          preferred: [
            Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hant',
              countryCode: 'TW',
            ),
          ],
          resolved: Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
          copyLabel: '複製',
        ),
        (
          preferred: [Locale('xx', 'ZZ'), Locale('ja', 'JP')],
          resolved: Locale('ja', 'JP'),
          copyLabel: 'コピー',
        ),
        (
          preferred: [Locale('ps', 'AF')],
          resolved: Locale('zh', 'CN'),
          copyLabel: '复制',
        ),
        (preferred: <Locale>[], resolved: Locale('zh', 'CN'), copyLabel: '复制'),
      ];
      for (final scenario in scenarios) {
        tester.platformDispatcher.localesTestValue = scenario.preferred;
        await tester.pumpAndSettle();
        unawaited(
          showDialog<void>(
            context: tester.element(find.byType(Scaffold).first),
            builder: (context) => AlertDialog(
              content: AppPlainTextFormRow(label: '备注', controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(TextField));
        await tester.pumpAndSettle();

        final fieldContext = tester.element(find.byType(TextField));
        expect(Localizations.localeOf(fieldContext), scenario.resolved);
        expect(find.text(scenario.copyLabel), findsOneWidget);
        Navigator.of(fieldContext).pop();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
      ErrorWidget.builder = previousErrorBuilder;
    }
  });
}
