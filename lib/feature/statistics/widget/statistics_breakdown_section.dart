import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/analytics/analysis_chart_card.dart';
import '../../../widget/business/analytics/analysis_section_card.dart';
import '../../../widget/business/analytics/category_progress_list_item.dart';
import '../../../widget/business/analytics/chart/app_chart_empty_state.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/statistics_period_presentation.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';
import 'statistics_charts.dart';

class StatisticsBreakdownSection extends ConsumerWidget {
  const StatisticsBreakdownSection({
    required this.categories,
    required this.tags,
    required this.control,
    super.key,
  });

  final StatisticsCategoryAnalysisPresentation categories;
  final StatisticsTagAnalysisPresentation tags;
  final StatisticsControlState control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(statisticsViewModelProvider.notifier);
    final showingExpense =
        control.categoryKind == StatisticsCategoryKind.expense;
    final categoryPrimary = showingExpense
        ? categories.expenseCategories
        : categories.incomeCategories;
    final categoryItems = selectStatisticsCategoryItems(
      categoryPrimary,
      secondary: control.categoryLevel == StatisticsCategoryLevel.secondary,
    );
    final tagItems = showingExpense ? tags.expenseTags : tags.incomeTags;
    final semantic = showingExpense
        ? MoneySemantic.expense
        : MoneySemantic.income;
    return Column(
      children: [
        _BreakdownAnalysisCard(
          title: '分类构成',
          items: categoryItems,
          semantic: semantic,
          centerLabel: showingExpense ? '总支出' : '总收入',
          emptyMessage: '区间内暂无分类数据',
          kindControlKey: const ValueKey('statistics-category-kind'),
          categoryKind: control.categoryKind,
          onCategoryKindChanged: notifier.selectCategoryKind,
          categoryLevel: control.categoryLevel,
          onCategoryLevelChanged: notifier.selectCategoryLevel,
          from: categories.from,
          until: categories.until,
          comparisonLabel: categories.comparisonLabel,
        ),
        const SizedBox(height: AppSpacing.space16),
        _BreakdownAnalysisCard(
          title: '标签构成',
          items: tagItems,
          semantic: semantic,
          centerLabel: '标签命中',
          emptyMessage: '区间内暂无标签数据',
          kindControlKey: const ValueKey('statistics-tag-kind'),
          categoryKind: control.categoryKind,
          onCategoryKindChanged: notifier.selectCategoryKind,
          from: tags.from,
          until: tags.until,
          comparisonLabel: tags.comparisonLabel,
          showTags: true,
        ),
      ],
    );
  }
}

class _BreakdownAnalysisCard extends StatelessWidget {
  const _BreakdownAnalysisCard({
    required this.title,
    required this.items,
    required this.semantic,
    required this.centerLabel,
    required this.emptyMessage,
    required this.kindControlKey,
    required this.categoryKind,
    required this.onCategoryKindChanged,
    required this.from,
    required this.until,
    this.categoryLevel,
    this.onCategoryLevelChanged,
    this.showTags = false,
    this.comparisonLabel,
  });

