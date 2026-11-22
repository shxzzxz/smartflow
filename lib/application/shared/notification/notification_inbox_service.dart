import 'notification_inbox_store.dart';
import 'notification_message.dart';
import 'notification_plan.dart';
import 'notification_registry.dart';

/// Owns local message history and read state, independently of OS permissions.
class NotificationInboxService {
  NotificationInboxService({
    required NotificationInboxStore store,
    DateTime Function()? clock,
  }) : _store = store,
       _clock = clock ?? DateTime.now;

  final NotificationInboxStore _store;
  final DateTime Function() _clock;
  Future<void> _pending = Future<void>.value();

  Stream<List<NotificationMessage>> watch() => _store.watch();

  Stream<List<NotificationMessage>> watchVisible() => watch().map((messages) {
    final now = _clock();
    return messages.where((message) => message.isVisibleAt(now)).toList()
      ..sort((a, b) {
        final byTime = b.plan.scheduledAt.compareTo(a.plan.scheduledAt);
        return byTime != 0 ? byTime : a.identity.compareTo(b.identity);
      });
  });

  Future<DateTime?> nextVisibleAt(DateTime now) async =>
      nextVisibleAtIn(await _store.read(), now);

  static DateTime? nextVisibleAtIn(
    List<NotificationMessage> messages,
    DateTime now,
  ) {
    DateTime? next;
    for (final message in messages) {
      final at = message.plan.scheduledAt;
      if (at.isAfter(now) && (next == null || at.isBefore(next))) next = at;
    }
    return next;
  }

  Future<void> synchronize({
    required String scope,
    required List<NotificationPlan> plans,
    required DateTime now,
  }) => _serial(() async {
    final desired = <String, NotificationPlan>{};
    for (final plan in plans) {
      if (!plan.expiresAt.isAfter(now)) continue;
      final identity = '$scope/${plan.key}';
      if (desired.containsKey(identity)) {
        throw ArgumentError('Duplicate notification identity.');
      }
      desired[identity] = plan;
    }
    final previous = await _store.read();
    final messages = <NotificationMessage>[];
    var changed = false;
    for (final message in previous) {
      if (message.scope != scope) {
        messages.add(message);
        continue;
      }
      final plan = desired.remove(message.identity);
      // Once available, the original message is history. Payment, disabling
      // reminders, or OS expiry must not remove it or postpone its timestamp.
      if (message.isVisibleAt(now)) {
        messages.add(message);
      } else if (plan != null) {
        messages.add(message.withPlan(plan));
        changed |= plan != message.plan;
      } else {
        changed = true;
      }
    }
    for (final plan in desired.values) {
      messages.add(
        NotificationMessage(scope: scope, plan: plan, createdAt: now),
      );
      changed = true;
    }
    if (changed) await _store.save(messages);
  });

  /// A tap supplies the original OS payload, including across app upgrades
  /// where that scheduled message predates the local inbox.
  Future<void> recordOpened(
    RegisteredNotification notification, {
    DateTime? now,
  }) => _serial(() async {
    final at = now ?? _clock();
    if (notification.plan.scheduledAt.isAfter(at)) return;
    final messages = List<NotificationMessage>.of(await _store.read());
    final index = messages.indexWhere(
      (message) => message.identity == notification.identity,
    );
    if (index < 0) {
      messages.add(
        NotificationMessage(
          scope: notification.scope,
          plan: notification.plan,
          createdAt: at,
          readAt: at,
        ),
      );
    } else if (!messages[index].isRead) {
      messages[index] = messages[index].markRead(at);
    } else {
      return;
    }
    await _store.save(messages);
  });

  Future<void> markRead(String identity, {DateTime? now}) =>
      _markRead((message) => message.identity == identity, now ?? _clock());

  Future<void> markAllRead({DateTime? now}) =>
      _markRead((_) => true, now ?? _clock());

  Future<void> _markRead(
    bool Function(NotificationMessage) matches,
    DateTime now,
  ) => _serial(() async {
    final previous = await _store.read();
    var changed = false;
    final messages = <NotificationMessage>[];
    for (final message in previous) {
      if (!message.isRead && message.isVisibleAt(now) && matches(message)) {
        messages.add(message.markRead(now));
        changed = true;
      } else {
        messages.add(message);
      }
    }
    if (changed) await _store.save(messages);
  });

  Future<void> _serial(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }
}
