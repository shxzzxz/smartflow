import '../../shared/task/app_task.dart';
import '../amortization/command/amortization_plan_app_service.dart';

class AmortizationGenerationTask implements AppTask {
  const AmortizationGenerationTask(this._service);

  final AmortizationPlanAppService _service;

  @override
  String get key => 'orchestration.amortization_generation';

  @override
  TaskRunPolicy get runPolicy =>
      TaskRunPolicy.oncePerWindow(const Duration(days: 1));

  @override
  Future<AppTaskResult> run(DateTime now) async {
    await _service.generateDue(now);
    return AppTaskResult.completed(
      nextCheckAt: runPolicy.nextAllowedAt(
        now: now,
        lastSuccessfulRunAt: now,
        lastCompletedAt: now,
      ),
    );
  }
}
