import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/notification_providers.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/repayment_reminder/command/repayment_reminder_app_service.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_visibility_task.dart';
import 'package:smartflow/application/shared/task/pull_task_scheduler.dart';
import 'package:smartflow/feature/shared/view_model/app_settings_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

import '../../../helper/fake_notification_delivery.dart';

class _Reminders extends Mock implements RepaymentReminderAppService {}

class _Settings implements AppSettingsStore {
  AppSettings value = const AppSettings();
  @override
  Future<AppSettings> read() async => value;
  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

void main() {
  test(
    'changing reminder time synchronizes immediately and hands the new hint to the scheduler',
    () async {
      final now = DateTime(2026, 11, 22, 5);
      final store = MemoryNotificationInboxStore();
      addTearDown(store.dispose);
      final inbox = NotificationInboxService(store: store, clock: () => now);
      NotificationPlan plan(int hour) => NotificationPlan(
        key: '2026-11-23',
        scheduledAt: DateTime(2026, 11, 22, hour),
        expiresAt: DateTime(2026, 11, 24),
        title: '还款提醒',
        body: '待还账单',
        route: '/calendar/bills/day?date=2026-11-23',
      );
      await inbox.synchronize(scope: 'repayment', plans: [plan(12)], now: now);
      final settings = _Settings();
      final reminders = _Reminders();
      when(() => reminders.synchronize(any())).thenAnswer((_) async {
        await inbox.synchronize(
          scope: 'repayment',
          plans: [plan(10)],
          now: now,
        );
      });
      final scheduler = PullTaskScheduler(
        tasks: [NotificationVisibilityTask(inbox: inbox)],
        clock: () => now,
      );
      addTearDown(scheduler.dispose);
      await scheduler.trigger();
      expect(scheduler.nextExpectedCheckAt(), DateTime(2026, 11, 22, 12));
      final container = ProviderContainer.test(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(settings),
          repaymentReminderAppServiceProvider.overrideWithValue(reminders),
          notificationInboxServiceProvider.overrideWithValue(inbox),
          pullTaskSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      await container.read(appSettingsViewModelProvider.future);
      final outcome = await container
          .read(appSettingsViewModelProvider.notifier)
          .setRepaymentReminderTime(
            const NotificationTime(hour: 10, minute: 0),
          );
      expect(outcome, isA<UiActionSuccess<void>>());
      verify(() => reminders.synchronize(any())).called(1);
      expect(
        settings.value.repaymentReminderTime,
        const NotificationTime(hour: 10, minute: 0),
      );
      expect(scheduler.nextExpectedCheckAt(), DateTime(2026, 11, 22, 10));
    },
  );
}
