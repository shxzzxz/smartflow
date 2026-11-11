import 'package:rational/rational.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../core/money/money.dart';
import '../../../../../core/money/rounding_mode.dart';
import '../../../valobj/credit_error_code.dart';
import '../../../valobj/installment_enums.dart';
import '../../../valobj/installment_plan_operation.dart';
import '../../../valobj/interest_accrual_segment.dart';
import '../../../valobj/interest_rate.dart';
import '../../../valobj/rate_change.dart';
import '../../../valobj/reference_rate.dart';
import '../calculator/interest_accrual_policy.dart';
import '../calculator/repayment_method_calculator.dart';
import 'installment_stage_context.dart';

/// 应用期内本金扣减：保留本期计划本金，并按本金、利率时间线拆息。
class PrincipalReductionHandler {
  const PrincipalReductionHandler();

  Money deduct(Money principal, int reductionMinor) {
    if (reductionMinor > principal.minorUnits) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '本金扣减超过该计息位置的可用本金',
      );
    }
    return principal - Money(minorUnits: reductionMinor);
  }

  ({InstallmentAmountAllocation allocation, int reductionMinor}) applyInPeriod(
    InstallmentStageContext context, {
    required int periodIndex,
    required Money openingPrincipal,
    required InterestRate? openingRate,
    required List<RateChange> changes,
    required List<PrincipalReduction> reductions,
    required InstallmentAmountAllocation currentAllocation,
    required RoundingMode rounding,
    required DateTime? interestSettledThrough,
  }) {
    final reductionMinor = reductions.fold<int>(
      0,
      (sum, reduction) => sum + reduction.principal.minorUnits,
    );
    if (reductionMinor > openingPrincipal.minorUnits) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '本金扣减超过该计息位置的可用本金',
      );
    }

    final availableAfterReduction =
        openingPrincipal.minorUnits - reductionMinor;
    final principalMinor =
        currentAllocation.principal.minorUnits > availableAfterReduction
        ? availableAfterReduction
        : currentAllocation.principal.minorUnits;
    final segments = _interestSegments(
      context,
      periodIndex: periodIndex,
      openingPrincipal: openingPrincipal,
      openingRate: openingRate,
      changes: changes,
      reductions: reductions,
      interestSettledThrough: interestSettledThrough,
    );
    final interest = segments.fold<Rational>(
      Rational.zero,
      (sum, segment) =>
          segment.isSettled ? sum : sum + segment.exactInterestMinor,
    );
    return (
      allocation: InstallmentAmountAllocation(
        principal: Money(minorUnits: principalMinor),
        interest: Money(minorUnits: interest.roundToInt(rounding)),
        interestSegments: List.unmodifiable(segments),
      ),
      reductionMinor: reductionMinor,
    );
  }

  List<InterestAccrualSegment> _interestSegments(
    InstallmentStageContext context, {
    required int periodIndex,
    required Money openingPrincipal,
    required InterestRate? openingRate,
    required List<RateChange> changes,
    required List<PrincipalReduction> reductions,
    required DateTime? interestSettledThrough,
  }) {
    final range = context.periodRange(periodIndex);
    final principalEvents = [
      for (final reduction in reductions)
        (
          date: referenceDate(reduction.date).add(const Duration(days: 1)),
          principal: reduction.principal,
        ),
    ]..sort((left, right) => left.date.compareTo(right.date));
    final rateEvents = [
      for (final change in changes)
        if (referenceDate(change.effectiveDate).isAfter(range.start) &&
            referenceDate(change.effectiveDate).isBefore(range.end))
          (date: referenceDate(change.effectiveDate), rate: change.rate),
    ]..sort((left, right) => left.date.compareTo(right.date));

    final segments = <InterestAccrualSegment>[];
    var cursor = range.start;
    var balance = openingPrincipal.minorUnits;
    var rate = openingRate;
    var principalIndex = 0;
    var rateIndex = 0;
    while (cursor.isBefore(range.end)) {
      final nextPrincipal = principalIndex < principalEvents.length
          ? principalEvents[principalIndex].date
          : range.end;
      final nextRate = rateIndex < rateEvents.length
          ? rateEvents[rateIndex].date
          : range.end;
      final boundary = nextPrincipal.isBefore(nextRate)
          ? nextPrincipal
          : nextRate;
      if (boundary.isAfter(cursor)) {
        segments.addAll(
          context.policy
              .periodRate(
                rate: rate,
                accrual: InterestAccrualMethod.daily,
                span: AccrualPeriodSpan(
                  days: boundary.difference(cursor).inDays,
                  months: 0,
                ),
                start: cursor,
                end: boundary,
              )
              .segments
              .map(
                (segment) => segment.forPrincipal(Money(minorUnits: balance)),
              ),
        );
      }
      cursor = boundary;
      while (principalIndex < principalEvents.length &&
          !principalEvents[principalIndex].date.isAfter(cursor)) {
        balance -= principalEvents[principalIndex].principal.minorUnits;
        principalIndex++;
      }
      while (rateIndex < rateEvents.length &&
          !rateEvents[rateIndex].date.isAfter(cursor)) {
        rate = rateEvents[rateIndex].rate;
        rateIndex++;
      }
    }
    if (interestSettledThrough == null) return segments;
    final settledThrough = referenceDate(interestSettledThrough);
    return List.unmodifiable([
      for (final segment in segments)
        segment.withSettlement(isSettled: !segment.end.isAfter(settledThrough)),
    ]);
  }
}
