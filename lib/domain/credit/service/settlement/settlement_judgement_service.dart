import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

class SettlementJudgementService {
  const SettlementJudgementService();

  BillItemStatus judgeBillItem({
    required int expectedPrincipalMinor,
    required int allocatedPrincipalMinor,
    required bool hasAllocation,
    required bool hasExpectedRepayment,
  }) {
    if (!hasAllocation) {
      return hasExpectedRepayment
          ? BillItemStatus.pending
          : BillItemStatus.paid;
    }
    if (allocatedPrincipalMinor >= expectedPrincipalMinor) {
      return BillItemStatus.paid;
    }
    return BillItemStatus.partiallyPaid;
  }

  BillStatus projectBillStatus(
    BillStatus current,
    Iterable<BillItemStatus> itemStatuses, {
    bool hasOpenConsumption = false,
  }) {
    final statuses = itemStatuses.toList(growable: false);
    // Billing lifecycle is independent from settlement. An open consumption
    // projection keeps the aggregate open even when its amount is zero,
    // paid, or overpaid.
    if (hasOpenConsumption) return BillStatus.open;
    final hasOutstanding = statuses.any(
      (status) =>
          status == BillItemStatus.pending ||
          status == BillItemStatus.partiallyPaid,
    );
    if (!hasOutstanding) return BillStatus.settled;
    return BillStatus.billed;
  }

  InstallmentScheduleStatus projectScheduleStatus(BillItemStatus itemStatus) {
    return switch (itemStatus) {
      BillItemStatus.paid => InstallmentScheduleStatus.paid,
      BillItemStatus.overpaid => InstallmentScheduleStatus.paid,
      BillItemStatus.partiallyPaid => InstallmentScheduleStatus.partiallyPaid,
      BillItemStatus.pending => InstallmentScheduleStatus.pending,
      BillItemStatus.skipped => InstallmentScheduleStatus.skipped,
    };
  }

  InstallmentScheduleStatus judgeScheduleFromRepayment({
    required int expectedPrincipalMinor,
    required int allocatedPrincipalMinor,
    required bool hasAllocation,
  }) {
    if (!hasAllocation) return InstallmentScheduleStatus.pending;
    if (allocatedPrincipalMinor >= expectedPrincipalMinor) {
      return InstallmentScheduleStatus.paid;
    }
    return InstallmentScheduleStatus.partiallyPaid;
  }

  InstallmentContractStatus projectContractStatus({
    required InstallmentContractStatus current,
    required Iterable<InstallmentScheduleStatus> scheduleStatuses,
  }) {
    final statuses = scheduleStatuses.toList(growable: false);
    if (statuses.isEmpty) return current;
    final hasOutstanding = statuses.any(
      (status) =>
          status == InstallmentScheduleStatus.pending ||
          status == InstallmentScheduleStatus.partiallyPaid,
    );
    if (hasOutstanding) return InstallmentContractStatus.active;
    final allDone = statuses.every(
      (status) =>
          status == InstallmentScheduleStatus.paid ||
          status == InstallmentScheduleStatus.skipped,
    );
    return allDone ? InstallmentContractStatus.settled : current;
  }
}
