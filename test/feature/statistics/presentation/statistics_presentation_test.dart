import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';

void main() {
  test('fills missing cashflow dates for a statistics range', () {
    final presentation = buildRangeStatisticsPresentation(
      report: StatisticsRangeReport(
        from: DateTime(2026, 1, 1),
        until: DateTime(2026, 1, 4),
        cashflow: const CashflowSummary(
          income: Money(minorUnits: 2000),
          expense: Money(minorUnits: 700),
        ),
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 2),
            income: const Money(minorUnits: 2000),
            expense: const Money(minorUnits: 700),
          ),
        ],
        categories: const [],
        tags: const [],
        balanceTrend: const [],
      ),
    );

    expect(presentation.dailySummaries.map((item) => item.date), [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 3),
    ]);
    expect(presentation.dailySummaries.first.net.minorUnits, 0);
    expect(presentation.dailySummaries[1].net.minorUnits, 1300);
    expect(presentation.dailySummaries.last.net.minorUnits, 0);
  });

  test('fills missing cashflow dates for monthly statistics', () {
    final presentation = buildStatisticsPresentation(
      cashflow: CashflowReport(
        comparison: const CashflowComparison(
          current: CashflowSummary(
            income: Money(minorUnits: 2000),
            expense: Money(minorUnits: 700),
          ),
          previousSamePeriod: CashflowSummary(
            income: Money(minorUnits: 0),
            expense: Money(minorUnits: 0),
          ),
          previousFullPeriod: CashflowSummary(
            income: Money(minorUnits: 0),
            expense: Money(minorUnits: 0),
          ),
        ),
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 1, 2),
            income: const Money(minorUnits: 2000),
            expense: const Money(minorUnits: 700),
          ),
        ],
        categories: const [],
      ),
      balance: const BalanceReport(
        comparison: BalanceSheetComparison(
          current: BalanceSheetSnapshot(
            assets: Money(minorUnits: 0),
            liabilities: Money(minorUnits: 0),
          ),
          previous: BalanceSheetSnapshot(
            assets: Money(minorUnits: 0),
            liabilities: Money(minorUnits: 0),
          ),
        ),
        trend: [],
        accounts: [],
      ),
      accountsById: const {},
      cashflowFrom: DateTime(2026, 1, 1),
      cashflowUntil: DateTime(2026, 1, 4),
      balanceUntil: DateTime(2026, 1, 4),
    );

    expect(presentation.dailySummaries.map((item) => item.date), [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 2),
      DateTime(2026, 1, 3),
    ]);
  });

  test('keeps zero-value dates in daily cashflow chart buckets', () {
    final buckets = buildStatisticsCashflowBuckets([
      DailyCashflowSummary(
        date: DateTime(2026, 1, 1),
        income: const Money(minorUnits: 0),
        expense: const Money(minorUnits: 0),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 2),
        income: const Money(minorUnits: 2000),
        expense: const Money(minorUnits: 700),
      ),
    ]);

    expect(buckets.map((item) => item.label), ['1/1', '1/2']);
    expect(buckets.first.incomeMinor, 0);
    expect(buckets.first.expenseMinor, 0);
    expect(buckets.last.incomeMinor, 2000);
    expect(buckets.last.expenseMinor, 700);
  });

  test('groups daily cashflow into calendar months for year charts', () {
    final buckets = buildStatisticsCashflowBuckets([
      DailyCashflowSummary(
        date: DateTime(2026, 1, 1),
        income: const Money(minorUnits: 1000),
        expense: const Money(minorUnits: 200),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 31),
        income: const Money(minorUnits: 500),
        expense: const Money(minorUnits: 300),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 2, 1),
        income: const Money(minorUnits: 800),
        expense: const Money(minorUnits: 100),
      ),
    ], grouping: StatisticsTimeGrouping.month);

    expect(buckets.map((item) => item.label), ['1月', '2月']);
    expect(buckets.first.incomeMinor, 1500);
    expect(buckets.first.expenseMinor, 500);
    expect(buckets.last.incomeMinor, 800);
    expect(buckets.last.expenseMinor, 100);
  });

  test('groups custom-range cashflow into seven-day buckets', () {
    final buckets = buildStatisticsCashflowBuckets([
      DailyCashflowSummary(
        date: DateTime(2026, 1, 1),
        income: const Money(minorUnits: 1000),
        expense: const Money(minorUnits: 0),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 7),
        income: const Money(minorUnits: 0),
        expense: const Money(minorUnits: 300),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 8),
        income: const Money(minorUnits: 200),
        expense: const Money(minorUnits: 50),
      ),
    ], grouping: StatisticsTimeGrouping.week);

    expect(buckets.map((item) => item.label), ['1/1', '1/8']);
    expect(buckets.first.incomeMinor, 1000);
    expect(buckets.first.expenseMinor, 300);
    expect(buckets.last.incomeMinor, 200);
    expect(buckets.last.expenseMinor, 50);
  });

  test('scopes weekly axis labels with their month', () {
    final buckets = buildStatisticsCashflowBuckets([
      DailyCashflowSummary(
        date: DateTime(2026, 1, 8),
        income: const Money(minorUnits: 200),
        expense: const Money(minorUnits: 50),
      ),
    ], grouping: StatisticsTimeGrouping.week);

    expect(buckets.single.label, '1/8');
  });

  test('labels monthly buckets across a year boundary', () {
    final buckets = buildStatisticsCashflowBuckets([
      DailyCashflowSummary(
        date: DateTime(2025, 12, 31),
        income: const Money(minorUnits: 100),
        expense: const Money(minorUnits: 0),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 1),
        income: const Money(minorUnits: 200),
        expense: const Money(minorUnits: 0),
      ),
    ], grouping: StatisticsTimeGrouping.month);

    expect(buckets.map((item) => item.label), ['12月', '1月']);
  });

  test('maps exclusive balance snapshots to their natural month end', () {
    final buckets = buildStatisticsBalanceTrendBuckets([
      BalanceTrendPoint(
        date: DateTime(2026, 1, 1),
        assets: const Money(minorUnits: 1000),
        liabilities: const Money(minorUnits: 200),
      ),
      BalanceTrendPoint(
        date: DateTime(2026, 1, 2),
        assets: const Money(minorUnits: 1100),
        liabilities: const Money(minorUnits: 200),
      ),
      BalanceTrendPoint(
        date: DateTime(2026, 2, 1),
        assets: const Money(minorUnits: 1500),
        liabilities: const Money(minorUnits: 300),
      ),
      BalanceTrendPoint(
        date: DateTime(2026, 3, 1),
        assets: const Money(minorUnits: 1200),
        liabilities: const Money(minorUnits: 400),
      ),
    ], grouping: StatisticsTimeGrouping.month);

    expect(buckets.map((item) => item.label), ['1月', '2月']);
    expect(buckets.first.assets.minorUnits, 1500);
    expect(buckets.first.liabilities.minorUnits, 300);
    expect(buckets.last.netAssets.minorUnits, 800);
  });

  test('provides display copy for statistics controls', () {
    expect(StatisticsTimeGrouping.day.description, contains('按日'));
  });

  test('selects secondary categories and calculates their share', () {
    const food = StatisticsBreakdownItem(
      id: 'food',
      title: '餐饮',
      accountType: AccountType.expense,
      amount: Money(minorUnits: 1000),
      progress: 1,
      children: [
        StatisticsBreakdownItem(
          id: 'dining',
          title: '聚餐',
          accountType: AccountType.expense,
          amount: Money(minorUnits: 750),
          progress: 1,
        ),
        StatisticsBreakdownItem(
          id: 'snack',
          title: '零食',
          accountType: AccountType.expense,
          amount: Money(minorUnits: 250),
          progress: .33,
        ),
      ],
    );

    final items = selectStatisticsCategoryItems([food], secondary: true);

    expect(items.map((item) => item.title), ['聚餐', '零食']);
    expect(statisticsCategoryShare(items.first, items), .75);
  });

  test('does not turn a net-negative refunded category into spending', () {
    const refunded = StatisticsBreakdownItem(
      id: 'refund',
      title: '退款后分类',
      accountType: AccountType.expense,
      amount: Money(minorUnits: -200),
      progress: 0,
    );
    const food = StatisticsBreakdownItem(
      id: 'food',
      title: '餐饮',
      accountType: AccountType.expense,
      amount: Money(minorUnits: 800),
      progress: 1,
    );

    expect(statisticsCategoryMagnitude(refunded), 0);
    expect(statisticsCategoryShare(refunded, [refunded, food]), 0);
    expect(statisticsCategoryShare(food, [refunded, food]), 1);
  });

  test('renormalizes secondary category progress across parents', () {
    StatisticsBreakdownItem parent(
      String id,
      List<StatisticsBreakdownItem> children,
    ) {
      return StatisticsBreakdownItem(
        id: id,
        title: id,
        accountType: AccountType.expense,
        amount: Money(
          minorUnits: children.fold(0, (sum, c) => sum + c.amount.minorUnits),
        ),
        progress: 1,
        children: children,
      );
    }

    StatisticsBreakdownItem child(String id, int minor, double progress) {
      return StatisticsBreakdownItem(
        id: id,
        title: id,
        accountType: AccountType.expense,
        amount: Money(minorUnits: minor),
        progress: progress,
      );
    }

    final items = selectStatisticsCategoryItems([
      // 各父分类内 progress 均以本组最大值归一，混排后需要重算。
      parent('food', [child('dining', 400, 1)]),
      parent('travel', [child('flight', 800, 1), child('hotel', 200, .25)]),
    ], secondary: true);

    expect(items.map((item) => item.id), ['flight', 'dining', 'hotel']);
    expect(items.map((item) => item.progress), [1, .5, .25]);
  });

  test('folds categories beyond the series slot cap into an other slice', () {
    final items = [
      for (var i = 0; i < 10; i++)
        StatisticsBreakdownItem(
          id: 'c$i',
          title: '分类$i',
          accountType: AccountType.expense,
          amount: Money(minorUnits: 1000 - i * 10),
          progress: 0,
        ),
    ];

    final slices = buildStatisticsDonutSlices(items);

    expect(slices.length, statisticsSeriesSlotCount);
    expect(slices.take(7).map((slice) => slice.isOther), everyElement(false));
    expect(slices.last.isOther, isTrue);
    expect(slices.last.title, '其他');
    expect(slices.last.valueMinor, 930 + 920 + 910);
  });

  test('keeps donut slices unfolded at or below the slot cap', () {
    final items = [
      for (var i = 0; i < statisticsSeriesSlotCount; i++)
        StatisticsBreakdownItem(
          id: 'c$i',
          title: '分类$i',
          accountType: AccountType.expense,
          amount: Money(minorUnits: 100),
          progress: 0,
        ),
    ];

    final slices = buildStatisticsDonutSlices(items);

    expect(slices.length, statisticsSeriesSlotCount);
    expect(slices.map((slice) => slice.isOther), everyElement(false));
  });

  test('derives cashflow kpis from daily summaries', () {
    final kpis = buildStatisticsCashflowKpis([
      DailyCashflowSummary(
        date: DateTime(2026, 1, 1),
        income: const Money(minorUnits: 3000),
        expense: const Money(minorUnits: 1000),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 2),
        income: const Money(minorUnits: 0),
        expense: const Money(minorUnits: 500),
      ),
    ]);

    expect(kpis.dailyAverageExpense.minorUnits, 750);
    expect(kpis.dailyAverageIncome.minorUnits, 1500);
    expect(kpis.maxDailyExpense.minorUnits, 1000);
  });

  test('averages weekday expense by weekday occurrences', () {
    // 2026-01-05 与 2026-01-12 都是周一，2026-01-06 是周二。
    final buckets = buildStatisticsWeekdayExpenseBuckets([
      DailyCashflowSummary(
        date: DateTime(2026, 1, 5),
        income: const Money(minorUnits: 0),
        expense: const Money(minorUnits: 1000),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 12),
        income: const Money(minorUnits: 0),
        expense: const Money(minorUnits: 500),
      ),
      DailyCashflowSummary(
        date: DateTime(2026, 1, 6),
        income: const Money(minorUnits: 0),
        expense: const Money(minorUnits: 300),
      ),
    ]);

    expect(buckets.length, 7);
    expect(buckets.first.label, '周一');
    expect(buckets.first.averageExpenseMinor, 750);
    expect(buckets[1].averageExpenseMinor, 300);
    expect(buckets.last.dayCount, 0);
    expect(buckets.last.averageExpenseMinor, 0);
  });
}
