import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

class SettlementJudgementService {
  const SettlementJudgementService();

  BillItemStatus judgeBillItem({
    required int expectedPrincipalMinor,
    required int allocatedPrincipalMinor,
    required bool hasAllocation,
  }) {
    if (allocatedPrincipalMinor >= expectedPrincipalMinor) {
      return BillItemStatus.paid;
    }
    return hasAllocation
        ? BillItemStatus.partiallyPaid
        : BillItemStatus.pending;
  }

  BillStatus projectBillStatus(
    BillStatus current,
    Iterable<BillItemStatus> itemStatuses,
  ) {
    if (current == BillStatus.open) return BillStatus.open;
    return itemStatuses.any(
          (status) =>
              status == BillItemStatus.pending ||
              status == BillItemStatus.partiallyPaid,
        )
        ? BillStatus.billed
        : BillStatus.settled;
  }

  InstallmentScheduleStatus projectScheduleStatus(BillItemStatus itemStatus) {
    return switch (itemStatus) {
      BillItemStatus.paid => InstallmentScheduleStatus.paid,
      BillItemStatus.partiallyPaid => InstallmentScheduleStatus.partiallyPaid,
      BillItemStatus.pending => InstallmentScheduleStatus.pending,
      BillItemStatus.skipped => InstallmentScheduleStatus.skipped,
    };
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
