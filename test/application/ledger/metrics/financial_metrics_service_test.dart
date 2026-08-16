import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import '../../../helper/fake_transaction_tag_repository.dart';

void main() {
  test('returns only dates that contain daily cashflow facts', () async {
    final aggregate = _FakeLedgerMetricsSource(
      accountTypeResults: const [],
      byDayResult: {
        DateTime(2026, 1, 2): const {
          AccountType.income: 3000,
          AccountType.expense: 1200,
        },
      },
    );
    final service = _service(aggregate);

    final summaries =
        await service
            .watchDailyCashflowSummaries(
              DailyCashflowSummaryQuery(month: MonthKey(year: 2026, month: 1)),
            )
            .first;

    expect(summaries.map((item) => item.date), [DateTime(2026, 1, 2)]);
    expect(summaries.single.income.minorUnits, 3000);
    expect(summaries.single.expense.minorUnits, 1200);
  });

  test(
    'builds cashflow and daily net-asset points for an arbitrary range',
    () async {
      final aggregate = _FakeLedgerMetricsSource(
        accountTypeResults: const [
          {AccountType.income: 3000, AccountType.expense: 1200},
          {AccountType.asset: 10000, AccountType.liability: 2000},
        ],
        byDayResults: [
          {
            DateTime(2026, 1, 2): const {
              AccountType.income: 3000,
              AccountType.expense: 1200,
            },
          },
          {
            DateTime(2026, 1, 2): const {AccountType.asset: 500},
            DateTime(2026, 1, 3): const {AccountType.liability: 200},
          },
        ],
        byAccountResult: const [
          AccountAggregate(
            accountId: 'food',
            accountType: AccountType.expense,
            amountMinor: 1200,
          ),
        ],
      );
      final service = _service(aggregate, categories: [_category('food')]);

      final report =
          await service
              .watchStatisticsRangeReport(
                StatisticsRangeReportQuery(
                  from: DateTime(2026, 1, 1),
                  until: DateTime(2026, 1, 4),
                ),
              )
              .first;

      expect(report.cashflow.net.minorUnits, 1800);
      expect(report.dailySummaries.map((item) => item.date), [
        DateTime(2026, 1, 2),
      ]);
      final group = report.categories.single;
      expect(group.id, 'food');
      expect(group.total.minorUnits, 1200);
      expect(group.items.single.id, 'food');
      expect(group.items.single.isUnsubdivided, isTrue);
      expect(report.balanceTrend.map((point) => point.assets.minorUnits), [
        10000,
        10000,
        10500,
        10500,
      ]);
      expect(report.balanceTrend.map((point) => point.liabilities.minorUnits), [
        2000,
        2000,
        2000,
        2200,
      ]);
      expect(report.balanceTrend.map((point) => point.netAssets.minorUnits), [
        8000,
        8000,
        8500,
        8300,
      ]);
    },
  );

  test('composes tag metrics with names and the untagged bucket', () async {
    final aggregate = _FakeLedgerMetricsSource(
      accountTypeResults: const [
        {AccountType.income: 0, AccountType.expense: 1300},
        {AccountType.asset: 0, AccountType.liability: 0},
      ],
      byTagResult: const [
        TagAggregate(
          tagId: 'tag-a',
          accountType: AccountType.expense,
          amountMinor: 800,
        ),
        TagAggregate(
          tagId: null,
          accountType: AccountType.expense,
          amountMinor: 500,
        ),
      ],
    );
    final tagRepository = FakeTransactionTagRepository();
    await tagRepository.insertTag(id: 'tag-a', name: '旅行');
    final service = FinancialMetricsServiceImpl(
      metricsSource: aggregate,
      accountQuery: _FakeAccountQueryService(const []),
      tagRepository: tagRepository,
    );

    final report =
        await service
            .watchStatisticsRangeReport(
              StatisticsRangeReportQuery(
                from: DateTime(2026, 1, 1),
                until: DateTime(2026, 1, 4),
              ),
            )
            .first;

    expect(report.tags.map((tag) => tag.name), ['旅行', '未打标签']);
    expect(report.tags.first.tagId, 'tag-a');
    expect(report.tags.first.amount.minorUnits, 800);
    expect(report.tags.last.isUntagged, isTrue);
    expect(report.tags.last.amount.minorUnits, 500);
  });

  test(
    'builds a current-state cashflow report for the selected month',
    () async {
      final aggregate = _FakeLedgerMetricsSource(
        accountTypeResults: const [
          {AccountType.income: 2000, AccountType.expense: 700},
          {AccountType.income: 1000, AccountType.expense: 400},
          {AccountType.income: 1000, AccountType.expense: 400},
        ],
        byDayResult: {
          DateTime(2026, 1, 5): const {
            AccountType.income: 2000,
            AccountType.expense: 1000,
          },
          DateTime(2026, 1, 6): const {AccountType.expense: -300},
        },
        byAccountResult: const [
          AccountAggregate(
            accountId: 'dining',
            accountType: AccountType.expense,
            amountMinor: 700,
          ),
          AccountAggregate(
            accountId: 'salary',
            accountType: AccountType.income,
            amountMinor: 2000,
          ),
        ],
      );
      final service = _service(
        aggregate,
        categories: [
          _category('food'),
          _category('dining', parentId: 'food'),
          _category('salary', type: AccountType.income),
        ],
      );

      final report =
          await service
              .watchCashflowReport(
                CashflowReportQuery(
                  month: MonthKey(year: 2026, month: 1),
                  asOfDate: DateTime(2026, 1, 15),
                ),
              )
              .first;

      expect(report.comparison.current.income.minorUnits, 2000);
      expect(report.comparison.current.expense.minorUnits, 700);
      expect(report.comparison.previousSamePeriod.income.minorUnits, 1000);
      expect(report.comparison.previousSamePeriod.expense.minorUnits, 400);
      expect(
        report.dailySummaries
            .singleWhere((item) => item.date == DateTime(2026, 1, 6))
            .expense
            .minorUnits,
        -300,
      );

      // 一级 food 无直接金额：total 归并二级 dining，且不产生"未细分"项。
      final expenseGroup = report.categories.singleWhere(
        (group) => group.accountType == AccountType.expense,
      );
      expect(expenseGroup.id, 'food');
      expect(expenseGroup.total.minorUnits, 700);
      expect(expenseGroup.items.single.id, 'dining');
      expect(expenseGroup.items.single.isUnsubdivided, isFalse);
      final incomeGroup = report.categories.singleWhere(
        (group) => group.accountType == AccountType.income,
      );
      expect(incomeGroup.id, 'salary');
      expect(incomeGroup.total.minorUnits, 2000);
    },
  );

  test(
    'assembles first-level totals with an unsubdivided own-amount item',
    () async {
      final aggregate = _FakeLedgerMetricsSource(
        accountTypeResults: const [
          {AccountType.expense: 1000},
          {AccountType.expense: 0},
          {AccountType.expense: 0},
        ],
        byAccountResult: const [
          AccountAggregate(
            accountId: 'food',
            accountType: AccountType.expense,
            amountMinor: 300,
          ),
          AccountAggregate(
            accountId: 'dining',
            accountType: AccountType.expense,
            amountMinor: 700,
          ),
        ],
      );
      final service = _service(
        aggregate,
        categories: [
          _category('food'),
          _category('dining', parentId: 'food'),
          _category('travel'),
        ],
      );

      final report =
          await service
              .watchCashflowReport(
                CashflowReportQuery(month: MonthKey(year: 2026, month: 1)),
              )
              .first;

      final group = report.categories.single;
      expect(group.id, 'food');
      expect(group.total.minorUnits, 1000);
      expect(group.items, hasLength(2));
      expect(group.items.first.id, 'dining');
      expect(group.items.first.amount.minorUnits, 700);
      final unsubdivided = group.items.last;
      expect(unsubdivided.id, 'food');
      expect(unsubdivided.isUnsubdivided, isTrue);
      expect(unsubdivided.amount.minorUnits, 300);
      // 零金额分类（travel）不返回统计读模型。
      expect(
        report.categories.map((item) => item.id),
        isNot(contains('travel')),
      );
    },
  );

  test(
    'keeps category items with activity when their net amount is zero',
    () async {
      final aggregate = _FakeLedgerMetricsSource(
        accountTypeResults: const [
          {AccountType.expense: 0},
          {AccountType.expense: 0},
          {AccountType.expense: 0},
        ],
        byAccountResult: const [
          AccountAggregate(
            accountId: 'food',
            accountType: AccountType.expense,
            amountMinor: 0,
          ),
          AccountAggregate(
            accountId: 'dining',
            accountType: AccountType.expense,
            amountMinor: 0,
          ),
        ],
      );
      final service = _service(
        aggregate,
        categories: [
          _category('food'),
          _category('dining', parentId: 'food'),
          _category('travel'),
        ],
      );

      final report =
          await service
              .watchCashflowReport(
                CashflowReportQuery(month: MonthKey(year: 2026, month: 1)),
              )
              .first;

      final group = report.categories.single;
      expect(group.id, 'food');
      expect(group.total.minorUnits, 0);
      expect(
        group.items.map((item) => item.id),
        containsAll(['food', 'dining']),
      );
      expect(group.items.every((item) => item.amount.minorUnits == 0), isTrue);
      expect(
        report.categories.map((item) => item.id),
        isNot(contains('travel')),
      );
    },
  );

  test('builds balance snapshots and trend from aggregate facts', () async {
    final december = MonthKey(year: 2025, month: 12);
    final january = MonthKey(year: 2026, month: 1);
    final aggregate = _FakeLedgerMetricsSource(
      accountTypeResults: const [
        {AccountType.asset: 11000, AccountType.liability: 2000},
        {AccountType.asset: 10000, AccountType.liability: 2000},
        {},
      ],
      byAccountResult: const [
        AccountAggregate(
          accountId: 'cash',
          accountType: AccountType.asset,
          amountMinor: 11000,
        ),
        AccountAggregate(
          accountId: 'card',
          accountType: AccountType.liability,
          amountMinor: 2000,
        ),
      ],
      byMonthResult: {
        december: const {AccountType.asset: 10000, AccountType.liability: 2000},
        january: const {AccountType.asset: 1000},
      },
    );
    final service = _service(aggregate);

    final report =
        await service
            .watchBalanceReport(
              BalanceReportQuery(
                month: january,
                asOfExclusive: DateTime(2026, 1, 16),
                trendMonths: 2,
              ),
            )
            .first;

    expect(report.comparison.previous.netAssets.minorUnits, 8000);
    expect(report.comparison.current.netAssets.minorUnits, 9000);
    expect(report.trend.map((point) => point.netAssets.minorUnits), [
      8000,
      9000,
    ]);
    expect(report.accounts.map((item) => item.accountId), ['cash', 'card']);
  });
}

