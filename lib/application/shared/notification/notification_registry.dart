import 'notification_plan.dart';

/// Registrations reserve reminders before platform delivery. Once the scheduled
/// time passes, a reservation is consumed even after failure or interruption.
/// It is not a delivery receipt.
class RegisteredNotification {
  const RegisteredNotification({
    required this.scope,
    required this.id,
    required this.plan,
  });

  final String scope;
  final int id;
  final NotificationPlan plan;

  String get identity => '$scope/${plan.key}';

  Map<String, Object> toJson() => {
    'scope': scope,
    'id': id,
    'plan': plan.toJson(),
  };

  factory RegisteredNotification.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'];
    final id = json['id'];
    final plan = json['plan'];
    if (scope is! String ||
        id is! int ||
        id < 0 ||
        id > 0x7fffffff ||
        plan is! Map<String, dynamic>) {
      throw const FormatException('Invalid notification registration.');
    }
    return RegisteredNotification(
      scope: scope,
      id: id,
      plan: NotificationPlan.fromJson(plan),
    );
  }
}

class NotificationRegistryState {
  NotificationRegistryState({
    List<RegisteredNotification> entries = const [],
    this.permissionRequested = false,
  }) : entries = List.unmodifiable(entries);

  final List<RegisteredNotification> entries;
  final bool permissionRequested;
}

abstract interface class NotificationRegistry {
  Future<NotificationRegistryState> read();

  Future<void> save(NotificationRegistryState state);
}
