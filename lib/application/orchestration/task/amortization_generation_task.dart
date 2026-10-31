import '../../shared/task/app_task.dart';
import '../amortization/command/amortization_plan_app_service.dart';

class AmortizationGenerationTask implements AppTask {
  const AmortizationGenerationTask(this._service);

  final AmortizationPlanAppService _service;

  @override
  String get key => 'orchestration.amortization_generation';

  @override
  Future<AppTaskOutcome> run(DateTime now) async {
    await _service.generateDue(now);
    return AppTaskOutcome.completed;
  }
}
