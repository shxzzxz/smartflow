import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
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
    final expense = loaded.presentation.expenseCategories.single;
    expect(expense.title, '餐饮');
    expect(expense.amount.minorUnits, 700);
    expect(expense.id, 'food');
    expect(expense.children.single.title, '聚餐');
    expect(expense.children.single.id, 'dining');
    final income = loaded.presentation.incomeCategories.single;
    expect(income.title, '工资');
    expect(income.children.single.title, '未细分');
    expect(income.children.single.isUnsubdivided, isTrue);
    expect(loaded.presentation.balanceAccounts.single.title, '现金');
  });

  test('uses report windows and scopes for contribution drilldowns', () async {
    final service = _RecordingTransactionQueryService();
    final container = ProviderContainer(
      overrides: [
        transactionQueryServiceProvider.overrideWithValue(service),
        accountLookupProvider.overrideWith(
          (ref) => Stream.value(
            AccountLookup({
              'food': _account('food', '餐饮', AccountType.expense),
              'dining': _account(
                'dining',
                '聚餐',
                AccountType.expense,
                parentId: 'food',
              ),
              'cash': _account('cash', '现金', AccountType.asset),
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final from = DateTime(2026, 1);
    final until = DateTime(2026, 1, 16);

    final cashflowProvider = statisticsTransactionsProvider(
      category: const CategorySelection.withDescendants('dining'),
      settlementAccountId: null,
      tagId: null,
      untaggedOnly: false,
      occurredFrom: from,
      occurredUntil: until,
      scope: StatisticsDrilldownScope.cashflow,
    );
    final unsubdividedProvider = statisticsTransactionsProvider(
      category: const CategorySelection.ownOnly('food'),
      settlementAccountId: null,
      tagId: null,
      untaggedOnly: false,
      occurredFrom: from,
      occurredUntil: until,
      scope: StatisticsDrilldownScope.cashflow,
    );
    final balanceProvider = statisticsTransactionsProvider(
      category: null,
      settlementAccountId: 'cash',
      tagId: null,
      untaggedOnly: false,
      occurredFrom: null,
      occurredUntil: until,
      scope: StatisticsDrilldownScope.balance,
    );
    final cashflowSub = container.listen(cashflowProvider, (_, _) {});
    final unsubdividedSub = container.listen(unsubdividedProvider, (_, _) {});
    final balanceSub = container.listen(balanceProvider, (_, _) {});
    addTearDown(cashflowSub.close);
    addTearDown(unsubdividedSub.close);
    addTearDown(balanceSub.close);
    await container.read(cashflowProvider.future);
    await container.read(unsubdividedProvider.future);
    await container.read(balanceProvider.future);

    final cashflow = service.queries[0];
    expect(cashflow.categoryAccountIds, {'dining'});
    expect(cashflow.settlementAccountIds, isNull);
    expect(cashflow.occurredFrom, from);
    expect(cashflow.occurredUntil, until);
    expect(cashflow.scope, same(TransactionScopeFilter.stats));
    expect(cashflow.topLevelOnly, isFalse);
    expect(cashflow.limit, isNull);

    final unsubdivided = service.queries[1];
    expect(unsubdivided.categoryAccountIds, {'food'});
    expect(unsubdivided.scope, same(TransactionScopeFilter.stats));

    final balance = service.queries[2];
    expect(balance.settlementAccountIds, {'cash'});
    expect(balance.categoryAccountIds, isNull);
    expect(balance.occurredFrom, isNull);
    expect(balance.occurredUntil, until);
    expect(balance.scope, same(TransactionScopeFilter.assetLiability));
    expect(balance.limit, isNull);
  });

  test('re-resolves category ids when the account lookup changes', () async {
    final accountLookups = StreamController<AccountLookup>();
    addTearDown(accountLookups.close);
    final service = _RecordingTransactionQueryService();
    final container = ProviderContainer(
      overrides: [
        transactionQueryServiceProvider.overrideWithValue(service),
        accountLookupProvider.overrideWith((ref) => accountLookups.stream),
      ],
    );
    addTearDown(container.dispose);
    final provider = statisticsTransactionsProvider(
      category: const CategorySelection.withDescendants('food'),
      settlementAccountId: null,
      tagId: null,
      untaggedOnly: false,
      occurredFrom: DateTime(2026, 1),
      occurredUntil: DateTime(2026, 2),
      scope: StatisticsDrilldownScope.cashflow,
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    accountLookups.add(
      AccountLookup({
        'food': _account('food', '餐饮', AccountType.expense),
        'dining': _account(
          'dining',
          '聚餐',
          AccountType.expense,
          parentId: 'food',
        ),
      }),
    );
    await _waitFor(() => service.queries.isNotEmpty);
    expect(service.queries.last.categoryAccountIds, {'food', 'dining'});

    accountLookups.add(
      AccountLookup({
        'food': _account('food', '餐饮', AccountType.expense),
        'dining': _account('dining', '聚餐', AccountType.expense),
        'hotpot': _account(
          'hotpot',
          '火锅',
          AccountType.expense,
          parentId: 'food',
        ),
      }),
    );
    await _waitFor(() => service.queries.length >= 2);
    expect(service.queries.last.categoryAccountIds, {'food', 'hotpot'});
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition was not met');
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
    categories: [
      CategoryMetricGroup(
        id: 'food',
        name: '餐饮',
        iconKey: null,
        accountType: AccountType.expense,
        total: const Money(minorUnits: 700),
        items: const [
          CategoryMetricItem(
            id: 'dining',
            name: '聚餐',
            iconKey: null,
            isUnsubdivided: false,
            amount: Money(minorUnits: 700),
          ),
        ],
      ),
      CategoryMetricGroup(
        id: 'salary',
        name: '工资',
        iconKey: null,
        accountType: AccountType.income,
        total: const Money(minorUnits: 2000),
        items: const [
          CategoryMetricItem(
            id: 'salary',
            name: '工资',
            iconKey: null,
            isUnsubdivided: true,
            amount: Money(minorUnits: 2000),
          ),
        ],
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
