import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/feature/credit/presentation/loan_calculator_presentation.dart';

void main() {
  test('maps installment amount modes to domain values', () {
    expect(
      equalInstallmentAmountFor(EqualInstallmentAmountMode.nominalRate),
      const EqualInstallmentAmount.nominalRate(),
    );
    expect(
      equalInstallmentAmountFor(EqualInstallmentAmountMode.actualRate),
      const EqualInstallmentAmount.actualRate(),
    );
    expect(
      equalInstallmentAmountFor(
        EqualInstallmentAmountMode.fixed,
        fixedAmount: const Money(minorUnits: 123),
      ),
      const EqualInstallmentAmount.fixed(Money(minorUnits: 123)),
    );
  });

  test('labels cover every option', () {
    for (final method in InstallmentRepaymentMethod.values) {
      expect(loanRepaymentMethodLabel(method), isNotEmpty);
    }
    for (final accrual in InterestAccrualMethod.values) {
      expect(interestAccrualMethodLabel(accrual), isNotEmpty);
    }
    for (final rounding in RoundingMode.values) {
      expect(roundingModeLabel(rounding), isNotEmpty);
    }
    expect(interestAccrualMethodLabel(InterestAccrualMethod.annual), '按年计息');
    expect(
      dayCountConventionLabel(DayCountConvention.thirty365),
      '月 30 天 / 年 365 天',
    );
  });

  test('formats percentages and signed differences', () {
    expect(formatRatePercent(0.0123), '1.23%');
    expect(formatRatePercent(0.0123, fractionDigits: 4), '1.2300%');
    expect(formatRatePercent(null), '—');
    expect(formatSignedMoney(const Money(minorUnits: 52)), '+0.52');
    expect(formatSignedMoney(const Money(minorUnits: -5)), '-0.05');
    expect(formatSignedMoney(Money.zero()), '0.00');
  });

  test('period breakdown omits zero interest and fee', () {
    final period = LoanCalculationPeriod(
      periodNo: 1,
      date: DateTime(2026, 2, 1),
      principal: const Money(minorUnits: 10000),
      interest: Money.zero(),
      fee: const Money(minorUnits: 880),
      remainingPrincipal: const Money(minorUnits: 110000),
    );

    expect(loanPeriodBreakdownText(period), '本金 100.00  手续费 8.80');
    expect(period.total, const Money(minorUnits: 10880));
  });
}
