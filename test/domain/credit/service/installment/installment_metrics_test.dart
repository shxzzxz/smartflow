import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/service/installment/installment_metrics.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';

void main() {
  const calculator = InstallmentMetricsCalculator();
  final principal = const Money(minorUnits: 10000);
  final borrowingDate = DateTime(2026, 1, 1);

  ContractMetrics compute(List<InstallmentSchedulePlanEntry> plan) {
    return calculator.compute(
      principal: principal,
      borrowingDate: borrowingDate,
      plan: plan,
    );
  }

  test('contract metrics are available when plan principal is conserved', () {
    final metrics = compute([
      _entry(periodNo: 1, principal: 4000, interest: 100),
      _entry(periodNo: 2, principal: 3000, interest: 100),
      _entry(periodNo: 3, principal: 3000, interest: 100),
    ]);

    expect(metrics.isAvailable, isTrue);
    expect(metrics.unavailableReason, isNull);
    expect(metrics.monthlyIrr, isNotNull);
    expect(metrics.nominalApr, isNotNull);
    expect(metrics.effectiveApr, isNotNull);
    expect(metrics.totalRepayment, const Money(minorUnits: 10300));
    expect(metrics.totalInterest, const Money(minorUnits: 300));
  });

  test('contract metrics are unavailable when plan principal is short', () {
    final metrics = compute([
      _entry(periodNo: 1, principal: 4000),
      _entry(periodNo: 2, principal: 3000),
      _entry(periodNo: 3, principal: 2999),
    ]);

    expect(metrics.isAvailable, isFalse);
    expect(
      metrics.unavailableReason,
      ContractMetricsUnavailableReason.principalNotConserved,
    );
    expect(metrics.monthlyIrr, isNull);
    expect(metrics.nominalApr, isNull);
    expect(metrics.effectiveApr, isNull);
  });

  test('contract metrics are unavailable when plan principal is excessive', () {
    final metrics = compute([
      _entry(periodNo: 1, principal: 4000),
      _entry(periodNo: 2, principal: 3000),
      _entry(periodNo: 3, principal: 3001),
    ]);

    expect(metrics.isAvailable, isFalse);
    expect(
      metrics.unavailableReason,
      ContractMetricsUnavailableReason.principalNotConserved,
    );
  });

  test('contract metrics report insufficient cashflows without fake rates', () {
    final metrics = compute([
      _entry(periodNo: 1, principal: 10000, interest: -10000),
    ]);

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
      final metrics = compute([
        _entry(periodNo: 1, principal: 10000, date: DateTime(2026, 1, 1)),
      ]);

      expect(metrics.isAvailable, isFalse);
      expect(
        metrics.unavailableReason,
        ContractMetricsUnavailableReason.noRateSolution,
      );
      expect(metrics.effectiveApr, isNull);
    },
  );

  test('monthly irr of a 1% per month equal installment plan is 1%', () {
    // 12000 借 12 期、月利率 1%，标准月供 1066.19。
    const principals = [
      94619,
      95565,
      96521,
      97486,
      98461,
      99446,
      100440,
      101444,
      102459,
      103483,
      104518,
      105558,
    ];
    const interests = [
      12000,
      11054,
      10098,
      9133,
      8158,
      7173,
      6179,
      5175,
      4160,
      3136,
      2101,
      1056,
    ];
    final metrics = calculator.compute(
      principal: const Money(minorUnits: 1200000),
      borrowingDate: DateTime(2026, 1, 10),
      plan: [
        for (var i = 0; i < 12; i++)
          InstallmentSchedulePlanEntry(
            periodNo: i + 1,
            expectedRepaymentDate: DateTime(2026, 2 + i, 10),
            expectedPrincipal: Money(minorUnits: principals[i]),
            expectedInterest: Money(minorUnits: interests[i]),
            expectedFee: Money.zero(),
          ),
      ],
    );

    expect(metrics.isAvailable, isTrue);
    expect(metrics.monthlyIrr, closeTo(0.01, 0.0015));
  });
}

InstallmentSchedulePlanEntry _entry({
  required int periodNo,
  required int principal,
  int interest = 0,
  DateTime? date,
}) {
  return InstallmentSchedulePlanEntry(
    periodNo: periodNo,
    expectedRepaymentDate: date ?? DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: Money(minorUnits: principal),
    expectedInterest: Money(minorUnits: interest),
    expectedFee: Money.zero(),
  );
}
