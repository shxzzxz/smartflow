import '../../../../core/money/money.dart';
import '../../entity/bill.dart';
import '../../port/bill_repository.dart';
import '../../port/installment_repository.dart';
import '../../port/repayment_repository.dart';
import '../../valobj/bill_enums.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/repayment_amount_breakdown.dart';

class CreditDebtBuckets {
  const CreditDebtBuckets({
    required this.billDebt,
    required this.futureContractDebt,
    required this.unattributedDebt,
  });

  final Money billDebt;
  final Money futureContractDebt;
  final Money unattributedDebt;
}

class CreditDebtBucketService {
  const CreditDebtBucketService();

  Future<CreditDebtBuckets> bucketsForAccount({
    required String accountId,
    required Money liabilityBalance,
    required BillRepository bills,
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
  }) async {
    final accountBills = await bills.listBillsByAccount(accountId);
    final outstandingBillItems = [
      for (final bill in accountBills)
        for (final item in bill.items)
          if (_isOutstandingItem(item)) item,
    ];
    final allocatedByItemId = await repayments.aggregateItemsByBillItemIds(
      outstandingBillItems.map((item) => item.id),
    );
    final projectedScheduleIds = {
      for (final item in outstandingBillItems)
        if (item.scheduleId != null) item.scheduleId!,
    };
    final outstandingSchedules =
        (await installments.listSchedulesByLiabilityAccount(accountId))
            .where(
              (schedule) =>
                  schedule.status == InstallmentScheduleStatus.pending ||
                  schedule.status == InstallmentScheduleStatus.partiallyPaid,
            )
            .toList();
    final projectedRemainingPrincipalByScheduleId = <String, int>{};
    var pendingBillConsumptionPrincipal = 0;
    var billDebt = 0;
    for (final item in outstandingBillItems) {
      final remaining = remainingPrincipalForBillItem(
        item,
        allocatedPrincipalMinor:
            allocatedByItemId[item.id]?.principal.minorUnits ?? 0,
      );
      billDebt += remaining;
      if (item.itemType == BillItemType.consumption) {
        pendingBillConsumptionPrincipal += remaining;
      }
      final scheduleId = item.scheduleId;
      if (scheduleId != null) {
        projectedRemainingPrincipalByScheduleId[scheduleId] = remaining;
      }
    }
    final pendingContractPrincipal = outstandingSchedules.fold<int>(0, (
      sum,
      schedule,
    ) {
      return sum +
          (projectedRemainingPrincipalByScheduleId[schedule.id] ??
              schedule.expectedPrincipal.minorUnits);
    });
    final futureContractDebt = outstandingSchedules
        .where((schedule) => !projectedScheduleIds.contains(schedule.id))
        .fold<int>(
          0,
          (sum, schedule) => sum + schedule.expectedPrincipal.minorUnits,
        );
    return CreditDebtBuckets(
      billDebt: Money(minorUnits: billDebt),
      futureContractDebt: Money(minorUnits: futureContractDebt),
      unattributedDebt: unattributedDebt(
        liabilityBalance: liabilityBalance,
        pendingContractPrincipalMinor: pendingContractPrincipal,
        pendingBillConsumptionPrincipalMinor: pendingBillConsumptionPrincipal,
      ),
    );
  }

  Future<Money> pendingPrincipalForBill(
    Bill bill, {
    required RepaymentRepository repayments,
  }) async {
    final outstandingItems = bill.items.where(_isOutstandingItem).toList();
    final allocatedByItemId = await repayments.aggregateItemsByBillItemIds(
      outstandingItems.map((item) => item.id),
    );
    var total = 0;
    for (final item in outstandingItems) {
      total += remainingPrincipalForBillItem(
        item,
        allocatedPrincipalMinor:
            allocatedByItemId[item.id]?.principal.minorUnits ?? 0,
      );
    }
    return Money(minorUnits: total);
  }

  int remainingPrincipalForBillItem(
    BillItem item, {
    required int allocatedPrincipalMinor,
  }) {
    if (!_isOutstandingItem(item)) return 0;
    return remainingPrincipal(
      expectedPrincipalMinor: item.expectedPrincipal.minorUnits,
      allocatedPrincipalMinor: allocatedPrincipalMinor,
    );
  }

  /// 明细待还总额：本息费各自剩余之和再扣减优惠，整体下限为 0。
  int remainingTotalForBillItem(
    BillItem item, {
    required RepaymentAmountBreakdown allocated,
  }) {
    if (!_isOutstandingItem(item)) return 0;
    final remaining =
        item.expectedPrincipal.minorUnits -
        allocated.principal.minorUnits +
        item.expectedInterest.minorUnits -
        allocated.interest.minorUnits +
        item.expectedFee.minorUnits -
        allocated.fee.minorUnits -
        allocated.discount.minorUnits;
    return remaining < 0 ? 0 : remaining;
  }

  bool _isOutstandingItem(BillItem item) {
    return item.status == BillItemStatus.pending ||
        item.status == BillItemStatus.partiallyPaid;
  }

  int remainingPrincipal({
    required int expectedPrincipalMinor,
    required int allocatedPrincipalMinor,
  }) {
    final remaining = expectedPrincipalMinor - allocatedPrincipalMinor;
    return remaining < 0 ? 0 : remaining;
  }

  Money unattributedDebt({
    required Money liabilityBalance,
    required int pendingContractPrincipalMinor,
    required int pendingBillConsumptionPrincipalMinor,
  }) {
    return Money(
      minorUnits:
          liabilityBalance.minorUnits -
          pendingContractPrincipalMinor -
          pendingBillConsumptionPrincipalMinor,
    );
  }
}
