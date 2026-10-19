import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../shared/analytics/time_series_transform.dart';
import '../../../widget/business/analytics/chart/app_chart_empty_state.dart';
import '../../../widget/business/analytics/chart/app_donut_chart.dart';
import '../../../widget/business/analytics/chart/app_cartesian_chart.dart';
import '../presentation/statistics_presentation.dart';
import '../presentation/statistics_state_presentation.dart';
import '../view_model/statistics_view_model.dart';

class StatisticsCashflowChart extends StatelessWidget {
  const StatisticsCashflowChart({
    required this.from,
    required this.until,
    required this.dailySummaries,
    required this.form,
    this.height = AppChartGeometry.primaryPlotHeight,
    super.key,
  });

  final DateTime from;
  final DateTime until;
  final List<DailyCashflowSummary> dailySummaries;
  final CashflowChartForm form;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grouping = resolveTimeSeriesGranularity(
          from: from,
          until: until,
          availableWidth: constraints.maxWidth,
          minimumSlotWidth: form == CashflowChartForm.bar
              ? AppChartGeometry.trendBarMinSlotWidth
              : AppChartGeometry.trendLineMinSlotWidth,
        );
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
                AppChartAxisPoint(
                  x: index.toDouble(),
                  label: buckets[index].label,
                  tooltipLabel: grouping.tooltipLabelFor(buckets[index].date),
                ),
            ],
            series: series,
          ),
          form: form == CashflowChartForm.bar
              ? AppCartesianChartForm.bar
              : AppCartesianChartForm.line,
          includeZero: true,
          height: height,
          maxAxisLabels: AppChartGeometry.adaptiveAxisLabelLimit(
            constraints.maxWidth,
          ),
          showLegend: true,
          showSeriesLabelInTooltip: true,
          emptyMessage: '区间内暂无收支数据',
        );
      },
    );
  }
}

class StatisticsComparisonTrendChart extends StatelessWidget {
  const StatisticsComparisonTrendChart({
    required this.from,
    required this.until,
    required this.comparisonFrom,
    required this.comparisonUntil,
    required this.currentDailySummaries,
    required this.comparisonDailySummaries,
    required this.metric,
    required this.comparisonLabel,
    this.height = AppChartGeometry.primaryPlotHeight,
    super.key,
  });

  final DateTime from;
  final DateTime until;
  final DateTime comparisonFrom;
  final DateTime comparisonUntil;
  final List<DailyCashflowSummary> currentDailySummaries;
  final List<DailyCashflowSummary> comparisonDailySummaries;
  final StatisticsComparisonMetric metric;
  final String comparisonLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final grouping = resolveTimeSeriesGranularity(
          from: from,
          until: until,
          availableWidth: constraints.maxWidth,
          minimumSlotWidth: AppChartGeometry.trendLineMinSlotWidth,
        );
        final trend = buildStatisticsComparisonCashflowTrend(
          currentItems: currentDailySummaries,
          currentFrom: from,
          currentUntil: until,
          comparisonItems: comparisonDailySummaries,
          comparisonFrom: comparisonFrom,
          comparisonUntil: comparisonUntil,
          grouping: grouping,
        );
        final current = trend.current;
        final comparison = trend.comparison;
        if (current.isEmpty) {
          return const AppChartEmptyState(message: '区间内暂无可对比数据');
        }
        final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
        final color = metric == StatisticsComparisonMetric.expense
            ? financeColors.expense
            : financeColors.income;
        int valueOf(StatisticsCashflowBucket bucket) =>
            metric == StatisticsComparisonMetric.expense
            ? bucket.expenseMinor
            : bucket.incomeMinor;

        final currentSeries = AppChartSeries(
          label: '本期',
          color: color,
          points: [
            for (var index = 0; index < current.length; index++)
              AppChartPoint(
                x: index.toDouble(),
                value: valueOf(current[index]) / 100,
                formattedValue: Money(
                  minorUnits: valueOf(current[index]),
                ).format(),
              ),
          ],
        );
        final comparisonSeries = AppChartSeries(
          label: comparisonLabel,
          color: color.withValues(alpha: .45),
          dashArray: const [6, 4],
          points: [
            for (var index = 0; index < comparison.length; index++)
              AppChartPoint(
                x: index.toDouble(),
                value: valueOf(comparison[index]) / 100,
                formattedValue: Money(
                  minorUnits: valueOf(comparison[index]),
                ).format(),
              ),
          ],
        );

