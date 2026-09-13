import 'package:rational/rational.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../core/money/money.dart';
import '../../../../../core/money/rounding_mode.dart';
import '../../../valobj/credit_error_code.dart';
import '../../../valobj/installment_enums.dart';
import '../../../valobj/installment_plan_operation.dart';
import '../../../valobj/interest_accrual_segment.dart';
import '../../../valobj/reference_rate.dart';

class InterestAdjustmentHandler {
  const InterestAdjustmentHandler();

  void validate(
    List<InterestAdjustment> adjustments,
    Iterable<InterestAccrualSegment> segments,
  ) {
    final ordered = [...adjustments]
      ..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 0; i < ordered.length; i++) {
      final adjustment = ordered[i];
      adjustment.validate();
      if (i > 0 && adjustment.overlaps(ordered[i - 1])) {
        _invalid('同一合同的利息调整区间不能重叠');
      }
      for (final segment in segments) {
        if (segment.accrual == InterestAccrualMethod.daily) continue;
        final start = referenceDate(adjustment.start),
            end = referenceDate(adjustment.end);
        final from = referenceDate(segment.start),
            until = referenceDate(segment.end);
        if (!start.isBefore(until) || !end.isAfter(from)) continue;
        if (start.isAfter(segment.unitStart) || end.isBefore(segment.unitEnd)) {
          _invalid('利息调整区间必须对齐完整计息单位；月、年计息不能按日截取');
        }
      }
    }
  }

  Money apply(
    List<InterestAccrualSegment> segments,
    List<InterestAdjustment> adjustments,
    RoundingMode rounding,
  ) {
    var interest = Rational.zero;
    for (final segment in segments) {
      interest += segment.exactInterestMinor;
      for (final adjustment in adjustments) {
        final from = referenceDate(adjustment.start).isAfter(segment.start)
            ? referenceDate(adjustment.start)
            : segment.start;
        final until = referenceDate(adjustment.end).isBefore(segment.end)
            ? referenceDate(adjustment.end)
            : segment.end;
        if (!from.isBefore(until)) continue;
        interest +=
            segment.interestWithin(from, until) *
            (adjustment.ratio - Rational.one);
      }
    }
    return Money(minorUnits: interest.roundToInt(rounding));
  }

  Never _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
