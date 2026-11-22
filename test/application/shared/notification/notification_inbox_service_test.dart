import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_registry.dart';
import 'package:smartflow/application/shared/notification/notification_sync_service.dart';

import '../../../helper/fake_notification_delivery.dart';

NotificationPlan plan({String key = '2026-11-23', int hour = 10}) =>
    NotificationPlan(
      key: key,
      scheduledAt: DateTime(2026, 11, 22, hour),
      expiresAt: DateTime(2026, 11, 24),
      title: '还款提醒',
      body: '2026年11月23日有待还账单，点击查看。',
      route: '/calendar/bills/day?date=$key',
    );

void main() {
  late MemoryNotificationInboxStore store;
  late NotificationInboxService inbox;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 11, 22, 5);
    store = MemoryNotificationInboxStore();
    inbox = NotificationInboxService(store: store, clock: () => now);
  });
  tearDown(() => store.dispose());

  Future<void> sync(
    List<NotificationPlan> plans, {
    String scope = 'repayment',
  }) => inbox.synchronize(scope: scope, plans: plans, now: now);

  test(
    'early messages are stored but become visible only at the planned time',
    () async {
      await sync([plan()]);
      expect(store.messages, hasLength(1));
      expect(await inbox.watchVisible().first, isEmpty);
      expect(await inbox.nextVisibleAt(now), DateTime(2026, 11, 22, 10));
      now = DateTime(2026, 11, 22, 10);
      final messages = await inbox.watchVisible().first;
      expect(messages, hasLength(1));
      expect(messages.single.isRead, isFalse);
      expect(await inbox.nextVisibleAt(now), isNull);
    },
  );

  test(
    'future replanning preserves identity and creation time without duplicating messages',
    () async {
      await sync([plan()]);
      final createdAt = store.messages.single.createdAt;
      now = DateTime(2026, 11, 22, 6);
      await sync([plan(hour: 12)]);
      await sync([plan(hour: 12)]);
      expect(store.messages, hasLength(1));
      expect(store.messages.single.createdAt, createdAt);
      expect(await inbox.nextVisibleAt(now), DateTime(2026, 11, 22, 12));
    },
  );

  test(
    'cancellation removes unpublished messages only within its scope',
    () async {
      await sync([plan()]);
      await sync([plan()], scope: 'other');
      await sync([]);
      expect(store.messages, hasLength(1));
      expect(store.messages.single.scope, 'other');
    },
  );

  test(
    'payment, disablement and expiry preserve published history and read state',
    () async {
      await sync([plan()]);
      now = DateTime(2026, 11, 22, 10);
      await inbox.markRead(store.messages.single.identity);
      await sync([plan(hour: 12)]);
      expect(
        store.messages.single.plan.scheduledAt,
        DateTime(2026, 11, 22, 10),
      );
      now = DateTime(2026, 11, 25);
      await sync([]);
      expect(store.messages, hasLength(1));
      expect(store.messages.single.isRead, isTrue);
    },
  );

  test(
    'read all excludes future messages and early single reads are ignored',
    () async {
      await sync([plan(), plan(key: 'future', hour: 12)]);
      final earlyIdentity = store.messages.last.identity;
      await inbox.markRead(earlyIdentity);
      expect(store.messages.every((message) => !message.isRead), isTrue);
      now = DateTime(2026, 11, 22, 10);
      await inbox.markAllRead();
      expect(store.messages.first.isRead, isTrue);
      expect(store.messages.last.isRead, isFalse);
    },
  );

  test(
    'concurrent discovery and reading retain both new messages and read state',
    () async {
      await sync([plan()]);
      now = DateTime(2026, 11, 22, 10);
      final identity = store.messages.single.identity;
      await Future.wait([
        sync([plan(), plan(key: 'future', hour: 12)]),
        inbox.markRead(identity),
      ]);
      expect(store.messages, hasLength(2));
      expect(
        store.messages
            .firstWhere((message) => message.identity == identity)
            .isRead,
        isTrue,
      );
    },
  );

  for (final supported in [true, false]) {
    test(
      'local messages survive unavailable system delivery (supported=$supported)',
      () async {
        final delivery = FakeNotificationDelivery(
          supported: supported,
          permissionGranted: false,
        );
        final service = NotificationSyncService(
          delivery: delivery,
          registry: MemoryNotificationRegistry(),
          inbox: inbox,
        );
        await service.synchronize(
          scope: 'repayment',
          plans: [plan()],
          now: now,
        );
        expect(store.messages, hasLength(1));
        expect(delivery.scheduled, isEmpty);
        now = DateTime(2026, 11, 22, 10);
        expect((await inbox.watchVisible().first).single.isRead, isFalse);
      },
    );
  }

  test(
    'an OS tap can restore and read a message that predates the inbox',
    () async {
      now = DateTime(2026, 11, 22, 11);
      final registration = RegisteredNotification(
        scope: 'repayment',
        id: 42,
        plan: plan(),
      );
      await inbox.recordOpened(registration);
      await inbox.recordOpened(registration);
      expect(store.messages, hasLength(1));
      expect(store.messages.single.isRead, isTrue);
      expect(store.messages.single.identity, registration.identity);
    },
  );
}
