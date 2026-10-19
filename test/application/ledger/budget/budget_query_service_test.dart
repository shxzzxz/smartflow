import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/budget/query/budget_query_service.dart';
import 'package:smartflow/application/ledger/budget/query/port/budget_query_source.dart';
import 'package:smartflow/core/time/month_key.dart';

void main() {
  test('总预算与父子分类预算按各自范围统计使用量和趋势', () async {
    final month = MonthKey(year: 2026, month: 8);
    final service = BudgetQueryServiceImpl(
      _FixedBudgetQuerySource(
        BudgetQuerySnapshot(
          budgets: const [
            BudgetSettingRow(id: 'total', amountMinor: 200000, sortOrder: 0),
            BudgetSettingRow(
              id: 'food-budget',
              categoryId: 'food',
              amountMinor: 100000,
              sortOrder: 0,
            ),
            BudgetSettingRow(
              id: 'lunch-budget',
              categoryId: 'lunch',
              amountMinor: 50000,
              sortOrder: 1,
            ),
          ],
          categories: const [
            BudgetCategoryRow(id: 'food', name: '餐饮', sortOrder: 0),
            BudgetCategoryRow(
              id: 'lunch',
              name: '午餐',
              parentId: 'food',
              sortOrder: 0,
            ),
            BudgetCategoryRow(id: 'travel', name: '出行', sortOrder: 1),
          ],
          dailyUsage: [
            BudgetDailyUsageRow(
              date: DateTime(2026, 8, 1),
              categoryId: 'food',
              amountMinor: 10000,
            ),
            BudgetDailyUsageRow(
              date: DateTime(2026, 8, 2),
              categoryId: 'lunch',
              amountMinor: 20000,
            ),
            BudgetDailyUsageRow(
              date: DateTime(2026, 8, 2),
              categoryId: 'travel',
              amountMinor: 30000,
            ),
          ],
        ),
      ),
    );

    final report = await service.watchMonthlyReport(month).first;

    expect(report.totalBudget?.spent.minorUnits, 60000);
    expect(report.totalBudget?.remaining.minorUnits, 140000);
    expect(report.totalBudget?.trend.map((point) => point.spent.minorUnits), [
      10000,
      60000,
    ]);
    expect(report.categoryGroups, hasLength(1));
    final group = report.categoryGroups.single;
    expect(group.name, '餐饮');
    expect(group.rootBudget?.spent.minorUnits, 30000);
    expect(group.rootBudget?.remaining.minorUnits, 70000);
    expect(group.childBudgets.single.name, '午餐');
    expect(group.childBudgets.single.spent.minorUnits, 20000);
    expect(group.childBudgets.single.remaining.minorUnits, 30000);
  });

  test('分类预算分组按预算排序位置排列并保留父子相邻', () async {
    final month = MonthKey(year: 2026, month: 8);
    final service = BudgetQueryServiceImpl(
      _FixedBudgetQuerySource(
        const BudgetQuerySnapshot(
          budgets: [
            BudgetSettingRow(
              id: 'bus-budget',
              categoryId: 'bus',
              amountMinor: 10000,
              sortOrder: 0,
            ),
            BudgetSettingRow(
              id: 'food-budget',
              categoryId: 'food',
              amountMinor: 10000,
              sortOrder: 1,
            ),
            BudgetSettingRow(
              id: 'lunch-budget',
              categoryId: 'lunch',
              amountMinor: 10000,
              sortOrder: 2,
            ),
          ],
          categories: [
            BudgetCategoryRow(id: 'food', name: '餐饮', sortOrder: 0),
            BudgetCategoryRow(
              id: 'lunch',
              name: '午餐',
              parentId: 'food',
              sortOrder: 0,
            ),
            BudgetCategoryRow(id: 'travel', name: '出行', sortOrder: 1),
            BudgetCategoryRow(
              id: 'bus',
              name: '公交',
              parentId: 'travel',
              sortOrder: 0,
            ),
          ],
          dailyUsage: [],
        ),
      ),
    );

    final report = await service.watchMonthlyReport(month).first;

    expect(report.categoryGroups.map((group) => group.name), ['出行', '餐饮']);
    expect(report.categoryGroups.last.rootBudget?.id, 'food-budget');
    expect(report.categoryGroups.last.childBudgets.single.id, 'lunch-budget');
    expect(report.orderedCategoryBudgetIds, [
      'bus-budget',
      'food-budget',
      'lunch-budget',
    ]);
  });

  test('环比和同比趋势使用当前月预算作为剩余基线', () async {
    final month = MonthKey(year: 2026, month: 8);
    final service = BudgetQueryServiceImpl(
      _FixedBudgetQuerySource(
        BudgetQuerySnapshot(
          budgets: const [
            BudgetSettingRow(id: 'total', amountMinor: 100000, sortOrder: 0),
            BudgetSettingRow(
              id: 'food-budget',
              categoryId: 'food',
              amountMinor: 50000,
              sortOrder: 0,
            ),
            BudgetSettingRow(
              id: 'lunch-budget',
              categoryId: 'lunch',
              amountMinor: 20000,
              sortOrder: 1,
            ),
          ],
          categories: const [
            BudgetCategoryRow(id: 'food', name: '餐饮', sortOrder: 0),
            BudgetCategoryRow(
              id: 'lunch',
              name: '午餐',
              parentId: 'food',
              sortOrder: 0,
            ),
          ],
          dailyUsage: const [],
          previousMonthDailyUsage: [
            BudgetDailyUsageRow(
              date: DateTime(2026, 7, 1),
              categoryId: 'food',
              amountMinor: 10000,
            ),
            BudgetDailyUsageRow(
              date: DateTime(2026, 7, 2),
              categoryId: 'lunch',
              amountMinor: 20000,
            ),
            BudgetDailyUsageRow(
              date: DateTime(2026, 7, 3),
              categoryId: 'travel',
              amountMinor: 30000,
            ),
          ],
          previousYearDailyUsage: [
            BudgetDailyUsageRow(
              date: DateTime(2025, 8, 5),
              categoryId: 'food',
              amountMinor: 15000,
            ),
          ],
        ),
      ),
    );

    final report = await service.watchMonthlyReport(month).first;
    final total = report.totalBudget!;
    final food = report.categoryGroups.single.rootBudget!;
    final lunch = report.categoryGroups.single.childBudgets.single;

    expect(total.previousMonthTrend.map((point) => point.spent.minorUnits), [
      10000,
      30000,
      60000,
    ]);
    expect(
      total.previousMonthTrend.map((point) => point.remaining.minorUnits),
      [90000, 70000, 40000],
    );
    expect(total.previousYearTrend.single.spent.minorUnits, 15000);
    expect(total.previousYearTrend.single.remaining.minorUnits, 85000);
    expect(food.previousMonthTrend.last.spent.minorUnits, 30000);
    expect(food.previousMonthTrend.last.remaining.minorUnits, 20000);
    expect(lunch.previousMonthTrend.single.spent.minorUnits, 20000);
    expect(lunch.previousMonthTrend.single.remaining.minorUnits, 0);
  });
}

class _FixedBudgetQuerySource implements BudgetQuerySource {
  const _FixedBudgetQuerySource(this.snapshot);

  final BudgetQuerySnapshot snapshot;

  @override
  Stream<BudgetQuerySnapshot> watchMonth(MonthKey month) =>
      Stream.value(snapshot);
}
