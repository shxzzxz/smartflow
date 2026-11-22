import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_sync_service.dart';
import 'package:smartflow/infrastructure/notification/drift_notification_registry.dart';

import '../../helper/fake_notification_delivery.dart';
import '../../helper/test_app_database.dart';

void main() {
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
