import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/theme/app_text_styles.dart';
import '../../../../design_system/token/chart.dart';
import '../../../../design_system/token/spacing.dart';
import 'app_chart_empty_state.dart';

class AppDonutSlice {
  const AppDonutSlice({
    required this.label,
    required this.value,
    required this.formattedValue,
    required this.color,
  });

  final String label;
  final double value;
  final String formattedValue;
  final Color color;
}

class AppDonutChart extends StatefulWidget {
  const AppDonutChart({
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
    super.key,
    this.emptyMessage = '暂无分类数据',
    this.height = AppChartGeometry.donutPlotHeight,
  });

  final List<AppDonutSlice> slices;
  final String centerLabel;
  final String centerValue;
  final String emptyMessage;
  final double height;

  @override
  State<AppDonutChart> createState() => _AppDonutChartState();
}

class _AppDonutChartState extends State<AppDonutChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(AppDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.slices, widget.slices)) _selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slices.isEmpty) {
      return AppChartEmptyState(message: widget.emptyMessage);
    }
    final selected =
        _selectedIndex != null && _selectedIndex! < widget.slices.length
            ? _selectedIndex
            : null;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final geometryScale = (widget.height / AppChartGeometry.donutPlotHeight)
        .clamp(1.0, 1.6);
    final centerLabel =
        selected == null ? widget.centerLabel : widget.slices[selected].label;
    final centerValue =
        selected == null
            ? widget.centerValue
            : widget.slices[selected].formattedValue;
    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            duration: AppChartMotion.switchDuration,
            PieChartData(
              centerSpaceRadius:
                  AppChartGeometry.pieCenterRadius * geometryScale,
              sectionsSpace: AppSpacing.space2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
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
                for (var index = 0; index < widget.slices.length; index++)
                  PieChartSectionData(
                    value: widget.slices[index].value,
                    color: widget.slices[index].color,
                    radius:
                        AppChartGeometry.pieSectionRadius * geometryScale +
                        (index == selected
                            ? AppChartGeometry.pieSelectedSectionBump *
                                geometryScale
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
