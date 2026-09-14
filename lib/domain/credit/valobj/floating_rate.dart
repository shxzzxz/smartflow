import '../../../core/error/app_exception.dart';
import 'credit_error_code.dart';
import 'installment_enums.dart';
import 'interest_rate.dart';
import 'reference_rate.dart';

export 'in_period_repricing_policy.dart';

/// 首次日期是永久日历锚点；月底截断后不会逐次漂移。
class FloatingRateRule {
  const FloatingRateRule({
    required this.referenceRateType,
    required this.spreadBp,
    required this.firstResetDate,
    required this.firstEffectiveDate,
    this.cycleMonths = 12,
  });

  final InterestRateType referenceRateType;
  final int spreadBp;
  final DateTime firstResetDate;
  final DateTime firstEffectiveDate;
  final int cycleMonths;

  void validate() {
    if (!referenceRateType.isFloating ||
        ![3, 6, 12].contains(cycleMonths) ||
        referenceDate(
          firstEffectiveDate,
        ).isBefore(referenceDate(firstResetDate))) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '重定价周期须为 3、6 或 12 个月，生效日不得早于重定价日',
      );
    }
  }

  DateTime resetDate(int index) => _advance(firstResetDate, index);
  DateTime effectiveDate(int index) => _advance(firstEffectiveDate, index);

  /// 不晚于指定生效日期的最后一个周期，早于首次生效日时返回空。
  int? effectiveCycleOnOrBefore(DateTime date) {
    final through = referenceDate(date);
    final first = referenceDate(firstEffectiveDate);
    if (through.isBefore(first)) return null;
    final months =
        (through.year - first.year) * 12 + through.month - first.month;
    var index = months ~/ cycleMonths;
    if (effectiveDate(index).isAfter(through)) index--;
    return index < 0 ? null : index;
  }

  @override
  bool operator ==(Object other) =>
      other is FloatingRateRule &&
      other.referenceRateType == referenceRateType &&
      other.spreadBp == spreadBp &&
      other.cycleMonths == cycleMonths &&
      referenceDate(other.firstResetDate) == referenceDate(firstResetDate) &&
      referenceDate(other.firstEffectiveDate) ==
          referenceDate(firstEffectiveDate);
  @override
  int get hashCode => Object.hash(
    referenceRateType,
    spreadBp,
    cycleMonths,
    referenceDate(firstResetDate),
    referenceDate(firstEffectiveDate),
  );

  DateTime _advance(DateTime anchor, int index) {
    final month = DateTime.utc(anchor.year, anchor.month + index * cycleMonths);
    final last = DateTime.utc(month.year, month.month + 1, 0).day;
    return DateTime.utc(
      month.year,
      month.month,
      anchor.day > last ? last : anchor.day,
    );
  }
}

/// 已确定的贷款执行利率；初始执行利率仍由阶段 rate 表达。
class RateChange {
  const RateChange({
    required this.resetDate,
    required this.effectiveDate,
    required this.referenceRate,
    required this.spreadBp,
  });
  final DateTime resetDate;
  final DateTime effectiveDate;
  final ReferenceRate referenceRate;
  final int spreadBp;
  InterestRate get rate => InterestRate(
    ppm: referenceRate.ratePpm + spreadBp * 100,
    period: InterestRatePeriod.annual,
  );

  void validate() {
    if (referenceDate(effectiveDate).isBefore(referenceDate(resetDate)) ||
        referenceDate(referenceRate.date).isAfter(referenceDate(resetDate)) ||
        referenceRate.ratePpm < 0 ||
        rate.ppm < 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '重定价日期或参考利率无效，执行利率不得为负',
      );
    }
  }
}
