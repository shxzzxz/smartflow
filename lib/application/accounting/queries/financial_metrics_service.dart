import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';
import 'package:smartflow/domain/accounting/enums/accounting_enums.dart';
import '../queries/financial_metrics_queries.dart';
import '../queries/transaction_scope.dart';
import '../read_models/financial_metrics_read_models.dart';
import '../read_models/transaction_read_models.dart';
import 'balance_aggregate_repository.dart';

abstract interface class FinancialMetricsService {
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

  final BalanceAggregateRepository _aggregate;

  static const Set<AccountType> _cashflowTypes = {
    AccountType.income,
    AccountType.expense,
  };

  static const Set<AccountType> _balanceTypes = {
    AccountType.asset,
    AccountType.liability,
  };

  @override
  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final periods = _cashflowPeriods(query);
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
    });
  }

  @override
  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final byDay = await _aggregate.aggregateByAccountTypeByDay(
        accountTypes: _cashflowTypes,
        scope: TransactionScopeFilter.stats,
        window: DateTimeWindow(
          from: query.month.start,
          until: query.month.nextMonthStart,
        ),
      );
      final dates = byDay.keys.toList()..sort();
      return [
        for (final date in dates)
          DailyCashflowSummary(
            date: date,
            income: Money(minorUnits: byDay[date]![AccountType.income] ?? 0),
            expense: Money(minorUnits: byDay[date]![AccountType.expense] ?? 0),
          ),
      ];
    });
  }

  @override
  Stream<BalanceSheetComparison> watchBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final currentCutoff = query.asOfExclusive ?? query.month.nextMonthStart;
      final previousCutoff = query.month.start;
      final results = await Future.wait([
        _aggregate.aggregateByAccountType(
          accountTypes: _balanceTypes,
          scope: TransactionScopeFilter.assetLiability,
          window: DateTimeWindow(until: currentCutoff),
        ),
        _aggregate.aggregateByAccountType(
          accountTypes: _balanceTypes,
          scope: TransactionScopeFilter.assetLiability,
          window: DateTimeWindow(until: previousCutoff),
        ),
      ]);
      return BalanceSheetComparison(
        current: _toBalanceSnapshot(results[0]),
        previous: _toBalanceSnapshot(results[1]),
      );
    });
  }

  @override
  Stream<List<NetAssetTrendPoint>> watchNetAssetTrend(
    NetAssetTrendQuery query,
  ) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final months = _trendMonths(query.endMonth, query.months);
      if (months.isEmpty) return const <NetAssetTrendPoint>[];
      final windows = [
        for (var i = 0; i < months.length; i++)
          DateTimeWindow(
            until:
                i == months.length - 1 && query.currentAsOfExclusive != null
                    ? query.currentAsOfExclusive
                    : months[i].nextMonthStart,
          ),
      ];
      final cutoffs = await _aggregate.aggregateByAccountTypeAtCutoffs(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        windows: windows,
      );
      return [
        for (var i = 0; i < months.length; i++)
          NetAssetTrendPoint(
            month: months[i],
            netAssets: _toBalanceSnapshot(cutoffs[i]).netAssets,
          ),
      ];
    });
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
