import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/service/installment/installment_metrics.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  test(
    'contract metrics are available when schedule principal is conserved',
    () {
      const calculator = InstallmentMetricsCalculator();
      final metrics = calculator.compute(
        contract: _contract(),
        schedules: [
          _schedule(id: 'one', periodNo: 1, principal: 4000, interest: 100),
          _schedule(id: 'two', periodNo: 2, principal: 3000, interest: 100),
          _schedule(id: 'three', periodNo: 3, principal: 3000, interest: 100),
        ],
      );

      expect(metrics.isAvailable, isTrue);
      expect(metrics.unavailableReason, isNull);
      expect(metrics.monthlyIrr, isNotNull);
      expect(metrics.nominalApr, isNotNull);
      expect(metrics.effectiveApr, isNotNull);
    },
  );

  test('contract metrics are unavailable when schedule principal is short', () {
    const calculator = InstallmentMetricsCalculator();
    final metrics = calculator.compute(
      contract: _contract(),
      schedules: [
        _schedule(id: 'one', periodNo: 1, principal: 4000),
        _schedule(id: 'two', periodNo: 2, principal: 3000),
        _schedule(id: 'three', periodNo: 3, principal: 2999),
      ],
    );

    expect(metrics.isAvailable, isFalse);
    expect(
      metrics.unavailableReason,
      ContractMetricsUnavailableReason.principalNotConserved,
    );
    expect(metrics.monthlyIrr, isNull);
    expect(metrics.nominalApr, isNull);
    expect(metrics.effectiveApr, isNull);
  });

  test(
    'contract metrics are unavailable when schedule principal is excessive',
    () {
      const calculator = InstallmentMetricsCalculator();
      final metrics = calculator.compute(
        contract: _contract(),
        schedules: [
          _schedule(id: 'one', periodNo: 1, principal: 4000),
          _schedule(id: 'two', periodNo: 2, principal: 3000),
          _schedule(id: 'three', periodNo: 3, principal: 3001),
        ],
      );

      expect(metrics.isAvailable, isFalse);
      expect(
        metrics.unavailableReason,
        ContractMetricsUnavailableReason.principalNotConserved,
      );
    },
  );

  test('contract metrics report insufficient cashflows without fake rates', () {
    const calculator = InstallmentMetricsCalculator();
    final metrics = calculator.compute(
      contract: _contract(),
      schedules: [
        _schedule(
          id: 'zero-outflow',
          periodNo: 1,
          principal: 10000,
          interest: -10000,
        ),
      ],
    );

    expect(metrics.isAvailable, isFalse);
    expect(
      metrics.unavailableReason,
      ContractMetricsUnavailableReason.insufficientCashflows,
    );
    expect(metrics.monthlyIrr, isNull);
  });

  test(
    'contract metrics report no rate solution without fallback estimates',
    () {
      const calculator = InstallmentMetricsCalculator();
      final metrics = calculator.compute(
        contract: _contract(),
        schedules: [
          _schedule(
            id: 'same-day',
            periodNo: 1,
            principal: 10000,
            date: DateTime(2026, 1, 1),
          ),
        ],
      );

      expect(metrics.isAvailable, isFalse);
      expect(
        metrics.unavailableReason,
        ContractMetricsUnavailableReason.noRateSolution,
      );
      expect(metrics.effectiveApr, isNull);
    },
  );

  test('schedule status changes do not change contract metrics', () {
    const calculator = InstallmentMetricsCalculator();
    final pendingMetrics = calculator.compute(
      contract: _contract(),
      schedules: [
        _schedule(id: 'one', periodNo: 1, principal: 4000, interest: 100),
        _schedule(id: 'two', periodNo: 2, principal: 3000, interest: 100),
        _schedule(id: 'three', periodNo: 3, principal: 3000, interest: 100),
      ],
    );
    final projectedMetrics = calculator.compute(
      contract: _contract(),
      schedules: [
        _schedule(
          id: 'one',
          periodNo: 1,
          principal: 4000,
          interest: 100,
          status: InstallmentScheduleStatus.partiallyPaid,
        ),
        _schedule(
          id: 'two',
          periodNo: 2,
          principal: 3000,
          interest: 100,
          status: InstallmentScheduleStatus.paid,
        ),
        _schedule(
          id: 'three',
          periodNo: 3,
          principal: 3000,
          interest: 100,
          status: InstallmentScheduleStatus.skipped,
        ),
      ],
    );

    expect(projectedMetrics.totalRepayment, pendingMetrics.totalRepayment);
    expect(projectedMetrics.totalInterest, pendingMetrics.totalInterest);
    expect(
      projectedMetrics.monthlyIrr,
      closeTo(pendingMetrics.monthlyIrr!, 1e-12),
    );
    expect(
      projectedMetrics.nominalApr,
      closeTo(pendingMetrics.nominalApr!, 1e-12),
    );
    expect(
      projectedMetrics.effectiveApr,
      closeTo(pendingMetrics.effectiveApr!, 1e-12),
    );
  });

  test('contract metrics depend only on planned cashflows', () {
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
    );

    expect(metrics.totalRepayment, const Money(minorUnits: 10300));
    expect(metrics.totalInterest, const Money(minorUnits: 300));
    expect(metrics.isAvailable, isTrue);
    expect(metrics.unavailableReason, isNull);
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
  DateTime? date,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: 'contract',
    periodNo: periodNo,
    expectedRepaymentDate: date ?? DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: Money(minorUnits: principal),
    expectedInterest: Money(minorUnits: interest),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}
