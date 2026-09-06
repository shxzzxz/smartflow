import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';
import 'package:smartflow/domain/credit/service/installment/interest_accrual_policy.dart';
import 'package:smartflow/domain/credit/valobj/day_count_convention.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/interest_rate.dart';

Rational _r(int numerator, int denominator) {
  return Rational(BigInt.from(numerator), BigInt.from(denominator));
}

void main() {
  const annual = InterestRate(ppm: 72000, period: InterestRatePeriod.annual);
  const monthly = InterestRate(ppm: 10000, period: InterestRatePeriod.monthly);
  const daily = InterestRate(ppm: 200, period: InterestRatePeriod.daily);

  group('rate conversion with 30/360', () {
    const policy = InterestAccrualPolicy();

    test('annual converts by 12 and by days per year', () {
      expect(policy.monthlyRate(annual), _r(72000, 12000000));
      expect(policy.dailyRate(annual), _r(72000, 360000000));
      expect(policy.annualRate(annual), _r(72000, 1000000));
    });

    test('monthly converts by days per month', () {
      expect(policy.dailyRate(monthly), _r(10000, 30000000));
      expect(policy.annualRate(monthly), _r(120000, 1000000));
    });

    test('daily converts by days per month and days per year', () {
      expect(policy.monthlyRate(daily), _r(6000, 1000000));
      expect(policy.annualRate(daily), _r(72000, 1000000));
    });
  });

  test('30/365 changes only the annual to daily conversion', () {
    const policy = InterestAccrualPolicy(
      dayCount: DayCountConvention.thirty365,
    );
    expect(policy.dailyRate(annual), _r(72000, 365000000));
    expect(policy.monthlyRate(annual), _r(72000, 12000000));
    expect(policy.dailyRate(monthly), _r(10000, 30000000));
  });

  group('period rate', () {
    const policy = InterestAccrualPolicy();

    test('daily basis uses actual days and nominal months', () {
      final rate = policy.periodRate(
        rate: monthly,
        accrual: InterestAccrualMethod.daily,
        span: const AccrualPeriodSpan(days: 45, months: 1),
      );
      expect(rate.actual, _r(15, 1000));
      expect(rate.nominal, _r(10, 1000));
    });

    test('monthly basis counts rhythm months regardless of days', () {
      final rate = policy.periodRate(
        rate: monthly,
        accrual: InterestAccrualMethod.monthly,
        span: const AccrualPeriodSpan(days: 45, months: 3),
      );
      expect(rate.actual, _r(30, 1000));
      expect(rate.nominal, rate.actual);
    });

    test('annual basis counts months over twelve', () {
      final rate = policy.periodRate(
        rate: annual,
        accrual: InterestAccrualMethod.annual,
        span: const AccrualPeriodSpan(days: 365, months: 12),
      );
      expect(rate.actual, _r(72, 1000));
      final quarterly = policy.periodRate(
        rate: annual,
        accrual: InterestAccrualMethod.annual,
        span: const AccrualPeriodSpan(days: 90, months: 3),
      );
      expect(quarterly.actual, _r(18, 1000));
    });

    test('missing or zero rate is interest free', () {
      final missing = policy.periodRate(
        rate: null,
        accrual: InterestAccrualMethod.daily,
        span: const AccrualPeriodSpan(days: 30, months: 1),
      );
      expect(missing.actual, Rational.zero);
      final zero = policy.periodRate(
        rate: const InterestRate(ppm: 0, period: InterestRatePeriod.annual),
        accrual: InterestAccrualMethod.monthly,
        span: const AccrualPeriodSpan(days: 30, months: 1),
      );
      expect(zero.nominal, Rational.zero);
    });
  });
}
