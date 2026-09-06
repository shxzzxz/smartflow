import '../../../core/error/app_exception.dart';
import 'credit_error_code.dart';
import 'installment_enums.dart';

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
      amountAlgorithm = null;

  const InstallmentStageRule.repayment({
    required this.id,
    required InstallmentRepaymentMethod this.method,
    this.intervalMonths,
    this.ratePeriod,
    this.accrual,
    this.amountAlgorithm,
  }) : kind = InstallmentStageKind.repayment;

  final String id;
  final InstallmentStageKind kind;
  final InstallmentRepaymentMethod? method;
  final int? intervalMonths;
  final InterestRatePeriod? ratePeriod;
  final InterestAccrualMethod? accrual;
  final InstallmentAmountAlgorithm? amountAlgorithm;

  void validate() {
    if (id.trim().isEmpty) _invalid('阶段标识不能为空');
    if (kind == InstallmentStageKind.deferment) return;
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
  }

  static void _invalid(String message) => throw BusinessException(
    CreditErrorCode.contractInvalidCommand,
    message: message,
  );
}
