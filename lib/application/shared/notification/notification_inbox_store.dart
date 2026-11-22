import 'notification_message.dart';

abstract interface class NotificationInboxStore {
  Future<List<NotificationMessage>> read();

  Stream<List<NotificationMessage>> watch();

  Future<void> save(List<NotificationMessage> messages);
}
