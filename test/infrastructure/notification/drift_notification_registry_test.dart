import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_sync_service.dart';
import 'package:smartflow/infrastructure/notification/drift_notification_registry.dart';
import 'package:smartflow/infrastructure/notification/drift_notification_inbox_store.dart';

import '../../helper/fake_notification_delivery.dart';
import '../../helper/test_app_database.dart';

void main() {
  test(
    'a failed system attempt stays consumed and preserves readable inbox history',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final now = DateTime(2026, 11, 13, 23);
      final plan = NotificationPlan(
        key: '2026-11-14',
        scheduledAt: DateTime(2026, 11, 13, 22),
        expiresAt: DateTime(2026, 11, 15),
        title: '还款提醒',
        body: '待还提醒',
        route: '/calendar/bills/day?date=2026-11-14',
      );
      final delivery = FakeNotificationDelivery()..failingKey = plan.key;
      final inbox = NotificationInboxService(
        store: DriftNotificationInboxStore(database),
        clock: () => now,
      );
      await expectLater(
        NotificationSyncService(
          delivery: delivery,
          registry: DriftNotificationRegistry(database),
          inbox: inbox,
        ).synchronize(scope: 'repayment', plans: [plan], now: now),
        throwsException,
      );
      final message = (await inbox.watchVisible().first).single;
      await inbox.markRead(message.identity);
      expect(
        (await DriftNotificationRegistry(database).read()).entries.single.plan,
        plan,
      );

      final restartedDelivery = FakeNotificationDelivery();
      final restartedInbox = NotificationInboxService(
        store: DriftNotificationInboxStore(database),
        clock: () => now,
      );
      await NotificationSyncService(
        delivery: restartedDelivery,
        registry: DriftNotificationRegistry(database),
        inbox: restartedInbox,
      ).synchronize(scope: 'repayment', plans: [plan], now: now);
      expect(restartedDelivery.shown, isEmpty);
      expect((await restartedInbox.watchVisible().first).single.isRead, isTrue);
    },
  );

  test(
    'a new service recovers registration history without repeating a catch-up notice',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final delivery = FakeNotificationDelivery();
      final plan = NotificationPlan(
        key: '2026-11-14',
        scheduledAt: DateTime(2026, 11, 13, 22),
        expiresAt: DateTime(2026, 11, 15),
        title: '还款提醒',
        body: '待还提醒',
        route: '/calendar/bills/day?date=2026-11-14',
      );
      await NotificationSyncService(
        delivery: delivery,
        registry: DriftNotificationRegistry(database),
        inbox: createMemoryNotificationInbox(),
      ).synchronize(
        scope: 'credit.repayment_reminder',
        plans: [plan],
        now: DateTime(2026, 11, 13, 23),
      );
      expect(delivery.shown, hasLength(1));
      final recovered = await DriftNotificationRegistry(database).read();
      expect(recovered.entries.single.plan, plan);
      await NotificationSyncService(
        delivery: delivery,
        registry: DriftNotificationRegistry(database),
        inbox: createMemoryNotificationInbox(),
      ).synchronize(
        scope: 'credit.repayment_reminder',
        plans: [plan],
        now: DateTime(2026, 11, 14, 9),
      );
      expect(delivery.shown, hasLength(1));
      final backupPreferences = await (database.select(
        database.appMetadata,
      )..where((row) => row.key.like('settings.%'))).get();
      expect(backupPreferences, isEmpty);
    },
  );
}
