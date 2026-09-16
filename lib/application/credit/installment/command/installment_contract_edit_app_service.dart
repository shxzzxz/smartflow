import '../../../../core/error/app_exception.dart';
import '../../../../domain/credit/valobj/credit_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'installment_command.dart';
import 'installment_contract_app_service.dart';
import 'installment_plan_app_service.dart';

/// 编排合同详情与计划编辑的页面级用例。
///
/// 合同服务和计划服务各自只维护自己的能力；这里负责把一次编辑提交
/// 作为一个事务组合起来。
abstract interface class InstallmentContractEditAppService {
  Future<void> updateContract(UpdateContractCommand command);
}

class InstallmentContractEditAppServiceImpl
    implements InstallmentContractEditAppService {
  const InstallmentContractEditAppServiceImpl({
    required InstallmentContractAppService contracts,
    required InstallmentPlanAppService plans,
    required TransactionRunner runner,
  }) : _contracts = contracts,
       _plans = plans,
       _runner = runner;

  final InstallmentContractAppService _contracts;
  final InstallmentPlanAppService _plans;
  final TransactionRunner _runner;

  @override
  Future<void> updateContract(UpdateContractCommand command) =>
      _runner.run(() async {
        if (command.regeneratePlan) {
          final token = command.planPreviewToken;
          final terms = command.stageTerms;
          if (token == null || terms == null || command.borrowingDate != null) {
            throw BusinessException(
              CreditErrorCode.contractPersistenceConflict,
              message: '请按当前借款日期重新预览计划后保存',
            );
          }
          await _plans.recalculateContractPlan(
            RecalculateContractPlanCommand(
              contractId: command.contractId,
              stageTerms: terms,
              planPreviewToken: token,
            ),
          );
        } else if (command.stageTerms != null) {
          await _plans.updateTermsSnapshot(
            command.contractId,
            command.stageTerms!,
          );
        }

        if (command.schedulePatches.isNotEmpty) {
          await _plans.patchSchedule(
            PatchInstallmentScheduleCommand(
              contractId: command.contractId,
              schedulePatches: command.schedulePatches,
            ),
          );
        }

        await _contracts.updateContractDetails(
          UpdateContractDetailsCommand(
            contractId: command.contractId,
            name: command.name,
            borrowingDate: command.borrowingDate,
            disbursementAccountId: command.disbursementAccountId,
            note: command.note,
          ),
        );
      });
}
