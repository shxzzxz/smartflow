import 'package:smartflow/application/shared/app_task.dart';

import 'credit_bill_generation_app_service.dart';

class CreditBillGenerationTask implements AppTask {
  const CreditBillGenerationTask(this._service);

  final CreditBillGenerationAppService _service;

  @override
  String get key => 'credit.bill_generation';

  @override
  Future<void> run(DateTime now) {
    return _service.generateDueBills(now: now);
  }
}
