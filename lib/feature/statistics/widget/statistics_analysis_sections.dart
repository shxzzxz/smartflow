import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/token/chart.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../widget/business/analytics/analysis_chart_card.dart';
import '../presentation/statistics_period_presentation.dart';
import '../view_model/statistics_view_model.dart';
import 'statistics_charts.dart';

class StatisticsComparisonSection extends ConsumerWidget {
  const StatisticsComparisonSection({
    required this.comparison,
    required this.cashflow,
    required this.control,
    super.key,
  });

  final StatisticsComparisonPresentation comparison;
  final StatisticsCashflowTrendPresentation cashflow;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    return AnalysisChartCard(
      title: '对比趋势',
      showExpandIcon: true,
      expandedReservedHeight: AppChartGeometry.interactiveLegendReservedHeight,
      trailing: AppSlidingSegmentedControl<StatisticsComparisonMetric>(
        key: const ValueKey('statistics-comparison-metric'),
        segments: const [
          AppSegment(value: StatisticsComparisonMetric.expense, label: '支出'),
          AppSegment(value: StatisticsComparisonMetric.income, label: '收入'),
        ],
        selected: control.comparisonMetric,
        onChanged: notifier.selectComparisonMetric,
      ),
      chart: StatisticsComparisonTrendChart(
        key: const ValueKey('statistics-comparison-chart'),
        currentDailySummaries: cashflow.dailySummaries,
        comparisonDailySummaries: comparison.dailySummaries,
        grouping: control.trendGrouping,
        metric: control.comparisonMetric,
        comparisonLabel: comparison.label,
      ),
      expandedChartBuilder: (height) => StatisticsComparisonTrendChart(
        currentDailySummaries: cashflow.dailySummaries,
        comparisonDailySummaries: comparison.dailySummaries,
        grouping: control.trendGrouping,
        metric: control.comparisonMetric,
        comparisonLabel: comparison.label,
        height: height,
      ),
    );
  }
}

class StatisticsCashflowSection extends ConsumerWidget {
  const StatisticsCashflowSection({
    required this.cashflow,
    required this.control,
    super.key,
  });

  final StatisticsCashflowTrendPresentation cashflow;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    return AnalysisChartCard(
      title: '收支统计',
      showExpandIcon: true,
      expandedReservedHeight: AppChartGeometry.interactiveLegendReservedHeight,
      trailing: AppSlidingSegmentedControl<CashflowChartForm>(
        key: const ValueKey('statistics-cashflow-form'),
        segments: const [
          AppSegment(value: CashflowChartForm.bar, label: '柱状'),
          AppSegment(value: CashflowChartForm.line, label: '曲线'),
        ],
        selected: control.chartForm,
        onChanged: notifier.selectChartForm,
      ),
      chart: StatisticsCashflowChart(
        key: const ValueKey('statistics-cashflow-chart'),
        dailySummaries: cashflow.dailySummaries,
        grouping: control.trendGrouping,
        form: control.chartForm,
      ),
      expandedChartBuilder: (height) => StatisticsCashflowChart(
        dailySummaries: cashflow.dailySummaries,
        grouping: control.trendGrouping,
        form: control.chartForm,
        height: height,
      ),
    );
  }
}

class StatisticsBalanceSection extends StatelessWidget {
  const StatisticsBalanceSection({
    required this.balance,
    required this.control,
    super.key,
  });

  final StatisticsBalanceTrendPresentation balance;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context) {
    return AnalysisChartCard(
      title: '资产走势',
      showExpandIcon: true,
      expandedReservedHeight: AppChartGeometry.interactiveLegendReservedHeight,
      chart: StatisticsBalanceTrendChart(
        points: balance.points,
        grouping: control.trendGrouping,
      ),
      expandedChartBuilder: (height) => StatisticsBalanceTrendChart(
        points: balance.points,
        grouping: control.trendGrouping,
        height: height,
      ),
    );
  }
}

class StatisticsWeekdaySection extends StatelessWidget {
  const StatisticsWeekdaySection({required this.cashflow, super.key});

  final StatisticsCashflowTrendPresentation cashflow;

  @override
  Widget build(BuildContext context) {
    return AnalysisChartCard(
      title: '支出习惯',
      subtitle: '按星期 · 日均支出',
      chart: StatisticsWeekdayChart(dailySummaries: cashflow.dailySummaries),
      expandedChartBuilder: (height) => StatisticsWeekdayChart(
        dailySummaries: cashflow.dailySummaries,
        height: height,
      ),
    );
  }
}
