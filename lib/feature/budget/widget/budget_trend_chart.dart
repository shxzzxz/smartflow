import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';
import '../../../widget/business/analytics/chart/app_cartesian_chart.dart';

enum _BudgetTrendMetric { remaining, spent }

class BudgetTrendChart extends StatefulWidget {
  const BudgetTrendChart({
    required this.month,
    required this.progress,
    this.height = AppChartGeometry.secondaryPlotHeight,
    super.key,
  });

  final MonthKey month;
  final BudgetProgress progress;
  final double height;

  @override
  State<BudgetTrendChart> createState() => _BudgetTrendChartState();
}

class _BudgetTrendChartState extends State<BudgetTrendChart> {
  final Set<_BudgetTrendMetric> _visibleMetrics = {
    _BudgetTrendMetric.remaining,
    _BudgetTrendMetric.spent,
  };
  var _showPreviousMonth = false;
  var _showPreviousYear = false;

  bool get _hasVisibleMetrics =>
      _visibleMetrics.contains(_BudgetTrendMetric.remaining) ||
      _visibleMetrics.contains(_BudgetTrendMetric.spent);

  @override
  Widget build(BuildContext context) {
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final axisDayCount = _axisDayCount();
    final currentPoints = _filledPoints(
      widget.progress.trend,
      targetDays: axisDayCount,
      initialRemaining: widget.progress.budget,
    );
    final previousMonthPoints = _filledPoints(
      widget.progress.previousMonthTrend,
      targetDays: axisDayCount,
      initialRemaining: widget.progress.budget,
    );
    final previousYearPoints = _filledPoints(
      widget.progress.previousYearTrend,
      targetDays: axisDayCount,
      initialRemaining: widget.progress.budget,
    );
    List<AppChartSeries> seriesFor(
      _BudgetTrendMetric metric, {
      required String label,
      required Color color,
      required Money originValue,
      required Money Function(_BudgetDayPoint point) value,
    }) {
      if (!_visibleMetrics.contains(metric)) return const [];
      return [
        _budgetSeries(
          label: label,
          color: color,
          points: currentPoints,
          originValue: originValue,
          value: value,
        ),
        if (_showPreviousMonth)
          _budgetSeries(
            label: '环比$label',
            color: color,
            points: previousMonthPoints,
            originValue: originValue,
            value: value,
            dashArray: AppChartGeometry.dashedLinePattern,
          ),
        if (_showPreviousYear)
          _budgetSeries(
            label: '同比$label',
            color: color,
            points: previousYearPoints,
            originValue: originValue,
            value: value,
            dashArray: AppChartGeometry.dottedLinePattern,
          ),
      ];
    }

    final series = [
      ...seriesFor(
        _BudgetTrendMetric.remaining,
        label: '余',
        color: financeColors.chart1,
        originValue: widget.progress.budget,
        value: (point) => point.remaining,
      ),
      ...seriesFor(
        _BudgetTrendMetric.spent,
        label: '支',
        color: financeColors.chart2,
        originValue: Money.zero(),
        value: (point) => point.spent,
      ),
    ];
    final chartSignature = [
      axisDayCount,
      for (final item in series) item.label,
    ].join('|');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCartesianChart(
          key: ValueKey('budget-trend-chart-$chartSignature'),
          data: AppCartesianChartData(
            axisPoints: [
              const AppChartAxisPoint(x: -1, label: '', showOnAxis: false),
              for (var day = 1; day <= axisDayCount; day++)
                AppChartAxisPoint(
                  x: (day - 1).toDouble(),
                  label: '$day日',
                  showOnAxis: day == 1 || day == 15 || day == axisDayCount,
                ),
            ],
            series: series,
          ),
          form: AppCartesianChartForm.line,
          height: widget.height,
          maxAxisLabels: 3,
          includeZero: true,
          emptyMessage: '请选择剩余或支出',
        ),
        const SizedBox(height: AppSpacing.space4),
        _BudgetTrendLegend(
          showRemaining: _visibleMetrics.contains(_BudgetTrendMetric.remaining),
          showSpent: _visibleMetrics.contains(_BudgetTrendMetric.spent),
          showPreviousMonth: _showPreviousMonth,
          showPreviousYear: _showPreviousYear,
          remainingColor: financeColors.chart1,
          spentColor: financeColors.chart2,
          onRemainingChanged: (selected) =>
              _setMetricVisible(_BudgetTrendMetric.remaining, selected),
          onSpentChanged: (selected) =>
              _setMetricVisible(_BudgetTrendMetric.spent, selected),
          onPreviousMonthChanged: (selected) =>
              setState(() => _showPreviousMonth = selected),
          onPreviousYearChanged: (selected) =>
              setState(() => _showPreviousYear = selected),
        ),
      ],
    );
  }

  void _setMetricVisible(_BudgetTrendMetric metric, bool selected) {
    setState(() {
      if (selected) {
        _visibleMetrics.add(metric);
      } else {
        _visibleMetrics.remove(metric);
      }
    });
  }

  int _axisDayCount() {
    var dayCount = _daysInMonth(widget.month);
    if (_hasVisibleMetrics) {
      if (_showPreviousMonth) {
        dayCount = math.max(dayCount, _daysInMonth(widget.month.previous));
      }
      if (_showPreviousYear) {
        dayCount = math.max(dayCount, _daysInMonth(widget.month.previousYear));
      }
    }
    return dayCount;
  }
}

