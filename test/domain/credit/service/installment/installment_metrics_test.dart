import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_metrics.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

void main() {
  test('contract metrics ignore regular repayment actual amounts', () {
    const calculator = InstallmentMetricsCalculator();
    final metrics = calculator.compute(
      contract: _contract(),
      schedules: [
        _schedule(
          id: 'paid',
          periodNo: 1,
          principal: 4000,
          interest: 100,
          status: InstallmentScheduleStatus.paid,
        ),
        _schedule(id: 'pending', periodNo: 2, principal: 5000, interest: 200),
        _schedule(
          id: 'skipped',
          periodNo: 3,
          principal: 1000,
          status: InstallmentScheduleStatus.skipped,
        ),
      ],
      repayments: [
        RepaymentCashflow(
          id: 'regular',
          repaymentType: RepaymentType.bill,
          occurredAt: DateTime(2026, 2, 1),
          principal: const Money(minorUnits: 4000),
          interest: const Money(minorUnits: 999),
          fee: Money.zero(),
        ),
        RepaymentCashflow(
          id: 'prepayment',
          repaymentType: RepaymentType.prepayment,
          occurredAt: DateTime(2026, 2, 10),
          principal: const Money(minorUnits: 1000),
          interest: const Money(minorUnits: 50),
          fee: Money.zero(),
        ),
      ],
    );

    expect(metrics.totalRepayment, const Money(minorUnits: 10350));
    expect(metrics.totalInterest, const Money(minorUnits: 350));
  });
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'liability',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: 'cash',
    disbursementTransactionId: 'borrowing',
    principal: const Money(minorUnits: 10000),
    totalPeriods: 3,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 4, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentSchedule _schedule({
  required String id,
  required int periodNo,
  required int principal,
  int interest = 0,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: 'contract',
    periodNo: periodNo,
    expectedRepaymentDate: DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: Money(minorUnits: principal),
    expectedInterest: Money(minorUnits: interest),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}