  final String title;
  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final String centerLabel;
  final String emptyMessage;
  final Key kindControlKey;
  final StatisticsCategoryKind categoryKind;
  final ValueChanged<StatisticsCategoryKind> onCategoryKindChanged;
  final StatisticsCategoryLevel? categoryLevel;
  final ValueChanged<StatisticsCategoryLevel>? onCategoryLevelChanged;
  final DateTime from;
  final DateTime until;
  final bool showTags;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final totalMinor = items.fold<int>(
      0,
      (sum, item) => sum + statisticsCategoryMagnitude(item),
    );
    final centerValue = Money(minorUnits: totalMinor).format();
    final controls = Wrap(
      spacing: AppSpacing.space6,
      runSpacing: AppSpacing.space6,
      children: [
        AppSlidingSegmentedControl<StatisticsCategoryKind>(
          key: kindControlKey,
          segments: const [
            AppSegment(value: StatisticsCategoryKind.expense, label: '支出'),
            AppSegment(value: StatisticsCategoryKind.income, label: '收入'),
          ],
          selected: categoryKind,
          onChanged: onCategoryKindChanged,
        ),
        if (categoryLevel != null && onCategoryLevelChanged != null)
          AppSlidingSegmentedControl<StatisticsCategoryLevel>(
            key: const ValueKey('statistics-category-level'),
            segments: const [
              AppSegment(value: StatisticsCategoryLevel.primary, label: '主分类'),
              AppSegment(
                value: StatisticsCategoryLevel.secondary,
                label: '子分类',
              ),
            ],
            selected: categoryLevel!,
            onChanged: onCategoryLevelChanged!,
          ),
      ],
    );
    return AnalysisChartCard(
      title: title,
      trailing: controls,
      chart: Column(
        children: [
          if (items.isEmpty)
            AppChartEmptyState(message: emptyMessage)
          else
            Column(
              children: [
                StatisticsDonutChart(
                  items: items,
                  centerLabel: centerLabel,
                  centerValue: centerValue,
                ),
                if (showTags)
                  _TagList(
                    items: items,
                    semantic: semantic,
                    from: from,
                    until: until,
                    comparisonLabel: comparisonLabel,
                  )
                else
                  _CategoryList(
                    items: items,
                    semantic: semantic,
                    level: categoryLevel!,
                    from: from,
                    until: until,
                    comparisonLabel: comparisonLabel,
                  ),
              ],
            ),
        ],
      ),
      expandedChartBuilder: (height) => StatisticsDonutChart(
        items: items,
        centerLabel: centerLabel,
        centerValue: centerValue,
        height: height,
      ),
    );
  }
}

class _TagList extends StatelessWidget {
  const _TagList({
    required this.items,
    required this.semantic,
    required this.from,
    required this.until,
    required this.comparisonLabel,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final DateTime from;
  final DateTime until;
  final String? comparisonLabel;

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
            comparisonLabel: comparisonLabel,
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
    required this.comparisonLabel,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final StatisticsCategoryLevel level;
  final DateTime from;
  final DateTime until;
  final String? comparisonLabel;

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
            comparisonLabel: comparisonLabel,
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
                      builder: (_) => _CategoryDetailPage(
                        item: items[i],
                        semantic: semantic,
                        from: from,
                        until: until,
                        comparisonLabel: comparisonLabel,
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
    this.comparisonLabel,
  });

  final StatisticsBreakdownItem item;
  final Color color;
  final Widget trailing;
  final VoidCallback onTap;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final baseline = item.comparisonAmount;
    return CategoryProgressListItem(
      title: item.title,
      titleTrailing: comparisonLabel == null || baseline == null
          ? null
          : _CategoryComparisonText(
              item: item,
              baseline: baseline,
              comparisonLabel: comparisonLabel!,
            ),
      progress: item.progress,
      color: color,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _CategoryComparisonText extends StatelessWidget {
  const _CategoryComparisonText({
    required this.item,
    required this.baseline,
    required this.comparisonLabel,
  });

  final StatisticsBreakdownItem item;
  final Money baseline;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final change = PeriodChange(current: item.amount, previous: baseline);
    final amount = formatCompactMoney(change.delta.abs());
    final prefix = _comparisonChangePrefix(comparisonLabel);
    final compact = change.isFlat
        ? '$prefix持平'
        : baseline.minorUnits == 0 && item.amount.minorUnits > 0
        ? '新增 ${item.amount.format()}'
        : change.delta.minorUnits > 0
        ? '$prefix增加 $amount'
        : '$prefix减少 $amount';
    return Tooltip(
      message: compact,
      child: Text(
        compact,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: context.appTextStyles.listSupporting,
      ),
    );
  }
}

String _comparisonChangePrefix(String comparisonLabel) {
  return comparisonLabel == '环比' || comparisonLabel == '同比'
      ? comparisonLabel
      : '较$comparisonLabel';
}

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

class _CategoryDetailPage extends StatelessWidget {
  const _CategoryDetailPage({
    required this.item,
    required this.semantic,
    required this.from,
    required this.until,
    required this.comparisonLabel,
  });

  final StatisticsBreakdownItem item;
  final MoneySemantic semantic;
  final DateTime from;
  final DateTime until;
  final String? comparisonLabel;

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
                            comparisonLabel: comparisonLabel,
                            trailing: _CategoryRowValue(
                              item: children[i],
                              items: children,
                              semantic: semantic,
                            ),
                            onTap: () => _openTransactions(
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
        'accountType': item.accountType.name,
        'scope': StatisticsDrilldownScope.cashflow.name,
      },
    ).toString(),
  );
}
