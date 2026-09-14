import 'package:rational/rational.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import 'credit_error_code.dart';
import 'floating_rate.dart';
import 'reference_rate.dart';

/// 只表达影响计算的本金事实，不包含还款状态或息费。
class PrincipalReduction {
  const PrincipalReduction({required this.date, required this.principal});

  final DateTime date;
  final Money principal;
}

/// 调整区间为 (start, end]，与计息周期使用相同的日期边界。
/// 比例沿用利率的 ppm 精度：1,000,000 为 100%。
class InterestAdjustment {
  const InterestAdjustment({
    required this.start,
    required this.end,
    required this.ratioPpm,
  });

  final DateTime start;
  final DateTime end;
  final int ratioPpm;

  /// 与计息片段求交时使用的起始包含、结束不包含日期。
  ({DateTime start, DateTime end}) get accrualRange => (
    start: referenceDate(start).add(const Duration(days: 1)),
    end: referenceDate(end).add(const Duration(days: 1)),
  );

  Rational get ratio => Rational(BigInt.from(ratioPpm), BigInt.from(1000000));

  void validate() {
    if (ratioPpm < 0 || !referenceDate(end).isAfter(referenceDate(start))) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '利息比例不得为负，结束日期必须晚于开始日期',
      );
    }
  }

  bool overlaps(InterestAdjustment other) =>
      referenceDate(start).isBefore(referenceDate(other.end)) &&
      referenceDate(other.start).isBefore(referenceDate(end));
}

class InstallmentPlanOperations {
  const InstallmentPlanOperations({
    this.principalReductions = const [],
    this.rateChangesByStage = const {},
    this.interestAdjustments = const [],
  });

  final List<PrincipalReduction> principalReductions;

  /// 阶段索引属于本次完整条款，持久化的稳定阶段 ID 由调用方映射。
  final Map<int, List<RateChange>> rateChangesByStage;
  final List<InterestAdjustment> interestAdjustments;
}
