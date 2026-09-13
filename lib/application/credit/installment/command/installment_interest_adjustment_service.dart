import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../domain/credit/entity/installment_interest_adjustment.dart';
import '../../../../domain/credit/port/installment_interest_adjustment_repository.dart';
import '../../../../domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/service/installment/handler/interest_adjustment_handler.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../../domain/credit/valobj/installment_plan_change.dart';
import '../../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../shared/transaction_runner.dart';
import 'installment_plan_service.dart';

class InstallmentInterestAdjustmentService {
  const InstallmentInterestAdjustmentService({
    required this.installments,
    required this.records,
    required this.plans,
    required this.runner,
    required this.ids,
  });
  final InstallmentRepository installments;
  final InstallmentInterestAdjustmentRepository records;
  final InstallmentPlanService plans;
  final TransactionRunner runner;
  final IdGenerator ids;

  Future<String> save(
    String contractId,
    InterestAdjustment adjustment, {
    String? id,
  }) => runner.run(() async {
    final contract = await installments.findContract(contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    if (id != null &&
        !contract.interestAdjustments.any((record) => record.id == id)) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '利息调整记录已变化，请刷新后重试',
      );
    }
    const InterestAdjustmentHandler().validate([
      for (final record in contract.interestAdjustments)
        if (record.id != id) record.adjustment,
      adjustment,
    ], const []);
    final recordId = id ?? ids.newId();
    await records.save(
      InstallmentInterestAdjustment(
        id: recordId,
        contractId: contractId,
        adjustment: adjustment,
      ),
    );
    // 生成最终计息片段并校验完整单位；失败会回滚记录及计划。
    await plans.applyAutomaticChange(
      contractId,
      const RecalculateFromOperations(),
    );
    return recordId;
  });

  Future<void> delete(String contractId, String id) => runner.run(() async {
    final contract = await installments.findContract(contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    if (!contract.interestAdjustments.any((record) => record.id == id)) {
      throw BusinessException(
        CreditErrorCode.contractPersistenceConflict,
        message: '利息调整记录已不存在',
      );
    }
    await records.delete(contractId, id);
    await plans.applyAutomaticChange(
      contractId,
      const RecalculateFromOperations(),
    );
  });
}
