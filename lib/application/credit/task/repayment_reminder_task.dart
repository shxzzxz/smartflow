import '../../shared/task/app_task.dart';
import '../repayment_reminder/command/repayment_reminder_app_service.dart';

class RepaymentReminderTask implements AppTask {
  const RepaymentReminderTask(this._service);

  final RepaymentReminderAppService _service;

  @override
  String get key => RepaymentReminderAppService.scope;

  @override
  TaskRunPolicy get runPolicy =>
      TaskRunPolicy.minInterval(const Duration(hours: 1));

  @override
  Future<AppTaskResult> run(DateTime now) async {
    await _service.synchronize(now);
    return const AppTaskResult.completed();
  }
}
