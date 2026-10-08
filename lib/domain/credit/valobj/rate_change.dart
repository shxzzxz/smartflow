import '../../../core/error/app_exception.dart';
import 'credit_error_code.dart';
import 'installment_enums.dart';
import 'interest_rate.dart';
import 'reference_rate.dart';

/// 已确定的执行利率事实；两种确定方式按生效日共用同一计息时间线。
sealed class RateChange {
  const RateChange({required this.effectiveDate});

  final DateTime effectiveDate;
  InterestRate get rate;

  void validate();
}

final class DirectRateChange extends RateChange {
  const DirectRateChange({required super.effectiveDate, required this.rate});

  @override
  final InterestRate rate;

  @override
  void validate() {
    if (rate.ppm < 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '执行利率不得为负',
      );
    }
  }
}

final class ReferenceRateChange extends RateChange {
  const ReferenceRateChange({
    required super.effectiveDate,
    required this.resetDate,
    required this.referenceRate,
    required this.spreadBp,
  });

  final DateTime resetDate;
  final ReferenceRate referenceRate;
  final int spreadBp;

  @override
  InterestRate get rate => InterestRate(
    ppm: referenceRate.ratePpm + spreadBp * 100,
    period: InterestRatePeriod.annual,
  );

  @override
  void validate() {
    if (!referenceRate.type.isFloating ||
        referenceDate(effectiveDate).isBefore(referenceDate(resetDate)) ||
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
