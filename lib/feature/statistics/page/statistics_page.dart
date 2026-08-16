import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/finance/cashflow_summary_card.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../widget/business/analytics/analysis_chart_card.dart';
import '../../../widget/business/analytics/analysis_section_card.dart';
import '../../../widget/business/analytics/category_progress_list_item.dart';
import '../../../widget/business/analytics/chart/app_chart_empty_state.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';
import '../widget/statistics_charts.dart';
import '../widget/statistics_period_sheet.dart';

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
              lastSelectableDate: state.lastSelectableDate,
            ),
            Expanded(
              child: _StatisticsBody(
                content: state.content,
                control: state.control,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 周期切换重新加载时保留上一次内容降透明度过渡，避免整页转圈闪烁。
class _StatisticsBody extends StatefulWidget {
  const _StatisticsBody({required this.content, required this.control});

  final StatisticsContentState content;
  final StatisticsControlState control;

  @override
  State<_StatisticsBody> createState() => _StatisticsBodyState();
}

class _StatisticsBodyState extends State<_StatisticsBody> {
  StatisticsContentLoaded? _lastLoaded;

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    if (content is StatisticsContentLoaded) {
      _lastLoaded = content;
    }
    return switch (content) {
      StatisticsContentLoaded(:final presentation) => _StatisticsContent(
        presentation: presentation,
        control: widget.control,
      ),
      StatisticsContentError(:final message) => _PageMessage(
        icon: RemixIcons.error_warning_line,
        message: message,
      ),
      StatisticsContentLoading() => switch (_lastLoaded) {
        null => const Center(child: CircularProgressIndicator()),
        final lastLoaded => IgnorePointer(
          child: Opacity(
            opacity: AppComponentTokens.staleContentOpacity,
            child: _StatisticsContent(
              presentation: lastLoaded.presentation,
              control: widget.control,
            ),
          ),
        ),
      },
    };
  }
}

class _StatisticsHeader extends ConsumerWidget {
  const _StatisticsHeader({
    required this.state,
    required this.periodLabel,
    required this.lastSelectableDate,
  });

  final StatisticsControlState state;
  final String periodLabel;
  final DateTime lastSelectableDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    return AppPageHeader.custom(
      titleContent: _PeriodPicker(
        label: periodLabel,
        onTap: () => _pickPeriod(context, notifier, lastSelectableDate),
      ),
    );
  }

  Future<void> _pickPeriod(
    BuildContext context,
    StatisticsViewModel notifier,
    DateTime lastSelectableDate,
  ) async {
    final selection = await showStatisticsPeriodSheet(
      context: context,
      granularity: state.granularity,
      mode: state.mode,
      from: state.periodFrom,
      untilExclusive: state.periodUntil,
      lastSelectableDate: lastSelectableDate,
    );
    if (selection == null) return;
    notifier.applyPeriodSelection(
      granularity: selection.granularity,
      mode: selection.mode,
      from: selection.from,
      untilExclusive: selection.untilExclusive,
    );
  }
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: SizedBox(
          height: AppSpacing.space48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space14),
            child: Row(
              children: [
                Icon(
                  RemixIcons.calendar_2_line,
                  size: AppSpacing.space20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.space10),
                Expanded(
                  child: Text(
                    label,
                    style: context.appTextStyles.subsectionTitleStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  RemixIcons.arrow_down_s_line,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
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
        const SizedBox(height: AppSpacing.space16),
        _WeekdaySection(presentation: presentation),
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
    final kpis = buildStatisticsCashflowKpis(presentation.dailySummaries);
    return Column(
      children: [
        CashflowSummaryCard(
          showCaptions: false,
          summary: CashflowSummaryPresentation(
            metrics: [
              CashflowSummaryMetricPresentation(
                label: '收入',
                amount: summary.income,
                caption: '',
                tone: FinanceTone.income,
              ),
              CashflowSummaryMetricPresentation(
                label: '支出',
                amount: summary.expense,
                caption: '',
                tone: FinanceTone.expense,
              ),
              CashflowSummaryMetricPresentation(
                label: '结余',
                amount: summary.net,
                caption: '',
                tone: FinanceTone.neutral,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space12),
        _KpiStrip(kpis: kpis),
      ],
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

class _CashflowSection extends ConsumerWidget {
  const _CashflowSection({required this.presentation, required this.control});

  final StatisticsPresentation presentation;
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
        dailySummaries: presentation.dailySummaries,
        grouping: control.trendGrouping,
        form: control.chartForm,
      ),
      expandedChartBuilder:
          (height) => StatisticsCashflowChart(
            dailySummaries: presentation.dailySummaries,
            grouping: control.trendGrouping,
            form: control.chartForm,
            height: height,
          ),
    );
  }
}

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({required this.presentation});

  final StatisticsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return AnalysisChartCard(
      title: '支出习惯',
      subtitle: '按星期 · 日均支出',
      chart: StatisticsWeekdayChart(
        dailySummaries: presentation.dailySummaries,
      ),
      expandedChartBuilder:
          (height) => StatisticsWeekdayChart(
            dailySummaries: presentation.dailySummaries,
            height: height,
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
    return AnalysisChartCard(
      title: '资产走势',
      showExpandIcon: true,
      expandedReservedHeight: AppChartGeometry.interactiveLegendReservedHeight,
      chart: StatisticsBalanceTrendChart(
        points: presentation.rangeBalanceTrend,
        grouping: control.trendGrouping,
      ),
      expandedChartBuilder:
          (height) => StatisticsBalanceTrendChart(
            points: presentation.rangeBalanceTrend,
            grouping: control.trendGrouping,
            height: height,
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
    final showingExpense =
        control.categoryKind == StatisticsCategoryKind.expense;
    final showingTags =
        control.categoryDimension == StatisticsCategoryDimension.tag;
    final primary =
        showingExpense
            ? (showingTags
                ? presentation.expenseTags
                : presentation.expenseCategories)
            : (showingTags
                ? presentation.incomeTags
                : presentation.incomeCategories);
    final items =
        showingTags
            ? primary
            : selectStatisticsCategoryItems(
              primary,
              secondary:
                  control.categoryLevel == StatisticsCategoryLevel.secondary,
            );
    final semantic =
        showingExpense ? MoneySemantic.expense : MoneySemantic.income;
    final totalMinor = items.fold<int>(
      0,
      (sum, item) => sum + statisticsCategoryMagnitude(item),
    );
    final centerLabel = showingExpense ? '总支出' : '总收入';
    final centerValue = Money(minorUnits: totalMinor).format();
    return AnalysisChartCard(
      title: showingTags ? '标签构成' : '分类构成',
      // 控制区放在内容区顶部而不是标题行 trailing：标题行的 Row 给
      // trailing 无界宽度，Wrap 不会换行，紧凑屏上会横向溢出。
      chart: Column(
        children: [
          Wrap(
            spacing: AppSpacing.space6,
            runSpacing: AppSpacing.space6,
            children: [
              AppSlidingSegmentedControl<StatisticsCategoryDimension>(
                key: const ValueKey('statistics-category-dimension'),
                segments: const [
                  AppSegment(
                    value: StatisticsCategoryDimension.category,
                    label: '分类',
                  ),
                  AppSegment(
                    value: StatisticsCategoryDimension.tag,
                    label: '标签',
                  ),
                ],
                selected: control.categoryDimension,
                onChanged: notifier.selectCategoryDimension,
              ),
              AppSlidingSegmentedControl<StatisticsCategoryKind>(
                key: const ValueKey('statistics-category-kind'),
                segments: const [
                  AppSegment(
                    value: StatisticsCategoryKind.expense,
                    label: '支出',
                  ),
                  AppSegment(value: StatisticsCategoryKind.income, label: '收入'),
                ],
                selected: control.categoryKind,
                onChanged: notifier.selectCategoryKind,
              ),
              if (!showingTags)
                AppSlidingSegmentedControl<StatisticsCategoryLevel>(
                  key: const ValueKey('statistics-category-level'),
                  segments: const [
                    AppSegment(
                      value: StatisticsCategoryLevel.primary,
                      label: '主分类',
                    ),
                    AppSegment(
                      value: StatisticsCategoryLevel.secondary,
                      label: '子分类',
                    ),
                  ],
                  selected: control.categoryLevel,
                  onChanged: notifier.selectCategoryLevel,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          if (items.isEmpty)
            AppChartEmptyState(message: showingTags ? '区间内暂无标签数据' : '区间内暂无分类数据')
          else
            Column(
              children: [
                StatisticsDonutChart(
                  items: items,
                  centerLabel: centerLabel,
                  centerValue: centerValue,
                ),
                if (showingTags)
                  _TagList(
                    items: items,
                    semantic: semantic,
                    from: presentation.cashflowFrom,
                    until: presentation.cashflowUntil,
                  )
                else
                  _CategoryList(
                    items: items,
                    semantic: semantic,
                    level: control.categoryLevel,
                    from: presentation.cashflowFrom,
                    until: presentation.cashflowUntil,
                  ),
              ],
            ),
        ],
      ),
      expandedChartBuilder:
          (height) => StatisticsDonutChart(
            items: items,
            centerLabel: centerLabel,
            centerValue: centerValue,
            height: height,
          ),
    );
  }
}

/// 标签构成列表：标签没有层级，每行直接钻取交易流水。
class _TagList extends StatelessWidget {
  const _TagList({
    required this.items,
    required this.semantic,
    required this.from,
    required this.until,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final DateTime from;
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _CategoryRow(
            item: items[i],
            color: statisticsCategoryRowColor(
              context,
              index: i,
              itemCount: items.length,
            ),
            trailing: _CategoryRowValue(
              item: items[i],
              items: items,
              semantic: semantic,
            ),
            onTap: () => _openTagTransactions(context, items[i], from, until),
          ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.items,
    required this.semantic,
    required this.level,
    required this.from,
    required this.until,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
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
            color: statisticsCategoryRowColor(
              context,
              index: i,
              itemCount: items.length,
            ),
            trailing: _CategoryRowValue(
              item: items[i],
              items: items,
              semantic: semantic,
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

/// 行尾金额与占比同时展示，占比随所在列表整体归一。
class _CategoryRowValue extends StatelessWidget {
  const _CategoryRowValue({
    required this.item,
    required this.items,
    required this.semantic,
  });

  final StatisticsBreakdownItem item;
  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        MoneyText(
          money: item.amount,
          semantic: semantic,
          style: context.appTextStyles.amountList,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          statisticsCategoryPercentageText(item, items),
          style: context.appTextStyles.listSupporting,
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
    return CategoryProgressListItem(
      title: item.title,
      progress: item.progress,
      color: color,
      trailing: trailing,
      onTap: onTap,
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
            AppPageHeader(title: item.title, subtitle: '二级分类构成'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space8,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  AnalysisSectionCard(
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
                            color: statisticsCategoryRowColor(
                              context,
                              index: i,
                              itemCount: children.length,
                            ),
                            trailing: _CategoryRowValue(
                              item: children[i],
                              items: children,
                              semantic: semantic,
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
  context.push(
    Uri(
      path: '/statistics/transactions',
      queryParameters: {
        'categoryId': item.id,
        if (item.isUnsubdivided) 'categoryScope': 'own',
        'from': from.toIso8601String(),
        'until': until.toIso8601String(),
        'title': item.title,
        'scope': StatisticsDrilldownScope.cashflow.name,
      },
    ).toString(),
  );
}

void _openTagTransactions(
  BuildContext context,
  StatisticsBreakdownItem item,
  DateTime from,
  DateTime until,
) {
  context.push(
    Uri(
      path: '/statistics/transactions',
      queryParameters: {
        if (item.id == untaggedTagItemId) 'untagged': '1' else 'tagId': item.id,
        'from': from.toIso8601String(),
        'until': until.toIso8601String(),
        'title': item.title,
        'scope': StatisticsDrilldownScope.cashflow.name,
      },
    ).toString(),
  );
}
