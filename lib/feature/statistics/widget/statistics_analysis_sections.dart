import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/analytics/analysis_chart_card.dart';
import '../../../widget/business/finance/cashflow_summary_card.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../presentation/statistics_period_presentation.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';
import 'statistics_charts.dart';

class StatisticsOverviewSection extends StatelessWidget {
  const StatisticsOverviewSection({
    required this.overview,
    required this.comparison,
    super.key,
  });

  final StatisticsOverviewPresentation overview;
  final StatisticsComparisonPresentation? comparison;

  @override
  Widget build(BuildContext context) {
    final summary = overview.cashflowComparison.current;
    return Column(
      children: [
        CashflowSummaryCard(
          showCaptions: comparison != null,
          summary: CashflowSummaryPresentation(
            metrics: [
              CashflowSummaryMetricPresentation(
                label: '收入',
                amount: summary.income,
                caption: _summaryComparisonCaption(
                  overview.cashflowComparison.incomeChange,
                  comparison?.label,
                ),
                tone: FinanceTone.income,
              ),
              CashflowSummaryMetricPresentation(
                label: '支出',
                amount: summary.expense,
                caption: _summaryComparisonCaption(
                  overview.cashflowComparison.expenseChange,
                  comparison?.label,
                ),
                tone: FinanceTone.expense,
              ),
              CashflowSummaryMetricPresentation(
                label: '结余',
                amount: summary.net,
                caption: comparison == null
                    ? ''
                    : _summaryComparisonCaption(
                        PeriodChange(
                          current: summary.net,
                          previous: comparison!.net,
                        ),
                        comparison!.label,
                      ),
                tone: FinanceTone.neutral,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        _KpiStrip(kpis: overview.kpis),
      ],
    );
  }
}

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

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final StatisticsCashflowKpis kpis;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: _KpiMetric(
                label: '日均支出',
                amount: kpis.dailyAverageExpense,
              ),
            ),
            Expanded(
              child: _KpiMetric(label: '日均收入', amount: kpis.dailyAverageIncome),
            ),
            Expanded(
              child: _KpiMetric(label: '最高单日支出', amount: kpis.maxDailyExpense),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiMetric extends StatelessWidget {
  const _KpiMetric({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.appTextStyles.metricLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(amount.format(), style: context.appTextStyles.amountList),
        ),
      ],
    );
  }
}

String _summaryComparisonCaption(PeriodChange change, String? comparisonLabel) {
  if (comparisonLabel == null) return '';
  final prefix = _comparisonChangePrefix(comparisonLabel);
  if (change.isFlat) return '$prefix持平';
  final delta = formatSignedCompactAmount(change.delta.minorUnits);
  final ratio = change.ratio;
  return ratio == null
      ? '$prefix $delta'
      : '$prefix $delta · ${formatSignedOptionalPercent(ratio)}';
}

String _comparisonChangePrefix(String comparisonLabel) {
  return comparisonLabel == '环比' || comparisonLabel == '同比'
      ? comparisonLabel
      : '较$comparisonLabel';
}
