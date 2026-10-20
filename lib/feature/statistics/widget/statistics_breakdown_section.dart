import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../../design_system/widget/app_sliding_segmented_control.dart';
import '../../../widget/business/analytics/analysis_chart_card.dart';
import '../../../widget/business/analytics/analytics_amount_column.dart';
import '../../../widget/business/analytics/chart/app_chart_empty_state.dart';
import '../../../widget/business/finance/money_text.dart';
import '../navigation/statistics_drilldown_routes.dart';
import '../presentation/statistics_period_presentation.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';
import 'statistics_category_row.dart';
import 'statistics_composition_list.dart';
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
                    categoryKind: categoryKind,
                    comparisonLabel: comparisonLabel,
                  )
                else
                  _CategoryList(
                    items: items,
                    semantic: semantic,
                    level: categoryLevel!,
                    from: from,
                    until: until,
                    categoryKind: categoryKind,
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
    required this.categoryKind,
    required this.comparisonLabel,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final DateTime from;
  final DateTime until;
  final StatisticsCategoryKind categoryKind;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    return StatisticsCompositionList<StatisticsBreakdownItem>(
      key: const ValueKey('statistics-tag-composition-list'),
      items: items,
      itemUnit: '项',
      resetToken: categoryKind,
      itemBuilder: (context, item, index) => StatisticsCategoryRow(
        item: item,
        color: statisticsCategoryRowColor(
          context,
          index: index,
          itemCount: items.length,
        ),
        comparisonLabel: comparisonLabel,
        trailing: AnalyticsAmountColumn(
          key: ValueKey('statistics-breakdown-value-${item.id}'),
          money: item.amount,
          semantic: semantic,
          maxWidth: AppChartGeometry.categoryAmountColumnWidth,
          secondaryText: statisticsCategoryPercentageText(item, items),
        ),
        onTap: () => openStatisticsTagTransactions(
          context,
          item: item,
          from: from,
          until: until,
        ),
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
    required this.categoryKind,
    required this.comparisonLabel,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final StatisticsCategoryLevel level;
  final DateTime from;
  final DateTime until;
  final StatisticsCategoryKind categoryKind;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    return StatisticsCompositionList<StatisticsBreakdownItem>(
      key: const ValueKey('statistics-category-composition-list'),
      items: items,
      itemUnit: '项',
      resetToken: (categoryKind, level),
      itemBuilder: (context, item, index) => StatisticsCategoryRow(
        item: item,
        color: statisticsCategoryRowColor(
          context,
          index: index,
          itemCount: items.length,
        ),
        comparisonLabel: comparisonLabel,
        trailing: AnalyticsAmountColumn(
          key: ValueKey('statistics-breakdown-value-${item.id}'),
          money: item.amount,
          semantic: semantic,
          maxWidth: AppChartGeometry.categoryAmountColumnWidth,
          secondaryText: statisticsCategoryPercentageText(item, items),
        ),
        onTap:
            level == StatisticsCategoryLevel.primary && item.children.isNotEmpty
            ? () => openStatisticsCategoryDetail(
                context,
                item: item,
                categoryKind: categoryKind,
                from: from,
                until: until,
              )
            : () => openStatisticsCategoryTransactions(
                context,
                item: item,
                from: from,
                until: until,
              ),
      ),
    );
  }
}
