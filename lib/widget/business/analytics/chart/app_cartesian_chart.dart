import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/chart.dart';
import '../../../../design_system/token/radius.dart';
import '../../../../design_system/token/spacing.dart';
import 'app_chart_empty_state.dart';
import 'app_chart_scale.dart';

enum AppCartesianChartForm { line, bar }

class AppChartAxisPoint {
  const AppChartAxisPoint({
    required this.x,
    required this.label,
    this.showOnAxis = true,
  });

  final double x;
  final String label;
  final bool showOnAxis;
}

class AppChartPoint {
  const AppChartPoint({
    required this.x,
    required this.value,
    required this.formattedValue,
  });

  final double x;
  final double value;
  final String formattedValue;
}

class AppChartSeries {
  const AppChartSeries({
    required this.label,
    required this.color,
    required this.points,
    this.fillArea = false,
  });

  final String label;
  final Color color;
  final List<AppChartPoint> points;
  final bool fillArea;
}

class AppCartesianChartData {
  const AppCartesianChartData({required this.axisPoints, required this.series});

  final List<AppChartAxisPoint> axisPoints;
  final List<AppChartSeries> series;

  bool get isEmpty =>
      axisPoints.isEmpty ||
      series.isEmpty ||
      series.every((item) => item.points.isEmpty);
}

class AppCartesianChart extends StatefulWidget {
  const AppCartesianChart({
    required this.data,
    required this.form,
    super.key,
    this.height = AppChartGeometry.primaryPlotHeight,
    this.maxAxisLabels = AppChartGeometry.cashflowAxisLabelLimit,
    this.includeZero = false,
    this.showLegend = false,
    this.showSeriesLabelInTooltip = true,
    this.emptyMessage = '暂无图表数据',
  });

  final AppCartesianChartData data;
  final AppCartesianChartForm form;
  final double height;
  final int maxAxisLabels;
  final bool includeZero;
  final bool showLegend;
  final bool showSeriesLabelInTooltip;
  final String emptyMessage;

  @override
  State<AppCartesianChart> createState() => _AppCartesianChartState();
}

class _AppCartesianChartState extends State<AppCartesianChart> {
  late Set<String> _visibleSeries = {
    for (final series in widget.data.series) series.label,
  };

