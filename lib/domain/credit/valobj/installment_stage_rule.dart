import '../../../core/error/app_exception.dart';
import 'credit_error_code.dart';
import 'installment_enums.dart';
import 'in_period_repricing_policy.dart';
import 'reference_rate.dart';
import 'tail_difference_policy.dart';

enum InstallmentStageKind { deferment, repayment }

enum InstallmentAmountAlgorithm { nominalRate, actualRate, fixed }

/// 产品可复用的阶段规则。不包含金额、期数或任何日期。
class InstallmentStageRule {
  const InstallmentStageRule.deferment({required this.id})
    : kind = InstallmentStageKind.deferment,
      method = null,
      intervalMonths = null,
      ratePeriod = null,
      accrual = null,
      amountAlgorithm = null,
      rateType = null,
      repricingCycleMonths = null,
      inPeriodRepricingPolicy = null,
      tailDifference = null;

  const InstallmentStageRule.repayment({
    required this.id,
    required InstallmentRepaymentMethod this.method,
    this.intervalMonths,
    this.ratePeriod,
    this.accrual,
    this.amountAlgorithm,
    InterestRateType rateType = InterestRateType.fixed,
    int repricingCycleMonths = 12,
    InPeriodRepricingPolicy inPeriodRepricingPolicy =
        InPeriodRepricingPolicy.preservePrincipal,
    this.tailDifference = TailDifferencePolicy.lastPeriod,
  }) : kind = InstallmentStageKind.repayment,
       rateType =
           method == InstallmentRepaymentMethod.flatFee ||
               method == InstallmentRepaymentMethod.custom
           ? null
           : rateType,
       repricingCycleMonths =
           method == InstallmentRepaymentMethod.flatFee ||
               method == InstallmentRepaymentMethod.custom ||
               rateType == InterestRateType.fixed
           ? null
           : repricingCycleMonths,
       inPeriodRepricingPolicy =
           method == InstallmentRepaymentMethod.equalInstallment
           ? inPeriodRepricingPolicy
           : null;

  final String id;
  final InstallmentStageKind kind;
  final InstallmentRepaymentMethod? method;
  final int? intervalMonths;
  final InterestRatePeriod? ratePeriod;
  final InterestAccrualMethod? accrual;
  final InstallmentAmountAlgorithm? amountAlgorithm;
  final InterestRateType? rateType;
  final int? repricingCycleMonths;
  final InPeriodRepricingPolicy? inPeriodRepricingPolicy;
  final TailDifferencePolicy? tailDifference;

  void validate() {
    if (id.trim().isEmpty) _invalid('阶段标识不能为空');
    if (kind == InstallmentStageKind.deferment) return;
    if (tailDifference == null) _invalid('请配置阶段尾差处理策略');
    if (method == InstallmentRepaymentMethod.flatFee) {
      if (intervalMonths != null ||
          ratePeriod != null ||
          accrual != null ||
          amountAlgorithm != null) {
        _invalid('一次性手续费阶段不使用期数间隔、利率或固定额算法');
      }
      return;
    }
    if (method == null ||
        intervalMonths == null ||
        intervalMonths! <= 0 ||
        ratePeriod == null ||
        accrual == null) {
      _invalid('请补齐阶段还款规则');
    }
    if ((method == InstallmentRepaymentMethod.equalInstallment) !=
        (amountAlgorithm != null)) {
      _invalid('只有等额本息阶段需要固定额算法');
    }
    if (rateType?.isFloating == true &&
        (ratePeriod != InterestRatePeriod.annual ||
            ![3, 6, 12].contains(repricingCycleMonths) ||
            amountAlgorithm == InstallmentAmountAlgorithm.fixed)) {
      _invalid('参考利率使用年利率、有效重定价周期和自动固定额算法');
    }
  }

  static void _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
