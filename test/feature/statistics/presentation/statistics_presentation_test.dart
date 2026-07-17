import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';

void main() {
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
    expect(buckets.first.netMinor, 0);
    expect(buckets.last.netMinor, 1300);
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
