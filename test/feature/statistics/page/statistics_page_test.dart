import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
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
import 'package:smartflow/widget/business/analytics/chart/app_cartesian_chart.dart';
import 'package:smartflow/widget/business/analytics/category_progress_list_item.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';

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
      findsNWidgets(3),
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
          .widget<MoneyText>(
            find.byKey(const ValueKey('statistics-installment-value-vehicle')),
          )
          .money
          .minorUnits,
      1800000,
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
          .widget<MoneyText>(
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
    expect(find.text('收支统计'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expands installment composition contracts', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStatisticsPage(tester);
    await tester.tap(find.text('当前状态'));
    await tester.pumpAndSettle();
    final compositionCard = find.byKey(
      const ValueKey('statistics-installment-composition-card'),
    );
    final expandButton = find.descendant(
      of: compositionCard,
      matching: find.text('查看全部 4 笔'),
    );
    await tester.ensureVisible(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('信用卡 · 分期卡'), findsNothing);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('信用卡 · 分期卡'), findsOneWidget);
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
    final categoryComparison = tester.getRect(find.text('环比增加 3'));
    expect(
      (categoryTitle.center.dy - categoryComparison.center.dy).abs(),
      lessThan(1),
    );
    expect(categoryComparison.left, greaterThan(categoryTitle.right));
    expect(tester.takeException(), isNull);
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
    await _pumpStatisticsPage(tester);

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

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('statistics-category-kind')),
        matching: find.text('收入'),
      ),
    );
    await tester.pump();
    expect(find.text('总收入'), findsOneWidget);
    expect(find.text('工资'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('工资'),
      100,
      scrollable: _verticalScrollable().last,
    );
    await tester.tap(find.text('工资'));
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
  TextScaler? textScaler,
}) async {
  final month = DateTime(2026, 1);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
            presentation: _statePresentation(),
          ),
        ),
        statisticsInstallmentsProvider(
          DateTime(2026, 1, 15),
        ).overrideWith((ref) async => _installmentsPresentation()),
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

StatisticsStatePresentation _statePresentation() {
  return StatisticsStatePresentation(
    asOf: DateTime(2026, 1, 15),
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

StatisticsInstallmentsPresentation _installmentsPresentation() {
  return StatisticsInstallmentsPresentation(
    asOf: DateTime(2026, 1, 15),
    compositionItems: [
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
    ],
    remainingPrincipal: const Money(minorUnits: 4400000),
    remainingInterest: const Money(minorUnits: 790000),
    remainingTotal: const Money(minorUnits: 5190000),
    cashflowMonths: [
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 1),
        principal: const Money(minorUnits: 500000),
        interest: const Money(minorUnits: 60000),
        fee: const Money(minorUnits: 0),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 2),
        principal: const Money(minorUnits: 520000),
        interest: const Money(minorUnits: 58000),
        fee: const Money(minorUnits: 2000),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 3),
        principal: const Money(minorUnits: 540000),
        interest: const Money(minorUnits: 56000),
        fee: const Money(minorUnits: 0),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 4),
        principal: const Money(minorUnits: 560000),
        interest: const Money(minorUnits: 54000),
        fee: const Money(minorUnits: 0),
      ),
      StatisticsInstallmentCashflowMonth(
        month: DateTime(2026, 5),
        principal: const Money(minorUnits: 580000),
        interest: const Money(minorUnits: 52000),
        fee: const Money(minorUnits: 0),
      ),
    ],
    overdueTotal: const Money(minorUnits: 30000),
  );
}
