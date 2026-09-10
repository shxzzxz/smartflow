import '../../../core/money/money.dart';
import '../../../core/money/rounding_mode.dart';
import '../../../core/error/app_exception.dart';
import 'credit_error_code.dart';
import 'day_count_convention.dart';
import 'equal_installment_amount.dart';
import 'installment_enums.dart';
import 'interest_rate.dart';
import 'floating_rate.dart';
import 'reference_rate.dart';
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
    this.floatingRate,
    this.rateChanges = const [],
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
  final FloatingRateRule? floatingRate;
  final List<RateChange> rateChanges;

  InterestRate? rateOn(DateTime date) {
    final active =
        rateChanges
            .where(
              (c) =>
                  !referenceDate(c.effectiveDate).isAfter(referenceDate(date)),
            )
            .toList()
          ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));
    return active.isEmpty ? rate : active.last.rate;
  }

  void validateFloatingRate() {
    final rule = floatingRate;
    if (rule == null) {
      if (rateChanges.isNotEmpty) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '固定利率阶段不能带有重定价结果',
        );
      }
      return;
    }
    rule.validate();
    if (rate == null ||
        rate!.period != InterestRatePeriod.annual ||
        rate!.ppm < 0 ||
        method == InstallmentRepaymentMethod.custom ||
        method == InstallmentRepaymentMethod.flatFee ||
        installmentAmount is FixedInstallmentAmount) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '浮动利率需要初始执行年利率及自动计算的还款方式和固定额算法',
      );
    }
    final effectiveDates = <DateTime>{};
    for (final change in rateChanges) {
      if (change.referenceRate.ratePpm < 0 ||
          change.rate.ppm < 0 ||
          change.referenceRate.type != rule.referenceRateType ||
          referenceDate(
            change.referenceRate.date,
          ).isAfter(referenceDate(change.resetDate)) ||
          referenceDate(
            change.resetDate,
          ).isAfter(referenceDate(change.effectiveDate)) ||
          !effectiveDates.add(referenceDate(change.effectiveDate))) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '重定价报价、日期或执行利率无效',
        );
      }
    }
  }

  final InterestAccrualMethod accrual;
  final Money? endPrincipal;

  /// 阶段手续费，均摊到各期，与还款方式正交。
  final Money fee;
  final EqualInstallmentAmount installmentAmount;
}
