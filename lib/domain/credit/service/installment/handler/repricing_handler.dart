import 'package:rational/rational.dart';

import '../../../../../core/money/money.dart';
import '../../../../../core/money/rounding_mode.dart';
import '../../../valobj/floating_rate.dart';
import '../../../valobj/installment_enums.dart';
import '../../../valobj/interest_rate.dart';
import '../../../valobj/reference_rate.dart';
import '../calculator/interest_accrual_policy.dart';
import '../calculator/repayment_method_calculator.dart';
import 'base_plan_generation_handler.dart';
import 'installment_stage_context.dart';

/// 应用已排序的执行利率事实，处理期内拆息与当期、下期固定额重算。
class RepricingHandler {
  const RepricingHandler(this._generation);

  final BasePlanGenerationHandler _generation;

  /// 利率事实保留原单位；是否重算按阶段计息单位下的精确值判断。
  bool hasSameRate(
    InstallmentStageContext context,
    InterestRate? left,
    InterestRate? right,
  ) {
    Rational value(InterestRate? rate) => rate == null
        ? Rational.zero
        : switch (context.stage.accrual) {
            InterestAccrualMethod.daily => context.policy.dailyRate(rate),
            InterestAccrualMethod.monthly => context.policy.monthlyRate(rate),
            InterestAccrualMethod.annual => context.policy.annualRate(rate),
          };
    return value(left) == value(right);
  }

  InterestRate? rateAt(
    InterestRate? initial,
    DateTime date,
    List<RateChange> changes,
  ) {
    var rate = initial;
    for (final change in changes) {
      if (!referenceDate(change.effectiveDate).isAfter(date)) {
        rate = change.rate;
      }
    }
    return rate;
  }

  ({
    InstallmentAmountAllocation allocation,
    InstallmentStageProjection? projection,
    InterestRate? closingRate,
    bool changed,
  })
  apply(
    InstallmentStageContext context, {
    required int periodIndex,
    required Money openingPrincipal,
    required Money endPrincipal,
    required InterestRate? openingRate,
    required InstallmentStageProjection projection,
    required List<RateChange> changes,
  }) {
    final range = context.periodRange(periodIndex);
    final previous = range.start;
    final until = range.end;
    final allocation = projection.allocationAt(periodIndex);
    final periodChanges = changes.where((change) {
      final effective = referenceDate(change.effectiveDate);
      return effective.isAfter(previous) && effective.isBefore(until);
    }).toList();
    var latestRate = openingRate;
    var rateChanged = false;
    for (final change in periodChanges) {
      if (!hasSameRate(context, latestRate, change.rate)) rateChanged = true;
      latestRate = change.rate;
    }
    if (!rateChanged) {
      return (
        allocation: allocation,
        projection: projection,
        closingRate: latestRate,
        changed: false,
      );
    }

    // 发生真实变化才改为按日拆息，拆分时仍保留各日期实际生效的利率事实。
    final segments = <AccrualRateSegment>[];
    var cursor = previous;
    var closingRate = openingRate;
    for (final change in periodChanges) {
      final effective = referenceDate(change.effectiveDate);
      if (change.rate == closingRate) continue;
      segments.addAll(_dailySegments(context, closingRate, cursor, effective));
      cursor = effective;
      closingRate = change.rate;
    }
    segments.addAll(_dailySegments(context, closingRate, cursor, until));
    final factor = segments.fold(
      Rational.zero,
      (sum, segment) => sum + segment.factor,
    );
    final mixed = PeriodRate(
      actual: factor,
      nominal: factor,
      segments: segments,
    );
    final nextPeriod =
        context.stage.method == InstallmentRepaymentMethod.equalInstallment &&
        context.stage.inPeriodRepricingPolicy ==
            InPeriodRepricingPolicy.preservePrincipal;
    if (nextPeriod) {
      return (
        allocation: InstallmentAmountAllocation(
          principal: allocation.principal,
          interest: Money(
            minorUnits: (Rational.fromInt(openingPrincipal.minorUnits) * factor)
                .roundToInt(context.rounding),
          ),
          interestSegments: mixed.interestSegments(openingPrincipal),
        ),
        projection: null,
        closingRate: closingRate,
        changed: true,
      );
    }

    final recalculated = _generation.generate(
      context,
      periodIndex: periodIndex,
      openingPrincipal: openingPrincipal,
      endPrincipal: endPrincipal,
      rate: closingRate,
      firstPeriodRate: mixed,
    );
    return (
      allocation: recalculated.allocationAt(periodIndex),
      projection: recalculated,
      closingRate: closingRate,
      changed: true,
    );
  }

  List<AccrualRateSegment> _dailySegments(
    InstallmentStageContext context,
    InterestRate? rate,
    DateTime start,
    DateTime end,
  ) => context.policy
      .periodRate(
        rate: rate,
        accrual: InterestAccrualMethod.daily,
        span: AccrualPeriodSpan(days: end.difference(start).inDays, months: 0),
        start: start,
        end: end,
      )
      .segments;
}
