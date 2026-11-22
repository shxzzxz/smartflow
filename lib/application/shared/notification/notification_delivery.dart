import 'notification_registry.dart';

class PendingNotification {
  const PendingNotification({required this.id, this.registration});

  final int id;
  final RegisteredNotification? registration;
}

class NotificationOpen {
  const NotificationOpen({required this.route, this.registration});

  final String route;
  final RegisteredNotification? registration;
}

/// Platform delivery only; business discovery and synchronization stay outside.
abstract interface class NotificationDelivery {
  bool get isSupported;

  Stream<NotificationOpen> get openedNotifications;

  Future<void> initialize();

  Future<NotificationOpen?> initialNotification();

  Future<bool> isPermissionGranted();

  Future<bool> requestPermission();

  Future<List<PendingNotification>> pendingNotifications();

  Future<void> schedule(RegisteredNotification notification);

  Future<void> show(RegisteredNotification notification);

  Future<void> cancel(int id);
}
