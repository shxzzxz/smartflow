import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

class CreditSettlementCoordinator {
  const CreditSettlementCoordinator({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    InstallmentLifecycleService lifecycle = const InstallmentLifecycleService(),
    InstallmentPrepaymentRecalculator prepaymentRecalculator =
        const InstallmentPrepaymentRecalculator(),
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments,
       _lifecycle = lifecycle,
       _prepaymentRecalculator = prepaymentRecalculator;

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final InstallmentLifecycleService _lifecycle;
  final InstallmentPrepaymentRecalculator _prepaymentRecalculator;

  Future<void> refreshBillStatuses(
    Bill bill,
    List<BillRepaymentAllocationDraft> allocations,
  ) async {
    final itemIds = allocations.map((allocation) => allocation.billItemId);
    final allocated = await _repayments.aggregateItemsByBillItemIds(itemIds);
    final result = bill.applyAllocations({
      for (final itemId in itemIds)
        itemId: (
          principalMinor: allocated[itemId]?.principal.minorUnits ?? 0,
          hasAllocation: allocated.containsKey(itemId),
        ),
    });
    await _bills.replaceBillItems(bill.id, bill.items);
    await refreshInstallmentStatuses(result.scheduleItemStatuses);
    await _bills.updateBill(bill);
  }

  Future<void> refreshInstallmentStatuses(
    Map<String, BillItemStatus> scheduleStatuses,
  ) async {
    if (scheduleStatuses.isEmpty) return;
    final touchedContractIds = <String>{};
    for (final scheduleId in scheduleStatuses.keys) {
      final schedule = await _installments.findSchedule(scheduleId);
      if (schedule != null) touchedContractIds.add(schedule.contractId);
    }

    for (final contractId in touchedContractIds) {
      final contract = await _installments.findContract(contractId);
      if (contract == null) continue;
      final schedules = await _installments.listSchedules(contractId);
      for (final schedule in schedules) {
        final billItemStatus = scheduleStatuses[schedule.id];
        if (billItemStatus != null) {
          schedule.applyBillItemStatus(billItemStatus);
        }
      }
      contract.refreshStatusFromSchedules(schedules);
      await _installments.saveAggregate(contract, schedules);
    }
  }

  Future<void> recalculateAllPendingSchedules(String contractId) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) return;

    final schedules = await _installments.listSchedules(contractId);
    final prepaymentPrincipalMinor = await prepaymentSumMinor(contractId);
    final recalculations = _prepaymentRecalculator.recalculateAllPending(
      contract: contract,
      schedules: schedules,
      prepaymentPrincipalMinor: prepaymentPrincipalMinor,
    );

    contract.reviseSchedules(
      schedules: schedules,
      revisions: [
        for (final recalculation in recalculations)
          InstallmentScheduleRevision(
            periodNo: recalculation.periodNo,
            expectedPrincipal: recalculation.expectedPrincipal,
            expectedInterest: recalculation.expectedInterest,
            expectedFee: recalculation.expectedFee,
            expectedRepaymentDate: recalculation.expectedRepaymentDate,
          ),
      ],
    );
    await _installments.saveAggregate(contract, schedules);
  }

  Future<int> prepaymentSumMinor(String contractId) async {
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contractId,
    );
    return _lifecycle.prepaymentPrincipalMinor(repayments);
  }

  Future<void> refreshContractStatus(String contractId) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) return;
    final schedules = await _installments.listSchedules(contractId);
    if (schedules.isEmpty) return;
    contract.refreshStatusFromSchedules(schedules);
    await _installments.saveAggregate(contract, schedules);
  }
}