class _BudgetTrendLegend extends StatelessWidget {
  const _BudgetTrendLegend({
    required this.showRemaining,
    required this.showSpent,
    required this.showPreviousMonth,
    required this.showPreviousYear,
    required this.remainingColor,
    required this.spentColor,
    required this.onRemainingChanged,
    required this.onSpentChanged,
    required this.onPreviousMonthChanged,
    required this.onPreviousYearChanged,
  });

  final bool showRemaining;
  final bool showSpent;
  final bool showPreviousMonth;
  final bool showPreviousYear;
  final Color remainingColor;
  final Color spentColor;
  final ValueChanged<bool> onRemainingChanged;
  final ValueChanged<bool> onSpentChanged;
  final ValueChanged<bool> onPreviousMonthChanged;
  final ValueChanged<bool> onPreviousYearChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.space16,
      runSpacing: AppSpacing.space8,
      children: [
        AppChartLegendItem(
          key: const ValueKey('budget-trend-legend-remaining'),
          label: '余',
          color: remainingColor,
          selected: showRemaining,
          onTap: () => onRemainingChanged(!showRemaining),
        ),
        AppChartLegendItem(
          key: const ValueKey('budget-trend-legend-spent'),
          label: '支',
          color: spentColor,
          selected: showSpent,
          onTap: () => onSpentChanged(!showSpent),
        ),
        AppChartLegendItem(
          key: const ValueKey('budget-trend-legend-previous-month'),
          label: '环比',
          color: colors.onSurfaceVariant,
          marker: _BudgetComparisonLegendMarker(
            remainingColor: remainingColor,
            spentColor: spentColor,
            dashArray: AppChartGeometry.dashedLinePattern,
          ),
          selected: showPreviousMonth,
          onTap: () => onPreviousMonthChanged(!showPreviousMonth),
        ),
        AppChartLegendItem(
          key: const ValueKey('budget-trend-legend-previous-year'),
          label: '同比',
          color: colors.onSurfaceVariant,
          marker: _BudgetComparisonLegendMarker(
            remainingColor: remainingColor,
            spentColor: spentColor,
            dashArray: AppChartGeometry.dottedLinePattern,
          ),
          selected: showPreviousYear,
          onTap: () => onPreviousYearChanged(!showPreviousYear),
        ),
      ],
    );
  }
}

class _BudgetComparisonLegendMarker extends StatelessWidget {
  const _BudgetComparisonLegendMarker({
    required this.remainingColor,
    required this.spentColor,
    required this.dashArray,
  });

  final Color remainingColor;
  final Color spentColor;
  final List<int> dashArray;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.space12,
      height: AppSpacing.space4,
      child: CustomPaint(
        painter: _BudgetComparisonLegendMarkerPainter(
          remainingColor: remainingColor,
          spentColor: spentColor,
          dashArray: dashArray,
        ),
      ),
    );
  }
}

class _BudgetComparisonLegendMarkerPainter extends CustomPainter {
  const _BudgetComparisonLegendMarkerPainter({
    required this.remainingColor,
    required this.spentColor,
    required this.dashArray,
  });

  final Color remainingColor;
  final Color spentColor;
  final List<int> dashArray;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDashedLine(
      canvas,
      y: size.height / 4,
      width: size.width,
      color: remainingColor,
    );
    _paintDashedLine(
      canvas,
      y: size.height * 3 / 4,
      width: size.width,
      color: spentColor,
    );
  }

  void _paintDashedLine(
    Canvas canvas, {
    required double y,
    required double width,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = AppChartGeometry.lineWidth / 2
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    var index = 0;
    while (x < width) {
      final end = math.min(x + dashArray[index % dashArray.length], width);
      if (index.isEven) {
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x = end;
      index++;
    }
  }

  @override
  bool shouldRepaint(
    covariant _BudgetComparisonLegendMarkerPainter oldDelegate,
  ) {
    return remainingColor != oldDelegate.remainingColor ||
        spentColor != oldDelegate.spentColor ||
        dashArray != oldDelegate.dashArray;
  }
}

AppChartSeries _budgetSeries({
  required String label,
  required Color color,
  required List<_BudgetDayPoint> points,
  required Money originValue,
  required Money Function(_BudgetDayPoint point) value,
  List<int>? dashArray,
}) {
  return AppChartSeries(
    label: label,
    color: color,
    dashArray: dashArray,
    points: [
      AppChartPoint(
        x: -1,
        value: originValue.minorUnits / 100,
        formattedValue: originValue.format(),
      ),
      for (final point in points)
        AppChartPoint(
          x: (point.day - 1).toDouble(),
          value: value(point).minorUnits / 100,
          formattedValue: value(point).format(),
        ),
    ],
  );
}

List<_BudgetDayPoint> _filledPoints(
  List<BudgetTrendPoint> trend, {
  required int targetDays,
  required Money initialRemaining,
}) {
  final trendByDay = {for (final point in trend) point.date.day: point};
  var spent = Money.zero();
  var remaining = initialRemaining;
  final points = <_BudgetDayPoint>[];
  for (var day = 1; day <= targetDays; day++) {
    if (trendByDay[day] case final point?) {
      spent = point.spent;
      remaining = point.remaining;
    }
    points.add(_BudgetDayPoint(day: day, spent: spent, remaining: remaining));
  }
  return points;
}

class _BudgetDayPoint {
  const _BudgetDayPoint({
    required this.day,
    required this.spent,
    required this.remaining,
  });

  final int day;
  final Money spent;
  final Money remaining;
}

int _daysInMonth(MonthKey month) {
  return month.nextMonthStart.subtract(const Duration(days: 1)).day;
}
