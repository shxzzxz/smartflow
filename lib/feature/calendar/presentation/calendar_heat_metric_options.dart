import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/widget/app_select.dart';

const calendarHeatMetricOptions = <AppSelectOption<CalendarHeatMetric>>[
  AppSelectOption(value: CalendarHeatMetric.expense, label: '支出'),
  AppSelectOption(value: CalendarHeatMetric.income, label: '收入'),
  AppSelectOption(value: CalendarHeatMetric.net, label: '净收入'),
];