        return AppCartesianChart(
          data: AppCartesianChartData(
            axisPoints: [
              for (var index = 0; index < current.length; index++)
                AppChartAxisPoint(
                  x: index.toDouble(),
                  label: current[index].label,
                  tooltipLabel: grouping.tooltipLabelFor(current[index].date),
                ),
            ],
            series: [currentSeries, comparisonSeries],
          ),
          form: AppCartesianChartForm.line,
          height: height,
          includeZero: true,
          maxAxisLabels: AppChartGeometry.adaptiveAxisLabelLimit(
            constraints.maxWidth,
          ),
          showLegend: true,
          emptyMessage: '区间内暂无可对比数据',
        );
      },
    );
  }
}

class StatisticsComparisonCashflowTrend {
  const StatisticsComparisonCashflowTrend({
    required this.current,
    required this.comparison,
  });

  final List<StatisticsCashflowBucket> current;
  final List<StatisticsCashflowBucket> comparison;
}

/// Maps both periods onto the same elapsed-day horizon before sampling the
/// comparison cumulative values at the current period's bucket boundaries.
StatisticsComparisonCashflowTrend buildStatisticsComparisonCashflowTrend({
  required List<DailyCashflowSummary> currentItems,
  required DateTime currentFrom,
  required DateTime currentUntil,
  required List<DailyCashflowSummary> comparisonItems,
  required DateTime comparisonFrom,
  required DateTime comparisonUntil,
  required StatisticsTimeGrouping grouping,
}) {
  final currentDaily = fillStatisticsDailyCashflowDates(
    currentItems,
    from: currentFrom,
    until: currentUntil,
  );
  final currentBuckets = buildStatisticsCashflowBuckets(
    currentDaily,
    grouping: grouping,
  );
  if (currentBuckets.isEmpty) {
    return const StatisticsComparisonCashflowTrend(current: [], comparison: []);
  }

  final currentDayCount = _calendarDayCount(currentFrom, currentUntil);
  final comparisonDayCount = _calendarDayCount(comparisonFrom, comparisonUntil);
  if (currentDayCount <= 0 || comparisonDayCount <= 0) {
    return const StatisticsComparisonCashflowTrend(current: [], comparison: []);
  }

  final targetDayCount = currentDayCount > comparisonDayCount
      ? currentDayCount
      : comparisonDayCount;
  final currentCumulative = _cashflowCumulativePrefix(
    currentDaily,
    from: currentFrom,
    dayCount: targetDayCount,
  );
  final comparisonDaily = comparisonItems.isEmpty
      ? const <DailyCashflowSummary>[]
      : fillStatisticsDailyCashflowDates(
          comparisonItems,
          from: comparisonFrom,
          until: comparisonUntil,
        );
  final comparisonCumulative = _cashflowCumulativePrefix(
    comparisonDaily,
    from: comparisonFrom,
    dayCount: targetDayCount,
  );

  final currentResult = <StatisticsCashflowBucket>[];
  final comparisonResult = <StatisticsCashflowBucket>[];
  for (var index = 0; index < currentBuckets.length; index++) {
    final bucket = currentBuckets[index];
    final endDay = index + 1 < currentBuckets.length
        ? _calendarDayOffset(currentFrom, currentBuckets[index + 1].date)
        : targetDayCount;
    final sampleIndex = endDay.clamp(1, targetDayCount).toInt() - 1;
    currentResult.add(
      StatisticsCashflowBucket(
        date: bucket.date,
        label: bucket.label,
        incomeMinor: currentCumulative.income[sampleIndex],
        expenseMinor: currentCumulative.expense[sampleIndex],
      ),
    );
    if (comparisonDaily.isNotEmpty) {
      comparisonResult.add(
        StatisticsCashflowBucket(
          date: bucket.date,
          label: bucket.label,
          incomeMinor: comparisonCumulative.income[sampleIndex],
          expenseMinor: comparisonCumulative.expense[sampleIndex],
        ),
      );
    }
  }
  return StatisticsComparisonCashflowTrend(
    current: currentResult,
    comparison: comparisonResult,
  );
}

({List<int> income, List<int> expense}) _cashflowCumulativePrefix(
  List<DailyCashflowSummary> items, {
  required DateTime from,
  required int dayCount,
}) {
  final byDay = <int, DailyCashflowSummary>{};
  for (final item in items) {
    final offset = _calendarDayOffset(from, item.date);
    if (offset >= 0 && offset < dayCount) byDay[offset] = item;
  }

  final income = List<int>.filled(dayCount, 0);
  final expense = List<int>.filled(dayCount, 0);
  var incomeTotal = 0;
  var expenseTotal = 0;
  for (var index = 0; index < dayCount; index++) {
    final item = byDay[index];
    incomeTotal += item?.income.minorUnits ?? 0;
    expenseTotal += item?.expense.minorUnits ?? 0;
    income[index] = incomeTotal;
    expense[index] = expenseTotal;
  }
  return (income: income, expense: expense);
}

