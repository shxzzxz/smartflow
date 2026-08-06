import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../widget/business/analytics/chart/app_cartesian_chart.dart';

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
    final lastDay = month.nextMonthStart.subtract(const Duration(days: 1)).day;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    return AppCartesianChart(
      data: AppCartesianChartData(
        axisPoints: [
          for (var day = 1; day <= lastDay; day++)
            AppChartAxisPoint(
              x: (day - 1).toDouble(),
              label: '$day日',
              showOnAxis: day == 1 || day == 15 || day == lastDay,
            ),
        ],
        series: [
          _budgetSeries(
            label: '余',
            color: financeColors.chart1,
            points: points,
            value: (point) => point.remaining,
          ),
          _budgetSeries(
            label: '支',
            color: financeColors.chart2,
            points: points,
            value: (point) => point.spent,
          ),
        ],
      ),
      form: AppCartesianChartForm.line,
      height: AppChartGeometry.secondaryPlotHeight,
      maxAxisLabels: 3,
      includeZero: true,
      showLegend: true,
    );
  }
}

AppChartSeries _budgetSeries({
  required String label,
  required Color color,
  required List<BudgetTrendPoint> points,
  required Money Function(BudgetTrendPoint point) value,
}) {
  return AppChartSeries(
    label: label,
    color: color,
    points: [
      for (final point in points)
        AppChartPoint(
          x: (point.date.day - 1).toDouble(),
          value: value(point).minorUnits / 100,
          formattedValue: value(point).format(),
        ),
    ],
  );
}

List<BudgetTrendPoint> _chartPoints(MonthKey month, BudgetProgress progress) {
  final lastDay = month.nextMonthStart.subtract(const Duration(days: 1)).day;
  final trendByDay = {
    for (final point in progress.trend) point.date.day: point,
  };
  var latest = BudgetTrendPoint(
    date: month.start,
    spent: Money.zero(),
    remaining: progress.budget,
  );
  return [
    for (var day = 1; day <= lastDay; day++)
      (latest =
          trendByDay[day] ??
          BudgetTrendPoint(
            date: DateTime(month.year, month.month, day),
            spent: latest.spent,
            remaining: latest.remaining,
          )),
  ];
}
