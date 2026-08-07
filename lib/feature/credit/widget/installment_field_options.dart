import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/design_system/widget/app_select.dart';

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

const List<AppSelectOption<InterestAccrualMethod>>
interestAccrualMethodOptions = [
  AppSelectOption(value: InterestAccrualMethod.daily, label: '按日计息'),
  AppSelectOption(value: InterestAccrualMethod.monthly, label: '按月计息'),
];
