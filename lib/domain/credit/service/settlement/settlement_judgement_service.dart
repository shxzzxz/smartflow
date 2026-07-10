import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
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

  BillStatus projectBillStatus(BillStatus current, List<BillItem> items) {
    if (current == BillStatus.open) return BillStatus.open;
    return items.any(
          (item) =>
              item.status == BillItemStatus.pending ||
              item.status == BillItemStatus.partiallyPaid,
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
    required List<InstallmentSchedule> schedules,
  }) {
    if (schedules.isEmpty) return current;
    final hasOutstanding = schedules.any(
      (schedule) =>
          schedule.status == InstallmentScheduleStatus.pending ||
          schedule.status == InstallmentScheduleStatus.partiallyPaid,
    );
    if (hasOutstanding) return InstallmentContractStatus.active;
    final allDone = schedules.every(
      (schedule) =>
          schedule.status == InstallmentScheduleStatus.paid ||
          schedule.status == InstallmentScheduleStatus.skipped,
    );
    return allDone ? InstallmentContractStatus.settled : current;
  }
}
