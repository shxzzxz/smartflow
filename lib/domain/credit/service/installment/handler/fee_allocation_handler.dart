import '../../../../../core/error/app_exception.dart';
import '../../../../../core/money/money.dart';
import '../../../../../core/money/rounding_mode.dart';
import '../../../valobj/credit_error_code.dart';
import '../../../valobj/tail_difference_policy.dart';
import '../calculator/repayment_method_calculator.dart';

/// 按阶段原约定完整分配手续费，不随本息重算而重复分配或缩减。
class FeeAllocationHandler {
  const FeeAllocationHandler();

  List<Money> allocate({
    required Money fee,
    required int periodCount,
    required RoundingMode rounding,
    TailDifferencePolicy tailDifference = TailDifferencePolicy.lastPeriod,
  }) {
    if (fee.minorUnits < 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '阶段手续费不得为负',
      );
    }
    return [
      for (final minor in splitEvenly(
        fee.minorUnits,
        periodCount,
        rounding,
        tailDifference: tailDifference,
      ))
        Money(minorUnits: minor),
    ];
  }
}
