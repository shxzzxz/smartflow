import '../../shared/task/app_task.dart';
import 'installment_repricing_task_coordinator.dart';
import '../installment/command/installment_repricing_app_service.dart';

class InstallmentRepricingTask implements AppTask {
  InstallmentRepricingTask(Object serviceOrCoordinator, {this.onChanged})
      : _coordinator = serviceOrCoordinator is InstallmentRepricingTaskCoordinator
            ? serviceOrCoordinator
            : InstallmentRepricingTaskCoordinator(
                serviceOrCoordinator as InstallmentRepricingAppService,
              );

  final InstallmentRepricingTaskCoordinator _coordinator;
  final void Function()? onChanged;

  @override
  String get key => 'credit.repricing';

  @override
  Future<AppTaskOutcome> run(DateTime now) async {
    final result = await _coordinator.runDue(now);
    if (result.changed) onChanged?.call();
    return result.needsRetry
        ? AppTaskOutcome.retryLater
        : AppTaskOutcome.completed;
  }
}
