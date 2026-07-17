import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../../transaction/query/transaction_read_models.dart';
import '../../transaction/query/transaction_scope.dart';
import 'financial_metrics_queries.dart';
import 'financial_metrics_read_models.dart';
import 'port/ledger_metrics_source.dart';

abstract interface class FinancialMetricsService {
  Stream<StatisticsRangeReport> watchStatisticsRangeReport(
    StatisticsRangeReportQuery query,
  );

  Stream<CashflowReport> watchCashflowReport(CashflowReportQuery query);

  Stream<BalanceReport> watchBalanceReport(BalanceReportQuery query);

  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  );

  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  );

  Stream<BalanceSheetComparison> watchBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  );

  Stream<List<NetAssetTrendPoint>> watchNetAssetTrend(NetAssetTrendQuery query);
}

class FinancialMetricsServiceImpl implements FinancialMetricsService {
  const FinancialMetricsServiceImpl(this._aggregate);

  final LedgerMetricsSource _aggregate;

  static const Set<AccountType> _cashflowTypes = {
    AccountType.income,
    AccountType.expense,
  };

  static const Set<AccountType> _balanceTypes = {
    AccountType.asset,
    AccountType.liability,
  };

  @override
  Stream<StatisticsRangeReport> watchStatisticsRangeReport(
    StatisticsRangeReportQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final window = DateTimeWindow(from: query.from, until: query.until);
      final results = await Future.wait([
        _aggregate.aggregateByAccountType(
          accountTypes: _cashflowTypes,
          scope: TransactionScopeFilter.stats,
          window: window,
        ),
        _loadDailyCashflowSummaries(window),
        _aggregate.aggregateByAccount(
          accountTypes: _cashflowTypes,
          scope: TransactionScopeFilter.stats,
          window: window,
        ),
        _loadBalanceTrend(query),
      ]);
      return StatisticsRangeReport(
        from: query.from,
        until: query.until,
        cashflow: _toCashflowSummary(results[0] as Map<AccountType, int>),
        dailySummaries: results[1] as List<DailyCashflowSummary>,
        categories: _toAccountMetrics(results[2] as List<AccountAggregate>),
        balanceTrend: results[3] as List<BalanceTrendPoint>,
      );
    });
  }

  Future<List<BalanceTrendPoint>> _loadBalanceTrend(
    StatisticsRangeReportQuery query,
  ) async {
    final results = await Future.wait([
      _aggregate.aggregateByAccountType(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(until: query.from),
      ),
      _aggregate.aggregateByAccountTypeByDay(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(from: query.from, until: query.until),
      ),
    ]);
    final running = Map<AccountType, int>.from(
      results[0] as Map<AccountType, int>,
    );
    final byDay = results[1] as Map<DateTime, Map<AccountType, int>>;
    final points = <BalanceTrendPoint>[
      BalanceTrendPoint(
        date: query.from,
        balance: Money(minorUnits: running[AccountType.asset] ?? 0),
      ),
    ];
    var date = DateTime(query.from.year, query.from.month, query.from.day);
    var index = 0;
    while (date.isBefore(query.until)) {
      final delta = byDay[date];
      if (delta != null) {
        for (final type in _balanceTypes) {
          running.update(
            type,
            (value) => value + (delta[type] ?? 0),
            ifAbsent: () => delta[type] ?? 0,
          );
        }
      }
      final isLast = !date.add(const Duration(days: 1)).isBefore(query.until);
      if (index % query.balancePointIntervalDays == 0 || isLast) {
        points.add(
          BalanceTrendPoint(
            date: date.add(const Duration(days: 1)),
            balance: Money(minorUnits: running[AccountType.asset] ?? 0),
          ),
        );
      }
      date = date.add(const Duration(days: 1));
      index++;
    }
    return points;
  }

  @override
  Stream<CashflowReport> watchCashflowReport(CashflowReportQuery query) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final periods = _cashflowPeriods(
        CashflowComparisonQuery(month: query.month, asOfDate: query.asOfDate),
      );
      final results = await Future.wait([
        _loadCashflowComparisonForPeriods(periods),
        _loadDailyCashflowSummaries(periods.current),
        _aggregate.aggregateByAccount(
          accountTypes: _cashflowTypes,
          scope: TransactionScopeFilter.stats,
          window: periods.current,
        ),
      ]);
      return CashflowReport(
        comparison: results[0] as CashflowComparison,
        dailySummaries: results[1] as List<DailyCashflowSummary>,
        categories: _toAccountMetrics(results[2] as List<AccountAggregate>),
      );
    });
  }

  @override
  Stream<BalanceReport> watchBalanceReport(BalanceReportQuery query) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final currentCutoff = query.asOfExclusive ?? query.month.nextMonthStart;
      final trendQuery = NetAssetTrendQuery(
        endMonth: query.month,
        months: query.trendMonths,
        currentAsOfExclusive: currentCutoff,
      );
      final results = await Future.wait([
        _loadBalanceSheetComparison(
          BalanceSheetComparisonQuery(
            month: query.month,
            asOfExclusive: currentCutoff,
          ),
        ),
        _aggregate.aggregateByAccount(
          accountTypes: _balanceTypes,
          scope: TransactionScopeFilter.assetLiability,
          window: DateTimeWindow(until: currentCutoff),
        ),
        _loadNetAssetTrend(trendQuery),
      ]);
      return BalanceReport(
        comparison: results[0] as BalanceSheetComparison,
        accounts: _toAccountMetrics(results[1] as List<AccountAggregate>),
        trend: results[2] as List<NetAssetTrendPoint>,
      );
    });
  }

  @override
  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap(
      (_) => _loadCashflowComparison(query),
    );
  }

  @override
  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  ) {
    final window = DateTimeWindow(
      from: query.month.start,
      until: query.month.nextMonthStart,
    );
    return _aggregate.watchChanges().asyncMap(
      (_) => _loadDailyCashflowSummaries(window),
    );
  }

  @override
  Stream<BalanceSheetComparison> watchBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap(
      (_) => _loadBalanceSheetComparison(query),
    );
  }

  @override
  Stream<List<NetAssetTrendPoint>> watchNetAssetTrend(
    NetAssetTrendQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap((_) => _loadNetAssetTrend(query));
  }

  Future<CashflowComparison> _loadCashflowComparison(
    CashflowComparisonQuery query,
  ) {
    return _loadCashflowComparisonForPeriods(_cashflowPeriods(query));
  }

  Future<CashflowComparison> _loadCashflowComparisonForPeriods(
    _CashflowPeriods periods,
  ) async {
    final results = await Future.wait([
      _aggregate.aggregateByAccountType(
        accountTypes: _cashflowTypes,
        scope: TransactionScopeFilter.stats,
        window: periods.current,
      ),
      _aggregate.aggregateByAccountType(
        accountTypes: _cashflowTypes,
        scope: TransactionScopeFilter.stats,
        window: periods.previousSame,
      ),
      _aggregate.aggregateByAccountType(
        accountTypes: _cashflowTypes,
        scope: TransactionScopeFilter.stats,
        window: periods.previousFull,
      ),
    ]);
    return CashflowComparison(
      current: _toCashflowSummary(results[0]),
      previousSamePeriod: _toCashflowSummary(results[1]),
      previousFullPeriod: _toCashflowSummary(results[2]),
    );
  }

  Future<List<DailyCashflowSummary>> _loadDailyCashflowSummaries(
    DateTimeWindow window,
  ) async {
    final byDay = await _aggregate.aggregateByAccountTypeByDay(
      accountTypes: _cashflowTypes,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    final from = window.from;
    final until = window.until;
    if (from == null || until == null) {
      final dates = byDay.keys.toList()..sort();
      return [
        for (final date in dates)
          DailyCashflowSummary(
            date: date,
            income: Money(minorUnits: byDay[date]![AccountType.income] ?? 0),
            expense: Money(minorUnits: byDay[date]![AccountType.expense] ?? 0),
          ),
      ];
    }
    final result = <DailyCashflowSummary>[];
    var date = DateTime(from.year, from.month, from.day);
    while (date.isBefore(until)) {
      final values = byDay[date] ?? const <AccountType, int>{};
      result.add(
        DailyCashflowSummary(
          date: date,
          income: Money(minorUnits: values[AccountType.income] ?? 0),
          expense: Money(minorUnits: values[AccountType.expense] ?? 0),
        ),
      );
      date = date.add(const Duration(days: 1));
    }
    return result;
  }

  Future<BalanceSheetComparison> _loadBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  ) async {
    final currentCutoff = query.asOfExclusive ?? query.month.nextMonthStart;
    final results = await Future.wait([
      _aggregate.aggregateByAccountType(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(until: currentCutoff),
      ),
      _aggregate.aggregateByAccountType(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(until: query.month.start),
      ),
    ]);
    return BalanceSheetComparison(
      current: _toBalanceSnapshot(results[0]),
      previous: _toBalanceSnapshot(results[1]),
    );
  }

  Future<List<NetAssetTrendPoint>> _loadNetAssetTrend(
    NetAssetTrendQuery query,
  ) async {
    final months = _trendMonths(query.endMonth, query.months);
    if (months.isEmpty) return const [];
    final firstMonth = months.first;
    final currentUntil =
        query.currentAsOfExclusive ?? query.endMonth.nextMonthStart;
    final results = await Future.wait([
      _aggregate.aggregateByAccountType(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(until: firstMonth.start),
      ),
      _aggregate.aggregateByAccountTypeByMonth(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(from: firstMonth.start, until: currentUntil),
      ),
    ]);
    final running = Map<AccountType, int>.from(
      results[0] as Map<AccountType, int>,
    );
    final byMonth = results[1] as Map<MonthKey, Map<AccountType, int>>;
    return [
      for (final month in months)
        NetAssetTrendPoint(
          month: month,
          netAssets:
              _toBalanceSnapshot(
                running
                  ..update(
                    AccountType.asset,
                    (value) =>
                        value + (byMonth[month]?[AccountType.asset] ?? 0),
                    ifAbsent: () => byMonth[month]?[AccountType.asset] ?? 0,
                  )
                  ..update(
                    AccountType.liability,
                    (value) =>
                        value + (byMonth[month]?[AccountType.liability] ?? 0),
                    ifAbsent: () => byMonth[month]?[AccountType.liability] ?? 0,
                  ),
              ).netAssets,
        ),
    ];
  }

  _CashflowPeriods _cashflowPeriods(CashflowComparisonQuery query) {
    final currentStart = query.month.start;
    final previousMonth = MonthKey.fromDate(
      DateTime(query.month.year, query.month.month - 1),
    );
    final previousStart = previousMonth.start;
    final isCurrentMonth =
        query.asOfDate != null &&
        query.asOfDate!.year == query.month.year &&
        query.asOfDate!.month == query.month.month;
    final currentUntil =
        isCurrentMonth
            ? DateTime(
              query.month.year,
              query.month.month,
              query.asOfDate!.day + 1,
            )
            : query.month.nextMonthStart;
    final previousSamePeriodUntil =
        isCurrentMonth
            ? _samePeriodUntil(previousMonth, query.asOfDate!.day)
            : currentStart;
    return _CashflowPeriods(
      current: DateTimeWindow(from: currentStart, until: currentUntil),
      previousSame: DateTimeWindow(
        from: previousStart,
        until: previousSamePeriodUntil,
      ),
      previousFull: DateTimeWindow(from: previousStart, until: currentStart),
    );
  }

  List<AccountMetric> _toAccountMetrics(List<AccountAggregate> aggregates) {
    return [
      for (final item in aggregates)
        AccountMetric(
          accountId: item.accountId,
          parentAccountId: item.parentAccountId,
          accountType: item.accountType,
          amountMinor: item.amountMinor,
        ),
    ]..sort(
      (left, right) =>
          right.amountMinor.abs().compareTo(left.amountMinor.abs()),
    );
  }

  CashflowSummary _toCashflowSummary(Map<AccountType, int> result) {
    return CashflowSummary(
      income: Money(minorUnits: result[AccountType.income] ?? 0),
      expense: Money(minorUnits: result[AccountType.expense] ?? 0),
    );
  }

  BalanceSheetSnapshot _toBalanceSnapshot(Map<AccountType, int> result) {
    return BalanceSheetSnapshot(
      assets: Money(minorUnits: result[AccountType.asset] ?? 0),
      liabilities: Money(minorUnits: result[AccountType.liability] ?? 0),
    );
  }

  List<MonthKey> _trendMonths(MonthKey endMonth, int count) {
    if (count <= 0) return const [];
    return [
      for (var i = count - 1; i >= 0; i--)
        MonthKey.fromDate(DateTime(endMonth.year, endMonth.month - i)),
    ];
  }

  DateTime _samePeriodUntil(MonthKey month, int day) {
    final nextMonthStart = month.nextMonthStart;
    final lastDay = nextMonthStart.subtract(const Duration(days: 1)).day;
    final inclusiveDay = day > lastDay ? lastDay : day;
    return DateTime(month.year, month.month, inclusiveDay + 1);
  }
}

class _CashflowPeriods {
  const _CashflowPeriods({
    required this.current,
    required this.previousSame,
    required this.previousFull,
  });

  final DateTimeWindow current;
  final DateTimeWindow previousSame;
  final DateTimeWindow previousFull;
}
