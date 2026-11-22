/// A one-off local notification and the end of its useful lifetime.
class NotificationPlan {
  const NotificationPlan({
    required this.key,
    required this.scheduledAt,
    required this.expiresAt,
    required this.title,
    required this.body,
    required this.route,
  });

  final String key;
  final DateTime scheduledAt;
  final DateTime expiresAt;
  final String title;
  final String body;
  final String route;

  Map<String, Object> toJson() => {
    'key': key,
    'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'title': title,
    'body': body,
    'route': route,
  };

  factory NotificationPlan.fromJson(Map<String, dynamic> json) {
    final scheduledAt = DateTime.tryParse('${json['scheduledAt'] ?? ''}');
    final expiresAt = DateTime.tryParse('${json['expiresAt'] ?? ''}');
    if (scheduledAt == null ||
        expiresAt == null ||
        !expiresAt.isAfter(scheduledAt) ||
        json['key'] is! String ||
        json['title'] is! String ||
        json['body'] is! String ||
        json['route'] is! String) {
      throw const FormatException('Invalid notification plan.');
    }
    return NotificationPlan(
      key: json['key'] as String,
      scheduledAt: scheduledAt,
      expiresAt: expiresAt,
      title: json['title'] as String,
      body: json['body'] as String,
      route: json['route'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPlan &&
      key == other.key &&
      scheduledAt.isAtSameMomentAs(other.scheduledAt) &&
      expiresAt.isAtSameMomentAs(other.expiresAt) &&
      title == other.title &&
      body == other.body &&
      route == other.route;

  @override
  int get hashCode => Object.hash(
    key,
    scheduledAt.microsecondsSinceEpoch,
    expiresAt.microsecondsSinceEpoch,
    title,
    body,
    route,
  );
}
