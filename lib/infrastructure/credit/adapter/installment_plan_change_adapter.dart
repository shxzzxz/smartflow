import 'package:smartflow/application/credit/installment/command/installment_plan_app_service.dart';
import 'package:smartflow/application/credit/installment/port/installment_plan_change_port.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';

/// 把计划用例适配成 application 层的最小能力端口。
///
/// 调用发生在消费用例自己的事务内，嵌套事务由 TransactionRunner 承接。
class InstallmentPlanChangeAdapter implements InstallmentPlanChangePort {
  const InstallmentPlanChangeAdapter(this._plans);

  final InstallmentPlanAppService _plans;

  @override
  Future<void> applyAutomaticChange(
    String contractId,
    InstallmentPlanChangeRequest request,
  ) => _plans.applyAutomaticChange(contractId, request);
}
