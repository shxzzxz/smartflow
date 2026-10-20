import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../widget/business/analytics/analysis_section_card.dart';
import '../../../widget/business/analytics/analytics_amount_column.dart';
import '../../../widget/business/analytics/chart/app_chart_empty_state.dart';
import '../../../widget/business/finance/money_text.dart';
import '../navigation/statistics_drilldown_routes.dart';
import '../presentation/statistics_period_presentation.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';
import '../widget/statistics_category_row.dart';
import '../widget/statistics_charts.dart';
import '../widget/statistics_composition_list.dart';

class StatisticsCategoryPage extends ConsumerWidget {
  const StatisticsCategoryPage({
    required this.categoryId,
    required this.categoryType,
    required this.from,
    required this.until,
    super.key,
  });

  final String categoryId;
  final AccountType categoryType;
  final DateTime from;
  final DateTime until;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(statisticsRangeContentProvider(from, until, 1));
    return switch (content) {
      StatisticsContentLoaded(:final categories) => _buildLoaded(
        context,
        categories,
      ),
      StatisticsContentError(:final message) => _CategoryMessagePage(
        title: '分类构成',
        message: message,
      ),
      StatisticsContentLoading() => const _CategoryMessagePage(
        title: '分类构成',
        loading: true,
      ),
    };
  }

  Widget _buildLoaded(
    BuildContext context,
    StatisticsCategoryAnalysisPresentation categories,
  ) {
    final items = categoryType == AccountType.income
        ? categories.incomeCategories
        : categories.expenseCategories;
    StatisticsBreakdownItem? primary;
    for (final item in items) {
      if (item.id == categoryId) {
        primary = item;
        break;
      }
    }
    if (primary == null) {
      return const _CategoryMessagePage(
        title: '分类构成',
        message: '分类数据已变化，请返回统计页重试。',
      );
    }

    final children = primary.children;
    final semantic = categoryType == AccountType.income
        ? MoneySemantic.income
        : MoneySemantic.expense;
    final totalMinor = children.fold<int>(
      0,
      (sum, child) => sum + statisticsCategoryMagnitude(child),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: primary.title, subtitle: '二级分类构成'),
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
                    child: children.isEmpty
                        ? const AppChartEmptyState(message: '该分类暂无二级分类数据')
                        : Column(
                            children: [
                              StatisticsDonutChart(
                                items: children,
                                centerLabel: '合计',
                                centerValue: Money(
                                  minorUnits: totalMinor,
                                ).format(),
                              ),
                              StatisticsCompositionList<
                                StatisticsBreakdownItem
                              >(
                                key: const ValueKey(
                                  'statistics-secondary-category-composition-list',
                                ),
                                items: children,
                                itemUnit: '项',
                                itemBuilder: (context, child, index) =>
                                    StatisticsCategoryRow(
                                      item: child,
                                      color: statisticsCategoryRowColor(
                                        context,
                                        index: index,
                                        itemCount: children.length,
                                      ),
                                      comparisonLabel:
                                          categories.comparisonLabel,
                                      trailing: AnalyticsAmountColumn(
                                        money: child.amount,
                                        semantic: semantic,
                                        maxWidth: AppChartGeometry
                                            .categoryAmountColumnWidth,
                                        secondaryText:
                                            statisticsCategoryPercentageText(
                                              child,
                                              children,
                                            ),
                                      ),
                                      onTap: () =>
                                          openStatisticsCategoryTransactions(
                                            context,
                                            item: child,
                                            from: from,
                                            until: until,
                                          ),
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

class _CategoryMessagePage extends StatelessWidget {
  const _CategoryMessagePage({
    required this.title,
    this.message,
    this.loading = false,
  });

  final String title;
  final String? message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title),
            Expanded(
              child: Center(
                child: loading
                    ? const CircularProgressIndicator()
                    : Text(message ?? '加载失败，请稍后重试。'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
