import '../../../core/money/money.dart';
import '../../../core/money/rounding_mode.dart';
import 'day_count_convention.dart';
import 'equal_installment_amount.dart';
import 'installment_enums.dart';
import 'interest_rate.dart';
import 'repayment_dates_strategy.dart';
import 'tail_difference_policy.dart';

/// 生成一份还款计划所需的全部条款：本金、借款日、计算约定与首尾相接的阶段序列。
class InstallmentPlanTerms {
  const InstallmentPlanTerms({
    required this.principal,
    required this.borrowingDate,
    required this.stages,
    this.dayCount = DayCountConvention.thirty360,
    this.rounding = RoundingMode.halfUp,
    this.tailDifference = TailDifferencePolicy.lastPeriod,
  });

  final Money principal;
  final DateTime borrowingDate;
  final DayCountConvention dayCount;
  final RoundingMode rounding;
  final TailDifferencePolicy tailDifference;
  final List<InstallmentStage> stages;
}

sealed class InstallmentStage {
  const InstallmentStage();
}

/// 免还期：只推进时间线，不产生期次，也不计息。
class DefermentStage extends InstallmentStage {
  const DefermentStage({required this.until});

  final DateTime until;
}

/// 摊还阶段：一段同质条款下的连续期次。
///
/// 期初本金来自上一阶段的期末本金（首阶段即合同本金）；[endPrincipal] 缺省规则：
/// 末阶段为 0，非末阶段的先息后本为期初本金，其余方式必须显式给出。
/// 末阶段显式给出大于 0 的期末本金表示末期额外归还该余额（气球贷）。
class AmortizingStage extends InstallmentStage {
  const AmortizingStage({
    required this.dates,
    required this.method,
    this.accrualStartDate,
    this.rate,
    this.accrual = InterestAccrualMethod.monthly,
    this.endPrincipal,
    this.fee = const Money(minorUnits: 0),
    this.installmentAmount = const EqualInstallmentAmount.nominalRate(),
  });

  final RepaymentDatesStrategy dates;

  /// 计息起点；缺省为上一阶段结束日或借款日。重算时取锚点期次日期。
  final DateTime? accrualStartDate;
  final InstallmentRepaymentMethod method;

  /// 为空即免息。
  final InterestRate? rate;
  final InterestAccrualMethod accrual;
  final Money? endPrincipal;

  /// 阶段手续费，均摊到各期，与还款方式正交。
  final Money fee;
  final EqualInstallmentAmount installmentAmount;
}
