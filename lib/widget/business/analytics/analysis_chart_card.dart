import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';
import 'analysis_section_card.dart';
import 'chart/app_chart_expand_button.dart';

typedef ExpandedChartBuilder = Widget Function(double height);

class AnalysisChartCard extends StatelessWidget {
  const AnalysisChartCard({
    required this.title,
    required this.chart,
    required this.expandedChartBuilder,
    super.key,
    this.subtitle,
    this.showExpandIcon = false,
    this.trailing,
    this.expandedReservedHeight = 0,
  });

  final String title;
  final String? subtitle;
  final bool showExpandIcon;
  final Widget chart;
  final ExpandedChartBuilder expandedChartBuilder;
  final Widget? trailing;
  final double expandedReservedHeight;

  @override
  Widget build(BuildContext context) {
    final chartContent =
        showExpandIcon
            ? Stack(
              children: [
                chart,
                Positioned(
                  top: 0,
                  right: 0,
                  child: AppChartExpandButton(
                    key: ValueKey('chart-expand-$title'),
                    tooltip: '横屏查看$title',
                    onTap: () => _openExpandedChart(context),
                  ),
                ),
              ],
            )
            : chart;
    return AnalysisSectionCard(
      title: title,
      subtitle: subtitle,
      headerPadding: const EdgeInsets.fromLTRB(
        AppChartGeometry.chartCardHorizontalPadding,
        AppChartGeometry.chartCardHeaderTopPadding,
        AppChartGeometry.chartCardHorizontalPadding,
        AppChartGeometry.chartCardHeaderBottomPadding,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppChartGeometry.chartCardHorizontalPadding,
        AppChartGeometry.chartCardHeaderToPlotGap,
        AppChartGeometry.chartCardHorizontalPadding,
        AppChartGeometry.chartCardPlotBottomPadding,
      ),
      trailing: trailing,
      child: chartContent,
    );
  }

  void _openExpandedChart(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _ExpandedChartPage(
              chartBuilder: expandedChartBuilder,
              reservedHeight: expandedReservedHeight,
            ),
      ),
    );
  }
}

class _ExpandedChartPage extends StatefulWidget {
  const _ExpandedChartPage({
    required this.chartBuilder,
    required this.reservedHeight,
  });

  final ExpandedChartBuilder chartBuilder;
  final double reservedHeight;

  @override
  State<_ExpandedChartPage> createState() => _ExpandedChartPageState();
}

class _ExpandedChartPageState extends State<_ExpandedChartPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space8),
          child: LayoutBuilder(
            builder:
                (context, constraints) => widget.chartBuilder(
                  (constraints.maxHeight - widget.reservedHeight)
                      .clamp(0, constraints.maxHeight)
                      .toDouble(),
                ),
          ),
        ),
      ),
    );
  }
}
