import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../feature/home/widget/monthly_summary_card.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';
import '../widget/statistics_charts.dart';
import '../widget/statistics_section.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsPageProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _StatisticsHeader(
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
                StatisticsContentError(:final message) => _PageMessage(
                  icon: RemixIcons.error_warning_line,
                  message: message,
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

class _StatisticsHeader extends ConsumerWidget {
  const _StatisticsHeader({
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
        AppSpacing.space18,
        AppSpacing.space16,
        AppSpacing.space12,
      ),
      child: Row(
        children: [
          Expanded(
            child: _PeriodNavigator(
              label: periodLabel,
              canGoBack: state.periodKind != StatisticsPeriodKind.custom,
              canGoForward:
                  state.periodKind != StatisticsPeriodKind.custom && canAdvance,
              onPrevious:
                  () => notifier.shiftMonth(
                    state.periodKind == StatisticsPeriodKind.year ? -12 : -1,
                  ),
              onNext:
                  () => notifier.shiftMonth(
                    state.periodKind == StatisticsPeriodKind.year ? 12 : 1,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.space4),
          AppSegmentedControl<StatisticsPeriodKind>(
            segments: const [
              AppSegment(value: StatisticsPeriodKind.month, label: '月'),
              AppSegment(value: StatisticsPeriodKind.year, label: '年'),
              AppSegment(value: StatisticsPeriodKind.custom, label: '自定义'),
            ],
            selected: state.periodKind,
            onChanged:
                (kind) => _selectPeriodKind(
                  context,
                  notifier,
                  kind,
                  lastSelectableDate,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPeriodKind(
    BuildContext context,
    StatisticsViewModel notifier,
    StatisticsPeriodKind kind,
    DateTime lastSelectableDate,
  ) async {
    if (kind != StatisticsPeriodKind.custom) {
      notifier.selectPeriodKind(kind);
      return;
    }
    final initial = DateTimeRange(
      start: state.customFrom,
      end: state.customUntil.subtract(const Duration(days: 1)),
    );
    final range = await showAppDateRangePicker(
      context: context,
      initialRange: initial,
      firstDate: DateTime(2000),
      lastDate: lastSelectableDate,
    );
    if (range != null) {
      notifier.selectCustomRange(range.start, range.end);
    }
  }
}

class _PeriodNavigator extends StatelessWidget {
  const _PeriodNavigator({
    required this.label,
    required this.canGoBack,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: AppSpacing.space48,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一周期',
            onPressed: canGoBack ? onPrevious : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: AppSpacing.space28,
              height: AppSpacing.space48,
            ),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.appTextStyles.subsectionTitleStrong,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: '下一周期',
            onPressed: canGoForward ? onNext : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: AppSpacing.space28,
              height: AppSpacing.space48,
            ),
            icon: const Icon(Icons.chevron_right_rounded),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space4,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        _Summary(presentation: presentation),
        const SizedBox(height: AppSpacing.space16),
        _CashflowSection(presentation: presentation, control: control),
        const SizedBox(height: AppSpacing.space16),
        _BalanceSection(presentation: presentation, control: control),
        const SizedBox(height: AppSpacing.space16),
        _CategoryAnalysis(presentation: presentation, control: control),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.presentation});

  final StatisticsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final summary = presentation.cashflowComparison.current;
    return MonthlySummaryCard(
      showCaptions: false,
      summary: MonthlySummaryPresentation(
        metrics: [
          MonthlySummaryMetricPresentation(
            label: '收入',
            amountText: summary.income.format(),
            caption: '',
            tone: FinanceTone.income,
          ),
          MonthlySummaryMetricPresentation(
            label: '支出',
            amountText: summary.expense.format(),
            caption: '',
            tone: FinanceTone.expense,
          ),
          MonthlySummaryMetricPresentation(
            label: '结余',
            amountText: summary.net.format(),
            caption: '',
            tone: FinanceTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _CashflowSection extends ConsumerWidget {
  const _CashflowSection({required this.presentation, required this.control});

  final StatisticsPresentation presentation;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StatisticsSectionCard(
      title: '收支统计',
      trailing: AppSegmentedControl<CashflowChartMetric>(
        segments: const [
          AppSegment(value: CashflowChartMetric.expense, label: '支出'),
          AppSegment(value: CashflowChartMetric.income, label: '收入'),
          AppSegment(value: CashflowChartMetric.net, label: '结余'),
        ],
        selected: control.chartMetric,
        onChanged:
            ref.read(statisticsViewModelProvider.notifier).selectChartMetric,
      ),
      child: StatisticsCashflowChart(
        dailySummaries: presentation.dailySummaries,
        until: presentation.cashflowUntil,
        grouping: control.trendGrouping,
        metric: control.chartMetric,
      ),
    );
  }
}

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({required this.presentation, required this.control});

  final StatisticsPresentation presentation;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context) {
    return StatisticsSectionCard(
      title: '资产走势',
      child: StatisticsBalanceTrendChart(
        points: presentation.rangeBalanceTrend,
        grouping: control.trendGrouping,
        until: presentation.balanceUntil,
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
    final totalMinor = items.fold<int>(
      0,
      (sum, item) => sum + statisticsCategoryMagnitude(item),
    );
    return StatisticsSectionCard(
      title: '分类构成',
      trailing: AppSegmentedControl<StatisticsCategoryKind>(
        segments: const [
          AppSegment(value: StatisticsCategoryKind.expense, label: '支出'),
          AppSegment(value: StatisticsCategoryKind.income, label: '收入'),
        ],
        selected: control.categoryKind,
        onChanged: notifier.selectCategoryKind,
      ),
      child:
          items.isEmpty
              ? const StatisticsEmptyState(message: '区间内暂无分类数据')
              : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppSegmentedControl<StatisticsCategoryLevel>(
                          segments: const [
                            AppSegment(
                              value: StatisticsCategoryLevel.primary,
                              label: '一级',
                            ),
                            AppSegment(
                              value: StatisticsCategoryLevel.secondary,
                              label: '二级',
                            ),
                          ],
                          selected: control.categoryLevel,
                          onChanged: notifier.selectCategoryLevel,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space8),
                      Expanded(
                        child: AppSegmentedControl<StatisticsValueMode>(
                          segments: const [
                            AppSegment(
                              value: StatisticsValueMode.amount,
                              label: '金额',
                            ),
                            AppSegment(
                              value: StatisticsValueMode.percentage,
                              label: '占比',
                            ),
                          ],
                          selected: control.valueMode,
                          onChanged: notifier.selectValueMode,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  StatisticsDonutChart(
                    items: items,
                    centerLabel:
                        control.categoryKind == StatisticsCategoryKind.expense
                            ? '总支出'
                            : '总收入',
                    centerValue: Money(minorUnits: totalMinor).format(),
                  ),
                  _CategoryList(
                    items: items,
                    semantic: semantic,
                    valueMode: control.valueMode,
                    level: control.categoryLevel,
                    from: presentation.cashflowFrom,
                    until: presentation.cashflowUntil,
                  ),
                ],
              ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.items,
    required this.semantic,
    required this.valueMode,
    required this.level,
    required this.from,
    required this.until,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final StatisticsValueMode valueMode;
  final StatisticsCategoryLevel level;
  final DateTime from;
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _CategoryRow(
            item: items[i],
            color: statisticsChartSeriesColor(context, i),
            trailing:
                valueMode == StatisticsValueMode.amount
                    ? MoneyText(
                      money: items[i].amount,
                      semantic: semantic,
                      style: context.appTextStyles.amountList,
                    )
                    : Text(
                      statisticsCategoryPercentageText(items[i], items),
                      style: context.appTextStyles.amountList,
                    ),
            onTap:
                level == StatisticsCategoryLevel.primary &&
                        items[i].children.isNotEmpty
                    ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => _CategoryDetailPage(
                              item: items[i],
                              semantic: semantic,
                              from: from,
                              until: until,
                            ),
                      ),
                    )
                    : () => _openTransactions(context, items[i], from, until),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.color,
    required this.trailing,
    required this.onTap,
  });

  final StatisticsBreakdownItem item;
  final Color color;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space10),
        child: Row(
          children: [
            Container(
              width: AppSpacing.space12,
              height: AppSpacing.space12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.space10),
            Expanded(
              child: Text(
                item.title,
                style: context.appTextStyles.listTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            trailing,
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              color: colors.onSurfaceVariant,
              size: AppSpacing.space20,
            ),
          ],
        ),
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
    final totalMinor = children.fold<int>(
      0,
      (sum, child) => sum + statisticsCategoryMagnitude(child),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space8,
                AppSpacing.space8,
                AppSpacing.space20,
                AppSpacing.space12,
              ),
              child: AppPageHeader(
                title: item.title,
                subtitle: '二级分类构成',
                showBackButton: true,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space4,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  StatisticsSectionCard(
                    title: '分类构成',
                    child: Column(
                      children: [
                        StatisticsDonutChart(
                          items: children,
                          centerLabel: '合计',
                          centerValue: Money(minorUnits: totalMinor).format(),
                        ),
                        for (var i = 0; i < children.length; i++)
                          _CategoryRow(
                            item: children[i],
                            color: statisticsChartSeriesColor(context, i),
                            trailing: MoneyText(
                              money: children[i].amount,
                              semantic: semantic,
                              style: context.appTextStyles.amountList,
                            ),
                            onTap:
                                () => _openTransactions(
                                  context,
                                  children[i],
                                  from,
                                  until,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.appTextStyles.listSupporting,
            ),
          ],
        ),
      ),
    );
  }
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
