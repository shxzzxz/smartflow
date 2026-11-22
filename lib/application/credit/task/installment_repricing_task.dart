import '../../shared/task/app_task.dart';
import '../installment/command/installment_repricing_app_service.dart';

class InstallmentRepricingTask implements AppTask {
  const InstallmentRepricingTask(this._service, {this.onChanged});

  final InstallmentRepricingAppService _service;
  final void Function()? onChanged;

  @override
  String get key => 'credit.repricing';

  @override
  TaskRunPolicy get runPolicy =>
      TaskRunPolicy.oncePerWindow(const Duration(days: 1));

  @override
  Future<AppTaskResult> run(DateTime now) async {
    final result = await _service.runDue(now);
    if (result.changed) onChanged?.call();
    return result.needsRetry
        ? const AppTaskResult.retryLater()
        : AppTaskResult.completed(
            nextCheckAt: runPolicy.nextAllowedAt(
              now: now,
              lastSuccessfulRunAt: now,
              lastCompletedAt: now,
            ),
          );
  }
}
