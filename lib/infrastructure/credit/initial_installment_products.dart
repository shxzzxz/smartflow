import '../../domain/credit/valobj/installment_enums.dart';
import '../../domain/credit/valobj/installment_stage_rule.dart';

/// 首次安装及升级时写入普通产品存储；只包含规则，不包含本笔贷款参数。
const initialInstallmentProducts = [
  (
    id: 'builtin-loan-equal-installment',
    name: '等额本息',
    stages: [
      InstallmentStageRule.repayment(
        id: 'builtin-loan-equal-installment-1',
        method: InstallmentRepaymentMethod.equalInstallment,
        intervalMonths: 1,
        ratePeriod: InterestRatePeriod.annual,
        accrual: InterestAccrualMethod.monthly,
        amountAlgorithm: InstallmentAmountAlgorithm.nominalRate,
      ),
    ],
  ),
  (
    id: 'builtin-loan-equal-principal',
    name: '等额本金',
    stages: [
      InstallmentStageRule.repayment(
        id: 'builtin-loan-equal-principal-1',
        method: InstallmentRepaymentMethod.equalPrincipal,
        intervalMonths: 1,
        ratePeriod: InterestRatePeriod.annual,
        accrual: InterestAccrualMethod.monthly,
      ),
    ],
  ),
  (
    id: 'builtin-loan-flat-fee',
    name: '一次性手续费',
    stages: [
      InstallmentStageRule.repayment(
        id: 'builtin-loan-flat-fee-1',
        method: InstallmentRepaymentMethod.flatFee,
      ),
    ],
  ),
  (
    id: 'builtin-loan-interest-first',
    name: '先息后本',
    stages: [
      InstallmentStageRule.repayment(
        id: 'builtin-loan-interest-first-1',
        method: InstallmentRepaymentMethod.interestFirst,
        intervalMonths: 1,
        ratePeriod: InterestRatePeriod.annual,
        accrual: InterestAccrualMethod.monthly,
      ),
    ],
  ),
  (
    id: 'builtin-loan-student',
    name: '国家助学贷款',
    stages: [
      InstallmentStageRule.deferment(id: 'builtin-loan-student-1'),
      InstallmentStageRule.repayment(
        id: 'builtin-loan-student-2',
        method: InstallmentRepaymentMethod.interestFirst,
        intervalMonths: 12,
        ratePeriod: InterestRatePeriod.annual,
        accrual: InterestAccrualMethod.annual,
      ),
      InstallmentStageRule.repayment(
        id: 'builtin-loan-student-3',
        method: InstallmentRepaymentMethod.equalPrincipal,
        intervalMonths: 12,
        ratePeriod: InterestRatePeriod.annual,
        accrual: InterestAccrualMethod.annual,
      ),
    ],
  ),
];
