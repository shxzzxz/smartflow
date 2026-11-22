import '../../shared/task/app_task.dart';

import '../bill/command/credit_bill_generation_app_service.dart';

class CreditBillGenerationTask implements AppTask {
  const CreditBillGenerationTask(this._service, {this.onChanged});

  final CreditBillGenerationAppService _service;
  final void Function()? onChanged;

  @override
  String get key => 'credit.bill_generation';

  @override
  TaskRunPolicy get runPolicy =>
      TaskRunPolicy.oncePerWindow(const Duration(days: 1));

  @override
  Future<AppTaskResult> run(DateTime now) async {
    await _service.generateDueBills(now: now);
    onChanged?.call();
    return AppTaskResult.completed(
      nextCheckAt: runPolicy.nextAllowedAt(
        now: now,
        lastSuccessfulRunAt: now,
        lastCompletedAt: now,
      ),
    );
  }
}
