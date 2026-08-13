import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/widget/app_select.dart';

const cashflowPeriodMetricOptions = <AppSelectOption<CashflowPeriodMetric>>[
  AppSelectOption(value: CashflowPeriodMetric.periodDelta, label: '同期增减'),
  AppSelectOption(value: CashflowPeriodMetric.periodRatio, label: '同期占比'),
  AppSelectOption(
    value: CashflowPeriodMetric.previousMonthRatio,
    label: '上月占比',
  ),
];
