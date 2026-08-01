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
    required this.grouping,
    required this.metric,
    super.key,
  });

  final List<DailyCashflowSummary> dailySummaries;
  final StatisticsTimeGrouping grouping;
  final CashflowChartMetric metric;

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
      return const StatisticsEmptyState(message: '区间内暂无收支数据');
    }
    return switch (metric) {
      CashflowChartMetric.compare => _CashflowCompareBars(buckets: buckets),
      CashflowChartMetric.cumulative => _CashflowCumulativeLine(
        buckets: buckets,
      ),
      _ => _CashflowMetricBars(buckets: buckets, metric: metric),
    };
  }
}

class _CashflowMetricBars extends StatelessWidget {
  const _CashflowMetricBars({required this.buckets, required this.metric});

  final List<StatisticsCashflowBucket> buckets;
  final CashflowChartMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final values = [
      for (final bucket in buckets) _metricMinor(bucket, metric) / 100,
    ];
    final scale = StatisticsChartScale.fromValues(values, includeZero: true);
    Color barColor(double value) =>
        metric == CashflowChartMetric.net
            ? (value < 0 ? financeColors.expense : financeColors.income)
            : statisticsCashflowMetricColor(context, metric);

    return SizedBox(
      height: AppChartGeometry.primaryPlotHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = _barWidth(constraints.maxWidth, buckets.length);
          return BarChart(
            duration: AppChartMotion.switchDuration,
            BarChartData(
              minY: scale.min,
              maxY: scale.max,
              baselineY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: _gridData(context, scale),
              titlesData: _titlesData(
                context,
                labels: [for (final bucket in buckets) bucket.label],
                maxLabels: AppChartGeometry.cashflowAxisLabelLimit,
                scale: scale,
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
                        color: barColor(values[i]),
                        width: barWidth,
                        borderRadius: _barRadius(values[i]),
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

class _CashflowCompareBars extends StatelessWidget {
  const _CashflowCompareBars({required this.buckets});

  final List<StatisticsCashflowBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final incomeValues = [
      for (final bucket in buckets) bucket.incomeMinor / 100,
    ];
    final expenseValues = [
      for (final bucket in buckets) bucket.expenseMinor / 100,
    ];
    final scale = StatisticsChartScale.fromValues([
      ...incomeValues,
      ...expenseValues,
    ], includeZero: true);
    return Column(
      children: [
        SizedBox(
          height: AppChartGeometry.primaryPlotHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = _barWidth(
                constraints.maxWidth,
                buckets.length * 2,
              );
              return BarChart(
                duration: AppChartMotion.switchDuration,
                BarChartData(
                  minY: scale.min,
                  maxY: scale.max,
                  baselineY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: _gridData(context, scale),
                  titlesData: _titlesData(
                    context,
                    labels: [for (final bucket in buckets) bucket.label],
                    maxLabels: AppChartGeometry.cashflowAxisLabelLimit,
                    scale: scale,
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => colors.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final bucket = buckets[group.x];
                        final base = TextStyle(color: colors.onInverseSurface);
                        return BarTooltipItem(
                          '${bucket.label}\n',
                          base,
                          textAlign: TextAlign.left,
                          children: [
                            TextSpan(
                              text: '● ',
                              style: TextStyle(color: financeColors.income),
                            ),
                            TextSpan(
                              text:
                                  '收入 ${Money(minorUnits: bucket.incomeMinor).format()}\n',
                            ),
                            TextSpan(
                              text: '● ',
                              style: TextStyle(color: financeColors.expense),
                            ),
                            TextSpan(
                              text:
                                  '支出 ${Money(minorUnits: bucket.expenseMinor).format()}',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: AppChartGeometry.groupedBarGap,
                        barRods: [
                          BarChartRodData(
                            toY: incomeValues[i],
                            color: financeColors.income,
                            width: barWidth,
                            borderRadius: _barRadius(incomeValues[i]),
                          ),
                          BarChartRodData(
                            toY: expenseValues[i],
                            color: financeColors.expense,
                            width: barWidth,
                            borderRadius: _barRadius(expenseValues[i]),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.space16,
          runSpacing: AppSpacing.space8,
          children: [
            _ChartLegendItem(label: '收入', color: financeColors.income),
            _ChartLegendItem(label: '支出', color: financeColors.expense),
          ],
        ),
      ],
    );
  }
}

class _CashflowCumulativeLine extends StatelessWidget {
  const _CashflowCumulativeLine({required this.buckets});

  final List<StatisticsCashflowBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    var runningMinor = 0;
    final cumulativeMinor = <int>[];
    final values = <double>[];
    for (final bucket in buckets) {
      runningMinor += bucket.netMinor;
      cumulativeMinor.add(runningMinor);
      values.add(runningMinor / 100);
    }
    final scale = StatisticsChartScale.fromValues(values, includeZero: true);
    return SizedBox(
      height: AppChartGeometry.primaryPlotHeight,
      child: LineChart(
        duration: AppChartMotion.switchDuration,
        LineChartData(
          minX: 0,
          maxX: math.max(1, buckets.length - 1).toDouble(),
          minY: scale.min,
          maxY: scale.max,
          borderData: FlBorderData(show: false),
          gridData: _gridData(context, scale),
          titlesData: _titlesData(
            context,
            labels: [for (final bucket in buckets) bucket.label],
            maxLabels: AppChartGeometry.cashflowAxisLabelLimit,
            scale: scale,
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) => colors.inverseSurface,
              getTooltipItems:
                  (touchedSpots) => [
                    for (final spot in touchedSpots)
                      LineTooltipItem(
                        '${buckets[spot.x.round()].label}\n'
                        '累计结余 ${Money(minorUnits: cumulativeMinor[spot.x.round()]).format()}',
                        TextStyle(color: colors.onInverseSurface),
                      ),
                  ],
            ),
          ),
          lineBarsData: [
            _trendLine(
              values,
              financeColors.equity,
              buckets.length,
              surfaceColor: colors.surfaceContainerLowest,
              fillArea: true,
            ),
          ],
        ),
      ),
    );
  }
}

class StatisticsBalanceTrendChart extends StatelessWidget {
  const StatisticsBalanceTrendChart({
    required this.points,
    required this.grouping,
    super.key,
  });

  final List<BalanceTrendPoint> points;
  final StatisticsTimeGrouping grouping;

  @override
  Widget build(BuildContext context) {
    final buckets = buildStatisticsBalanceTrendBuckets(
      points,
      grouping: grouping,
    );
    if (buckets.isEmpty) {
      return const StatisticsEmptyState(message: '区间内暂无资产数据');
    }
    final assetValues = [
      for (final bucket in buckets) bucket.assets.minorUnits / 100,
    ];
    final liabilityValues = [
      for (final bucket in buckets) bucket.liabilities.minorUnits / 100,
    ];
    final netAssetValues = [
      for (final bucket in buckets) bucket.netAssets.minorUnits / 100,
    ];
    final scale = StatisticsChartScale.fromValues([
      ...assetValues,
      ...liabilityValues,
      ...netAssetValues,
    ]);
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    return Column(
      children: [
        SizedBox(
          height: AppChartGeometry.secondaryPlotHeight,
          child: LineChart(
            duration: AppChartMotion.switchDuration,
            LineChartData(
              minX: 0,
              maxX: math.max(1, buckets.length - 1).toDouble(),
              minY: scale.min,
              maxY: scale.max,
              borderData: FlBorderData(show: false),
              gridData: _gridData(context, scale),
              titlesData: _titlesData(
                context,
                labels: [for (final bucket in buckets) bucket.label],
                maxLabels: AppChartGeometry.trendAxisLabelLimit,
                scale: scale,
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => colors.inverseSurface,
                  getTooltipItems:
                      (touchedSpots) => [
                        for (final spot in touchedSpots)
                          _balanceTooltipItem(context, buckets, spot),
                      ],
                ),
              ),
              lineBarsData: [
                _trendLine(
                  assetValues,
                  financeColors.asset,
                  buckets.length,
                  surfaceColor: colors.surfaceContainerLowest,
                ),
                _trendLine(
                  liabilityValues,
                  financeColors.liability,
                  buckets.length,
                  surfaceColor: colors.surfaceContainerLowest,
                ),
                _trendLine(
                  netAssetValues,
                  financeColors.equity,
                  buckets.length,
                  surfaceColor: colors.surfaceContainerLowest,
                  fillArea: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.space16,
          runSpacing: AppSpacing.space8,
          children: [
            _ChartLegendItem(label: '资产', color: financeColors.asset),
            _ChartLegendItem(label: '负债', color: financeColors.liability),
            _ChartLegendItem(label: '净资产', color: financeColors.equity),
          ],
        ),
      ],
    );
  }
}

LineTooltipItem _balanceTooltipItem(
  BuildContext context,
  List<StatisticsBalanceTrendBucket> buckets,
  LineBarSpot spot,
) {
  final colors = Theme.of(context).colorScheme;
  final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
  final bucket = buckets[spot.x.round()];
  final (name, seriesColor, minor) = switch (spot.barIndex) {
    0 => ('资产', financeColors.asset, bucket.assets.minorUnits),
    1 => ('负债', financeColors.liability, bucket.liabilities.minorUnits),
    _ => ('净资产', financeColors.equity, bucket.netAssets.minorUnits),
  };
  return LineTooltipItem(
    spot.barIndex == 0 ? '${bucket.label}\n' : '',
    TextStyle(color: colors.onInverseSurface),
    textAlign: TextAlign.left,
    children: [
      TextSpan(text: '● ', style: TextStyle(color: seriesColor)),
      TextSpan(text: '$name ${Money(minorUnits: minor).format()}'),
    ],
  );
}

class StatisticsWeekdayChart extends StatelessWidget {
  const StatisticsWeekdayChart({required this.dailySummaries, super.key});

  final List<DailyCashflowSummary> dailySummaries;

  @override
  Widget build(BuildContext context) {
    final buckets = buildStatisticsWeekdayExpenseBuckets(dailySummaries);
    if (buckets.every((bucket) => bucket.totalExpenseMinor == 0)) {
      return const StatisticsEmptyState(message: '区间内暂无支出数据');
    }
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final values = [
      for (final bucket in buckets) bucket.averageExpenseMinor / 100,
    ];
    final scale = StatisticsChartScale.fromValues(values, includeZero: true);
    return SizedBox(
      height: AppChartGeometry.secondaryPlotHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = _barWidth(constraints.maxWidth, buckets.length);
          return BarChart(
            duration: AppChartMotion.switchDuration,
            BarChartData(
              minY: scale.min,
              maxY: scale.max,
              baselineY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: _gridData(context, scale),
              titlesData: _titlesData(
                context,
                labels: [for (final bucket in buckets) bucket.label],
                maxLabels: AppChartGeometry.weekdayAxisLabelLimit,
                scale: scale,
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => colors.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final bucket = buckets[group.x];
                    final amount =
                        Money(minorUnits: bucket.averageExpenseMinor).format();
                    return BarTooltipItem(
                      '${bucket.label}\n日均 $amount',
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
                        color: financeColors.expense,
                        width: barWidth,
                        borderRadius: _barRadius(values[i]),
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

LineChartBarData _trendLine(
  List<double> values,
  Color color,
  int pointCount, {
  required Color surfaceColor,
  bool fillArea = false,
}) {
  return LineChartBarData(
    spots: [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ],
    color: color,
    barWidth: AppChartGeometry.lineWidth,
    isCurved: pointCount > 2,
    preventCurveOverShooting: true,
    dotData: FlDotData(
      show: pointCount <= 12,
      getDotPainter:
          (spot, percent, bar, index) => FlDotCirclePainter(
            radius: AppChartGeometry.lineDotRadius,
            color: color,
            strokeWidth: AppChartGeometry.lineDotStrokeWidth,
            strokeColor: surfaceColor,
          ),
    ),
    belowBarData: BarAreaData(
      show: fillArea,
      color: color.withValues(alpha: AppChartGeometry.areaFillOpacity),
    ),
  );
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.space12,
          height: AppSpacing.space4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          ),
        ),
        const SizedBox(width: AppSpacing.space6),
        Text(label, style: context.appTextStyles.listSupporting),
      ],
    );
  }
}

class StatisticsDonutChart extends StatefulWidget {
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
  State<StatisticsDonutChart> createState() => _StatisticsDonutChartState();
}

class _StatisticsDonutChartState extends State<StatisticsDonutChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(StatisticsDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const StatisticsEmptyState(message: '区间内暂无分类数据');
    }
    final slices = buildStatisticsDonutSlices(widget.items);
    final selected =
        _selectedIndex != null && _selectedIndex! < slices.length
            ? _selectedIndex
            : null;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final centerLabel =
        selected == null ? widget.centerLabel : slices[selected].title;
    final centerValue =
        selected == null
            ? widget.centerValue
            : Money(minorUnits: slices[selected].valueMinor).format();
    return SizedBox(
      height: AppChartGeometry.donutPlotHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            duration: AppChartMotion.switchDuration,
            PieChartData(
              centerSpaceRadius: AppChartGeometry.pieCenterRadius,
              sectionsSpace: AppSpacing.space2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) {
                    return;
                  }
                  final index = response?.touchedSection?.touchedSectionIndex;
                  setState(() {
                    _selectedIndex =
                        index == null || index < 0 || index == _selectedIndex
                            ? null
                            : index;
                  });
                },
              ),
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].valueMinor.toDouble(),
                    color:
                        slices[i].isOther
                            ? statisticsChartOtherColor(context)
                            : statisticsChartSeriesColor(context, i),
                    radius:
                        AppChartGeometry.pieSectionRadius +
                        (i == selected
                            ? AppChartGeometry.pieSelectedSectionBump
                            : 0),
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
    _ => colors.equity,
  };
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
  assert(
    index >= 0 && index < slots.length,
    '系列色不循环复用，超出槽位的项应折叠为"其他"',
  );
  return slots[index % slots.length];
}

Color statisticsChartOtherColor(BuildContext context) =>
    Theme.of(context).extension<AppThemeExtension>()!.chartOther;

/// 列表行与环形图共用的取色：折叠场景下尾部行统一使用"其他"色。
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

class StatisticsChartScale {
  const StatisticsChartScale._(this.min, this.max, this.interval);

  /// 把数据范围取整到干净的刻度倍数，保证网格线与轴标签对齐。
  factory StatisticsChartScale.fromValues(
    List<double> values, {
    bool includeZero = false,
  }) {
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (includeZero) {
      lo = math.min(lo, 0);
      hi = math.max(hi, 0);
    }
    if (lo == hi) {
      final pad = math.max(1.0, lo.abs() * .16);
      if (lo >= 0 && includeZero) {
        hi = lo + pad;
        lo = 0;
      } else {
        lo -= pad;
        hi += pad;
      }
    }
    final interval = _niceInterval(hi - lo);
    final niceLo = (lo / interval).floorToDouble() * interval;
    var niceHi = (hi / interval).ceilToDouble() * interval;
    if (niceHi == niceLo) {
      niceHi = niceLo + interval;
    }
    return StatisticsChartScale._(niceLo, niceHi, interval);
  }

  final double min;
  final double max;
  final double interval;

  static double _niceInterval(double span) {
    final raw = span / 3;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final fraction = raw / magnitude;
    final step =
        fraction <= 1
            ? 1.0
            : fraction <= 2
            ? 2.0
            : fraction <= 5
            ? 5.0
            : 10.0;
    return step * magnitude;
  }
}

/// 轴刻度金额的紧凑格式：整数元为主，达到万/亿换单位。
String statisticsAxisLabel(double value) {
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();
  if (abs >= 100000000) {
    return '$sign${_compactNumber(abs / 100000000)}亿';
  }
  if (abs >= 10000) {
    return '$sign${_compactNumber(abs / 10000)}万';
  }
  return '$sign${_compactNumber(abs)}';
}

String _compactNumber(double value) {
  var text = value.toStringAsFixed(2);
  while (text.contains('.') && (text.endsWith('0') || text.endsWith('.'))) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

double _barWidth(double maxWidth, int slotCount) =>
    ((maxWidth - AppChartGeometry.leftAxisReservedWidth) /
            slotCount *
            AppChartGeometry.barWidthRatio)
        .clamp(AppChartGeometry.barWidthMin, AppChartGeometry.barWidthMax);

BorderRadius _barRadius(double value) =>
    value < 0
        ? const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.radiusSm),
        )
        : const BorderRadius.vertical(top: Radius.circular(AppRadius.radiusSm));

FlGridData _gridData(BuildContext context, StatisticsChartScale scale) {
  final colors = Theme.of(context).colorScheme;
  return FlGridData(
    drawVerticalLine: false,
    horizontalInterval: scale.interval,
    getDrawingHorizontalLine:
        (value) => FlLine(
          color: colors.outlineVariant.withValues(
            alpha:
                value == 0 && scale.min < 0
                    ? AppChartGeometry.zeroLineOpacity
                    : AppChartGeometry.gridLineOpacity,
          ),
          strokeWidth: AppChartGeometry.gridLineWidth,
        ),
  );
}

FlTitlesData _titlesData(
  BuildContext context, {
  required List<String> labels,
  required int maxLabels,
  required StatisticsChartScale scale,
}) {
  final interval = math.max(1, (labels.length / maxLabels).ceil());
  final style = Theme.of(context).textTheme.labelSmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: AppChartGeometry.leftAxisReservedWidth,
        interval: scale.interval,
        getTitlesWidget:
            (value, meta) => SideTitleWidget(
              meta: meta,
              space: AppSpacing.space6,
              child: Text(
                statisticsAxisLabel(value),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
      ),
    ),
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
      _ => bucket.netMinor,
    };
