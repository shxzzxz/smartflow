import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/notification_providers.dart';
import '../../../application/shared/notification/notification_message.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'notification_center_view_model.g.dart';

class NotificationCenterViewState {
  NotificationCenterViewState(List<NotificationMessage> messages)
    : messages = List.unmodifiable(messages);

  final List<NotificationMessage> messages;
  int get unreadCount => messages.where((message) => !message.isRead).length;
}

@riverpod
class NotificationCenterViewModel extends _$NotificationCenterViewModel {
  @override
  Future<NotificationCenterViewState> build() async {
    return NotificationCenterViewState(
      await ref.watch(notificationMessagesProvider.future),
    );
  }

  Future<UiActionOutcome<void>> markRead(NotificationMessage message) =>
      guardUiAction(
        Logger('feature.profile.notifications'),
        'read notification',
        () => ref
            .read(notificationInboxServiceProvider)
            .markRead(message.identity),
      );

  Future<UiActionOutcome<void>> markAllRead() => guardUiAction(
    Logger('feature.profile.notifications'),
    'read all notifications',
    () => ref.read(notificationInboxServiceProvider).markAllRead(),
  );

  Future<UiActionOutcome<void>> refresh() => guardUiAction(
    Logger('feature.profile.notifications'),
    'refresh notifications',
    () async {
      ref.invalidate(notificationMessagesProvider);
      await ref.read(notificationMessagesProvider.future);
    },
  );
}
