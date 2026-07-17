import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/core/time/month_key.dart';

void main() {
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
      final service = FinancialMetricsServiceImpl(aggregate);

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
        DateTime(2026, 1, 1),
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
      ]);
      expect(report.categories.single.accountId, 'food');
      expect(report.balanceTrend.map((point) => point.balance.minorUnits), [
        10000,
        10000,
        10500,
        10500,
      ]);
    },
  );

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
            parentAccountId: 'food',
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
      final service = FinancialMetricsServiceImpl(aggregate);

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
      expect(
        report.categories.singleWhere((item) => item.accountId == 'dining'),
        const AccountMetric(
          accountId: 'dining',
          parentAccountId: 'food',
          accountType: AccountType.expense,
          amountMinor: 700,
        ),
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
    final service = FinancialMetricsServiceImpl(aggregate);

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

class _FakeLedgerMetricsSource implements LedgerMetricsSource {
  _FakeLedgerMetricsSource({
    this.accountTypeResults = const [],
    this.byDayResult = const {},
    this.byAccountResult = const [],
    this.byMonthResult = const {},
    this.byDayResults,
  });

  final List<Map<AccountType, int>> accountTypeResults;
  final Map<DateTime, Map<AccountType, int>> byDayResult;
  final List<AccountAggregate> byAccountResult;
  final Map<MonthKey, Map<AccountType, int>> byMonthResult;
  final List<Map<DateTime, Map<AccountType, int>>>? byDayResults;
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
