import 'package:rational/rational.dart';

import '../../../../../core/money/money.dart';
import '../../../valobj/day_count_convention.dart';
import '../../../valobj/installment_enums.dart';
import '../../../valobj/interest_rate.dart';
import '../../../valobj/interest_accrual_segment.dart';
import '../../../valobj/reference_rate.dart';
import '../../../valobj/repayment_dates_strategy.dart';

/// 一期的时间跨度：实际天数与还款节奏月数。
class AccrualPeriodSpan {
  const AccrualPeriodSpan({required this.days, required this.months});

  final int days;
  final int months;
}

/// 合同时间安排中的完整计息单位，首尾日期包含不规则首期和末期。
class AccrualUnit {
  const AccrualUnit({
    required this.start,
    required this.end,
    required this.startMonth,
    required this.endMonth,
  });

  final DateTime start, end;
  final int startMonth, endMonth;
}

/// 一期的期利率：[actual] 用于逐期计息，[nominal] 用于按标准公式求等额本息固定额。
///
/// 按日计息时二者不同（实际天数 vs 节奏月数 × 标准月天数），其余计息基础下相同。
class PeriodRate {
  const PeriodRate({
    required this.actual,
    required this.nominal,
    this.segments = const [],
  });

  static final zero = PeriodRate(actual: Rational.zero, nominal: Rational.zero);

  final Rational actual;
  final Rational nominal;
  final List<AccrualRateSegment> segments;

  List<InterestAccrualSegment> interestSegments(Money principal) => [
    for (final segment in segments) segment.forPrincipal(principal),
  ];
}

class AccrualRateSegment {
  const AccrualRateSegment({
    required this.start,
    required this.end,
    required this.rate,
    required this.accrual,
    required this.dayCount,
    required this.factor,
    DateTime? unitStart,
    DateTime? unitEnd,
  }) : unitStart = unitStart ?? start,
       unitEnd = unitEnd ?? end;

  final DateTime start, end;
  final DateTime unitStart, unitEnd;
  final InterestRate? rate;
  final InterestAccrualMethod accrual;
  final DayCountConvention dayCount;
  final Rational factor;

  InterestAccrualSegment forPrincipal(Money principal) =>
      InterestAccrualSegment(
        start: start,
        end: end,
        principal: principal,
        rate: rate,
        accrual: accrual,
        dayCount: dayCount,
        exactInterestMinor: Rational.fromInt(principal.minorUnits) * factor,
        unitStart: unitStart,
        unitEnd: unitEnd,
      );
}

/// 计息策略：把输入利率按标准天数换算到计息基础，再折算为每期的期利率。
///
/// 换算表：年 ↔ 月按 12；月 ↔ 日按 [DayCountConvention.daysPerMonth]；
/// 年 ↔ 日按 [DayCountConvention.daysPerYear]。
class InterestAccrualPolicy {
  const InterestAccrualPolicy({this.dayCount = DayCountConvention.thirty360});

  final DayCountConvention dayCount;

