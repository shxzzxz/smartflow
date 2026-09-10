import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';

/// 核销事实的加载、领域行为调用与持久化；由还款用例提供事务。
/// 核销判断和状态投影属于 domain，此处不计算计划或自行判定状态。
class SettlementAppService {
  const SettlementAppService({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments;

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;

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
}
