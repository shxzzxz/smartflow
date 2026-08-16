import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/shared/analytics/time_series_transform.dart';

import '../../account/query/account_query_service.dart';
import '../../tag/tag_read_models.dart';
import '../../tag/tag_repository.dart';
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
  const FinancialMetricsServiceImpl({
    required LedgerMetricsSource metricsSource,
    required AccountQueryService accountQuery,
    required TransactionTagRepository tagRepository,
  }) : _aggregate = metricsSource,
       _accountQuery = accountQuery,
       _tagRepository = tagRepository;

  final LedgerMetricsSource _aggregate;
  final AccountQueryService _accountQuery;
  final TransactionTagRepository _tagRepository;

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
      final cashflowFuture = _aggregate.aggregateByAccountType(
        accountTypes: _cashflowTypes,
        scope: TransactionScopeFilter.stats,
        window: window,
      );
      final dailySummariesFuture = _loadDailyCashflowSummaries(window);
      final categoriesFuture = _loadCategoryGroups(window);
      final tagsFuture = _loadTagMetrics(window);
      final balanceTrendFuture = _loadBalanceTrend(query);
      return StatisticsRangeReport(
        from: query.from,
        until: query.until,
        cashflow: _toCashflowSummary(await cashflowFuture),
        dailySummaries: await dailySummariesFuture,
        categories: await categoriesFuture,
        tags: await tagsFuture,
        balanceTrend: await balanceTrendFuture,
      );
    });
  }

  Future<List<BalanceTrendPoint>> _loadBalanceTrend(
    StatisticsRangeReportQuery query,
  ) async {
    final openingFuture = _aggregate.aggregateByAccountType(
      accountTypes: _balanceTypes,
      scope: TransactionScopeFilter.assetLiability,
      window: DateTimeWindow(until: query.from),
    );
    final byDayFuture = _aggregate.aggregateByAccountTypeByDay(
      accountTypes: _balanceTypes,
      scope: TransactionScopeFilter.assetLiability,
      window: DateTimeWindow(from: query.from, until: query.until),
    );
    final running = Map<AccountType, int>.from(await openingFuture);
    final byDay = await byDayFuture;
    final opening = BalanceTrendPoint(
      date: query.from,
      assets: Money(minorUnits: running[AccountType.asset] ?? 0),
      liabilities: Money(minorUnits: running[AccountType.liability] ?? 0),
    );
    final dailyPoints = <BalanceTrendPoint>[];
    var date = DateTime(query.from.year, query.from.month, query.from.day);
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
      dailyPoints.add(
        BalanceTrendPoint(
          date: date.add(const Duration(days: 1)),
          assets: Money(minorUnits: running[AccountType.asset] ?? 0),
          liabilities: Money(minorUnits: running[AccountType.liability] ?? 0),
        ),
      );
      date = date.add(const Duration(days: 1));
    }
    return [
      opening,
      ...sampleEveryNthPreservingLast(
        dailyPoints,
        step: query.balancePointIntervalDays,
      ),
    ];
  }

  @override
  Stream<CashflowReport> watchCashflowReport(CashflowReportQuery query) {
    return _aggregate.watchChanges().asyncMap((_) async {
      final periods = _cashflowPeriods(
        CashflowComparisonQuery(month: query.month, asOfDate: query.asOfDate),
      );
      final comparisonFuture = _loadCashflowComparisonForPeriods(periods);
      final dailySummariesFuture = _loadDailyCashflowSummaries(periods.current);
      final categoriesFuture = _loadCategoryGroups(periods.current);
      return CashflowReport(
        comparison: await comparisonFuture,
        dailySummaries: await dailySummariesFuture,
        categories: await categoriesFuture,
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
      final comparisonFuture = _loadBalanceSheetComparison(
        BalanceSheetComparisonQuery(
          month: query.month,
          asOfExclusive: currentCutoff,
        ),
      );
      final accountsFuture = _aggregate.aggregateByAccount(
        accountTypes: _balanceTypes,
        scope: TransactionScopeFilter.assetLiability,
        window: DateTimeWindow(until: currentCutoff),
      );
      final trendFuture = _loadNetAssetTrend(trendQuery);
      return BalanceReport(
        comparison: await comparisonFuture,
        accounts: _toAccountMetrics(await accountsFuture),
        trend: await trendFuture,
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
    final currentFuture = _aggregate.aggregateByAccountType(
      accountTypes: _cashflowTypes,
      scope: TransactionScopeFilter.stats,
      window: periods.current,
    );
    final previousSameFuture = _aggregate.aggregateByAccountType(
      accountTypes: _cashflowTypes,
      scope: TransactionScopeFilter.stats,
      window: periods.previousSame,
    );
    final previousFullFuture = _aggregate.aggregateByAccountType(
      accountTypes: _cashflowTypes,
      scope: TransactionScopeFilter.stats,
      window: periods.previousFull,
    );
    return CashflowComparison(
      current: _toCashflowSummary(await currentFuture),
      previousSamePeriod: _toCashflowSummary(await previousSameFuture),
      previousFullPeriod: _toCashflowSummary(await previousFullFuture),
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

  Future<BalanceSheetComparison> _loadBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  ) async {
    final currentCutoff = query.asOfExclusive ?? query.month.nextMonthStart;
    final currentFuture = _aggregate.aggregateByAccountType(
      accountTypes: _balanceTypes,
      scope: TransactionScopeFilter.assetLiability,
      window: DateTimeWindow(until: currentCutoff),
    );
    final previousFuture = _aggregate.aggregateByAccountType(
      accountTypes: _balanceTypes,
      scope: TransactionScopeFilter.assetLiability,
      window: DateTimeWindow(until: query.month.start),
    );
    return BalanceSheetComparison(
      current: _toBalanceSnapshot(await currentFuture),
      previous: _toBalanceSnapshot(await previousFuture),
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
    final openingFuture = _aggregate.aggregateByAccountType(
      accountTypes: _balanceTypes,
      scope: TransactionScopeFilter.assetLiability,
      window: DateTimeWindow(until: firstMonth.start),
    );
    final byMonthFuture = _aggregate.aggregateByAccountTypeByMonth(
      accountTypes: _balanceTypes,
      scope: TransactionScopeFilter.assetLiability,
      window: DateTimeWindow(from: firstMonth.start, until: currentUntil),
    );
    final running = Map<AccountType, int>.from(await openingFuture);
    final byMonth = await byMonthFuture;
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

  /// 分类统计读模型：SQL 按物理分类聚合后，沿活跃二层分类树组装
  /// 一级 total 与二级 own 金额；一级自身直接金额呈现为"未细分"项。
  Future<List<CategoryMetricGroup>> _loadCategoryGroups(
    DateTimeWindow window,
  ) async {
    final aggregatesFuture = _aggregate.aggregateByAccount(
      accountTypes: _cashflowTypes,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    final categoriesFuture = _accountQuery.findAccounts(_cashflowTypes);
    return _buildCategoryGroups(
      aggregates: await aggregatesFuture,
      categories: await categoriesFuture,
    );
  }

  List<CategoryMetricGroup> _buildCategoryGroups({
    required List<AccountAggregate> aggregates,
    required List<Account> categories,
  }) {
    final amountByCategoryId = {
      for (final aggregate in aggregates)
        aggregate.accountId: aggregate.amountMinor,
    };
    final roots = <Account>[];
    final childrenByParent = <String, List<Account>>{};
    for (final category in categories) {
      final parentId = category.parentId;
      if (parentId == null) {
        roots.add(category);
      } else {
        childrenByParent.putIfAbsent(parentId, () => []).add(category);
      }
    }

    final groups = <CategoryMetricGroup>[];
    for (final root in roots) {
      final own = amountByCategoryId[root.id] ?? 0;
      final items = <CategoryMetricItem>[
        for (final child in childrenByParent[root.id] ?? const <Account>[])
          if (amountByCategoryId.containsKey(child.id))
            CategoryMetricItem(
              id: child.id,
              name: child.name,
              iconKey: child.iconKey,
              isUnsubdivided: false,
              amount: Money(minorUnits: amountByCategoryId[child.id]!),
            ),
        if (amountByCategoryId.containsKey(root.id))
          CategoryMetricItem(
            id: root.id,
            name: root.name,
            iconKey: root.iconKey,
            isUnsubdivided: true,
            amount: Money(minorUnits: own),
          ),
      ];
      if (items.isEmpty) continue;
      items.sort(
        (left, right) => right.amount.minorUnits.abs().compareTo(
          left.amount.minorUnits.abs(),
        ),
      );
      groups.add(
        CategoryMetricGroup(
          id: root.id,
          name: root.name,
          iconKey: root.iconKey,
          accountType: root.type,
          total: items.fold(
            const Money(minorUnits: 0),
            (sum, item) => sum + item.amount,
          ),
          items: items,
        ),
      );
    }
    groups.sort(
      (left, right) =>
          right.total.minorUnits.abs().compareTo(left.total.minorUnits.abs()),
    );
    return groups;
  }

  /// 标签构成读模型：SQL 按 `(标签, 账户类型)` 聚合后组装命名条目。
  /// 未打标签的聚合行呈现为「未打标签」项；词表内无引用的标签不出现。
  Future<List<TagMetricItem>> _loadTagMetrics(DateTimeWindow window) async {
    final aggregatesFuture = _aggregate.aggregateByTag(
      accountTypes: _cashflowTypes,
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    final tagsFuture = _tagRepository.listTags();
    final aggregates = await aggregatesFuture;
    if (aggregates.isEmpty) return const [];
    final nameByTagId = {
      for (final TagView tag in await tagsFuture) tag.id: tag.name,
    };
    return [
      for (final aggregate in aggregates)
        TagMetricItem(
          tagId: aggregate.tagId,
          name:
              aggregate.tagId == null
                  ? '未打标签'
                  : nameByTagId[aggregate.tagId] ?? '已删除标签',
          accountType: aggregate.accountType,
          amount: Money(minorUnits: aggregate.amountMinor),
        ),
    ]..sort(
      (left, right) =>
          right.amount.minorUnits.abs().compareTo(left.amount.minorUnits.abs()),
    );
  }

  List<AccountMetric> _toAccountMetrics(List<AccountAggregate> aggregates) {
    return [
      for (final item in aggregates)
        AccountMetric(
          accountId: item.accountId,
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