  /// 日期边界与计划共用同一时间安排；日计息直接按实际覆盖天数处理。
  List<AccrualUnit> unitsFor({
    required InterestAccrualMethod accrual,
    required DateTime start,
    required List<DateTime> dates,
    required int intervalMonths,
  }) {
    if (accrual == InterestAccrualMethod.daily || dates.isEmpty) {
      return const [];
    }
    final totalMonths = dates.length * intervalMonths;
    final unitMonths = accrual == InterestAccrualMethod.monthly ? 1 : 12;
    DateTime boundary(int month) {
      if (month == 0) return referenceDate(start);
      final period = (month - 1) ~/ intervalMonths;
      final offset = month - period * intervalMonths;
      final until = referenceDate(dates[period]);
      if (offset == intervalMonths) return until;
      final from = period == 0 ? start : dates[period - 1];
      final candidate = referenceDate(
        IntervalRepaymentDates.addMonthsClamped(from, offset),
      );
      return candidate.isBefore(until) ? candidate : until;
    }

    final units = <AccrualUnit>[];
    for (var month = 0; month < totalMonths; month += unitMonths) {
      final last = month + unitMonths < totalMonths
          ? month + unitMonths
          : totalMonths;
      final from = boundary(month), until = boundary(last);
      // 短期末尾可能提前截断多个名义单位，金额仍按合同约定月数计算。
      if (from == until && units.isNotEmpty) {
        final previous = units.removeLast();
        units.add(
          AccrualUnit(
            start: previous.start,
            end: until,
            startMonth: previous.startMonth,
            endMonth: last,
          ),
        );
      } else {
        units.add(
          AccrualUnit(
            start: from,
            end: until,
            startMonth: month,
            endMonth: last,
          ),
        );
      }
    }
    return List.unmodifiable(units);
  }

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
    DateTime? start,
    DateTime? end,
    List<AccrualUnit>? units,
    int elapsedMonths = 0,
  }) {
    final segments = start == null || end == null
        ? const <AccrualRateSegment>[]
        : _segments(
            rate: rate,
            accrual: accrual,
            span: span,
            start: start,
            end: end,
            units:
                units ??
                unitsFor(
                  accrual: accrual,
                  start: start,
                  dates: [end],
                  intervalMonths: span.months,
                ),
            elapsedMonths: elapsedMonths,
          );
    if (rate == null || rate.isZero) {
      return PeriodRate(
        actual: Rational.zero,
        nominal: Rational.zero,
        segments: segments,
      );
    }
    final months = Rational.fromInt(span.months);
    switch (accrual) {
      case InterestAccrualMethod.daily:
        return PeriodRate(
          actual: dailyRate(rate) * Rational.fromInt(span.days),
          nominal: monthlyRate(rate) * months,
          segments: segments,
        );
      case InterestAccrualMethod.monthly:
        final periodRate = monthlyRate(rate) * months;
        return PeriodRate(
          actual: periodRate,
          nominal: periodRate,
          segments: segments,
        );
      case InterestAccrualMethod.annual:
        final periodRate = annualRate(rate) * months / _twelve;
        return PeriodRate(
          actual: periodRate,
          nominal: periodRate,
          segments: segments,
        );
    }
  }

  List<AccrualRateSegment> _segments({
    required InterestRate? rate,
    required InterestAccrualMethod accrual,
    required AccrualPeriodSpan span,
    required DateTime start,
    required DateTime end,
    required List<AccrualUnit> units,
    required int elapsedMonths,
  }) {
    final from = referenceDate(start), until = referenceDate(end);
    if (accrual == InterestAccrualMethod.daily) {
      return [
        AccrualRateSegment(
          start: from,
          end: until,
          rate: rate,
          accrual: accrual,
          dayCount: dayCount,
          factor: rate == null
              ? Rational.zero
              : dailyRate(rate) * Rational.fromInt(span.days),
        ),
      ];
    }
    final unitMonths = accrual == InterestAccrualMethod.monthly ? 1 : 12;
    final unitRate = rate == null
        ? Rational.zero
        : accrual == InterestAccrualMethod.monthly
        ? monthlyRate(rate)
        : annualRate(rate);
    final result = <AccrualRateSegment>[];
    final periodEndMonth = elapsedMonths + span.months;
    for (final unit in units) {
      if (unit.endMonth <= elapsedMonths || unit.startMonth >= periodEndMonth) {
        continue;
      }
      final firstMonth = unit.startMonth > elapsedMonths
          ? unit.startMonth
          : elapsedMonths;
      final lastMonth = unit.endMonth < periodEndMonth
          ? unit.endMonth
          : periodEndMonth;
      final count = lastMonth - firstMonth;
      result.add(
        AccrualRateSegment(
          start: from.isAfter(unit.start) ? from : unit.start,
          end: until.isBefore(unit.end) ? until : unit.end,
          unitStart: unit.start,
          unitEnd: unit.end,
          rate: rate,
          accrual: accrual,
          dayCount: dayCount,
          factor:
              unitRate * Rational(BigInt.from(count), BigInt.from(unitMonths)),
        ),
      );
    }
    return result;
  }
}

final Rational _twelve = Rational.fromInt(12);
