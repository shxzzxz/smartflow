import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_date_picker_panel.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/statistics/page/statistics_page.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_view_model.dart';
import 'package:smartflow/feature/statistics/widget/statistics_charts.dart';
import 'package:smartflow/widget/business/analytics/chart/app_cartesian_chart.dart';

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
    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('按日汇总，点击柱形查看金额'), findsNothing);
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
      presentation: _presentation(
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

  testWidgets('keeps the category header compact with inline controls', (
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
    expect(kindControl, findsOneWidget);
    expect(levelControl, findsOneWidget);
    expect(tester.getRect(kindControl).right, lessThanOrEqualTo(360));
    expect(tester.getRect(levelControl).right, lessThanOrEqualTo(360));
    expect(find.text('主分类'), findsOneWidget);

    // 金额与占比同时展示，不再提供数值模式开关。
    expect(find.text('金额'), findsNothing);
    expect(find.text('占比'), findsNothing);
    expect(find.text('100.0%'), findsOneWidget);
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
    expect(find.text('2026.1.1 - 2026.1.31'), findsOneWidget);
    await tester.tap(find.text('2026.1.1 - 2026.1.31'));
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

    expect(find.text('2025.12.10 - 2025.12.12'), findsOneWidget);
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
    await tester.tap(find.text('2026.1.1 - 2026.1.31'));
    await tester.pumpAndSettle();
    expect(find.text('2026年'), findsOneWidget);
    await tester.tap(find.text('1月'));
    await tester.pumpAndSettle();
    expect(find.text('2026.1.1 - 2026.1.31'), findsOneWidget);

    await tester.tap(find.text('2026.1.1 - 2026.1.31'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();
    expect(find.text('2026.1.1 - 2026.12.31'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows market-level charts and switches analysis dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpStatisticsPage(tester);

    expect(find.text('2026.1.1 - 2026.1.31'), findsOneWidget);
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
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('主分类'), findsOneWidget);
    expect(find.text('子分类'), findsOneWidget);
    expect(find.text('总支出'), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);

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
  StatisticsPresentation? presentation,
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
        ).overrideWith(
          (ref) => StatisticsContentState.loaded(
            presentation: presentation ?? _presentation(),
          ),
        ),
        statisticsRangeContentProvider(
          DateTime(2025, 12, 10),
          DateTime(2025, 12, 13),
          1,
        ).overrideWith(
          (ref) => StatisticsContentState.loaded(
            presentation: presentation ?? _presentation(),
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder:
            textScaler == null
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

StatisticsPresentation _presentation({
  List<DailyCashflowSummary>? dailySummaries,
}) {
  return StatisticsPresentation(
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
    dailySummaries:
        dailySummaries ??
        [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 5),
            income: const Money(minorUnits: 2000),
            expense: const Money(minorUnits: 700),
          ),
        ],
    incomeCategories: const [
      StatisticsBreakdownItem(
        id: 'salary',
        title: '工资',
        accountType: AccountType.income,
        amount: Money(minorUnits: 2000),
        progress: 1,
        children: [
          StatisticsBreakdownItem(
            id: 'base-salary',
            title: '基本工资',
            accountType: AccountType.income,
            amount: Money(minorUnits: 2000),
            progress: 1,
          ),
        ],
      ),
    ],
    expenseCategories: const [
      StatisticsBreakdownItem(
        id: 'food',
        title: '餐饮',
        accountType: AccountType.expense,
        amount: Money(minorUnits: 700),
        progress: 1,
      ),
    ],
    balanceComparison: const BalanceSheetComparison(
      current: BalanceSheetSnapshot(
        assets: Money(minorUnits: 10000),
        liabilities: Money(minorUnits: 2000),
      ),
      previous: BalanceSheetSnapshot(
        assets: Money(minorUnits: 9000),
        liabilities: Money(minorUnits: 2000),
      ),
    ),
    netAssetTrend: const [],
    balanceAccounts: const [
      StatisticsBreakdownItem(
        id: 'cash',
        title: '现金',
        accountType: AccountType.asset,
        amount: Money(minorUnits: 10000),
        progress: 1,
      ),
    ],
    cashflowFrom: DateTime(2026, 1),
    cashflowUntil: DateTime(2026, 1, 16),
    balanceUntil: DateTime(2026, 1, 16),
    incomeChangeText: '较上月同期 +10.00',
    expenseChangeText: '较上月同期 +3.00',
    netAssetChangeText: '较上月 +10.00',
    rangeBalanceTrend: [
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
  );
}
