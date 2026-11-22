import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_registry.dart';
import 'package:smartflow/application/shared/notification/notification_sync_service.dart';

import '../../../helper/fake_notification_delivery.dart';

void main() {
  late FakeNotificationDelivery delivery;
  late MemoryNotificationRegistry registry;
  late NotificationSyncService service;
  late MemoryNotificationInboxStore inboxStore;
  late NotificationInboxService inbox;
  final before = DateTime(2026, 11, 13, 21);
  final plan = NotificationPlan(
    key: '2026-11-14',
    scheduledAt: DateTime(2026, 11, 13, 22),
    expiresAt: DateTime(2026, 11, 15),
    title: '还款提醒',
    body: '11月14日有待还账单',
    route: '/calendar/bills/day?date=2026-11-14',
  );

  Future<void> sync(
    List<NotificationPlan> plans, {
    DateTime? now,
    String scope = 'repayment',
  }) {
    return service.synchronize(scope: scope, plans: plans, now: now ?? before);
  }

  setUp(() {
    delivery = FakeNotificationDelivery();
    registry = MemoryNotificationRegistry();
    inboxStore = MemoryNotificationInboxStore();
    inbox = NotificationInboxService(store: inboxStore);
    service = NotificationSyncService(
      delivery: delivery,
      registry: registry,
      inbox: inbox,
    );
  });
  tearDown(() => inboxStore.dispose());

  test(
    'repeated discovery maintains one plan and changed settings update its id',
    () async {
      await sync([plan]);
      final id = delivery.scheduled.single.$1;
      await sync([plan]);
      expect(delivery.scheduled, hasLength(1));
      final changed = NotificationPlan(
        key: plan.key,
        scheduledAt: DateTime(2026, 11, 13, 23),
        expiresAt: plan.expiresAt,
        title: plan.title,
        body: plan.body,
        route: plan.route,
      );
      await sync([changed]);
      expect(delivery.scheduled, hasLength(2));
      expect(delivery.scheduled.last.$1, id);
      expect(delivery.pending, {id});
      await sync([]);
      expect(delivery.cancelled, contains(id));
      expect(delivery.pending, isEmpty);
      expect(registry.state.entries, isEmpty);
    },
  );

  test(
    'payment cancels only its scope, preserving other notification types',
    () async {
      await sync([plan]);
      await sync([plan], scope: 'another-type');
      final otherId = delivery.scheduled.last.$1;
      expect(otherId, isNot(delivery.scheduled.first.$1));
      await sync([]);
      expect(delivery.pending, {otherId});
      expect(registry.state.entries.single.scope, 'another-type');
    },
  );

  test(
    'a first discovery at 23:00 catches up once across service restart',
    () async {
      final late = DateTime(2026, 11, 13, 23);
      await sync([plan], now: late);
      expect(delivery.shown, hasLength(1));
      expect(delivery.scheduled, isEmpty);
      service = NotificationSyncService(
        delivery: delivery,
        registry: registry,
        inbox: createMemoryNotificationInbox(),
      );
      await sync([plan], now: DateTime(2026, 11, 14, 9));
      expect(delivery.shown, hasLength(1));
    },
  );

  test('discovery after the repayment day never catches up', () async {
    await sync([plan], now: DateTime(2026, 11, 15));
    expect(delivery.shown, isEmpty);
    expect(delivery.scheduled, isEmpty);
    expect(registry.state.entries, isEmpty);
  });

  test(
    'a pre-scheduled reminder is not repeated when the OS is late',
    () async {
      await sync([plan]);
      await sync([plan], now: DateTime(2026, 11, 13, 23));
      expect(delivery.shown, isEmpty);
      expect(delivery.scheduled, hasLength(1));
      expect(delivery.pending, isNotEmpty);
    },
  );

  test(
    'paid reminders retain catch-up deduplication when payment is undone',
    () async {
      final late = DateTime(2026, 11, 13, 23);
      await sync([plan], now: late);
      await sync([], now: late);
      await sync([plan], now: DateTime(2026, 11, 14, 1));
      expect(delivery.shown, hasLength(1));
      await sync([], now: DateTime(2026, 11, 15));
      expect(registry.state.entries, isEmpty);
    },
  );

  test(
    'permission refusal does not repeatedly prompt, explicit request can retry',
    () async {
      delivery.permissionGranted = false;
      await sync([plan]);
      await sync([plan]);
      expect(delivery.permissionRequests, 1);
      expect(delivery.scheduled, isEmpty);
      delivery.permissionResult = true;
      expect(await service.requestPermission(), isTrue);
      await sync([plan]);
      expect(delivery.permissionRequests, 2);
      expect(delivery.scheduled, hasLength(1));
    },
  );

  test(
    'retry preserves earlier accepted plans when another one fails',
    () async {
      final other = NotificationPlan(
        key: '2026-11-16',
        scheduledAt: DateTime(2026, 11, 15, 22),
        expiresAt: DateTime(2026, 11, 17),
        title: plan.title,
        body: '另一条提醒',
        route: '/calendar/bills/day?date=2026-11-16',
      );
      delivery.failingKey = other.key;
      await expectLater(sync([plan, other]), throwsException);
      expect(
        registry.state.entries.map((entry) => entry.plan.key),
        unorderedEquals([plan.key, other.key]),
      );
      delivery.failingKey = null;
      await sync([plan, other]);
      expect(delivery.scheduled, hasLength(2));
    },
  );

  test(
    'a permission dialog crossing the due day cannot deliver an expired reminder',
    () async {
      var deliveryTime = before;
      delivery.permissionGranted = false;
      delivery.permissionResult = true;
      delivery.onPermissionRequest = () async {
        deliveryTime = DateTime(2026, 11, 15);
      };
      service = NotificationSyncService(
        delivery: delivery,
        registry: registry,
        inbox: createMemoryNotificationInbox(),
        clock: () => deliveryTime,
      );
      await sync([plan]);
      expect(delivery.shown, isEmpty);
      expect(delivery.scheduled, isEmpty);
      expect(registry.state.entries, isEmpty);
    },
  );

  test('missing future OS registrations are repaired', () async {
    await sync([plan]);
    final id = delivery.scheduled.single.$1;
    delivery.pending.clear();
    await sync([plan]);
    expect(delivery.scheduled, hasLength(2));
    expect(delivery.scheduled.last.$1, id);
  });

  test(
    'native registrations permit cancellation when local history is missing',
    () async {
      await sync([plan]);
      final id = delivery.scheduled.single.$1;
      registry.state = NotificationRegistryState();
      await sync([]);
      expect(delivery.pending, isEmpty);
      expect(delivery.cancelled, contains(id));
    },
  );

  for (final (label, now) in [
    ('future schedule', before),
    ('catch-up', DateTime(2026, 11, 13, 23)),
  ]) {
    test(
      'a registry failure prevents $label delivery and permits a later retry',
      () async {
        final failingRegistry = _FailingRegistry()..failNextSave = true;
        service = NotificationSyncService(
          delivery: delivery,
          registry: failingRegistry,
          inbox: inbox,
        );
        await expectLater(sync([plan], now: now), throwsException);
        expect(delivery.scheduled, isEmpty);
        expect(delivery.shown, isEmpty);
        expect(inboxStore.messages.single.plan, plan);
        await sync([plan], now: now);
        await sync([plan], now: now);
        expect(delivery.scheduled.length + delivery.shown.length, 1);
      },
    );
  }

  test(
    'a failed catch-up is consumed across restart while its inbox stays visible',
    () async {
      final now = DateTime(2026, 11, 13, 23);
      delivery.failingKey = plan.key;
      await expectLater(sync([plan], now: now), throwsException);
      delivery.failingKey = null;
      service = NotificationSyncService(
        delivery: delivery,
        registry: registry,
        inbox: inbox,
      );
      await sync([plan], now: DateTime(2026, 11, 14, 9));
      expect(delivery.shown, isEmpty);
      expect(registry.state.entries.single.plan, plan);
      expect(inboxStore.messages.single.isVisibleAt(now), isTrue);
    },
  );

  test(
    'a catch-up accepted before an uncertain result is never attempted again',
    () async {
      final uncertain = _AcceptedThenFailedDelivery();
      service = NotificationSyncService(
        delivery: uncertain,
        registry: registry,
        inbox: inbox,
      );
      await expectLater(
        sync([plan], now: DateTime(2026, 11, 13, 23)),
        throwsException,
      );
      uncertain.failAfterAcceptance = false;
      service = NotificationSyncService(
        delivery: uncertain,
        registry: registry,
        inbox: inbox,
      );
      await sync([plan], now: DateTime(2026, 11, 14, 9));
      expect(uncertain.shown, hasLength(1));
    },
  );

  test(
    'a future schedule with an uncertain result cannot become a second catch-up',
    () async {
      final uncertain = _AcceptedThenFailedDelivery();
      service = NotificationSyncService(
        delivery: uncertain,
        registry: registry,
        inbox: inbox,
      );
      await expectLater(sync([plan]), throwsException);
      // The OS has already triggered the one-off request before discovery resumes.
      uncertain.pending.clear();
      uncertain.failAfterAcceptance = false;
      service = NotificationSyncService(
        delivery: uncertain,
        registry: registry,
        inbox: inbox,
      );
      await sync([plan], now: DateTime(2026, 11, 14, 9));
      expect(uncertain.scheduled, hasLength(1));
      expect(uncertain.shown, isEmpty);
    },
  );

  test(
    'a failed future reservation is consumed once its reminder time has passed',
    () async {
      delivery.failingKey = plan.key;
      await expectLater(sync([plan]), throwsException);
      delivery.failingKey = null;
      service = NotificationSyncService(
        delivery: delivery,
        registry: registry,
        inbox: inbox,
      );
      await sync([plan], now: DateTime(2026, 11, 14, 9));
      expect(delivery.scheduled, isEmpty);
      expect(delivery.shown, isEmpty);
    },
  );

  test(
    'a failed time update repairs the old native plan under the same id',
    () async {
      await sync([plan]);
      final id = delivery.scheduled.single.$1;
      final changed = NotificationPlan(
        key: plan.key,
        scheduledAt: DateTime(2026, 11, 13, 23),
        expiresAt: plan.expiresAt,
        title: plan.title,
        body: plan.body,
        route: plan.route,
      );
      delivery.failingKey = plan.key;
      await expectLater(sync([changed]), throwsException);
      delivery.failingKey = null;
      await sync([changed]);
      expect(delivery.scheduled, hasLength(2));
      expect(delivery.scheduled.last, (id, changed));
    },
  );

  test(
    'recovering an empty local registry leaves other scopes and unknown requests untouched',
    () async {
      await sync([plan]);
      await sync([plan], scope: 'another-type');
      final otherId = delivery.scheduled.last.$1;
      delivery.pending.add(7);
      registry.state = NotificationRegistryState();
      await sync([]);
      expect(delivery.pending, {otherId, 7});
    },
  );
}

class _FailingRegistry extends MemoryNotificationRegistry {
  bool failNextSave = false;

  @override
  Future<void> save(NotificationRegistryState state) async {
    if (failNextSave) {
      failNextSave = false;
      throw Exception('Cannot save notification registrations.');
    }
    await super.save(state);
  }
}

class _AcceptedThenFailedDelivery extends FakeNotificationDelivery {
  bool failAfterAcceptance = true;

  @override
  Future<void> show(RegisteredNotification notification) async {
    await super.show(notification);
    if (failAfterAcceptance) {
      throw Exception('System notification result lost.');
    }
  }

  @override
  Future<void> schedule(RegisteredNotification notification) async {
    await super.schedule(notification);
    if (failAfterAcceptance) {
      throw Exception('System schedule result lost.');
    }
  }
}
