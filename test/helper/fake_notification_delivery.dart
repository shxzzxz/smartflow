import 'dart:async';

import 'package:smartflow/application/shared/notification/notification_inbox_service.dart';
import 'package:smartflow/application/shared/notification/notification_inbox_store.dart';
import 'package:smartflow/application/shared/notification/notification_message.dart';
import 'package:smartflow/application/shared/notification/notification_delivery.dart';
import 'package:smartflow/application/shared/notification/notification_plan.dart';
import 'package:smartflow/application/shared/notification/notification_registry.dart';

class FakeNotificationDelivery implements NotificationDelivery {
  FakeNotificationDelivery({
    this.supported = true,
    this.permissionGranted = true,
  });

  final bool supported;
  bool permissionGranted;
  bool permissionResult = false;
  Future<void> Function()? onPermissionRequest;
  String? failingKey;
  int permissionRequests = 0;
  final pending = <int>{};
  final _nativeRegistrations = <int, RegisteredNotification>{};
  final scheduled = <(int, NotificationPlan)>[];
  final shown = <(int, NotificationPlan)>[];
  final cancelled = <int>[];

  @override
  bool get isSupported => supported;

  @override
  Stream<NotificationOpen> get openedNotifications => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationOpen?> initialNotification() async => null;

  @override
  Future<bool> isPermissionGranted() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    await onPermissionRequest?.call();
    return permissionGranted = permissionResult;
  }

  @override
  Future<List<PendingNotification>> pendingNotifications() async => [
    for (final id in pending)
      PendingNotification(id: id, registration: _nativeRegistrations[id]),
  ];

  @override
  Future<void> schedule(RegisteredNotification notification) async {
    final id = notification.id;
    final plan = notification.plan;
    if (plan.key == failingKey) throw Exception('Cannot schedule this plan.');
    pending.add(id);
    _nativeRegistrations[id] = notification;
    scheduled.add((id, plan));
  }

  @override
  Future<void> show(RegisteredNotification notification) async {
    final id = notification.id;
    final plan = notification.plan;
    if (plan.key == failingKey) throw Exception('Cannot show this plan.');
    shown.add((id, plan));
  }

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
    _nativeRegistrations.remove(id);
    cancelled.add(id);
  }
}

NotificationInboxService createMemoryNotificationInbox({
  DateTime Function()? clock,
}) => NotificationInboxService(
  store: MemoryNotificationInboxStore(),
  clock: clock,
);

class MemoryNotificationInboxStore implements NotificationInboxStore {
  List<NotificationMessage> messages = [];
  final _changes = StreamController<List<NotificationMessage>>.broadcast();

  @override
  Future<List<NotificationMessage>> read() async => List.of(messages);

  @override
  Stream<List<NotificationMessage>> watch() => Stream.multi((controller) {
    final subscription = _changes.stream.listen(
      controller.addSync,
      onError: controller.addErrorSync,
      onDone: controller.closeSync,
    );
    controller.addSync(List.of(messages));
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<void> save(List<NotificationMessage> value) async {
    messages = List.of(value);
    _changes.add(List.of(messages));
  }

  Future<void> dispose() => _changes.close();
}

class MemoryNotificationRegistry implements NotificationRegistry {
  NotificationRegistryState state = NotificationRegistryState();

  @override
  Future<NotificationRegistryState> read() async => state;

  @override
  Future<void> save(NotificationRegistryState value) async {
    state = value;
  }
}
