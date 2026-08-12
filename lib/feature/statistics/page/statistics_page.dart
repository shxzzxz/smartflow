import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/finance/cashflow_summary_card.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../../../widget/business/finance/money_text.dart';
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space18,
        AppSpacing.space16,
        AppSpacing.space12,
      ),
      child: _PeriodPicker(
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
    return AnalysisSectionCard(
      title: '收支统计',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChartExpandButton(
            title: '收支统计',
            tooltip: '横屏查看收支统计',
            builder:
                (height) => StatisticsCashflowChart(
                  dailySummaries: presentation.dailySummaries,
                  grouping: control.trendGrouping,
                  form: control.chartForm,
                  height: height,
                ),
          ),
          const SizedBox(width: AppSpacing.space4),
          AppPopupMenuButton(
            key: const ValueKey('statistics-cashflow-settings'),
            tooltip: '图表设置',
            icon: RemixIcons.settings_3_line,
            items: [
              AppPopupMenuChoice(
                label: '柱状图',
                icon: RemixIcons.bar_chart_line,
                selected: control.chartForm == CashflowChartForm.bar,
                onPressed:
                    () => notifier.selectChartForm(CashflowChartForm.bar),
              ),
              AppPopupMenuChoice(
                label: '曲线',
                icon: RemixIcons.line_chart_line,
                selected: control.chartForm == CashflowChartForm.line,
                onPressed:
                    () => notifier.selectChartForm(CashflowChartForm.line),
              ),
            ],
          ),
        ],
      ),
      child: StatisticsCashflowChart(
        key: const ValueKey('statistics-cashflow-chart'),
        dailySummaries: presentation.dailySummaries,
        grouping: control.trendGrouping,
        form: control.chartForm,
      ),
    );
  }
}

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({required this.presentation});

  final StatisticsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return AnalysisSectionCard(
      title: '支出习惯',
      subtitle: '按星期 · 日均支出',
      trailing: _ChartExpandButton(
        title: '支出习惯',
        tooltip: '横屏查看支出习惯',
        builder:
            (height) => StatisticsWeekdayChart(
              dailySummaries: presentation.dailySummaries,
              height: height,
            ),
      ),
      child: StatisticsWeekdayChart(
        dailySummaries: presentation.dailySummaries,
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
    return AnalysisSectionCard(
      title: '资产走势',
      trailing: _ChartExpandButton(
        title: '资产走势',
        tooltip: '横屏查看资产走势',
        builder:
            (height) => StatisticsBalanceTrendChart(
              points: presentation.rangeBalanceTrend,
              grouping: control.trendGrouping,
              height: height,
            ),
      ),
      child: StatisticsBalanceTrendChart(
        points: presentation.rangeBalanceTrend,
        grouping: control.trendGrouping,
      ),
    );
  }
}

class _ChartExpandButton extends StatelessWidget {
  const _ChartExpandButton({
    required this.title,
    required this.tooltip,
    required this.builder,
  });

  final String title;
  final String tooltip;
  final Widget Function(double height) builder;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('chart-expand-$tooltip'),
      tooltip: tooltip,
      onPressed:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) =>
                      _LandscapeChartPage(title: title, chartBuilder: builder),
            ),
          ),
      icon: const Icon(RemixIcons.fullscreen_line),
    );
  }
}

class _LandscapeChartPage extends StatefulWidget {
  const _LandscapeChartPage({required this.title, required this.chartBuilder});

  final String title;
  final Widget Function(double height) chartBuilder;

  @override
  State<_LandscapeChartPage> createState() => _LandscapeChartPageState();
}

class _LandscapeChartPageState extends State<_LandscapeChartPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(RemixIcons.arrow_left_line),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: context.appTextStyles.sectionTitleStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space16),
              Expanded(
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => widget.chartBuilder(
                        (constraints.maxHeight -
                                AppChartGeometry
                                    .interactiveLegendReservedHeight)
                            .clamp(0, constraints.maxHeight)
                            .toDouble(),
                      ),
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
    final showingExpense =
        control.categoryKind == StatisticsCategoryKind.expense;
    final primary =
        showingExpense
            ? presentation.expenseCategories
            : presentation.incomeCategories;
    final items = selectStatisticsCategoryItems(
      primary,
      secondary: control.categoryLevel == StatisticsCategoryLevel.secondary,
    );
    final semantic =
        showingExpense ? MoneySemantic.expense : MoneySemantic.income;
    final totalMinor = items.fold<int>(
      0,
      (sum, item) => sum + statisticsCategoryMagnitude(item),
    );
    return AnalysisSectionCard(
      title: '分类构成',
      trailing: Wrap(
        spacing: AppSpacing.space6,
        runSpacing: AppSpacing.space6,
        children: [
          AppSlidingSegmentedControl<StatisticsCategoryKind>(
            key: const ValueKey('statistics-category-kind'),
            segments: const [
              AppSegment(value: StatisticsCategoryKind.expense, label: '支出'),
              AppSegment(value: StatisticsCategoryKind.income, label: '收入'),
            ],
            selected: control.categoryKind,
            onChanged: notifier.selectCategoryKind,
          ),
          AppSlidingSegmentedControl<StatisticsCategoryLevel>(
            key: const ValueKey('statistics-category-level'),
            segments: const [
              AppSegment(value: StatisticsCategoryLevel.primary, label: '主分类'),
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
      child:
          items.isEmpty
              ? const AppChartEmptyState(message: '区间内暂无分类数据')
              : Column(
                children: [
                  StatisticsDonutChart(
                    items: items,
                    centerLabel: showingExpense ? '总支出' : '总收入',
                    centerValue: Money(minorUnits: totalMinor).format(),
                  ),
                  _CategoryList(
                    items: items,
                    semantic: semantic,
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
