import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import '../../settlement/settlement_app_service.dart';

/// 在场景用例的顶层事务中清除分期及其来源、账单投影和计划。
class InstallmentContractRemovalAppService {
  InstallmentContractRemovalAppService({
    required InstallmentRepository installments,
    required BillRepository bills,
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
    InstallmentLifecycleService lifecycle = const InstallmentLifecycleService(),
    RepaymentPolicyService repaymentPolicy = const RepaymentPolicyService(),
  }) : _installments = installments,
       _bills = bills,
       _repayments = repayments,
       _ledger = ledger,
       _lifecycle = lifecycle,
       _repaymentPolicy = repaymentPolicy,
       _settlement = SettlementAppService(
         bills: bills,
         repayments: repayments,
         installments: installments,
       );

  final InstallmentRepository _installments;
  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final InstallmentLifecycleService _lifecycle;
  final RepaymentPolicyService _repaymentPolicy;
  final SettlementAppService _settlement;

  /// 调用方负责开启事务。
  Future<void> remove(InstallmentContract contract) async {
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contract.id,
    );
    _lifecycle.validateDelete(repayments: repayments, contract: contract);

    if (contract.installmentType == InstallmentType.billConversion) {
      await _removeBillConversionSource(contract);
    } else {
      final sourceTransactionId = contract.sourceRefId;
      if (sourceTransactionId != null) {
        await _ledger.deleteTransaction(sourceTransactionId);
      }
    }
    await _removeBillItems(contract);
    await _installments.deleteContract(contract.id);
  }

  Future<void> _removeBillConversionSource(InstallmentContract contract) async {
    final sourceRepaymentId = contract.sourceRefId;
    if (sourceRepaymentId == null) return;
    final sourceRepayment = await _repayments.findRepayment(sourceRepaymentId);
    if (sourceRepayment == null) return;
    final sourceBill = await _bills.findBill(sourceRepayment.targetId);
    if (sourceBill == null) {
      throw BusinessException(CreditErrorCode.billNotFound);
    }
    final allocations = _repaymentPolicy.allocationsFromItems(
      sourceRepayment.items,
    );
    await _repayments.deleteRepayment(sourceRepayment.id);
    await _settlement.refreshBillStatuses(sourceBill, allocations);
  }

  Future<void> _removeBillItems(InstallmentContract contract) async {
    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    for (final bill in bills) {
      final retained = [
        for (final item in bill.items)
          if (item.contractId != contract.id) item,
      ];
      if (retained.length == bill.items.length) continue;
      await _bills.replaceBillItems(bill.id, retained);
      if (bill.status == BillStatus.open) {
        bill.refreshOpenProjection(window: bill.window!, sourceItems: retained);
      } else {
        bill.synchronizeBilledItems(retained);
      }
      await _bills.updateBill(bill);
    }
  }
}
