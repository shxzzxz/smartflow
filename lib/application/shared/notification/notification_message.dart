import 'notification_plan.dart';

/// A locally retained message. Availability is independent of OS delivery.
class NotificationMessage {
  const NotificationMessage({
    required this.scope,
    required this.plan,
    required this.createdAt,
    this.readAt,
  });

  final String scope;
  final NotificationPlan plan;
  final DateTime createdAt;
  final DateTime? readAt;

  String get identity => '$scope/${plan.key}';
  bool get isRead => readAt != null;
  bool isVisibleAt(DateTime now) => !plan.scheduledAt.isAfter(now);

  NotificationMessage withPlan(NotificationPlan value) => NotificationMessage(
    scope: scope,
    plan: value,
    createdAt: createdAt,
    readAt: readAt,
  );

  NotificationMessage markRead(DateTime now) => NotificationMessage(
    scope: scope,
    plan: plan,
    createdAt: createdAt,
    readAt: readAt ?? now,
  );

  Map<String, Object?> toJson() => {
    'scope': scope,
    'plan': plan.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'readAt': readAt?.toUtc().toIso8601String(),
  };

  factory NotificationMessage.fromJson(Map<String, dynamic> json) {
    final scope = json['scope'];
    final plan = json['plan'];
    final createdAt = DateTime.tryParse('${json['createdAt'] ?? ''}');
    final readAt = json['readAt'] == null
        ? null
        : DateTime.tryParse('${json['readAt']}');
    if (scope is! String ||
        scope.isEmpty ||
        plan is! Map<String, dynamic> ||
        createdAt == null ||
        (json['readAt'] != null && readAt == null)) {
      throw const FormatException('Invalid notification message.');
    }
    return NotificationMessage(
      scope: scope,
      plan: NotificationPlan.fromJson(plan),
      createdAt: createdAt,
      readAt: readAt,
    );
  }
}