  @override
  void didUpdateWidget(covariant AppCartesianChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.series != widget.data.series) {
      final labels = widget.data.series.map((series) => series.label).toSet();
      _visibleSeries = _visibleSeries.intersection(labels);
      if (_visibleSeries.isEmpty &&
          labels.isNotEmpty &&
          !_sameLabels(
            oldWidget.data.series.map((series) => series.label),
            labels,
          )) {
        _visibleSeries = labels;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return AppChartEmptyState(message: widget.emptyMessage);
    }

    final visibleData = AppCartesianChartData(
      axisPoints: widget.data.axisPoints,
      series: [
        for (final series in widget.data.series)
          if (_visibleSeries.contains(series.label)) series,
      ],
    );

    final chart =
        visibleData.series.isEmpty
            ? SizedBox(
              height: widget.height,
              child: const AppChartEmptyState(message: '未选择数据系列'),
            )
            : SizedBox(
              height: widget.height,
              child: switch (widget.form) {
                AppCartesianChartForm.line => _buildLineChart(
                  context,
                  visibleData,
                ),
                AppCartesianChartForm.bar => _buildBarChart(
                  context,
                  visibleData,
                ),
              },
            );
    if (!widget.showLegend) return chart;
    return Column(
      children: [
        chart,
        const SizedBox(height: AppSpacing.space12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.space16,
          runSpacing: AppSpacing.space8,
          children: [
            for (final series in widget.data.series)
              _AppChartLegendItem(
                key: ValueKey('chart-legend-${series.label}'),
                label: series.label,
                color: series.color,
                selected: _visibleSeries.contains(series.label),
                onTap:
                    () => setState(() {
                      if (_visibleSeries.contains(series.label)) {
                        _visibleSeries.remove(series.label);
                      } else {
                        _visibleSeries.add(series.label);
                      }
                    }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, AppCartesianChartData data) {
    final colors = Theme.of(context).colorScheme;
    final scale = _scale(data);
    return LineChart(
      duration: AppChartMotion.switchDuration,
      LineChartData(
        minX: data.axisPoints.first.x,
        maxX: math.max(data.axisPoints.first.x + 1, data.axisPoints.last.x),
        minY: scale.min,
        maxY: scale.max,
        borderData: FlBorderData(show: false),
        gridData: _gridData(context, scale),
        titlesData: _titlesData(context, scale, data: data),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => colors.inverseSurface,
            getTooltipItems: (spots) => _lineTooltipItems(context, spots, data),
          ),
        ),
        lineBarsData: [
          for (final series in data.series)
            LineChartBarData(
              spots: [
                for (final point in series.points) FlSpot(point.x, point.value),
              ],
              color: series.color,
              barWidth: AppChartGeometry.lineWidth,
              isCurved: series.points.length > 2,
              preventCurveOverShooting: true,
              dotData: FlDotData(
                show: series.points.length <= 12,
                getDotPainter:
                    (_, _, _, _) => FlDotCirclePainter(
                      radius: AppChartGeometry.lineDotRadius,
                      color: series.color,
                      strokeWidth: AppChartGeometry.lineDotStrokeWidth,
                      strokeColor: colors.surfaceContainerLowest,
                    ),
              ),
              belowBarData: BarAreaData(
                show: series.fillArea,
                color: series.color.withValues(
                  alpha: AppChartGeometry.areaFillOpacity,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, AppCartesianChartData data) {
    if (data.series.any(
      (series) => series.points.length != data.axisPoints.length,
    )) {
      throw ArgumentError(
        'Bar chart series must contain one point for every axis point.',
      );
    }
    final colors = Theme.of(context).colorScheme;
    final scale = _scale(data);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = _barWidth(
          constraints.maxWidth,
          data.axisPoints.length * data.series.length,
        );
        return BarChart(
          duration: AppChartMotion.switchDuration,
          BarChartData(
            minY: scale.min,
            maxY: scale.max,
            baselineY: widget.includeZero ? 0 : null,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: _gridData(context, scale),
            titlesData: _titlesData(
              context,
              scale,
              data: data,
              useAxisIndex: true,
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => colors.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return _barTooltipItem(
                    context,
                    data: data,
                    axisLabel: data.axisPoints[group.x].label,
                    pointIndex: group.x,
                  );
                },
              ),
            ),
            barGroups: [
              for (var index = 0; index < data.axisPoints.length; index++)
                BarChartGroupData(
                  x: index,
                  barsSpace: AppChartGeometry.groupedBarGap,
                  barRods: [
                    for (final series in data.series)
                      BarChartRodData(
                        toY: series.points[index].value,
                        color: series.color,
                        width: barWidth,
                        borderRadius: _barRadius(series.points[index].value),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  AppChartScale _scale(AppCartesianChartData data) {
    return AppChartScale.fromValues([
      for (final series in data.series)
        for (final point in series.points) point.value,
    ], includeZero: widget.includeZero);
  }

  List<LineTooltipItem> _lineTooltipItems(
    BuildContext context,
    List<LineBarSpot> spots,
    AppCartesianChartData data,
  ) {
    final colors = Theme.of(context).colorScheme;
    return [
      for (var index = 0; index < spots.length; index++)
        _lineTooltipItem(
          colors,
          data: data,
          spot: spots[index],
          showAxisLabel: index == 0,
        ),
    ];
  }

  LineTooltipItem _lineTooltipItem(
    ColorScheme colors, {
    required AppCartesianChartData data,
    required LineBarSpot spot,
    required bool showAxisLabel,
  }) {
    final series = data.series[spot.barIndex];
    final point = series.points[spot.spotIndex];
    final axisLabel = _axisLabelForX(data, point.x);
    final seriesLabel =
        widget.showSeriesLabelInTooltip ? '${series.label} ' : '';
    return LineTooltipItem(
      showAxisLabel ? '$axisLabel\n' : '',
      TextStyle(color: colors.onInverseSurface),
      textAlign: TextAlign.left,
      children: [
        if (widget.showSeriesLabelInTooltip)
          TextSpan(text: '● ', style: TextStyle(color: series.color)),
        TextSpan(text: '$seriesLabel${point.formattedValue}'),
      ],
    );
  }

  BarTooltipItem _barTooltipItem(
    BuildContext context, {
    required AppCartesianChartData data,
    required String axisLabel,
    required int pointIndex,
  }) {
    final colors = Theme.of(context).colorScheme;
    return BarTooltipItem(
      '$axisLabel\n',
      TextStyle(color: colors.onInverseSurface),
      textAlign: TextAlign.left,
      children: [
        for (var index = 0; index < data.series.length; index++) ...[
          if (widget.showSeriesLabelInTooltip)
            TextSpan(
              text: '● ',
              style: TextStyle(color: data.series[index].color),
            ),
          TextSpan(
            text:
                '${widget.showSeriesLabelInTooltip ? '${data.series[index].label} ' : ''}'
                '${data.series[index].points[pointIndex].formattedValue}'
                '${index == data.series.length - 1 ? '' : '\n'}',
          ),
        ],
      ],
    );
  }

  String _axisLabelForX(AppCartesianChartData data, double x) {
    for (final axisPoint in data.axisPoints) {
      if ((axisPoint.x - x).abs() < .0001) return axisPoint.label;
    }
    return '';
  }

  FlGridData _gridData(BuildContext context, AppChartScale scale) {
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
    BuildContext context,
    AppChartScale scale, {
    required AppCartesianChartData data,
    bool useAxisIndex = false,
  }) {
    final visibleAxisIndexes = [
      for (var index = 0; index < data.axisPoints.length; index++)
        if (data.axisPoints[index].showOnAxis) index,
    ];
    final labelInterval = math.max(
      1,
      (visibleAxisIndexes.length / widget.maxAxisLabels).ceil(),
    );
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
                  appChartAxisLabel(value),
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
            final index =
                useAxisIndex
                    ? value.round()
                    : data.axisPoints.indexWhere(
                      (point) => (point.x - value).abs() < .0001,
                    );
            if (index < 0 || index >= data.axisPoints.length) {
              return const SizedBox.shrink();
            }
            final visibleIndex = visibleAxisIndexes.indexOf(index);
            if (visibleIndex < 0) return const SizedBox.shrink();
            final lastVisibleIndex = visibleAxisIndexes.length - 1;
            final show =
                visibleIndex == 0 ||
                visibleIndex == lastVisibleIndex ||
                (visibleIndex % labelInterval == 0 &&
                    lastVisibleIndex - visibleIndex >= labelInterval);
            if (!show) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              space: AppSpacing.space8,
              child: Text(
                data.axisPoints[index].label,
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
}

bool _sameLabels(Iterable<String> oldLabels, Set<String> newLabels) {
  final oldSet = oldLabels.toSet();
  return oldSet.length == newLabels.length && oldSet.containsAll(newLabels);
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

class _AppChartLegendItem extends StatelessWidget {
  const _AppChartLegendItem({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${selected ? '，已显示' : '，已隐藏'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space4,
            vertical: AppSpacing.space6,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.space48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSpacing.space12,
                  height: AppSpacing.space4,
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? color
                            : color.withValues(
                              alpha: AppChartGeometry.hiddenLegendMarkerOpacity,
                            ),
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  ),
                ),
                const SizedBox(width: AppSpacing.space6),
                Text(
                  label,
                  style: context.appTextStyles.listSupporting.copyWith(
                    color:
                        selected
                            ? null
                            : Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withValues(
                              alpha: AppChartGeometry.hiddenLegendLabelOpacity,
                            ),
                    decoration: selected ? null : TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
