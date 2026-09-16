import '../../shared/task/app_task.dart';
import '../installment/command/installment_repricing_app_service.dart';

class InstallmentRepricingTask implements AppTask {
  const InstallmentRepricingTask(this._service, {this.onChanged});

  final InstallmentRepricingAppService _service;
  final void Function()? onChanged;

  @override
  String get key => 'credit.repricing';

  @override
  Future<AppTaskOutcome> run(DateTime now) async {
    final result = await _service.runDue(now);
    if (result.changed) onChanged?.call();
    return result.needsRetry
        ? AppTaskOutcome.retryLater
        : AppTaskOutcome.completed;
  }
}
