import 'package:rational/rational.dart';

import '../../valobj/day_count_convention.dart';
import '../../valobj/installment_enums.dart';
import '../../valobj/interest_rate.dart';

/// 一期的时间跨度：实际天数与还款节奏月数。
class AccrualPeriodSpan {
  const AccrualPeriodSpan({required this.days, required this.months});

  final int days;
  final int months;
}

/// 一期的期利率：[actual] 用于逐期计息，[nominal] 用于按标准公式求等额本息固定额。
///
/// 按日计息时二者不同（实际天数 vs 节奏月数 × 标准月天数），其余计息基础下相同。
class PeriodRate {
  const PeriodRate({required this.actual, required this.nominal});

  static final zero = PeriodRate(actual: Rational.zero, nominal: Rational.zero);

  final Rational actual;
  final Rational nominal;
}

/// 计息策略：把输入利率按标准天数换算到计息基础，再折算为每期的期利率。
///
/// 换算表：年 ↔ 月按 12；月 ↔ 日按 [DayCountConvention.daysPerMonth]；
/// 年 ↔ 日按 [DayCountConvention.daysPerYear]。
class InterestAccrualPolicy {
  const InterestAccrualPolicy({this.dayCount = DayCountConvention.thirty360});

  final DayCountConvention dayCount;

  Rational dailyRate(InterestRate rate) {
    return switch (rate.period) {
      InterestRatePeriod.annual =>
        rate.fraction / Rational.fromInt(dayCount.daysPerYear),
      InterestRatePeriod.monthly =>
        rate.fraction / Rational.fromInt(dayCount.daysPerMonth),
      InterestRatePeriod.daily => rate.fraction,
    };
  }

  Rational monthlyRate(InterestRate rate) {
    return switch (rate.period) {
      InterestRatePeriod.annual => rate.fraction / _twelve,
      InterestRatePeriod.monthly => rate.fraction,
      InterestRatePeriod.daily =>
        rate.fraction * Rational.fromInt(dayCount.daysPerMonth),
    };
  }

  Rational annualRate(InterestRate rate) {
    return switch (rate.period) {
      InterestRatePeriod.annual => rate.fraction,
      InterestRatePeriod.monthly => rate.fraction * _twelve,
      InterestRatePeriod.daily =>
        rate.fraction * Rational.fromInt(dayCount.daysPerYear),
    };
  }

  PeriodRate periodRate({
    required InterestRate? rate,
    required InterestAccrualMethod accrual,
    required AccrualPeriodSpan span,
  }) {
    if (rate == null || rate.isZero) return PeriodRate.zero;
    final months = Rational.fromInt(span.months);
    switch (accrual) {
      case InterestAccrualMethod.daily:
        return PeriodRate(
          actual: dailyRate(rate) * Rational.fromInt(span.days),
          nominal: monthlyRate(rate) * months,
        );
      case InterestAccrualMethod.monthly:
        final periodRate = monthlyRate(rate) * months;
        return PeriodRate(actual: periodRate, nominal: periodRate);
      case InterestAccrualMethod.annual:
        final periodRate = annualRate(rate) * months / _twelve;
        return PeriodRate(actual: periodRate, nominal: periodRate);
    }
  }
}

final Rational _twelve = Rational.fromInt(12);
