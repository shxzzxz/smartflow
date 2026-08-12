import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../widget/business/analytics/chart/app_chart_empty_state.dart';
import '../../../widget/business/analytics/chart/app_donut_chart.dart';
import '../../../widget/business/analytics/chart/app_cartesian_chart.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';

class StatisticsCashflowChart extends StatelessWidget {
  const StatisticsCashflowChart({
    required this.dailySummaries,
    required this.grouping,
    required this.form,
    this.height = AppChartGeometry.primaryPlotHeight,
    super.key,
  });

  final List<DailyCashflowSummary> dailySummaries;
  final StatisticsTimeGrouping grouping;
  final CashflowChartForm form;
  final double height;

  @override
  Widget build(BuildContext context) {
    final buckets = buildStatisticsCashflowBuckets(
      dailySummaries,
      grouping: grouping,
    );
    if (buckets.isEmpty ||
        buckets.every(
          (bucket) => bucket.incomeMinor == 0 && bucket.expenseMinor == 0,
        )) {
      return const AppChartEmptyState(message: '区间内暂无收支数据');
    }

    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final series = [
      _cashflowSeries(
        label: '收入',
        color: financeColors.income,
        buckets: buckets,
        fillArea: form == CashflowChartForm.line,
        valueMinor: (bucket) => bucket.incomeMinor,
      ),
      _cashflowSeries(
        label: '支出',
        color: financeColors.expense,
        buckets: buckets,
        fillArea: form == CashflowChartForm.line,
        valueMinor: (bucket) => bucket.expenseMinor,
      ),
    ];
    return AppCartesianChart(
      data: AppCartesianChartData(
        axisPoints: [
          for (var index = 0; index < buckets.length; index++)
            AppChartAxisPoint(x: index.toDouble(), label: buckets[index].label),
        ],
        series: series,
      ),
      form:
          form == CashflowChartForm.bar
              ? AppCartesianChartForm.bar
              : AppCartesianChartForm.line,
      includeZero: true,
      height: height,
      showLegend: true,
      showSeriesLabelInTooltip: true,
      emptyMessage: '区间内暂无收支数据',
    );
  }
}

AppChartSeries _cashflowSeries({
  required String label,
  required Color color,
  required List<StatisticsCashflowBucket> buckets,
  required int Function(StatisticsCashflowBucket bucket) valueMinor,
  bool fillArea = false,
}) {
  return AppChartSeries(
    label: label,
    color: color,
    fillArea: fillArea,
    points: [
      for (var index = 0; index < buckets.length; index++)
        AppChartPoint(
          x: index.toDouble(),
          value: valueMinor(buckets[index]) / 100,
          formattedValue:
              Money(minorUnits: valueMinor(buckets[index])).format(),
        ),
    ],
  );
}

class StatisticsBalanceTrendChart extends StatelessWidget {
  const StatisticsBalanceTrendChart({
    required this.points,
    required this.grouping,
    this.height = AppChartGeometry.secondaryPlotHeight,
    super.key,
  });

  final List<BalanceTrendPoint> points;
  final StatisticsTimeGrouping grouping;
  final double height;

  @override
  Widget build(BuildContext context) {
    final buckets = buildStatisticsBalanceTrendBuckets(
      points,
      grouping: grouping,
    );
    if (buckets.isEmpty) {
      return const AppChartEmptyState(message: '区间内暂无资产数据');
    }
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    return AppCartesianChart(
      data: AppCartesianChartData(
        axisPoints: [
          for (var index = 0; index < buckets.length; index++)
            AppChartAxisPoint(x: index.toDouble(), label: buckets[index].label),
        ],
        series: [
          _balanceSeries(
            label: '资产',
            color: financeColors.asset,
            buckets: buckets,
            value: (bucket) => bucket.assets,
          ),
          _balanceSeries(
            label: '负债',
            color: financeColors.liability,
            buckets: buckets,
            value: (bucket) => bucket.liabilities,
          ),
          _balanceSeries(
            label: '净资产',
            color: financeColors.equity,
            buckets: buckets,
            value: (bucket) => bucket.netAssets,
            fillArea: true,
          ),
        ],
      ),
      form: AppCartesianChartForm.line,
      height: height,
      maxAxisLabels: AppChartGeometry.trendAxisLabelLimit,
      showLegend: true,
      emptyMessage: '区间内暂无资产数据',
    );
  }
}

