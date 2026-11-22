import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'notification_delivery.dart';
import 'notification_inbox_service.dart';
import 'notification_plan.dart';
import 'notification_registry.dart';

/// Reconciles one scope's desired plans without touching other notice types.
class NotificationSyncService {
  NotificationSyncService({
    required NotificationDelivery delivery,
    required NotificationRegistry registry,
    required NotificationInboxService inbox,
    DateTime Function()? clock,
  }) : _delivery = delivery,
       _registry = registry,
       _inbox = inbox,
       _clock = clock;

  final NotificationDelivery _delivery;
  final NotificationRegistry _registry;
  final NotificationInboxService _inbox;
  final DateTime Function()? _clock;
  Future<void> _pending = Future<void>.value();

  Future<bool> requestPermission() => _serial(() async {
    if (!_delivery.isSupported) return false;
    await _delivery.initialize();
    final state = await _registry.read();
    await _registry.save(
      NotificationRegistryState(
        entries: state.entries,
        permissionRequested: true,
      ),
    );
    return _delivery.requestPermission();
  });

  Future<void> synchronize({
    required String scope,
    required List<NotificationPlan> plans,
    required DateTime now,
  }) => _serial(() => _synchronize(scope, plans, now));

  Future<void> _synchronize(
    String scope,
    List<NotificationPlan> plans,
    DateTime now,
  ) async {
    await _inbox.synchronize(scope: scope, plans: plans, now: now);
    if (!_delivery.isSupported) return;
    await _delivery.initialize();
    var state = await _registry.read();
    final entries = {for (final entry in state.entries) entry.identity: entry};
    final nativePending = await _delivery.pendingNotifications();
    for (final pending in nativePending) {
      final registration = pending.registration;
      if (registration != null && registration.scope == scope) {
        final stored = entries[registration.identity];
        if (stored == null) {
          entries[registration.identity] = registration;
        } else if (stored.id != pending.id) {
          await _delivery.cancel(pending.id);
        }
      }
    }
    final desired = <String, NotificationPlan>{};
    for (final plan in plans) {
      if (!plan.expiresAt.isAfter(now)) continue;
      final identity = '$scope/${plan.key}';
      if (desired.containsKey(identity)) {
        throw ArgumentError('Duplicate notification identity.');
      }
      desired[identity] = plan;
    }

    for (final entry in entries.values.toList().where(
      (entry) => entry.scope == scope,
    )) {
      if (!entry.plan.expiresAt.isAfter(now)) {
        await _delivery.cancel(entry.id);
        entries.remove(entry.identity);
      } else if (!desired.containsKey(entry.identity)) {
        await _delivery.cancel(entry.id);
        // Retain attempted reminders until expiry, even if the debt was paid.
        // An undo or a settings change must not cause a second catch-up notice.
        if (entry.plan.scheduledAt.isAfter(now)) entries.remove(entry.identity);
      }
    }

    var allowed = await _delivery.isPermissionGranted();
    if (desired.isNotEmpty && !allowed && !state.permissionRequested) {
      state = NotificationRegistryState(
        entries: entries.values.toList(),
        permissionRequested: true,
      );
      // Remember the prompt before displaying it, including process death.
      await _registry.save(state);
      allowed = await _delivery.requestPermission();
    }
    if (!allowed) {
      await _registry.save(
        NotificationRegistryState(
          entries: entries.values.toList(),
          permissionRequested: state.permissionRequested,
        ),
      );
      return;
    }

    // Permission dialogs can outlive the reminder window. Refresh the delivery
    // decision time without rerunning business discovery or adding a timer.
    final deliveryAt = _clock?.call() ?? now;
    final pendingById = {
      for (final pending in nativePending) pending.id: pending,
    };
    final pendingIds = pendingById.keys.toSet();
    for (final identity in desired.keys.toList()..sort()) {
      final plan = desired[identity]!;
      final previous = entries[identity];
      if (!plan.expiresAt.isAfter(deliveryAt)) {
        if (previous != null) await _delivery.cancel(previous.id);
        entries.remove(identity);
        continue;
      }
      if (previous != null && !previous.plan.scheduledAt.isAfter(deliveryAt)) {
        // A reservation consumes the reminder after its scheduled time, even
        // if the platform call failed or the process stopped before delivery.
        continue;
      }
      final id =
          previous?.id ?? _allocateId(identity, entries.values, pendingIds);
      final notification = RegisteredNotification(
        scope: scope,
        id: id,
        plan: plan,
      );
      final isFuture = plan.scheduledAt.isAfter(deliveryAt);
      final pending = pendingById[id]?.registration;
      if (isFuture &&
          previous?.plan == plan &&
          pending?.identity == identity &&
          pending?.plan == plan) {
        continue;
      }
      entries[identity] = notification;
      // Persist the reservation before invoking the platform. A failed save
      // cannot deliver; a saved reminder is never caught up a second time.
      await _registry.save(
        NotificationRegistryState(
          entries: entries.values.toList(),
          permissionRequested: state.permissionRequested,
        ),
      );
      if (isFuture) {
        // Repairs before the reminder time replace the same native request.
        // Compare its payload too: an earlier time update may have failed.
        await _delivery.schedule(notification);
      } else {
        if (previous != null) await _delivery.cancel(id);
        await _delivery.show(notification);
      }
    }
    await _registry.save(
      NotificationRegistryState(
        entries: entries.values.toList(),
        permissionRequested: state.permissionRequested,
      ),
    );
  }

  int _allocateId(
    String identity,
    Iterable<RegisteredNotification> entries,
    Set<int> pendingIds,
  ) {
    final bytes = sha256.convert(utf8.encode(identity)).bytes;
    var id =
        ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
        0x7fffffff;
    final occupied = {...pendingIds, for (final entry in entries) entry.id};
    while (occupied.contains(id)) {
      id = (id + 1) & 0x7fffffff;
    }
    return id;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }
}
