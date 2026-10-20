import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/app_shell.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/router.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/token/typography.dart';
import 'package:smartflow/design_system/widget/app_date_picker_panel.dart';
import 'package:smartflow/design_system/widget/app_page_header.dart';
import 'package:smartflow/design_system/widget/app_sliding_segmented_control.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/statistics/page/statistics_page.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_period_presentation.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_state_presentation.dart';
import 'package:smartflow/feature/statistics/view/statistics_period_view.dart';
import 'package:smartflow/feature/statistics/view/statistics_state_view.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_state_view_model.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_view_model.dart';
import 'package:smartflow/feature/statistics/widget/statistics_charts.dart';
import 'package:smartflow/feature/statistics/widget/statistics_composition_list.dart';
import 'package:smartflow/widget/business/analytics/analytics_amount_column.dart';
import 'package:smartflow/widget/business/analytics/chart/app_cartesian_chart.dart';
import 'package:smartflow/widget/business/analytics/category_progress_list_item.dart';

void main() {
  testWidgets('shows a clear statistics hierarchy on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);

    expect(find.text('统计'), findsNothing);
    expect(find.text('查看收支结构与资产变化'), findsNothing);
    expect(find.text('本期概览'), findsNothing);
    expect(find.byType(AppPageHeader), findsNothing);
    expect(find.byType(StatisticsPeriodView), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    final viewSwitcher = tester.widget<TabBar>(
      find.byKey(const ValueKey('statistics-view-switcher')),
    );
    expect(viewSwitcher.labelStyle?.fontSize, AppTypography.fontSizeMd);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('statistics-view-switcher')))
          .height,
      greaterThanOrEqualTo(AppSpacing.space48),
    );
    expect(find.text('本期'), findsWidgets);
    expect(find.text('环比'), findsWidgets);
    expect(find.text('2026.1.1 - 1.15'), findsOneWidget);
    expect(find.text('2025.12.1 - 12.15'), findsOneWidget);
    expect(find.textContaining('已过'), findsNothing);
    expect(find.textContaining('累计支出 · 对比'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-period-comparison')),
        matching: find.byType(Material),
      ),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('收支统计'),
      200,
      scrollable: _verticalScrollable().last,
    );
    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('按日汇总，点击柱形查看金额'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens comparison quick settings from the period bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    await tester.tap(
      find.byKey(const ValueKey('statistics-period-comparison')),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置对比'), findsOneWidget);
    expect(find.text('同比'), findsOneWidget);
    expect(find.text('不对比'), findsOneWidget);

    await tester.tap(find.text('不对比'));
    await tester.pumpAndSettle();
    expect(find.text('未设置'), findsOneWidget);
    expect(find.text('环比'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows overview changes and ratios in two lines', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);

    final card = find.byKey(const ValueKey('statistics-overview-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(Divider)),
      findsNothing,
    );
    final expenseLabel = find.descendant(of: card, matching: find.text('支出'));
    final incomeLabel = find.descendant(of: card, matching: find.text('收入'));
    final netLabel = find.descendant(of: card, matching: find.text('结余'));
    expect(
      tester.getRect(expenseLabel).left,
      lessThan(tester.getRect(incomeLabel).left),
    );
    expect(
      tester.getRect(incomeLabel).left,
      lessThan(tester.getRect(netLabel).left),
    );
    expect(
      find.descendant(of: card, matching: find.text('对比期 · 环比')),
      findsNothing,
    );
    expect(
      find.descendant(of: card, matching: find.text('日均支出')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('最高单日支出')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('日均收入')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('statistics-overview-income-change-amount'),
            ),
          )
          .data,
      '+10',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('statistics-overview-income-change-ratio'),
            ),
          )
          .data,
      '+100%',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('statistics-overview-expense-change-amount'),
            ),
          )
          .data,
      '+3',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('statistics-overview-expense-change-ratio'),
            ),
          )
          .data,
      '+75%',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('statistics-overview-net-change-amount')),
          )
          .data,
      '+7',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('statistics-overview-net-change-ratio')),
          )
          .data,
      '+117%',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the merged overview usable at large text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester, textScaler: const TextScaler.linear(2));

    expect(
      find.byKey(const ValueKey('statistics-overview-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('statistics-overview-income-change-amount')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses fixed breakdown columns and adaptive amount formatting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = _loadedContent();
    final content = StatisticsContentLoaded(
      overview: base.overview,
      comparison: base.comparison,
      cashflow: base.cashflow,
      categories: StatisticsCategoryAnalysisPresentation(
        from: DateTime(2026, 1),
        until: DateTime(2026, 1, 16),
        comparisonLabel: '环比',
        incomeCategories: base.categories.incomeCategories,
        expenseCategories: [
          StatisticsBreakdownItem(
            id: 'large',
            title: '大额支出',
            accountType: AccountType.expense,
            amount: const Money(minorUnits: 12345678900),
            progress: .8,
            comparisonAmount: const Money(minorUnits: 10000000000),
          ),
          StatisticsBreakdownItem(
            id: 'small',
            title: '一个很长很长的分类名称用于观察省略',
            accountType: AccountType.expense,
            amount: const Money(minorUnits: 700),
            progress: .2,
            comparisonAmount: const Money(minorUnits: 400),
          ),
          StatisticsBreakdownItem(
            id: 'plain',
            title: '新增分类',
            accountType: AccountType.expense,
            amount: const Money(minorUnits: 20000000),
            progress: .1,
            comparisonAmount: const Money(minorUnits: 0),
          ),
          StatisticsBreakdownItem(
            id: 'huge',
            title: '超大额分类',
            accountType: AccountType.expense,
            amount: const Money(minorUnits: 123456789000000),
            progress: .1,
            comparisonAmount: const Money(minorUnits: 0),
          ),
        ],
      ),
      tags: base.tags,
      balance: base.balance,
    );

    await _pumpStatisticsPage(tester, content: content);
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    final largeValue = find.byKey(
      const ValueKey('statistics-breakdown-value-large'),
    );
    final smallValue = find.byKey(
      const ValueKey('statistics-breakdown-value-small'),
    );
    final largeComparison = find.byKey(
      const ValueKey('statistics-breakdown-comparison-large'),
    );
    final smallComparison = find.byKey(
      const ValueKey('statistics-breakdown-comparison-small'),
    );
    expect(
      find.descendant(of: largeValue, matching: find.text('1.23亿')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: smallValue, matching: find.text('7')),
      findsOneWidget,
    );
    expect(
      tester.getRect(largeValue).right,
      moreOrLessEquals(tester.getRect(smallValue).right, epsilon: .01),
    );
    expect(
      tester.getRect(largeComparison).left,
      moreOrLessEquals(tester.getRect(smallComparison).left, epsilon: .01),
    );
    final plainComparison = find.byKey(
      const ValueKey('statistics-breakdown-comparison-plain'),
    );
    expect(
      find.descendant(of: plainComparison, matching: find.text('200000')),
      findsOneWidget,
    );
    final hugeComparison = find.byKey(
      const ValueKey('statistics-breakdown-comparison-huge'),
    );
    expect(
      find.descendant(of: hugeComparison, matching: find.text('1.23万亿')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('folds long category and tag composition lists', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester, content: _longBreakdownContent());
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    final categoryList = find.byKey(
      const ValueKey('statistics-category-composition-list'),
    );
    expect(
      find.descendant(
        of: categoryList,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(statisticsCompositionCollapsedItemCount),
    );
    final categoryExpand = find.descendant(
      of: categoryList,
      matching: find.text('查看全部 6 项'),
    );
    await tester.ensureVisible(categoryExpand);
    await tester.pumpAndSettle();
    await tester.tap(categoryExpand);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: categoryList,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(6),
    );
    expect(
      find.descendant(of: categoryList, matching: find.text('收起')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('标签构成'),
      200,
      scrollable: _verticalScrollable().last,
    );
    final tagList = find.byKey(
      const ValueKey('statistics-tag-composition-list'),
    );
    expect(
      find.descendant(
        of: tagList,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(statisticsCompositionCollapsedItemCount),
    );
    final tagExpand = find.descendant(
      of: tagList,
      matching: find.text('查看全部 6 项'),
    );
    await tester.ensureVisible(tagExpand);
    await tester.pumpAndSettle();
    await tester.tap(tagExpand);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: tagList,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(6),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches between period analysis and current state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);

    await tester.tap(find.text('当前状态'));
    await tester.pumpAndSettle();

    expect(find.byType(StatisticsStateView), findsOneWidget);
    expect(find.byType(AppPageHeader), findsNothing);
    expect(find.textContaining('截至'), findsNothing);
    expect(find.text('净资产'), findsNothing);
    expect(find.text('本月预算'), findsNothing);
    expect(find.text('资产构成'), findsOneWidget);
    expect(find.text('负债构成'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分期构成'),
      300,
      scrollable: _verticalScrollable().last,
    );
    expect(find.text('分期构成'), findsOneWidget);
    expect(find.text('预计剩余利息'), findsNothing);
    expect(find.text('分期还款走势'), findsOneWidget);
    expect(find.text('概览'), findsNothing);
    expect(find.text('还款走势'), findsNothing);
    expect(find.text('待还本金'), findsWidgets);
    expect(find.text('待还利息'), findsWidgets);
    expect(find.text('逾期待还'), findsOneWidget);
    expect(find.textContaining('下一还款日'), findsNothing);
    expect(find.text('未来待还'), findsNothing);
    expect(find.textContaining('代还'), findsNothing);
    expect(find.text('2026年1月'), findsNothing);
    final compositionCard = find.byKey(
      const ValueKey('statistics-installment-composition-card'),
    );
    final compositionCardElement = tester.element(compositionCard);
    final cashflowCard = find.byKey(
      const ValueKey('statistics-installment-cashflow-card'),
    );
    final cashflowCardElement = tester.element(cashflowCard);
    final compositionDonut = find.descendant(
      of: compositionCard,
      matching: find.byType(StatisticsDonutChart),
    );
    expect(compositionDonut, findsOneWidget);
    expect(
      find.descendant(
        of: compositionCard,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(4),
    );
    expect(
      find.descendant(of: compositionCard, matching: find.byType(Divider)),
      findsNothing,
    );
    expect(
      find.descendant(of: compositionCard, matching: find.text('18000')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: compositionCard, matching: find.text('900')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: compositionCard, matching: find.text('18.00%')),
      findsOneWidget,
    );
    expect(
      tester.widget<StatisticsDonutChart>(compositionDonut).centerLabel,
      '待还本金',
    );
    expect(
      tester
          .widget<AnalyticsAmountColumn>(
            find.byKey(const ValueKey('statistics-installment-value-vehicle')),
          )
          .money
          .minorUnits,
      1800000,
    );
    final vehicleAmount = tester.getRect(
      find.byKey(const ValueKey('statistics-installment-value-vehicle')),
    );
    final consumerAmount = tester.getRect(
      find.byKey(const ValueKey('statistics-installment-value-consumer')),
    );
    final billAmount = tester.getRect(
      find.byKey(const ValueKey('statistics-installment-value-bill')),
    );
    expect(
      vehicleAmount.right,
      moreOrLessEquals(consumerAmount.right, epsilon: .01),
    );
    expect(
      consumerAmount.right,
      moreOrLessEquals(billAmount.right, epsilon: .01),
    );
    final metricControl = find.byKey(
      const ValueKey('statistics-installment-composition-metric'),
    );
    final horizonControl = find.byKey(
      const ValueKey('statistics-installment-cashflow-horizon'),
    );
    expect(
      tester
          .widget<
            AppSlidingSegmentedControl<StatisticsInstallmentCompositionMetric>
          >(metricControl)
          .selected,
      StatisticsInstallmentCompositionMetric.principal,
    );
    await tester.tap(find.text('总待还'));
    await tester.pump();
    expect(
      tester
          .widget<
            AppSlidingSegmentedControl<StatisticsInstallmentCompositionMetric>
          >(metricControl)
          .selected,
      StatisticsInstallmentCompositionMetric.total,
    );
    expect(tester.element(compositionCard), same(compositionCardElement));
    expect(
      tester.widget<StatisticsDonutChart>(compositionDonut).centerLabel,
      '总待还',
    );
    expect(
      tester
          .widget<AnalyticsAmountColumn>(
            find.byKey(const ValueKey('statistics-installment-value-vehicle')),
          )
          .money
          .minorUnits,
      1890000,
    );
    expect(find.text('信用卡 · 分期卡'), findsOneWidget);
    expect(
      tester
          .widget<
            AppSlidingSegmentedControl<StatisticsInstallmentCashflowHorizon>
          >(horizonControl)
          .selected,
      StatisticsInstallmentCashflowHorizon.sixMonths,
    );
    await tester.tap(find.text('一年'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<
            AppSlidingSegmentedControl<StatisticsInstallmentCashflowHorizon>
          >(horizonControl)
          .selected,
      StatisticsInstallmentCashflowHorizon.oneYear,
    );
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<
            AppSlidingSegmentedControl<StatisticsInstallmentCashflowHorizon>
          >(horizonControl)
          .selected,
      StatisticsInstallmentCashflowHorizon.all,
    );
    expect(tester.element(cashflowCard), same(cashflowCardElement));
    expect(find.text('分期还款走势'), findsOneWidget);
    expect(find.byType(StatisticsInstallmentCashflowChart), findsOneWidget);
    expect(tester.takeException(), isNull);

    final cashflowExpand = find.byTooltip('横屏查看分期还款走势');
    await tester.ensureVisible(cashflowExpand);
    await tester.pumpAndSettle();
    await tester.tap(cashflowExpand);
    await tester.pumpAndSettle();
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.text('分期还款走势'), findsNothing);
    expect(find.byType(StatisticsInstallmentCashflowChart), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.text('期间分析'));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsPeriodView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('statistics-overview-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses fixed amount columns for current-state asset and liability rows',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = StatisticsStatePresentation(
        asOf: DateTime(2026, 1, 15),
        totalAssets: const Money(minorUnits: 12345778900),
        totalLiabilities: const Money(minorUnits: 2000),
        assetAccounts: const [
          StatisticsBreakdownItem(
            id: 'cash',
            title: '现金',
            accountType: AccountType.asset,
            amount: Money(minorUnits: 100000),
            progress: .2,
          ),
          StatisticsBreakdownItem(
            id: 'fund',
            title: '基金',
            accountType: AccountType.asset,
            amount: Money(minorUnits: 12345678900),
            progress: 1,
          ),
        ],
        liabilityAccounts: const [
          StatisticsBreakdownItem(
            id: 'card',
            title: '信用卡',
            accountType: AccountType.liability,
            amount: Money(minorUnits: 2000),
            progress: 1,
          ),
        ],
      );

      await _pumpStatisticsPage(tester, statePresentation: state);
      await tester.tap(find.text('当前状态'));
      await tester.pumpAndSettle();

      final cashAmount = find.byKey(
        const ValueKey('statistics-state-amount-asset-cash'),
      );
      final fundAmount = find.byKey(
        const ValueKey('statistics-state-amount-asset-fund'),
      );
      final cardAmount = find.byKey(
        const ValueKey('statistics-state-amount-liability-card'),
      );
      expect(
        find.descendant(of: fundAmount, matching: find.text('1.23亿')),
        findsOneWidget,
      );
      expect(
        tester.getRect(cashAmount).right,
        moreOrLessEquals(tester.getRect(fundAmount).right, epsilon: .01),
      );
      expect(
        tester.getRect(fundAmount).right,
        moreOrLessEquals(tester.getRect(cardAmount).right, epsilon: .01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the signed liability total from current-state balance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(
      tester,
      statePresentation: StatisticsStatePresentation(
        asOf: DateTime(2026, 1, 15),
        totalAssets: const Money(minorUnits: 10000),
        totalLiabilities: const Money(minorUnits: 1500),
        assetAccounts: const [
          StatisticsBreakdownItem(
            id: 'cash',
            title: '现金',
            accountType: AccountType.asset,
            amount: Money(minorUnits: 10000),
            progress: 1,
          ),
        ],
        liabilityAccounts: const [
          StatisticsBreakdownItem(
            id: 'card',
            title: '信用卡',
            accountType: AccountType.liability,
            amount: Money(minorUnits: 2000),
            progress: 1,
          ),
          StatisticsBreakdownItem(
            id: 'overpaid-card',
            title: '超额还款卡',
            accountType: AccountType.liability,
            amount: Money(minorUnits: -500),
            progress: .25,
          ),
        ],
      ),
    );

    await tester.tap(find.text('当前状态'));
    await tester.pumpAndSettle();
    final liabilityCard = find.byKey(
      const ValueKey('statistics-state-liabilities'),
    );
    await tester.scrollUntilVisible(
      liabilityCard,
      200,
      scrollable: _verticalScrollable().last,
    );
    final donut = tester.widget<StatisticsDonutChart>(
      find.descendant(
        of: liabilityCard,
        matching: find.byType(StatisticsDonutChart),
      ),
    );
    expect(donut.centerValue, '15.00');
    expect(find.text('超额还款卡'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folds long asset and liability composition lists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(
      tester,
      statePresentation: _longStatePresentation(),
    );
    await tester.tap(find.text('当前状态'));
    await tester.pumpAndSettle();

    final assetCard = find.byKey(const ValueKey('statistics-state-assets'));
    await tester.scrollUntilVisible(
      assetCard,
      200,
      scrollable: _verticalScrollable().last,
    );
    final assetList = find.byKey(
      const ValueKey('statistics-state-composition-list-asset'),
    );
    expect(
      find.descendant(
        of: assetList,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(statisticsCompositionCollapsedItemCount),
    );
    final assetExpand = find.descendant(
      of: assetList,
      matching: find.text('查看全部 6 项'),
    );
    await tester.ensureVisible(assetExpand);
    await tester.pumpAndSettle();
    await tester.tap(assetExpand);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: assetList,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(6),
    );

    final liabilityCard = find.byKey(
      const ValueKey('statistics-state-liabilities'),
    );
    await tester.scrollUntilVisible(
      liabilityCard,
      200,
      scrollable: _verticalScrollable().last,
    );
    final liabilityList = find.byKey(
      const ValueKey('statistics-state-composition-list-liability'),
    );
    expect(
      find.descendant(
        of: liabilityList,
        matching: find.byType(CategoryProgressListItem),
      ),
      findsNWidgets(statisticsCompositionCollapsedItemCount),
    );
    expect(
      find.descendant(of: liabilityList, matching: find.text('查看全部 6 项')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expands installment composition contracts', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(
      tester,
      installmentsPresentation: _installmentsPresentation(withOverflow: true),
    );
    await tester.tap(find.text('当前状态'));
    await tester.pumpAndSettle();
    final compositionCard = find.byKey(
      const ValueKey('statistics-installment-composition-card'),
    );
    final expandButton = find.descendant(
      of: compositionCard,
      matching: find.text('查看全部 6 笔'),
    );
    await tester.ensureVisible(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('储蓄卡 · 备用分期'), findsNothing);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('储蓄卡 · 备用分期'), findsOneWidget);
    await tester.tap(
      find.descendant(of: compositionCard, matching: find.text('收起')),
    );
    await tester.pumpAndSettle();
    expect(find.text('储蓄卡 · 备用分期'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps installment analysis usable with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester, textScaler: const TextScaler.linear(2));
    await tester.tap(find.text('当前状态'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('分期构成'),
      300,
      scrollable: _verticalScrollable().last,
    );

    expect(find.text('分期构成'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分期还款走势'),
      300,
      scrollable: _verticalScrollable().last,
    );
    expect(find.text('分期还款走势'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a cashflow empty state when the range has no activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(
      tester,
      content: _loadedContent(
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 5),
            income: const Money(minorUnits: 0),
            expense: const Money(minorUnits: 0),
          ),
        ],
      ),
    );

    expect(find.text('区间内暂无收支数据'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('shows category and tag breakdowns in separate cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    final kindControl = find.byKey(const ValueKey('statistics-category-kind'));
    final levelControl = find.byKey(
      const ValueKey('statistics-category-level'),
    );
    final tagKindControl = find.byKey(const ValueKey('statistics-tag-kind'));
    expect(kindControl, findsOneWidget);
    expect(levelControl, findsOneWidget);
    expect(tagKindControl, findsOneWidget);
    expect(find.text('标签构成'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('statistics-category-dimension')),
      findsNothing,
    );
    expect(tester.getRect(kindControl).right, lessThanOrEqualTo(360));
    expect(tester.getRect(levelControl).right, lessThanOrEqualTo(360));
    expect(find.text('主分类'), findsOneWidget);

    // 金额与占比同时展示，不再提供数值模式开关。
    expect(find.text('金额'), findsNothing);
    expect(find.text('占比'), findsNothing);
    expect(find.text('100.0%'), findsNWidgets(2));
    final categoryTitle = tester.getRect(find.text('餐饮'));
    final categoryComparison = find.byKey(
      const ValueKey('statistics-breakdown-comparison-food'),
    );
    final comparisonPrefix = tester.getRect(
      find.descendant(of: categoryComparison, matching: find.text('环比增加')),
    );
    final comparisonAmount = tester.getRect(
      find.descendant(of: categoryComparison, matching: find.text('3')),
    );
    expect(
      (categoryTitle.center.dy - comparisonPrefix.center.dy).abs(),
      lessThan(1),
    );
    expect(comparisonPrefix.left, greaterThan(categoryTitle.right));
    expect(comparisonAmount.left, greaterThan(comparisonPrefix.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('category drilldown pages hide the bottom navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsRouter(tester);
    await _openSalaryCategoryDetail(tester);

    expect(find.text('二级分类构成'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await _openSalaryTransactions(tester);

    expect(find.text('基本工资'), findsWidgets);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('predictive and regular back restore the category detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsRouter(tester);
    await _openSalaryCategoryDetail(tester);
    await _openSalaryTransactions(tester);

    await _sendPredictiveBackGesture(tester);

    expect(find.text('二级分类构成'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('statistics-secondary-category-composition-list'),
      ),
      findsOneWidget,
    );

    await _openSalaryTransactions(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('二级分类构成'), findsOneWidget);
  });

  testWidgets('keeps the category header stable with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester, textScaler: const TextScaler.linear(1.3));
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps category controls usable at accessibility text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester, textScaler: const TextScaler.linear(2));
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );

    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens every expanded chart view on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);

    for (final tooltip in ['横屏查看收支统计', '横屏查看资产走势']) {
      await tester.scrollUntilVisible(
        find.byTooltip(tooltip),
        200,
        scrollable: _verticalScrollable().last,
      );
      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();
      expect(find.byTooltip('返回'), findsNothing);
      expect(
        find.byType(AppCartesianChart).evaluate().isNotEmpty ||
            find.byType(StatisticsDonutChart).evaluate().isNotEmpty,
        isTrue,
      );
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('selects a custom date range from the period sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    expect(find.text('2026.1.1 - 1.15'), findsOneWidget);
    await tester.tap(find.text('2026.1.1 - 1.15'));
    await tester.pumpAndSettle();

    // 粒度切到「日」，模式切到「范围」
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('范围'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();
    expect(find.text('2025年12月'), findsOneWidget);
    final panel = find.byType(AppDatePickerPanel);
    await tester.tap(find.descendant(of: panel, matching: find.text('10')));
    await tester.pump();
    await tester.tap(find.descendant(of: panel, matching: find.text('12')));
    await tester.pump();
    expect(find.text('2025.12.10 - 2025.12.12'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('2025.12.10 - 12.12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick-selects month and year from the period sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    await tester.tap(find.text('2026.1.1 - 1.15'));
    await tester.pumpAndSettle();
    expect(find.text('2026年'), findsOneWidget);
    await tester.tap(find.text('1月'));
    await tester.pumpAndSettle();
    expect(find.text('2026.1.1 - 1.15'), findsOneWidget);

    await tester.tap(find.text('2026.1.1 - 1.15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    expect(find.text('2026.1.1 - 1.15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows market-level charts and switches analysis kinds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpStatisticsRouter(tester);

    expect(find.text('2026.1.1 - 1.15'), findsOneWidget);
    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('累计'), findsNothing);

    final cashflowChart = find.byKey(
      const ValueKey('statistics-cashflow-chart'),
    );
    expect(
      find.descendant(of: cashflowChart, matching: find.byType(BarChart)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('statistics-cashflow-metric')),
      findsNothing,
    );
    expect(
      find.descendant(of: cashflowChart, matching: find.text('收入')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: cashflowChart,
        matching: find.byKey(const ValueKey('chart-legend-支出')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BarChart>(
            find.descendant(of: cashflowChart, matching: find.byType(BarChart)),
          )
          .data
          .barGroups
          .single
          .barRods,
      hasLength(1),
    );

    final cashflowForm = find.byKey(const ValueKey('statistics-cashflow-form'));
    expect(cashflowForm, findsOneWidget);
    expect(
      find.descendant(of: cashflowForm, matching: find.text('柱状')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: cashflowForm, matching: find.text('曲线')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: cashflowChart, matching: find.byType(LineChart)),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('横屏查看收支统计'));
    await tester.pumpAndSettle();
    expect(find.text('收支统计'), findsNothing);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('分类构成'),
      200,
      scrollable: _verticalScrollable().last,
    );
    expect(find.byType(PieChart), findsNWidgets(2));
    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(find.text('总支出'), findsOneWidget);
    expect(find.text('标签命中'), findsOneWidget);
    expect(find.text('100.0%'), findsNWidgets(2));

    await tester.scrollUntilVisible(
      find.text('支出习惯'),
      200,
      scrollable: _verticalScrollable().last,
    );
    expect(find.byType(StatisticsWeekdayChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分类构成'),
      -200,
      scrollable: _verticalScrollable().last,
    );

    final categoryKindIncome = find.descendant(
      of: find.byKey(const ValueKey('statistics-category-kind')),
      matching: find.text('收入'),
    );
    await tester.ensureVisible(categoryKindIncome);
    await tester.pumpAndSettle();
    await tester.tap(categoryKindIncome);
    await tester.pump();
    expect(find.text('总收入'), findsOneWidget);
    expect(find.text('工资'), findsOneWidget);

    final categoryList = find.byKey(
      const ValueKey('statistics-category-composition-list'),
    );
    final salary = find.descendant(of: categoryList, matching: find.text('工资'));
    await tester.scrollUntilVisible(
      salary,
      100,
      scrollable: _verticalScrollable().last,
    );
    await tester.tap(salary);
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
  });
}

Finder _verticalScrollable() => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable &&
      axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
);

Future<void> _pumpStatisticsPage(
  WidgetTester tester, {
  StatisticsContentLoaded? content,
  StatisticsStatePresentation? statePresentation,
  StatisticsInstallmentsPresentation? installmentsPresentation,
  TextScaler? textScaler,
}) async {
  final month = DateTime(2026, 1);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_TestAppSettingsStore()),
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 1, 15)),
        statisticsRangeContentProvider(
          month,
          DateTime(2026, 1, 16),
          1,
        ).overrideWith((ref) {
          if (content != null) return content;
          final comparisonMode = ref.watch(
            statisticsViewModelProvider.select((value) => value.comparisonMode),
          );
          return _loadedContent(
            includeComparison: comparisonMode != StatisticsComparisonMode.none,
          );
        }),
        statisticsRangeContentProvider(
          DateTime(2025, 12, 10),
          DateTime(2025, 12, 13),
          1,
        ).overrideWith((ref) {
          if (content != null) return content;
          final comparisonMode = ref.watch(
            statisticsViewModelProvider.select((value) => value.comparisonMode),
          );
          return _loadedContent(
            includeComparison: comparisonMode != StatisticsComparisonMode.none,
          );
        }),
        statisticsStateContentProvider(DateTime(2026, 1, 15)).overrideWith(
          (ref) => StatisticsStateContentState.loaded(
            presentation: statePresentation ?? _statePresentation(),
          ),
        ),
        statisticsInstallmentsProvider(DateTime(2026, 1, 15)).overrideWith(
          (ref) => Stream.value(
            installmentsPresentation ?? _installmentsPresentation(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const StatisticsPage(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpStatisticsRouter(WidgetTester tester) async {
  final content = _loadedContent();
  appRouter.go('/statistics');
  addTearDown(() => appRouter.go('/'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWithValue(_TestAppSettingsStore()),
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 1, 15)),
        statisticsRangeContentProvider(
          DateTime(2026, 1),
          DateTime(2026, 1, 16),
          1,
        ).overrideWith((ref) => content),
        statisticsRangeContentProvider(
          DateTime(2025, 12, 10),
          DateTime(2025, 12, 13),
          1,
        ).overrideWith((ref) => content),
        statisticsStateContentProvider(DateTime(2026, 1, 15)).overrideWith(
          (ref) => StatisticsStateContentState.loaded(
            presentation: _statePresentation(),
          ),
        ),
        statisticsInstallmentsProvider(
          DateTime(2026, 1, 15),
        ).overrideWith((ref) => Stream.value(_installmentsPresentation())),
        statisticsTransactionsContentProvider(
          category: CategorySelection.withDescendants('base-salary'),
          settlementAccountId: null,
          tagId: null,
          untaggedOnly: false,
          occurredFrom: DateTime(2026, 1),
          occurredUntil: DateTime(2026, 1, 16),
          scope: StatisticsDrilldownScope.cashflow,
          accountType: null,
        ).overrideWith(
          (ref) => const StatisticsTransactionsContentState.loaded(groups: []),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: appRouter,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSalaryCategoryDetail(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('分类构成'),
    200,
    scrollable: _verticalScrollable().last,
  );
  final incomeSegment = find.descendant(
    of: find.byKey(const ValueKey('statistics-category-kind')),
    matching: find.text('收入'),
  );
  await tester.ensureVisible(incomeSegment);
  await tester.tap(incomeSegment);
  await tester.pumpAndSettle();

  final categoryList = find.byKey(
    const ValueKey('statistics-category-composition-list'),
  );
  final salary = find.descendant(of: categoryList, matching: find.text('工资'));
  await tester.scrollUntilVisible(
    salary,
    100,
    scrollable: _verticalScrollable().last,
  );
  await tester.tap(salary);
  await tester.pumpAndSettle();
}

Future<void> _openSalaryTransactions(WidgetTester tester) async {
  final secondaryList = find.byKey(
    const ValueKey('statistics-secondary-category-composition-list'),
  );
  final baseSalary = find.descendant(
    of: secondaryList,
    matching: find.text('基本工资'),
  );
  await tester.ensureVisible(baseSalary);
  await tester.tap(baseSalary);
  await tester.pumpAndSettle();
}

Future<void> _sendPredictiveBackGesture(WidgetTester tester) async {
  for (final call in const [
    MethodCall('startBackGesture', <String, dynamic>{
      'touchOffset': <double>[5, 300],
      'progress': 0.0,
      'swipeEdge': 0,
    }),
    MethodCall('updateBackGestureProgress', <String, dynamic>{
      'x': 100.0,
      'y': 300.0,
      'progress': 0.35,
      'swipeEdge': 0,
    }),
    MethodCall('commitBackGesture'),
  ]) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

class _TestAppSettingsStore implements AppSettingsStore {
  AppSettings settings = const AppSettings();

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}

StatisticsContentLoaded _loadedContent({
  List<DailyCashflowSummary>? dailySummaries,
  bool includeComparison = true,
}) {
  final values =
      dailySummaries ??
      [
        DailyCashflowSummary(
          date: DateTime(2026, 1, 5),
          income: const Money(minorUnits: 2000),
          expense: const Money(minorUnits: 700),
        ),
      ];
  final cashflow = StatisticsCashflowTrendPresentation(
    from: DateTime(2026, 1),
    until: DateTime(2026, 1, 16),
    dailySummaries: values,
  );
  final comparison = includeComparison
      ? StatisticsComparisonPresentation(
          label: '环比',
          from: DateTime(2025, 12),
          until: DateTime(2025, 12, 16),
          cashflow: const CashflowSummary(
            income: Money(minorUnits: 1000),
            expense: Money(minorUnits: 400),
          ),
          dailySummaries: [
            DailyCashflowSummary(
              date: DateTime(2025, 12, 5),
              income: const Money(minorUnits: 1000),
              expense: const Money(minorUnits: 400),
            ),
          ],
        )
      : null;
  return StatisticsContentLoaded(
    overview: StatisticsOverviewPresentation(
      cashflowComparison: const CashflowComparison(
        current: CashflowSummary(
          income: Money(minorUnits: 2000),
          expense: Money(minorUnits: 700),
        ),
        previousSamePeriod: CashflowSummary(
          income: Money(minorUnits: 1000),
          expense: Money(minorUnits: 400),
        ),
        previousFullPeriod: CashflowSummary(
          income: Money(minorUnits: 1000),
          expense: Money(minorUnits: 400),
        ),
      ),
      kpis: buildStatisticsCashflowKpis(values),
    ),
    comparison: comparison,
    cashflow: cashflow,
    categories: StatisticsCategoryAnalysisPresentation(
      from: DateTime(2026, 1),
      until: DateTime(2026, 1, 16),
      comparisonLabel: includeComparison ? '环比' : null,
      incomeCategories: [
        StatisticsBreakdownItem(
          id: 'salary',
          title: '工资',
          accountType: AccountType.income,
          amount: Money(minorUnits: 2000),
          progress: 1,
          comparisonAmount: Money(minorUnits: 1000),
          children: [
            StatisticsBreakdownItem(
              id: 'base-salary',
              title: '基本工资',
              accountType: AccountType.income,
              amount: Money(minorUnits: 2000),
              progress: 1,
              comparisonAmount: Money(minorUnits: 1000),
            ),
          ],
        ),
      ],
      expenseCategories: [
        StatisticsBreakdownItem(
          id: 'food',
          title: '餐饮',
          accountType: AccountType.expense,
          amount: Money(minorUnits: 700),
          progress: 1,
          comparisonAmount: Money(minorUnits: 400),
        ),
      ],
    ),
    tags: StatisticsTagAnalysisPresentation(
      from: DateTime(2026, 1),
      until: DateTime(2026, 1, 16),
      comparisonLabel: includeComparison ? '环比' : null,
      incomeTags: [
        StatisticsBreakdownItem(
          id: 'work',
          title: '工作',
          accountType: AccountType.income,
          amount: Money(minorUnits: 2000),
          progress: 1,
          comparisonAmount: Money(minorUnits: 1000),
        ),
      ],
      expenseTags: [
        StatisticsBreakdownItem(
          id: 'trip',
          title: '旅行',
          accountType: AccountType.expense,
          amount: Money(minorUnits: 700),
          progress: 1,
          comparisonAmount: Money(minorUnits: 200),
        ),
      ],
    ),
    balance: StatisticsBalanceTrendPresentation(
      points: [
        BalanceTrendPoint(
          date: DateTime(2026, 1),
          assets: const Money(minorUnits: 10000),
          liabilities: const Money(minorUnits: 2000),
        ),
        BalanceTrendPoint(
          date: DateTime(2026, 1, 15),
          assets: const Money(minorUnits: 11500),
          liabilities: const Money(minorUnits: 2500),
        ),
      ],
    ),
  );
}

StatisticsContentLoaded _longBreakdownContent() {
  final base = _loadedContent();
  final expenseCategories = [
    for (var index = 0; index < 6; index++)
      StatisticsBreakdownItem(
        id: 'expense-$index',
        title: '分类 ${index + 1}',
        accountType: AccountType.expense,
        amount: Money(minorUnits: 600 - index * 50),
        progress: 1 - index * .1,
        comparisonAmount: Money(minorUnits: 300 - index * 20),
      ),
  ];
  final expenseTags = [
    for (var index = 0; index < 6; index++)
      StatisticsBreakdownItem(
        id: 'tag-$index',
        title: '标签 ${index + 1}',
        accountType: AccountType.expense,
        amount: Money(minorUnits: 600 - index * 50),
        progress: 1 - index * .1,
        comparisonAmount: Money(minorUnits: 300 - index * 20),
      ),
  ];
  return StatisticsContentLoaded(
    overview: base.overview,
    comparison: base.comparison,
    cashflow: base.cashflow,
    categories: StatisticsCategoryAnalysisPresentation(
      from: DateTime(2026, 1),
      until: DateTime(2026, 1, 16),
      comparisonLabel: '环比',
      incomeCategories: base.categories.incomeCategories,
      expenseCategories: expenseCategories,
    ),
    tags: StatisticsTagAnalysisPresentation(
      from: DateTime(2026, 1),
      until: DateTime(2026, 1, 16),
      comparisonLabel: '环比',
      incomeTags: base.tags.incomeTags,
      expenseTags: expenseTags,
    ),
    balance: base.balance,
  );
}

StatisticsStatePresentation _statePresentation() {
  return StatisticsStatePresentation(
    asOf: DateTime(2026, 1, 15),
    totalAssets: const Money(minorUnits: 10000),
    totalLiabilities: const Money(minorUnits: 2000),
    assetAccounts: const [
      StatisticsBreakdownItem(
        id: 'cash',
        title: '现金',
        accountType: AccountType.asset,
        amount: Money(minorUnits: 10000),
        progress: 1,
      ),
    ],
    liabilityAccounts: const [
      StatisticsBreakdownItem(
        id: 'card',
        title: '信用卡',
        accountType: AccountType.liability,
        amount: Money(minorUnits: 2000),
        progress: 1,
      ),
    ],
  );
}

StatisticsStatePresentation _longStatePresentation() {
  final assetAccounts = [
    for (var index = 0; index < 6; index++)
      StatisticsBreakdownItem(
        id: 'asset-$index',
        title: '资产账户 ${index + 1}',
        accountType: AccountType.asset,
        amount: Money(minorUnits: 6000 - index * 500),
        progress: 1 - index * .1,
      ),
  ];
  final liabilityAccounts = [
    for (var index = 0; index < 6; index++)
      StatisticsBreakdownItem(
        id: 'liability-$index',
        title: '负债账户 ${index + 1}',
        accountType: AccountType.liability,
        amount: Money(minorUnits: 3000 - index * 250),
        progress: 1 - index * .1,
      ),
  ];
  return StatisticsStatePresentation(
    asOf: DateTime(2026, 1, 15),
    totalAssets: Money(
      minorUnits: assetAccounts.fold(
        0,
        (sum, item) => sum + item.amount.minorUnits,
      ),
    ),
    totalLiabilities: Money(
      minorUnits: liabilityAccounts.fold(
        0,
        (sum, item) => sum + item.amount.minorUnits,
      ),
    ),
    assetAccounts: assetAccounts,
    liabilityAccounts: liabilityAccounts,
  );
}

StatisticsInstallmentsPresentation _installmentsPresentation({
  bool withOverflow = false,
}) {
  final compositionItems = [
    StatisticsInstallmentCompositionItem(
      contractId: 'vehicle',
      contractName: '车辆分期',
      accountName: '贷款账户',
      remainingPrincipal: const Money(minorUnits: 1800000),
      remainingInterest: const Money(minorUnits: 90000),
      remainingTotal: const Money(minorUnits: 1890000),
      xirr: .18,
    ),
    StatisticsInstallmentCompositionItem(
      contractId: 'consumer',
      contractName: '消费贷',
      accountName: '借呗',
      remainingPrincipal: const Money(minorUnits: 1200000),
      remainingInterest: const Money(minorUnits: 220000),
      remainingTotal: const Money(minorUnits: 1420000),
      xirr: .12,
    ),
    StatisticsInstallmentCompositionItem(
      contractId: 'bill',
      contractName: '账单分期',
      accountName: '信用卡',
      remainingPrincipal: const Money(minorUnits: 800000),
      remainingInterest: const Money(minorUnits: 120000),
      remainingTotal: const Money(minorUnits: 920000),
      xirr: .08,
    ),
    StatisticsInstallmentCompositionItem(
      contractId: 'installment-card',
      contractName: '分期卡',
      accountName: '信用卡',
      remainingPrincipal: const Money(minorUnits: 600000),
      remainingInterest: const Money(minorUnits: 360000),
      remainingTotal: const Money(minorUnits: 960000),
      xirr: .04,
    ),
    if (withOverflow) ...[
      StatisticsInstallmentCompositionItem(
        contractId: 'backup-a',
        contractName: '临时分期',
        accountName: '储蓄卡',
        remainingPrincipal: const Money(minorUnits: 500000),
        remainingInterest: const Money(minorUnits: 100000),
        remainingTotal: const Money(minorUnits: 600000),
        xirr: .03,
      ),
      StatisticsInstallmentCompositionItem(
        contractId: 'backup-b',
        contractName: '备用分期',
        accountName: '储蓄卡',
        remainingPrincipal: const Money(minorUnits: 400000),
        remainingInterest: const Money(minorUnits: 80000),
        remainingTotal: const Money(minorUnits: 480000),
        xirr: .02,
      ),
    ],
  ];
  return StatisticsInstallmentsPresentation(
    asOf: DateTime(2026, 1, 15),
    compositionItems: compositionItems,
    remainingPrincipal: Money(
      minorUnits: compositionItems.fold(
        0,
        (sum, item) => sum + item.remainingPrincipal.minorUnits,
      ),
    ),
    remainingInterest: Money(
      minorUnits: compositionItems.fold(
        0,
        (sum, item) => sum + item.remainingInterest.minorUnits,
      ),
    ),
    remainingTotal: Money(
      minorUnits: compositionItems.fold(
        0,
        (sum, item) => sum + item.remainingTotal.minorUnits,
      ),
    ),
    cashflowMonths: [
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 1),
        principal: const Money(minorUnits: 500000),
        interest: const Money(minorUnits: 60000),
        fee: const Money(minorUnits: 0),
        total: const Money(minorUnits: 560000),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 2),
        principal: const Money(minorUnits: 520000),
        interest: const Money(minorUnits: 58000),
        fee: const Money(minorUnits: 2000),
        total: const Money(minorUnits: 580000),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 3),
        principal: const Money(minorUnits: 540000),
        interest: const Money(minorUnits: 56000),
        fee: const Money(minorUnits: 0),
        total: const Money(minorUnits: 596000),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 4),
        principal: const Money(minorUnits: 560000),
        interest: const Money(minorUnits: 54000),
        fee: const Money(minorUnits: 0),
        total: const Money(minorUnits: 614000),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 5),
        principal: const Money(minorUnits: 580000),
        interest: const Money(minorUnits: 52000),
        fee: const Money(minorUnits: 0),
        total: const Money(minorUnits: 632000),
      ),
    ],
    overdueTotal: const Money(minorUnits: 30000),
  );
}
