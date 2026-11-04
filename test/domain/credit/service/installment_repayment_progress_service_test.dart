import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_repayment_progress_service.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';

void main() {
  const service = InstallmentRepaymentProgressService();

  test('derives period progress and remaining principal from plan facts', () {
    final contract = _contract([
      _schedule(1, status: InstallmentScheduleStatus.paid),
      _schedule(2, status: InstallmentScheduleStatus.partiallyPaid),
      _schedule(3),
    ]);

    final progress = service.project(
      installment: contract,
      allocatedByScheduleId: {
        'schedule-2': _breakdown(principal: 50, interest: 5, fee: 2),
      },
      repayments: [
        _breakdown(principal: 150, interest: 20, fee: 5, discount: 2),
      ],
    );

    expect(progress.completedPeriodCount, 1);
    expect(progress.totalPeriodCount, 3);
    expect(progress.remainingPrincipal, const Money(minorUnits: 150));
    expect(
      progress.repaid,
      _breakdown(principal: 150, interest: 20, fee: 5, discount: 2),
    );
  });

  test(
    'counts skipped periods as completed without consuming remaining principal',
    () {
      final contract = _contract([
        _schedule(1, status: InstallmentScheduleStatus.skipped),
        _schedule(2),
      ]);

      final progress = service.project(
        installment: contract,
        allocatedByScheduleId: const {},
        repayments: const [],
      );

      expect(progress.completedPeriodCount, 1);
      expect(progress.totalPeriodCount, 2);
      expect(progress.remainingPrincipal, const Money(minorUnits: 100));
    },
  );
}

InstallmentContract _contract(List<InstallmentSchedule> schedules) {
  return InstallmentContract(
    id: 'installment-1',
    liabilityAccountId: 'credit-account',
    installmentType: InstallmentType.purchase,
    sourceRefId: 'purchase-transaction',
    principal: const Money(minorUnits: 300),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'stage-1',
      totalPeriods: schedules.length,
      firstDate: DateTime(2026, 2, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.monthly,
    ),
    schedules: schedules,
  );
}

InstallmentSchedule _schedule(
  int periodNo, {
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentSchedule(
    id: 'schedule-$periodNo',
    contractId: 'installment-1',
    periodNo: periodNo,
    expectedRepaymentDate: DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: const Money(minorUnits: 100),
    expectedInterest: const Money(minorUnits: 10),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

RepaymentAmountBreakdown _breakdown({
  required int principal,
  int interest = 0,
  int fee = 0,
  int discount = 0,
}) {
  return RepaymentAmountBreakdown(
    principal: Money(minorUnits: principal),
    interest: Money(minorUnits: interest),
    fee: Money(minorUnits: fee),
    discount: Money(minorUnits: discount),
  );
}
