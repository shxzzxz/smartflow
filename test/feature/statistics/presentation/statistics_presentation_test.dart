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
        balanceTrend: const [],
      ),
      accountsById: const {},
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

    expect(buckets.map((item) => item.label), ['1', '2']);
    expect(buckets.first.netMinor, 0);
    expect(buckets.last.netMinor, 1300);
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

    expect(buckets.map((item) => item.label), ['1', '2']);
    expect(buckets.first.incomeMinor, 1500);
    expect(buckets.first.expenseMinor, 500);
    expect(buckets.last.netMinor, 700);
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

    expect(buckets.map((item) => item.label), ['1', '8']);
    expect(buckets.first.netMinor, 700);
    expect(buckets.last.netMinor, 150);
  });

  test('clamps the final weekly label to the selected range', () {
    final buckets = buildStatisticsCashflowBuckets(
      [
        DailyCashflowSummary(
          date: DateTime(2026, 1, 8),
          income: const Money(minorUnits: 200),
          expense: const Money(minorUnits: 50),
        ),
      ],
      grouping: StatisticsTimeGrouping.week,
      until: DateTime(2026, 1, 10),
    );

    expect(buckets.single.label, '8');
  });

  test('keeps multi-year monthly bucket labels numeric', () {
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

    expect(buckets.map((item) => item.label), ['12', '1']);
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

    expect(buckets.map((item) => item.label), ['1', '2']);
    expect(buckets.first.assets.minorUnits, 1500);
    expect(buckets.first.liabilities.minorUnits, 300);
    expect(buckets.last.netAssets.minorUnits, 800);
  });

  test('provides display copy for statistics controls', () {
    expect(StatisticsTimeGrouping.day.description, contains('按日'));
    expect(
      statisticsCategoryLevelLabel(StatisticsCategoryLevel.secondary),
      '二级',
    );
    expect(statisticsValueModeLabel(StatisticsValueMode.percentage), '占比');
  });

  test('selects secondary categories and calculates their share', () {
    const food = StatisticsBreakdownItem(
      id: 'food',
      title: '餐饮',
      accountIds: {'dining', 'snack'},
      accountType: AccountType.expense,
      amount: Money(minorUnits: 1000),
      progress: 1,
      children: [
        StatisticsBreakdownItem(
          id: 'dining',
          title: '聚餐',
          accountIds: {'dining'},
          accountType: AccountType.expense,
          amount: Money(minorUnits: 750),
          progress: 1,
        ),
        StatisticsBreakdownItem(
          id: 'snack',
          title: '零食',
          accountIds: {'snack'},
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
      accountIds: {'refund'},
      accountType: AccountType.expense,
      amount: Money(minorUnits: -200),
      progress: 0,
    );
    const food = StatisticsBreakdownItem(
      id: 'food',
      title: '餐饮',
      accountIds: {'food'},
      accountType: AccountType.expense,
      amount: Money(minorUnits: 800),
      progress: 1,
    );

    expect(statisticsCategoryMagnitude(refunded), 0);
    expect(statisticsCategoryShare(refunded, [refunded, food]), 0);
    expect(statisticsCategoryShare(food, [refunded, food]), 1);
  });
}
