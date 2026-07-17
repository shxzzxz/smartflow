import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsPageProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              state: state.control,
              periodLabel: state.periodLabel,
              canAdvance: state.canAdvance,
              lastSelectableDate: state.lastSelectableDate,
            ),
            Expanded(
              child: switch (state.content) {
                StatisticsContentLoaded(:final presentation) =>
                  _StatisticsContent(
                    presentation: presentation,
                    control: state.control,
                  ),
                StatisticsContentError(:final message) => Center(
                  child: Text(message),
                ),
                StatisticsContentLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.state,
    required this.periodLabel,
    required this.canAdvance,
    required this.lastSelectableDate,
  });

  final StatisticsControlState state;
  final String periodLabel;
  final bool canAdvance;
  final DateTime lastSelectableDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space10,
        AppSpacing.space16,
        AppSpacing.space12,
      ),
      child: Column(
        children: [
          SegmentedButton<StatisticsPeriodKind>(
            segments: const [
              ButtonSegment(
                value: StatisticsPeriodKind.month,
                label: Text('月'),
              ),
              ButtonSegment(value: StatisticsPeriodKind.year, label: Text('年')),
              ButtonSegment(
                value: StatisticsPeriodKind.custom,
                label: Text('自定义'),
              ),
            ],
            selected: {state.periodKind},
            showSelectedIcon: false,
            onSelectionChanged: (value) async {
              final kind = value.first;
              if (kind != StatisticsPeriodKind.custom) {
                notifier.selectPeriodKind(kind);
                return;
              }
              final initial = DateTimeRange(
                start: state.customFrom,
                end: state.customUntil.subtract(const Duration(days: 1)),
              );
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: lastSelectableDate,
                initialDateRange: initial,
              );
              if (range != null) {
                notifier.selectCustomRange(range.start, range.end);
              }
            },
          ),
          const SizedBox(height: AppSpacing.space10),
          Row(
            children: [
              IconButton(
                tooltip: '上一周期',
                onPressed:
                    state.periodKind == StatisticsPeriodKind.custom
                        ? null
                        : () => notifier.shiftMonth(
                          state.periodKind == StatisticsPeriodKind.year
                              ? -12
                              : -1,
                        ),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  periodLabel,
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.sectionTitle,
                ),
              ),
              IconButton(
                tooltip: '下一周期',
                onPressed:
                    !canAdvance
                        ? null
                        : () => notifier.shiftMonth(
                          state.periodKind == StatisticsPeriodKind.year
                              ? 12
                              : 1,
                        ),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.presentation, required this.control});

  final StatisticsPresentation presentation;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context) {
    final summary = presentation.cashflowComparison.current;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space0,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        _Summary(summary: summary),
        const SizedBox(height: AppSpacing.space20),
        _CashflowChart(
          presentation: presentation,
          selected: control.chartMetric,
        ),
        const SizedBox(height: AppSpacing.space20),
        _BalanceChart(presentation: presentation),
        const SizedBox(height: AppSpacing.space20),
        _CategoryAnalysis(presentation: presentation, control: control),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final CashflowSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _metric(context, '收入', summary.income, MoneySemantic.income),
            _metric(context, '支出', summary.expense, MoneySemantic.expense),
            _metric(context, '结余', summary.net, MoneySemantic.neutral),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    Money value,
    MoneySemantic semantic,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.appTextStyles.metricLabel),
          const SizedBox(height: 6),
          FittedBox(
            child: MoneyText(
              money: value,
              semantic: semantic,
              style: context.appTextStyles.metricValue,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowChart extends ConsumerWidget {
  const _CashflowChart({required this.presentation, required this.selected});
  final StatisticsPresentation presentation;
  final CashflowChartMetric selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buckets = buildStatisticsCashflowBuckets(presentation.dailySummaries);
    final extension = Theme.of(context).extension<AppThemeExtension>()!;
    final color = switch (selected) {
      CashflowChartMetric.expense => extension.expense,
      CashflowChartMetric.income => extension.income,
      CashflowChartMetric.net => extension.equity,
    };
    return _ChartCard(
      title: '收支统计',
      controls: SegmentedButton<CashflowChartMetric>(
        segments: const [
          ButtonSegment(value: CashflowChartMetric.expense, label: Text('支出')),
          ButtonSegment(value: CashflowChartMetric.income, label: Text('收入')),
          ButtonSegment(value: CashflowChartMetric.net, label: Text('结余')),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged:
            (value) => ref
                .read(statisticsViewModelProvider.notifier)
                .selectChartMetric(value.first),
      ),
      child:
          buckets.isEmpty
              ? const _Empty(message: '区间内暂无收支数据')
              : SizedBox(
                height: AppChartGeometry.plotHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(
                      AppChartGeometry.minimumScrollableWidth,
                      buckets.length * AppSpacing.space12,
                    ),
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: AppSpacing.space28,
                              interval: math.max(
                                1,
                                (buckets.length / 6).ceilToDouble(),
                              ),
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= buckets.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppSpacing.space8,
                                  ),
                                  child: Text(
                                    buckets[index].label,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < buckets.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: _metricValue(buckets[i], selected) / 100,
                                  color: color,
                                  width: math.max(
                                    AppChartGeometry.barWidthMin,
                                    math.min(
                                      AppChartGeometry.barWidthMax,
                                      AppChartGeometry.barWidthBudget /
                                          buckets.length,
                                    ),
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppRadius.radiusSm),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}

class _BalanceChart extends StatelessWidget {
  const _BalanceChart({required this.presentation});
  final StatisticsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final points = presentation.rangeBalanceTrend;
    final color = Theme.of(context).extension<AppThemeExtension>()!.asset;
    return _ChartCard(
      title: '资产走势',
      subtitle: presentation.netAssetChangeText,
      child:
          points.isEmpty
              ? const _Empty(message: '区间内暂无资产数据')
              : SizedBox(
                height: AppChartGeometry.plotHeight,
                child: LineChart(
                  LineChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: AppSpacing.space28,
                          interval: math.max(
                            1,
                            (points.length / 5).ceilToDouble(),
                          ),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final date = points[index].date;
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.space8,
                              ),
                              child: Text(
                                statisticsDateLabel(date),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: const LineTouchData(enabled: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(
                              i.toDouble(),
                              points[i].balance.minorUnits / 100,
                            ),
                        ],
                        color: color,
                        barWidth: AppChartGeometry.lineWidth,
                        isCurved: true,
                        dotData: FlDotData(show: points.length < 15),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: .12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

class _CategoryAnalysis extends ConsumerWidget {
  const _CategoryAnalysis({required this.presentation, required this.control});
  final StatisticsPresentation presentation;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    final primary =
        control.categoryKind == StatisticsCategoryKind.expense
            ? presentation.expenseCategories
            : presentation.incomeCategories;
    final items = selectStatisticsCategoryItems(
      primary,
      secondary: control.categoryLevel == StatisticsCategoryLevel.secondary,
    );
    final semantic =
        control.categoryKind == StatisticsCategoryKind.expense
            ? MoneySemantic.expense
            : MoneySemantic.income;
    return _ChartCard(
      title: '分类占比',
      controls: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<StatisticsCategoryKind>(
                  segments: const [
                    ButtonSegment(
                      value: StatisticsCategoryKind.expense,
                      label: Text('支出'),
                    ),
                    ButtonSegment(
                      value: StatisticsCategoryKind.income,
                      label: Text('收入'),
                    ),
                  ],
                  selected: {control.categoryKind},
                  showSelectedIcon: false,
                  onSelectionChanged:
                      (v) => notifier.selectCategoryKind(v.first),
                ),
              ),
              const SizedBox(width: AppSpacing.space8),
              Expanded(
                child: SegmentedButton<StatisticsCategoryLevel>(
                  segments: const [
                    ButtonSegment(
                      value: StatisticsCategoryLevel.primary,
                      label: Text('一级'),
                    ),
                    ButtonSegment(
                      value: StatisticsCategoryLevel.secondary,
                      label: Text('二级'),
                    ),
                  ],
                  selected: {control.categoryLevel},
                  showSelectedIcon: false,
                  onSelectionChanged:
                      (v) => notifier.selectCategoryLevel(v.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<StatisticsValueMode>(
              segments: const [
                ButtonSegment(
                  value: StatisticsValueMode.amount,
                  label: Text('金额'),
                ),
                ButtonSegment(
                  value: StatisticsValueMode.percentage,
                  label: Text('占比'),
                ),
              ],
              selected: {control.valueMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => notifier.selectValueMode(v.first),
            ),
          ),
        ],
      ),
      child:
          items.isEmpty
              ? const _Empty(message: '区间内暂无分类数据')
              : Column(
                children: [
                  SizedBox(
                    height: AppChartGeometry.plotHeight,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: AppChartGeometry.pieCenterRadius,
                        sectionsSpace: AppSpacing.space2,
                        sections: [
                          for (var i = 0; i < items.length; i++)
                            PieChartSectionData(
                              value:
                                  statisticsCategoryMagnitude(
                                    items[i],
                                  ).toDouble(),
                              color: _pieColor(context, i),
                              radius: AppChartGeometry.pieSectionRadius,
                              title: statisticsCategoryValueText(
                                items[i],
                                items,
                                percentage:
                                    control.valueMode ==
                                    StatisticsValueMode.percentage,
                              ),
                              titleStyle: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (final item in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _pieColor(
                          context,
                          items.indexOf(item),
                        ),
                        radius: AppChartGeometry.categoryMarkerRadius,
                      ),
                      title: Text(item.title),
                      subtitle: null,
                      trailing:
                          control.valueMode == StatisticsValueMode.amount
                              ? MoneyText(
                                money: item.amount,
                                semantic: semantic,
                                style: context.appTextStyles.amountList,
                              )
                              : Text(
                                statisticsCategoryPercentageText(item, items),
                              ),
                      onTap:
                          control.categoryLevel ==
                                  StatisticsCategoryLevel.primary
                              ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => _CategoryDetailPage(
                                        item: item,
                                        semantic: semantic,
                                        from: presentation.cashflowFrom,
                                        until: presentation.cashflowUntil,
                                      ),
                                ),
                              )
                              : () => _openTransactions(
                                context,
                                item,
                                presentation.cashflowFrom,
                                presentation.cashflowUntil,
                              ),
                    ),
                ],
              ),
    );
  }
}

class _CategoryDetailPage extends StatelessWidget {
  const _CategoryDetailPage({
    required this.item,
    required this.semantic,
    required this.from,
    required this.until,
  });
  final StatisticsBreakdownItem item;
  final MoneySemantic semantic;
  final DateTime from;
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final children = item.children;
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.space16),
        children: [
          AppSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space16),
              child: Column(
                children: [
                  SizedBox(
                    height: AppChartGeometry.plotHeight,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius:
                            AppChartGeometry.pieDetailCenterRadius,
                        sections: [
                          for (var i = 0; i < children.length; i++)
                            PieChartSectionData(
                              value:
                                  statisticsCategoryMagnitude(
                                    children[i],
                                  ).toDouble(),
                              color: _pieColor(context, i),
                              title: statisticsCategoryPercentageText(
                                children[i],
                                children,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (final child in children)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(child.title),
                      trailing: MoneyText(
                        money: child.amount,
                        semantic: semantic,
                        style: context.appTextStyles.amountList,
                      ),
                      onTap:
                          () => _openTransactions(context, child, from, until),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.controls,
  });
  final String title;
  final String? subtitle;
  final Widget? controls;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.appTextStyles.sectionTitle),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.space4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (controls != null) ...[
              const SizedBox(height: AppSpacing.space12),
              controls!,
            ],
            const SizedBox(height: AppSpacing.space16),
            child,
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppChartGeometry.emptyHeight,
    child: Center(child: Text(message)),
  );
}

double _metricValue(
  StatisticsCashflowBucket bucket,
  CashflowChartMetric metric,
) => switch (metric) {
  CashflowChartMetric.expense => bucket.expenseMinor.toDouble(),
  CashflowChartMetric.income => bucket.incomeMinor.toDouble(),
  CashflowChartMetric.net => bucket.netMinor.toDouble(),
};

Color _pieColor(BuildContext context, int index) {
  final colors = Theme.of(context).extension<AppThemeExtension>()!;
  return [
    colors.chart1,
    colors.chart2,
    colors.chart3,
    colors.chart4,
    colors.chart5,
  ][index % 5];
}

void _openTransactions(
  BuildContext context,
  StatisticsBreakdownItem item,
  DateTime from,
  DateTime until,
) {
  final ids = (item.accountIds.toList()..sort()).join(',');
  context.push(
    Uri(
      path: '/statistics/transactions',
      queryParameters: {
        'accountIds': ids,
        'from': from.toIso8601String(),
        'until': until.toIso8601String(),
        'title': item.title,
        'scope': StatisticsDrilldownScope.cashflow.name,
      },
    ).toString(),
  );
}
