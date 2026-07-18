import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';
import 'statistics_section.dart';

class StatisticsCashflowChart extends StatelessWidget {
  const StatisticsCashflowChart({
    required this.dailySummaries,
    required this.until,
    required this.grouping,
    required this.metric,
    super.key,
  });

  final List<DailyCashflowSummary> dailySummaries;
  final DateTime until;
  final StatisticsTimeGrouping grouping;
  final CashflowChartMetric metric;

  @override
  Widget build(BuildContext context) {
    final buckets = buildStatisticsCashflowBuckets(
      dailySummaries,
      grouping: grouping,
      until: until,
    );
    if (buckets.isEmpty ||
        buckets.every(
          (bucket) => bucket.incomeMinor == 0 && bucket.expenseMinor == 0,
        )) {
      return const StatisticsEmptyState(message: '区间内暂无收支数据');
    }
    final values = [
      for (final bucket in buckets) _metricMinor(bucket, metric) / 100,
    ];
    final range = _ChartRange.from(values);
    final colors = Theme.of(context).colorScheme;
    final color = statisticsCashflowMetricColor(context, metric);

    return SizedBox(
      height: AppChartGeometry.primaryPlotHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = (constraints.maxWidth /
                  buckets.length *
                  AppChartGeometry.barWidthRatio)
              .clamp(
                AppChartGeometry.barWidthMin,
                AppChartGeometry.barWidthMax,
              );
          return BarChart(
            BarChartData(
              minY: range.min,
              maxY: range.max,
              baselineY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color: colors.outlineVariant.withValues(
                        alpha: AppChartGeometry.gridLineOpacity,
                      ),
                      strokeWidth: AppChartGeometry.gridLineWidth,
                    ),
              ),
              titlesData: _bottomTitles(
                context,
                labels: [for (final bucket in buckets) bucket.label],
                maxLabels: AppChartGeometry.cashflowAxisLabelLimit,
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => colors.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final bucket = buckets[group.x];
                    final amount =
                        Money(
                          minorUnits: _metricMinor(bucket, metric),
                        ).format();
                    return BarTooltipItem(
                      '${bucket.label}\n$amount',
                      TextStyle(color: colors.onInverseSurface),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < buckets.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        color: color,
                        width: barWidth,
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class StatisticsBalanceTrendChart extends StatelessWidget {
  const StatisticsBalanceTrendChart({
    required this.points,
    required this.grouping,
    required this.until,
    super.key,
  });

  final List<BalanceTrendPoint> points;
  final StatisticsTimeGrouping grouping;
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final buckets = buildStatisticsBalanceTrendBuckets(
      points,
      grouping: grouping,
      until: until,
    );
    if (buckets.isEmpty) {
      return const StatisticsEmptyState(message: '区间内暂无资产数据');
    }
    final values = [
      for (final bucket in buckets) bucket.balance.minorUnits / 100,
    ];
    final range = _ChartRange.from(values);
    final colors = Theme.of(context).colorScheme;
    final color = Theme.of(context).extension<AppThemeExtension>()!.asset;
    return SizedBox(
      height: AppChartGeometry.secondaryPlotHeight,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: math.max(1, buckets.length - 1).toDouble(),
          minY: range.min,
          maxY: range.max,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine:
                (_) => FlLine(
                  color: colors.outlineVariant.withValues(
                    alpha: AppChartGeometry.gridLineOpacity,
                  ),
                  strokeWidth: AppChartGeometry.gridLineWidth,
                ),
          ),
          titlesData: _bottomTitles(
            context,
            labels: [for (final bucket in buckets) bucket.label],
            maxLabels: AppChartGeometry.trendAxisLabelLimit,
          ),
          lineTouchData: const LineTouchData(enabled: true),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < buckets.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              color: color,
              barWidth: AppChartGeometry.lineWidth,
              isCurved: buckets.length > 2,
              dotData: FlDotData(show: buckets.length <= 12),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(
                  alpha: AppChartGeometry.areaFillOpacity,
                ),
              ),
            ),
          ],
        ),
      ),
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
    if (items.isEmpty) {
      return const StatisticsEmptyState(message: '区间内暂无分类数据');
    }
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: AppChartGeometry.donutPlotHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              centerSpaceRadius: AppChartGeometry.pieCenterRadius,
              sectionsSpace: AppSpacing.space2,
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: statisticsCategoryMagnitude(items[i]).toDouble(),
                    color: statisticsChartSeriesColor(context, i),
                    radius: AppChartGeometry.pieSectionRadius,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  centerValue,
                  style: context.appTextStyles.subsectionTitleStrong,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color statisticsCashflowMetricColor(
  BuildContext context,
  CashflowChartMetric metric,
) {
  final colors = Theme.of(context).extension<AppThemeExtension>()!;
  return switch (metric) {
    CashflowChartMetric.expense => colors.expense,
    CashflowChartMetric.income => colors.income,
    CashflowChartMetric.net => colors.equity,
  };
}

Color statisticsChartSeriesColor(BuildContext context, int index) {
  final colors = Theme.of(context).extension<AppThemeExtension>()!;
  return [
    colors.chart1,
    colors.chart2,
    colors.chart3,
    colors.chart4,
    colors.chart5,
  ][index % 5];
}

FlTitlesData _bottomTitles(
  BuildContext context, {
  required List<String> labels,
  required int maxLabels,
}) {
  final interval = math.max(1, (labels.length / maxLabels).ceil());
  final style = Theme.of(context).textTheme.labelSmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  return FlTitlesData(
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: AppSpacing.space28,
        interval: 1,
        minIncluded: true,
        maxIncluded: true,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (value != index.toDouble() ||
              index < 0 ||
              index >= labels.length) {
            return const SizedBox.shrink();
          }
          final lastIndex = labels.length - 1;
          final show =
              index == 0 ||
              index == lastIndex ||
              (index % interval == 0 && lastIndex - index >= interval);
          if (!show) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            space: AppSpacing.space8,
            child: Text(
              labels[index],
              style: style,
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          );
        },
      ),
    ),
  );
}

int _metricMinor(StatisticsCashflowBucket bucket, CashflowChartMetric metric) =>
    switch (metric) {
      CashflowChartMetric.expense => bucket.expenseMinor,
      CashflowChartMetric.income => bucket.incomeMinor,
      CashflowChartMetric.net => bucket.netMinor,
    };

class _ChartRange {
  const _ChartRange(this.min, this.max);

  factory _ChartRange.from(List<double> values) {
    final smallest = values.reduce(math.min);
    final largest = values.reduce(math.max);
    if (smallest == largest) {
      final padding = math.max(1.0, smallest.abs() * .16);
      return _ChartRange(math.min(0, smallest - padding), largest + padding);
    }
    final span = largest - smallest;
    final padding = span * .12;
    return _ChartRange(
      smallest >= 0 ? 0 : smallest - padding,
      largest <= 0 ? 0 : largest + padding,
    );
  }

  final double min;
  final double max;
}
