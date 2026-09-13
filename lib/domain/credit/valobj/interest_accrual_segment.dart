import 'package:rational/rational.dart';

import '../../../core/money/money.dart';
import 'day_count_convention.dart';
import 'installment_enums.dart';
import 'interest_rate.dart';
import 'reference_rate.dart';

/// 未舍入的基础计息依据。日片段可按天切分；月、年片段记录所属完整计息单位。
class InterestAccrualSegment {
  const InterestAccrualSegment({
    required this.start,
    required this.end,
    required this.principal,
    required this.rate,
    required this.accrual,
    required this.dayCount,
    required this.exactInterestMinor,
    DateTime? unitStart,
    DateTime? unitEnd,
  }) : unitStart = unitStart ?? start,
       unitEnd = unitEnd ?? end;

  final DateTime start;
  final DateTime end;

  /// 所属完整计息单位；年计息即使按月还款，仍按完整计息年校验。
  final DateTime unitStart, unitEnd;
  final Money principal;
  final InterestRate? rate;
  final InterestAccrualMethod accrual;
  final DayCountConvention dayCount;
  final Rational exactInterestMinor;

  Rational interestWithin(DateTime from, DateTime until) {
    if (accrual != InterestAccrualMethod.daily) return exactInterestMinor;
    final days = referenceDate(end).difference(referenceDate(start)).inDays;
    final covered = referenceDate(until).difference(referenceDate(from)).inDays;
    return exactInterestMinor *
        Rational(BigInt.from(covered), BigInt.from(days));
  }
}