AppChartSeries _balanceSeries({
  required String label,
  required Color color,
  required List<StatisticsBalanceTrendBucket> buckets,
  required Money Function(StatisticsBalanceTrendBucket bucket) value,
  bool fillArea = false,
}) {
  return AppChartSeries(
    label: label,
    color: color,
    fillArea: fillArea,
    points: [
      for (var index = 0; index < buckets.length; index++)
        AppChartPoint(
          x: index.toDouble(),
          value: value(buckets[index]).minorUnits / 100,
          formattedValue: value(buckets[index]).format(),
        ),
    ],
  );
}

class StatisticsWeekdayChart extends StatelessWidget {
  const StatisticsWeekdayChart({
    required this.dailySummaries,
    this.height = AppChartGeometry.secondaryPlotHeight,
    super.key,
  });

  final List<DailyCashflowSummary> dailySummaries;
  final double height;

  @override
  Widget build(BuildContext context) {
    final buckets = buildStatisticsWeekdayExpenseBuckets(dailySummaries);
    if (buckets.every((bucket) => bucket.totalExpenseMinor == 0)) {
      return const AppChartEmptyState(message: '区间内暂无支出数据');
    }
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    return AppCartesianChart(
      data: AppCartesianChartData(
        axisPoints: [
          for (var index = 0; index < buckets.length; index++)
            AppChartAxisPoint(x: index.toDouble(), label: buckets[index].label),
        ],
        series: [
          AppChartSeries(
            label: '日均支出',
            color: financeColors.expense,
            points: [
              for (var index = 0; index < buckets.length; index++)
                AppChartPoint(
                  x: index.toDouble(),
                  value: buckets[index].averageExpenseMinor / 100,
                  formattedValue:
                      '日均 ${Money(minorUnits: buckets[index].averageExpenseMinor).format()}',
                ),
            ],
          ),
        ],
      ),
      form: AppCartesianChartForm.bar,
      height: height,
      maxAxisLabels: AppChartGeometry.weekdayAxisLabelLimit,
      includeZero: true,
      showLegend: true,
      showSeriesLabelInTooltip: false,
      emptyMessage: '区间内暂无支出数据',
    );
  }
}

class StatisticsDonutChart extends StatelessWidget {
  const StatisticsDonutChart({
    required this.items,
    required this.centerLabel,
    required this.centerValue,
    super.key,
  });

  final List<StatisticsBreakdownItem> items;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) {
    final slices = buildStatisticsDonutSlices(items);
    return AppDonutChart(
      slices: [
        for (var index = 0; index < slices.length; index++)
          AppDonutSlice(
            label: slices[index].title,
            value: slices[index].valueMinor.toDouble(),
            formattedValue:
                Money(minorUnits: slices[index].valueMinor).format(),
            color:
                slices[index].isOther
                    ? statisticsChartOtherColor(context)
                    : statisticsChartSeriesColor(context, index),
          ),
      ],
      centerLabel: centerLabel,
      centerValue: centerValue,
      emptyMessage: '区间内暂无分类数据',
    );
  }
}

Color statisticsChartSeriesColor(BuildContext context, int index) {
  final colors = Theme.of(context).extension<AppThemeExtension>()!;
  final slots = [
    colors.chart1,
    colors.chart2,
    colors.chart3,
    colors.chart4,
    colors.chart5,
    colors.chart6,
    colors.chart7,
    colors.chart8,
  ];
  assert(index >= 0 && index < slots.length, '系列色不循环复用，超出槽位的项应折叠为"其他"');
  return slots[index % slots.length];
}

Color statisticsChartOtherColor(BuildContext context) =>
    Theme.of(context).extension<AppThemeExtension>()!.chartOther;

Color statisticsCategoryRowColor(
  BuildContext context, {
  required int index,
  required int itemCount,
}) {
  if (itemCount > statisticsSeriesSlotCount &&
      index >= statisticsSeriesSlotCount - 1) {
    return statisticsChartOtherColor(context);
  }
  return statisticsChartSeriesColor(context, index);
}
