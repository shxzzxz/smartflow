import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/design_system/widget/app_segmented_control.dart';
import 'package:smartflow/design_system/widget/app_select.dart';

const List<AppSegment<InterestRatePeriod>> interestRatePeriodSegments = [
  AppSegment(value: InterestRatePeriod.annual, label: '年'),
  AppSegment(value: InterestRatePeriod.monthly, label: '月'),
  AppSegment(value: InterestRatePeriod.daily, label: '日'),
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

const List<AppSegment<InterestAccrualMethod>> interestAccrualMethodSegments = [
  AppSegment(value: InterestAccrualMethod.daily, label: '按日计息'),
  AppSegment(value: InterestAccrualMethod.monthly, label: '按月计息'),
];