FinancialMetricsServiceImpl _service(
  LedgerMetricsSource aggregate, {
  List<Account> categories = const [],
}) {
  return FinancialMetricsServiceImpl(
    metricsSource: aggregate,
    accountQuery: _FakeAccountQueryService(categories),
    tagRepository: FakeTransactionTagRepository(),
  );
}

Account _category(
  String id, {
  String? parentId,
  AccountType type = AccountType.expense,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    parentId: parentId,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeAccountQueryService implements AccountQueryService {
  _FakeAccountQueryService(this._categories);

  final List<Account> _categories;

  @override
  Future<List<Account>> findAccounts(Set<AccountType> types) async => [
    for (final account in _categories)
      if (types.contains(account.type)) account,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeLedgerMetricsSource implements LedgerMetricsSource {
  _FakeLedgerMetricsSource({
    this.accountTypeResults = const [],
    this.byDayResult = const {},
    this.byAccountResult = const [],
    this.byMonthResult = const {},
    this.byDayResults,
    this.byTagResult = const [],
  });

  final List<Map<AccountType, int>> accountTypeResults;
  final Map<DateTime, Map<AccountType, int>> byDayResult;
  final List<AccountAggregate> byAccountResult;
  final Map<MonthKey, Map<AccountType, int>> byMonthResult;
  final List<Map<DateTime, Map<AccountType, int>>>? byDayResults;
  final List<TagAggregate> byTagResult;
  int _accountTypeIndex = 0;
  int _byDayIndex = 0;

  @override
  Future<List<AccountAggregate>> aggregateByAccount({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    return byAccountResult;
  }

  @override
  Future<List<TagAggregate>> aggregateByTag({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    return byTagResult;
  }

  @override
  Future<Map<AccountType, int>> aggregateByAccountType({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    return accountTypeResults[_accountTypeIndex++];
  }

  @override
  Future<Map<DateTime, Map<AccountType, int>>> aggregateByAccountTypeByDay({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    DateTimeWindow window = const DateTimeWindow(),
  }) async {
    final results = byDayResults;
    return results == null ? byDayResult : results[_byDayIndex++];
  }

  @override
  Future<Map<MonthKey, Map<AccountType, int>>> aggregateByAccountTypeByMonth({
    required Set<AccountType> accountTypes,
    required TransactionScopeFilter scope,
    required DateTimeWindow window,
  }) async {
    return byMonthResult;
  }

  @override
  Stream<void> watchChanges() => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
