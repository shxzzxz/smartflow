import '../../../core/money/money.dart';

/// 等额本息下固定还款额 A 的取法。
///
/// 三种取法共用同一个求解器和同一套本金分摊形状，只是喂给求解器的期利率序列不同，
/// 或直接采用产品披露的金额。
sealed class EqualInstallmentAmount {
  const EqualInstallmentAmount();

  /// 按名义期利率序列求解：银行与消费贷的标准月供公式。
  const factory EqualInstallmentAmount.nominalRate() =
      NominalRateInstallmentAmount;

  /// 按各期实际期利率折现求解：首期跨期天数会反映到 A 中。
  const factory EqualInstallmentAmount.actualRate() =
      ActualRateInstallmentAmount;

  /// 直接采用产品披露的每期还款额。
  const factory EqualInstallmentAmount.fixed(Money amount) =
      FixedInstallmentAmount;
}

final class NominalRateInstallmentAmount extends EqualInstallmentAmount {
  const NominalRateInstallmentAmount();

  @override
  bool operator ==(Object other) => other is NominalRateInstallmentAmount;

  @override
  int get hashCode => (NominalRateInstallmentAmount).hashCode;
}

final class ActualRateInstallmentAmount extends EqualInstallmentAmount {
  const ActualRateInstallmentAmount();

  @override
  bool operator ==(Object other) => other is ActualRateInstallmentAmount;

  @override
  int get hashCode => (ActualRateInstallmentAmount).hashCode;
}

final class FixedInstallmentAmount extends EqualInstallmentAmount {
  const FixedInstallmentAmount(this.amount);

  final Money amount;

  @override
  bool operator ==(Object other) {
    return other is FixedInstallmentAmount && other.amount == amount;
  }

  @override
  int get hashCode => Object.hash(FixedInstallmentAmount, amount);
}
