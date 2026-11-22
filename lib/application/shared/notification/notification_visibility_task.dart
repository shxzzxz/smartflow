import '../task/app_task.dart';
import 'notification_inbox_service.dart';

/// Refreshes time-dependent message queries without rediscovering obligations.
class NotificationVisibilityTask implements AppTask {
  const NotificationVisibilityTask({required this.inbox, this.onChanged});

  static const taskKey = 'notification.visibility';
  final NotificationInboxService inbox;
  final void Function()? onChanged;

  @override
  String get key => taskKey;

  @override
  TaskRunPolicy get runPolicy => TaskRunPolicy.minInterval(Duration.zero);

  @override
  Future<AppTaskResult> run(DateTime now) async {
    onChanged?.call();
    return AppTaskResult.completed(nextCheckAt: await inbox.nextVisibleAt(now));
  }
}
