import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  group('Bill aggregate behavior', () {
    test('applyAllocations settles items and projects bill status', () {
      final bill = Bill(
        id: 'bill',
        accountId: 'credit',
        period: BillPeriod(year: 2026, month: 7),
        status: BillStatus.billed,
        items: [
          _billItem(id: 'item-1', principalMinor: 1000),
          _billItem(id: 'item-2', principalMinor: 500, scheduleId: 'schedule'),
        ],
      );

      final result = bill.applyAllocations({
        'item-1': (principalMinor: 1000, hasAllocation: true),
        'item-2': (principalMinor: 499, hasAllocation: true),
      });

      expect(bill.items[0].status, BillItemStatus.paid);
      expect(bill.items[1].status, BillItemStatus.partiallyPaid);
      expect(bill.status, BillStatus.billed);
      expect(result.scheduleItemStatuses, {
        'schedule': BillItemStatus.partiallyPaid,
      });

      bill.applyAllocations({
        'item-2': (principalMinor: 500, hasAllocation: true),
      });

      expect(bill.items[1].status, BillItemStatus.paid);
      expect(bill.status, BillStatus.settled);
    });
  });

  group('CreditLiabilityAccount cycle behavior', () {
    test('derives current period and bill window from account parameters', () {
      final account = CreditLiabilityAccount(
        id: 'extension',
        accountId: 'credit',
        kind: CreditLiabilityAccountKind.credit,
        billingDay: 5,
        repaymentDay: 20,
        billingDayToNext: true,
      );

      expect(
        account.creditPeriodForDate(DateTime(2026, 7, 4)),
        BillPeriod(year: 2026, month: 7),
      );
      expect(
        account.creditPeriodForDate(DateTime(2026, 7, 5)),
        BillPeriod(year: 2026, month: 8),
      );

      final window = account.nextCreditBillWindow(
        BillPeriod(year: 2026, month: 7),
      );

      expect(window.startDate, DateTime(2026, 6, 5));
      expect(window.billingDate, DateTime(2026, 7, 5));
      expect(window.repaymentDate, DateTime(2026, 7, 20));
      expect(account.effectiveCreditWindowStart(window), window.startDate);
      expect(account.effectiveCreditWindowEnd(window), window.billingDate);
    });
  });

  group('Installment aggregate behavior', () {
    test('schedule status changes project contract status', () {
      final contract = _contract();
      final schedules = [
        _schedule(id: 's1', status: InstallmentScheduleStatus.pending),
        _schedule(id: 's2', status: InstallmentScheduleStatus.skipped),
      ];

      contract.markSchedulePaid(schedules.first, schedules: schedules);

      expect(schedules.first.status, InstallmentScheduleStatus.paid);
      expect(contract.status, InstallmentContractStatus.settled);

      schedules.last.restore();
      contract.refreshStatusFromSchedules(schedules);

      expect(schedules.last.status, InstallmentScheduleStatus.pending);
      expect(contract.status, InstallmentContractStatus.active);
    });
  });
}

BillItem _billItem({
  required String id,
  required int principalMinor,
  String? scheduleId,
}) {
  return BillItem(
    id: id,
    billId: 'bill',
    itemType:
        scheduleId == null
            ? BillItemType.consumption
            : BillItemType.installment,
    contractId: scheduleId == null ? null : 'contract',
    scheduleId: scheduleId,
    repaymentDate: DateTime(2026, 7, 20),
    expectedPrincipal: Money(minorUnits: principalMinor),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: BillItemStatus.pending,
  );
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'credit',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 1000),
    totalPeriods: 2,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 3, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentSchedule _schedule({
  required String id,
  required InstallmentScheduleStatus status,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: 'contract',
    periodNo: id == 's1' ? 1 : 2,
    expectedRepaymentDate: DateTime(2026, id == 's1' ? 2 : 3, 1),
    expectedPrincipal: const Money(minorUnits: 500),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}
