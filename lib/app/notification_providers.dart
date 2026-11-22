import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/shared/notification/notification_delivery.dart';
import '../application/shared/notification/notification_inbox_service.dart';
import '../application/shared/notification/notification_message.dart';
import '../application/shared/notification/notification_visibility_task.dart';
import '../application/shared/notification/notification_sync_service.dart';
import '../infrastructure/database/database_provider.dart';
import '../infrastructure/notification/drift_notification_registry.dart';
import '../infrastructure/notification/drift_notification_inbox_store.dart';
import '../infrastructure/notification/flutter_local_notification_delivery.dart';

final notificationDeliveryProvider = Provider<NotificationDelivery>((ref) {
  final delivery = FlutterLocalNotificationDelivery();
  ref.onDispose(() => unawaited(delivery.dispose()));
  return delivery;
});

final notificationInboxServiceProvider = Provider<NotificationInboxService>((
  ref,
) {
  return NotificationInboxService(
    store: DriftNotificationInboxStore(ref.watch(appDatabaseProvider)),
  );
});

final notificationMessagesProvider =
    StreamProvider.autoDispose<List<NotificationMessage>>((ref) {
      return ref.watch(notificationInboxServiceProvider).watchVisible();
    });

final notificationUnreadCountProvider = Provider.autoDispose<int>((ref) {
  final messages = ref.watch(notificationMessagesProvider).value;
  return messages?.where((message) => !message.isRead).length ?? 0;
});

final notificationVisibilityTaskProvider = Provider<NotificationVisibilityTask>(
  (ref) => NotificationVisibilityTask(
    inbox: ref.watch(notificationInboxServiceProvider),
    onChanged: () => ref.invalidate(notificationMessagesProvider),
  ),
);

final notificationSyncServiceProvider = Provider<NotificationSyncService>((
  ref,
) {
  return NotificationSyncService(
    delivery: ref.watch(notificationDeliveryProvider),
    registry: DriftNotificationRegistry(ref.watch(appDatabaseProvider)),
    inbox: ref.watch(notificationInboxServiceProvider),
    clock: DateTime.now,
  );
});

final notificationPermissionProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(notificationDeliveryProvider).isPermissionGranted();
});

final notificationsSupportedProvider = Provider<bool>((ref) {
  return ref.watch(notificationDeliveryProvider).isSupported;
});
