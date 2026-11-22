import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_registry.dart';
import 'package:smartflow/application/shared/notification/notification_sync_service.dart';

import '../../../helper/fake_notification_delivery.dart';

void main() {
  late FakeNotificationDelivery delivery;
  late MemoryNotificationRegistry registry;
  late NotificationSyncService service;
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
    service = NotificationSyncService(
      delivery: delivery,
      registry: registry,
      inbox: createMemoryNotificationInbox(),
    );
  });

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
      expect(registry.state.entries.single.plan.key, plan.key);
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
    'system registration recovery permits cancellation after a local save failure',
    () async {
      final failingRegistry = _FailingRegistry()..failNextSave = true;
      service = NotificationSyncService(
        delivery: delivery,
        registry: failingRegistry,
        inbox: createMemoryNotificationInbox(),
      );
      await expectLater(sync([plan]), throwsException);
      final id = delivery.scheduled.single.$1;
      expect(failingRegistry.state.entries, isEmpty);
      await sync([]);
      expect(delivery.pending, isEmpty);
      expect(delivery.cancelled, contains(id));
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