int _calendarDayCount(DateTime from, DateTime until) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(until.year, until.month, until.day);
  return end.difference(start).inDays;
}

int _calendarDayOffset(DateTime from, DateTime date) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final target = DateTime.utc(date.year, date.month, date.day);
  return target.difference(start).inDays;
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
          formattedValue: Money(
            minorUnits: valueMinor(buckets[index]),
          ).format(),
        ),
    ],
  );
}

class StatisticsInstallmentCashflowChart extends StatelessWidget {
  const StatisticsInstallmentCashflowChart({
    required this.months,
    this.height = AppChartGeometry.primaryPlotHeight,
    super.key,
  });

  final List<StatisticsInstallmentCashflowMonth> months;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return const AppChartEmptyState(message: '暂无未来分期还款');
    }
    return AppCartesianChart(
      data: AppCartesianChartData(
        axisPoints: [
          for (var index = 0; index < months.length; index++)
            AppChartAxisPoint(
              x: index.toDouble(),
              label: months[index].month.month == 1
                  ? '${months[index].month.year}年'
                  : '${months[index].month.month}月',
            ),
        ],
        series: [
          AppChartSeries(
            label: '待还本金',
            color: statisticsChartSeriesColor(context, 0),
            points: [
              for (var index = 0; index < months.length; index++)
                AppChartPoint(
                  x: index.toDouble(),
                  value: months[index].principal.minorUnits / 100,
                  formattedValue: months[index].principal.format(),
                ),
            ],
          ),
          AppChartSeries(
            label: '待还利息',
            color: statisticsChartSeriesColor(context, 1),
            points: [
              for (var index = 0; index < months.length; index++)
                AppChartPoint(
                  x: index.toDouble(),
                  value: months[index].interest.minorUnits / 100,
                  formattedValue: months[index].interest.format(),
                ),
            ],
          ),
        ],
      ),
      form: AppCartesianChartForm.bar,
      height: height,
      includeZero: true,
      showLegend: true,
      emptyMessage: '暂无未来分期还款',
    );
  }
}

class StatisticsBalanceTrendChart extends StatelessWidget {
  const StatisticsBalanceTrendChart({
    required this.points,
    this.height = AppChartGeometry.secondaryPlotHeight,
    super.key,
  });

  final List<BalanceTrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = _balanceTrendBounds(points);
        final grouping = bounds == null
            ? StatisticsTimeGrouping.day
            : resolveTimeSeriesGranularity(
                from: bounds.from,
                until: bounds.until,
                availableWidth: constraints.maxWidth,
                minimumSlotWidth: AppChartGeometry.trendLineMinSlotWidth,
              );
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
                AppChartAxisPoint(
                  x: index.toDouble(),
                  label: buckets[index].label,
                  tooltipLabel: grouping.tooltipLabelFor(buckets[index].date),
                ),
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
          maxAxisLabels: AppChartGeometry.adaptiveAxisLabelLimit(
            constraints.maxWidth,
          ),
          showLegend: true,
          emptyMessage: '区间内暂无资产数据',
        );
      },
    );
  }
}

({DateTime from, DateTime until})? _balanceTrendBounds(
  List<BalanceTrendPoint> points,
) {
  if (points.isEmpty) return null;
  var from = points.first.date;
  var until = points.first.date;
  for (final point in points.skip(1)) {
    if (point.date.isBefore(from)) from = point.date;
    if (point.date.isAfter(until)) until = point.date;
  }
  if (!until.isAfter(from)) {
    until = from.add(const Duration(days: 1));
  }
  return (from: from, until: until);
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
      showLegend: false,
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
    this.height = AppChartGeometry.donutPlotHeight,
    super.key,
  });

  final List<StatisticsBreakdownItem> items;
  final String centerLabel;
  final String centerValue;
  final double height;

  @override
  Widget build(BuildContext context) {
    final slices = buildStatisticsDonutSlices(items);
    return AppDonutChart(
      slices: [
        for (var index = 0; index < slices.length; index++)
          AppDonutSlice(
            label: slices[index].title,
            value: slices[index].valueMinor.toDouble(),
            formattedValue: Money(
              minorUnits: slices[index].valueMinor,
            ).format(),
            color: slices[index].isOther
                ? statisticsChartOtherColor(context)
                : statisticsChartSeriesColor(context, index),
          ),
      ],
      centerLabel: centerLabel,
      centerValue: centerValue,
      height: height,
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
