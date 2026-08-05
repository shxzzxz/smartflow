import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';

class BudgetTrendChart extends StatelessWidget {
  const BudgetTrendChart({
    required this.month,
    required this.progress,
    super.key,
  });

  final MonthKey month;
  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final points = _chartPoints(month, progress);
    final spent = [for (final point in points) point.spent.minorUnits / 100];
    final remaining = [
      for (final point in points) point.remaining.minorUnits / 100,
    ];
    final values = [...spent, ...remaining];
    final minValue = math.min(0, values.reduce(math.min));
    var maxValue = math.max(0, values.reduce(math.max));
    if (maxValue == minValue) maxValue = minValue + 1;
    final padding = math.max(1.0, (maxValue - minValue) * .12);
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final lastDay = month.nextMonthStart.subtract(const Duration(days: 1)).day;

    return Column(
      children: [
        SizedBox(
          height: AppChartGeometry.secondaryPlotHeight,
          child: LineChart(
            duration: AppChartMotion.switchDuration,
            LineChartData(
              minX: 0,
              maxX: math.max(1, lastDay - 1).toDouble(),
              minY: minValue - padding,
              maxY: maxValue + padding,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine:
                    (_) => FlLine(
                      color: colors.outlineVariant.withValues(alpha: .42),
                      strokeWidth: 1,
                    ),
              ),
              titlesData: _titles(context, lastDay),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => colors.inverseSurface,
                  getTooltipItems:
                      (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                            '${spot.x.round() + 1}日\n'
                            '${spot.barIndex == 0 ? '剩余' : '支出'} '
                            '${Money(minorUnits: (spot.y * 100).round()).format()}',
                            TextStyle(color: colors.onInverseSurface),
                          ),
                      ],
                ),
              ),
              lineBarsData: [
                _line(
                  points: points,
                  values: remaining,
                  color: financeColors.chart1,
                  surface: colors.surfaceContainerLowest,
                ),
                _line(
                  points: points,
                  values: spent,
                  color: financeColors.chart2,
                  surface: colors.surfaceContainerLowest,
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
            _Legend(label: '剩余预算', color: financeColors.chart1),
            _Legend(label: '预算支出', color: financeColors.chart2),
          ],
        ),
      ],
    );
  }
}

List<BudgetTrendPoint> _chartPoints(MonthKey month, BudgetProgress progress) {
  final byDay = <int, BudgetTrendPoint>{
    1: BudgetTrendPoint(
      date: month.start,
      spent: Money.zero(),
      remaining: progress.budget,
    ),
    for (final point in progress.trend) point.date.day: point,
  };
  final lastDay = month.nextMonthStart.subtract(const Duration(days: 1)).day;
  final latest = progress.trend.isEmpty ? byDay[1]! : progress.trend.last;
  byDay[lastDay] = BudgetTrendPoint(
    date: DateTime(month.year, month.month, lastDay),
    spent: latest.spent,
    remaining: latest.remaining,
  );
  final days = byDay.keys.toList()..sort();
  return [for (final day in days) byDay[day]!];
}

LineChartBarData _line({
  required List<BudgetTrendPoint> points,
  required List<double> values,
  required Color color,
  required Color surface,
}) {
  return LineChartBarData(
    spots: [
      for (var index = 0; index < points.length; index++)
        FlSpot((points[index].date.day - 1).toDouble(), values[index]),
    ],
    color: color,
    barWidth: AppChartGeometry.lineWidth,
    isCurved: points.length > 2,
    preventCurveOverShooting: true,
    dotData: FlDotData(
      show: points.length <= 12,
      getDotPainter:
          (_, _, _, _) => FlDotCirclePainter(
            radius: AppChartGeometry.lineDotRadius,
            color: color,
            strokeWidth: AppChartGeometry.lineDotStrokeWidth,
            strokeColor: surface,
          ),
    ),
  );
}

FlTitlesData _titles(BuildContext context, int lastDay) {
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
        getTitlesWidget:
            (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(_axisLabel(value), style: style),
            ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: AppSpacing.space28,
        getTitlesWidget: (value, meta) {
          final day = value.round() + 1;
          if (value != value.roundToDouble()) {
            return const SizedBox.shrink();
          }
          if (day != 1 && day != 15 && day != lastDay) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            child: Text('$day日', style: style),
          );
        },
      ),
    ),
  );
}

String _axisLabel(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 10000) return '$sign${(abs / 10000).toStringAsFixed(1)}万';
  return '$sign${abs.round()}';
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

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
