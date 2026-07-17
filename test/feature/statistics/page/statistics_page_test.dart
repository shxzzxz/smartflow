import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/statistics/page/statistics_page.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_view_model.dart';

void main() {
  testWidgets('shows market-level charts and switches analysis dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
            (ref) =>
                StatisticsContentState.loaded(presentation: _presentation()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const StatisticsPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('月'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    expect(find.text('自定义'), findsOneWidget);
    expect(find.text('收支统计'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分类占比'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('一级'), findsOneWidget);
    expect(find.text('二级'), findsOneWidget);
    expect(find.text('金额'), findsOneWidget);
    expect(find.text('占比'), findsOneWidget);

    final categoryKindControl = find.byType(
      SegmentedButton<StatisticsCategoryKind>,
    );
    await tester.scrollUntilVisible(
      categoryKindControl,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.descendant(of: categoryKindControl, matching: find.text('收入')),
    );
    await tester.pump();
    expect(find.text('工资'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('工资'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('工资'));
    await tester.pumpAndSettle();
    expect(find.byType(PieChart), findsOneWidget);
  });
}

StatisticsPresentation _presentation() {
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
    dailySummaries: [
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
        accountIds: {'salary'},
        accountType: AccountType.income,
        amount: Money(minorUnits: 2000),
        progress: 1,
      ),
    ],
    expenseCategories: const [
      StatisticsBreakdownItem(
        id: 'food',
        title: '餐饮',
        accountIds: {'dining'},
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
        accountIds: {'cash'},
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
        balance: const Money(minorUnits: 8000),
      ),
      BalanceTrendPoint(
        date: DateTime(2026, 1, 15),
        balance: const Money(minorUnits: 9000),
      ),
    ],
  );
}
