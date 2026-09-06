import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/design_system/widget/app_select.dart';

import '../../../domain/credit/valobj/installment_stage_rule.dart';

const List<AppSelectOption<InterestRatePeriod>> interestRatePeriodOptions = [
  AppSelectOption(value: InterestRatePeriod.annual, label: '年'),
  AppSelectOption(value: InterestRatePeriod.monthly, label: '月'),
  AppSelectOption(value: InterestRatePeriod.daily, label: '日'),
];

const List<AppSelectOption<InstallmentRepaymentMethod>>
installmentRepaymentMethodOptions = [
  AppSelectOption(
    value: InstallmentRepaymentMethod.equalInstallment,
    label: '等额本息',
  ),
  AppSelectOption(
    value: InstallmentRepaymentMethod.equalPrincipal,
    label: '等额本金',
  ),
  AppSelectOption(
    value: InstallmentRepaymentMethod.interestFirst,
    label: '先息后本',
  ),
  AppSelectOption(value: InstallmentRepaymentMethod.flatFee, label: '一次性手续费'),
  AppSelectOption(value: InstallmentRepaymentMethod.custom, label: '自定义'),
];

/// 贷款计算器的自动还款方式；自定义计划需要手工录入，不单列。
const List<AppSelectOption<InstallmentRepaymentMethod>>
loanCalculatorRepaymentMethodOptions = [
  AppSelectOption(
    value: InstallmentRepaymentMethod.equalInstallment,
    label: '等额本息',
  ),
  AppSelectOption(
    value: InstallmentRepaymentMethod.equalPrincipal,
    label: '等额本金',
  ),
  AppSelectOption(
    value: InstallmentRepaymentMethod.interestFirst,
    label: '先息后本',
  ),
  AppSelectOption(value: InstallmentRepaymentMethod.flatFee, label: '一次性手续费'),
];

const List<AppSelectOption<InterestAccrualMethod>>
interestAccrualMethodOptions = [
  AppSelectOption(value: InterestAccrualMethod.daily, label: '按日计息'),
  AppSelectOption(value: InterestAccrualMethod.monthly, label: '按月计息'),
  AppSelectOption(value: InterestAccrualMethod.annual, label: '按年计息'),
];

const List<AppSelectOption<DayCountConvention>> dayCountConventionOptions = [
  AppSelectOption(
    value: DayCountConvention.thirty360,
    label: '月 30 天 / 年 360 天',
  ),
  AppSelectOption(
    value: DayCountConvention.thirty365,
    label: '月 30 天 / 年 365 天',
  ),
];

const List<AppSelectOption<RoundingMode>> roundingModeOptions = [
  AppSelectOption(value: RoundingMode.halfUp, label: '四舍五入'),
  AppSelectOption(value: RoundingMode.halfEven, label: '银行家舍入'),
  AppSelectOption(value: RoundingMode.down, label: '舍去'),
  AppSelectOption(value: RoundingMode.up, label: '进一'),
];

const List<AppSelectOption<InstallmentAmountAlgorithm>>
installmentAmountAlgorithmOptions = [
  AppSelectOption(
    value: InstallmentAmountAlgorithm.nominalRate,
    label: '固定名义期利率',
  ),
  AppSelectOption(
    value: InstallmentAmountAlgorithm.actualRate,
    label: '动态实际期利率',
  ),
  AppSelectOption(value: InstallmentAmountAlgorithm.fixed, label: '指定固定额'),
];
