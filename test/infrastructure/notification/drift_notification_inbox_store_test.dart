import 'dart:convert';
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_message.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_registry.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/notification/drift_notification_inbox_store.dart';

import '../../helper/test_app_database.dart';

void main() {
  final now = DateTime(2026, 11, 22, 11);
  final plan = NotificationPlan(
    key: '2026-11-23',
    scheduledAt: DateTime(2026, 11, 22, 10),
    expiresAt: DateTime(2026, 11, 24),
    title: '还款提醒',
    body: '待还账单',
    route: '/calendar/bills/day?date=2026-11-23',
  );

  test(
    'OS opening persists read history even when the metadata row is absent',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftNotificationInboxStore(database);
      final inbox = NotificationInboxService(store: store, clock: () => now);
      await inbox.recordOpened(
        RegisteredNotification(scope: 'repayment', id: 42, plan: plan),
      );
      final recovered = NotificationInboxService(
        store: DriftNotificationInboxStore(database),
        clock: () => now,
      );
      final messages = await recovered.watchVisible().first;
      expect(messages, hasLength(1));
      expect(messages.single.isRead, isTrue);
      expect(messages.single.readAt?.isAtSameMomentAs(now), isTrue);
      expect(messages.single.plan, plan);
    },
  );

  test(
    'reactive queries observe message persistence and tolerate unrelated malformed records',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftNotificationInboxStore(database);
      final message = NotificationMessage(
        scope: 'repayment',
        plan: plan,
        createdAt: now,
      );
      final initial = Completer<void>();
      final changed = Completer<void>();
      final received = <List<NotificationMessage>>[];
      final subscription = store.watch().listen((messages) {
        received.add(messages);
        if (!initial.isCompleted) initial.complete();
        if (messages.isNotEmpty && !changed.isCompleted) changed.complete();
      });
      addTearDown(subscription.cancel);
      await initial.future;
      expect(received.last, isEmpty);
      await store.save([message]);
      await changed.future;
      expect(received.last.single.identity, message.identity);
      await database
          .into(database.appMetadata)
          .insertOnConflictUpdate(
            AppMetadataCompanion.insert(
              key: 'notification.inbox',
              value: jsonEncode({
                'messages': [
                  message.toJson(),
                  {'scope': 'broken'},
                ],
              }),
              updatedAt: Value(now),
            ),
          );
      final decoded = await store.read();
      expect(decoded, hasLength(1));
      expect(decoded.single.identity, message.identity);
    },
  );
}
