import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/statistics/presentation/statistics_presentation.dart';
import 'package:smartflow/feature/statistics/view_model/statistics_view_model.dart';

void main() {
  test('defaults to the current month', () {
    final container = ProviderContainer(
      overrides: [
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 7, 18)),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(statisticsViewModelProvider);
    expect(state.visibleMonth, DateTime(2026, 7));
    expect(state.granularity, StatisticsPeriodGranularity.month);
    expect(state.mode, StatisticsPeriodMode.single);
    expect(state.periodFrom, DateTime(2026, 7));
    expect(state.periodUntil, DateTime(2026, 8));
    expect(state.chartMetric, CashflowChartMetric.expense);
    expect(state.chartForm, CashflowChartForm.bar);
  });

  test('switches month, year and custom statistic ranges', () {
    final container = ProviderContainer(
      overrides: [
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 7, 18)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(statisticsViewModelProvider.notifier);

    notifier.applyPeriodSelection(
      granularity: StatisticsPeriodGranularity.month,
      mode: StatisticsPeriodMode.single,
      from: DateTime(2026, 3),
      untilExclusive: DateTime(2026, 4),
    );
    expect(
      container.read(statisticsViewModelProvider).range(DateTime(2026, 7, 18)),
      isA<StatisticsDateRange>()
          .having((range) => range.from, 'from', DateTime(2026, 3))
          .having((range) => range.until, 'until', DateTime(2026, 4)),
    );
    expect(
      container.read(statisticsViewModelProvider).visibleMonth,
      DateTime(2026, 3),
    );

    notifier.applyPeriodSelection(
      granularity: StatisticsPeriodGranularity.year,
      mode: StatisticsPeriodMode.single,
      from: DateTime(2026),
      untilExclusive: DateTime(2027),
    );
    final year = container
        .read(statisticsViewModelProvider)
        .range(DateTime(2026, 7, 18));
    expect(year.from, DateTime(2026));
    expect(year.until, DateTime(2026, 7, 19));

    notifier.applyPeriodSelection(
      granularity: StatisticsPeriodGranularity.date,
      mode: StatisticsPeriodMode.range,
      from: DateTime(2026, 2, 3),
      untilExclusive: DateTime(2026, 2, 9),
    );
    final custom = container
        .read(statisticsViewModelProvider)
        .range(DateTime(2026, 7, 18));
    expect(custom.from, DateTime(2026, 2, 3));
    expect(custom.until, DateTime(2026, 2, 9));
  });

  test('chooses readable trend grouping for each period span', () {
    final month = _control(from: DateTime(2026, 1), until: DateTime(2026, 2));
    final year = _control(from: DateTime(2026, 1), until: DateTime(2027, 1));
    final mediumCustom = _control(
      from: DateTime(2026, 1, 1),
      until: DateTime(2026, 3, 2),
    );
    final longCustom = _control(
      from: DateTime(2026, 1, 1),
      until: DateTime(2026, 8, 1),
    );
    final multiYearCustom = _control(
      from: DateTime(2024, 1, 1),
      until: DateTime(2026, 8, 1),
    );

    expect(month.trendGrouping, StatisticsTimeGrouping.day);
    expect(year.trendGrouping, StatisticsTimeGrouping.month);
    expect(mediumCustom.trendGrouping, StatisticsTimeGrouping.week);
    expect(longCustom.trendGrouping, StatisticsTimeGrouping.month);
    expect(multiYearCustom.trendGrouping, StatisticsTimeGrouping.year);
    expect(year.range(DateTime(2026, 7, 18)).balancePointIntervalDays, 1);
    expect(
      mediumCustom.range(DateTime(2026, 7, 18)).balancePointIntervalDays,
      7,
    );
    expect(longCustom.range(DateTime(2026, 7, 18)).balancePointIntervalDays, 1);
    expect(
      multiYearCustom.range(DateTime(2026, 7, 18)).balancePointIntervalDays,
      30,
    );
  });

  test('combines reports into a category-rollup page state', () async {
    final visibleMonth = DateTime(2026, 1);
    final container = ProviderContainer(
      overrides: [
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 1, 15)),
        accountsByIdProvider.overrideWith(
          (ref) => Stream.value({
            'food': _account('food', '餐饮', AccountType.expense),
            'dining': _account(
              'dining',
              '聚餐',
              AccountType.expense,
              parentId: 'food',
            ),
            'salary': _account('salary', '工资', AccountType.income),
            'cash': _account('cash', '现金', AccountType.asset),
          }),
        ),
        statisticsCashflowReportProvider(
          visibleMonth,
        ).overrideWith((ref) => Stream.value(_cashflowReport())),
        statisticsBalanceReportProvider(
          visibleMonth,
        ).overrideWith((ref) => Stream.value(_balanceReport())),
      ],
    );
    addTearDown(container.dispose);

    final viewModelSub = container.listen(
      statisticsViewModelProvider,
      (_, _) {},
    );
    final contentSub = container.listen(
      statisticsContentProvider(visibleMonth),
      (_, _) {},
    );
    addTearDown(viewModelSub.close);
    addTearDown(contentSub.close);
    await container.read(statisticsCashflowReportProvider(visibleMonth).future);
    await container.read(statisticsBalanceReportProvider(visibleMonth).future);
    await container.read(accountsByIdProvider.future);
    await container.pump();

    final content = container.read(statisticsContentProvider(visibleMonth));
    expect(content, isA<StatisticsContentLoaded>());
    final loaded = content as StatisticsContentLoaded;
    expect(loaded.presentation.expenseCategories.single.title, '餐饮');
    expect(loaded.presentation.expenseCategories.single.amount.minorUnits, 700);
    expect(loaded.presentation.expenseCategories.single.accountIds, {'dining'});
    expect(loaded.presentation.incomeCategories.single.title, '工资');
    expect(loaded.presentation.balanceAccounts.single.title, '现金');
  });

  test('uses report windows and scopes for contribution drilldowns', () async {
    final service = _RecordingTransactionQueryService();
    final container = ProviderContainer(
      overrides: [transactionQueryServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final from = DateTime(2026, 1);
    final until = DateTime(2026, 1, 16);

    final cashflowProvider = statisticsTransactionsProvider(
      accountIdsKey: 'dining,salary',
      occurredFrom: from,
      occurredUntil: until,
      scope: StatisticsDrilldownScope.cashflow,
    );
    final balanceProvider = statisticsTransactionsProvider(
      accountIdsKey: 'cash',
      occurredFrom: null,
      occurredUntil: until,
      scope: StatisticsDrilldownScope.balance,
    );
    final cashflowSub = container.listen(cashflowProvider, (_, _) {});
    final balanceSub = container.listen(balanceProvider, (_, _) {});
    addTearDown(cashflowSub.close);
    addTearDown(balanceSub.close);
    await container.read(cashflowProvider.future);
    await container.read(balanceProvider.future);

    final cashflow = service.queries[0];
    expect(cashflow.accountIds, {'dining', 'salary'});
    expect(cashflow.occurredFrom, from);
    expect(cashflow.occurredUntil, until);
    expect(cashflow.scope, same(TransactionScopeFilter.stats));
    expect(cashflow.topLevelOnly, isFalse);
    expect(cashflow.limit, isNull);

    final balance = service.queries[1];
    expect(balance.accountIds, {'cash'});
    expect(balance.occurredFrom, isNull);
    expect(balance.occurredUntil, until);
    expect(balance.scope, same(TransactionScopeFilter.assetLiability));
    expect(balance.limit, isNull);
  });
}

StatisticsControlState _control({
  required DateTime from,
  required DateTime until,
}) {
  return StatisticsControlState(
    visibleMonth: DateTime(2026, 1),
    section: StatisticsSection.cashflow,
    granularity: StatisticsPeriodGranularity.date,
    mode: StatisticsPeriodMode.range,
    periodFrom: from,
    periodUntil: until,
    chartMetric: CashflowChartMetric.expense,
    chartForm: CashflowChartForm.bar,
    categoryKind: StatisticsCategoryKind.expense,
    categoryLevel: StatisticsCategoryLevel.primary,
  );
}

Account _account(String id, String name, AccountType type, {String? parentId}) {
  return Account(
    id: id,
    name: name,
    type: type,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
  );
}

CashflowReport _cashflowReport() {
  return CashflowReport(
    comparison: const CashflowComparison(
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
    categories: const [
      AccountMetric(
        accountId: 'dining',
        parentAccountId: 'food',
        accountType: AccountType.expense,
        amountMinor: 700,
      ),
      AccountMetric(
        accountId: 'salary',
        accountType: AccountType.income,
        amountMinor: 2000,
      ),
    ],
  );
}

BalanceReport _balanceReport() {
  return BalanceReport(
    comparison: const BalanceSheetComparison(
      current: BalanceSheetSnapshot(
        assets: Money(minorUnits: 10000),
        liabilities: Money(minorUnits: 2000),
      ),
      previous: BalanceSheetSnapshot(
        assets: Money(minorUnits: 9000),
        liabilities: Money(minorUnits: 2000),
      ),
    ),
    trend: [
      NetAssetTrendPoint(
        month: MonthKey(year: 2026, month: 1),
        netAssets: const Money(minorUnits: 8000),
      ),
    ],
    accounts: const [
      AccountMetric(
        accountId: 'cash',
        accountType: AccountType.asset,
        amountMinor: 10000,
      ),
    ],
  );
}

class _RecordingTransactionQueryService implements TransactionQueryService {
  final List<TransactionListQuery> queries = [];

  @override
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
