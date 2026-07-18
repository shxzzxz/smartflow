import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';

class StatisticsPresentation {
  const StatisticsPresentation({
    required this.cashflowComparison,
    required this.dailySummaries,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.balanceComparison,
    required this.netAssetTrend,
    required this.balanceAccounts,
    required this.cashflowFrom,
    required this.cashflowUntil,
    required this.balanceUntil,
    required this.incomeChangeText,
    required this.expenseChangeText,
    required this.netAssetChangeText,
    this.rangeBalanceTrend = const [],
  });

  final CashflowComparison cashflowComparison;
  final List<DailyCashflowSummary> dailySummaries;
  final List<StatisticsBreakdownItem> incomeCategories;
  final List<StatisticsBreakdownItem> expenseCategories;
  final BalanceSheetComparison balanceComparison;
  final List<NetAssetTrendPoint> netAssetTrend;
  final List<StatisticsBreakdownItem> balanceAccounts;
  final DateTime cashflowFrom;
  final DateTime cashflowUntil;
  final DateTime balanceUntil;
  final String incomeChangeText;
  final String expenseChangeText;
  final String netAssetChangeText;
  final List<BalanceTrendPoint> rangeBalanceTrend;
}

StatisticsPresentation buildRangeStatisticsPresentation({
  required StatisticsRangeReport report,
  required Map<String, Account> accountsById,
}) {
  final categoryGroups = _buildCategoryGroups(report.categories, accountsById);
  final firstBalance =
      report.balanceTrend.isEmpty
          ? const Money(minorUnits: 0)
          : report.balanceTrend.first.balance;
  final lastBalance =
      report.balanceTrend.isEmpty
          ? const Money(minorUnits: 0)
          : report.balanceTrend.last.balance;
  return StatisticsPresentation(
    cashflowComparison: CashflowComparison(
      current: report.cashflow,
      previousSamePeriod: const CashflowSummary(
        income: Money(minorUnits: 0),
        expense: Money(minorUnits: 0),
      ),
      previousFullPeriod: const CashflowSummary(
        income: Money(minorUnits: 0),
        expense: Money(minorUnits: 0),
      ),
    ),
    dailySummaries: _fillDailyCashflowDates(
      report.dailySummaries,
      from: report.from,
      until: report.until,
    ),
    incomeCategories:
        categoryGroups
            .where((item) => item.accountType == AccountType.income)
            .toList(),
    expenseCategories:
        categoryGroups
            .where((item) => item.accountType == AccountType.expense)
            .toList(),
    balanceComparison: BalanceSheetComparison(
      current: BalanceSheetSnapshot(
        assets: lastBalance,
        liabilities: const Money(minorUnits: 0),
      ),
      previous: BalanceSheetSnapshot(
        assets: firstBalance,
        liabilities: const Money(minorUnits: 0),
      ),
    ),
    netAssetTrend: const [],
    balanceAccounts: const [],
    cashflowFrom: report.from,
    cashflowUntil: report.until,
    balanceUntil: report.until,
    incomeChangeText: '',
    expenseChangeText: '',
    netAssetChangeText: _changeText(
      '区间变化',
      PeriodChange(current: lastBalance, previous: firstBalance),
    ),
    rangeBalanceTrend: report.balanceTrend,
  );
}

class StatisticsBreakdownItem {
  const StatisticsBreakdownItem({
    required this.id,
    required this.title,
    required this.accountIds,
    required this.accountType,
    required this.amount,
    required this.progress,
    this.children = const [],
  });

  final String id;
  final String title;
  final Set<String> accountIds;
  final AccountType accountType;
  final Money amount;
  final double progress;
  final List<StatisticsBreakdownItem> children;

  StatisticsBreakdownItem copyWith({
    double? progress,
    List<StatisticsBreakdownItem>? children,
  }) {
    return StatisticsBreakdownItem(
      id: id,
      title: title,
      accountIds: accountIds,
      accountType: accountType,
      amount: amount,
      progress: progress ?? this.progress,
      children: children ?? this.children,
    );
  }
}

enum StatisticsCashflowGrouping { day, week, month }

class StatisticsCashflowBucket {
  const StatisticsCashflowBucket({
    required this.date,
    required this.label,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime date;
  final String label;
  final int incomeMinor;
  final int expenseMinor;
  int get netMinor => incomeMinor - expenseMinor;
}

List<StatisticsCashflowBucket> buildStatisticsCashflowBuckets(
  List<DailyCashflowSummary> items, {
  StatisticsCashflowGrouping grouping = StatisticsCashflowGrouping.day,
}) {
  if (items.isEmpty) {
    return const [];
  }
  final sorted = [...items]
    ..sort((left, right) => left.date.compareTo(right.date));
  final anchor = DateTime(
    sorted.first.date.year,
    sorted.first.date.month,
    sorted.first.date.day,
  );
  final buckets = <DateTime, _CashflowBucketAccumulator>{};
  for (final item in sorted) {
    final date = DateTime(item.date.year, item.date.month, item.date.day);
    final bucketStart = switch (grouping) {
      StatisticsCashflowGrouping.day => date,
      StatisticsCashflowGrouping.week => anchor.add(
        Duration(days: date.difference(anchor).inDays ~/ 7 * 7),
      ),
      StatisticsCashflowGrouping.month => DateTime(date.year, date.month),
    };
    final bucket = buckets.putIfAbsent(
      bucketStart,
      () => _CashflowBucketAccumulator(date: bucketStart),
    );
    bucket.incomeMinor += item.income.minorUnits;
    bucket.expenseMinor += item.expense.minorUnits;
  }
  return [
    for (final bucket in buckets.values)
      StatisticsCashflowBucket(
        date: bucket.date,
        label: switch (grouping) {
          StatisticsCashflowGrouping.day =>
            '${bucket.date.month}/${bucket.date.day}',
          StatisticsCashflowGrouping.week => _weekLabel(bucket.date),
          StatisticsCashflowGrouping.month => '${bucket.date.month}月',
        },
        incomeMinor: bucket.incomeMinor,
        expenseMinor: bucket.expenseMinor,
      ),
  ];
}

List<DailyCashflowSummary> _fillDailyCashflowDates(
  List<DailyCashflowSummary> items, {
  required DateTime from,
  required DateTime until,
}) {
  final byDate = {
    for (final item in items)
      DateTime(item.date.year, item.date.month, item.date.day): item,
  };
  final result = <DailyCashflowSummary>[];
  var date = DateTime(from.year, from.month, from.day);
  while (date.isBefore(until)) {
    result.add(
      byDate[date] ??
          DailyCashflowSummary(
            date: date,
            income: const Money(minorUnits: 0),
            expense: const Money(minorUnits: 0),
          ),
    );
    date = DateTime(date.year, date.month, date.day + 1);
  }
  return result;
}

String _weekLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  return '${start.month}/${start.day}–${end.month}/${end.day}';
}

class _CashflowBucketAccumulator {
  _CashflowBucketAccumulator({required this.date});

  final DateTime date;
  int incomeMinor = 0;
  int expenseMinor = 0;
}

List<StatisticsBreakdownItem> selectStatisticsCategoryItems(
  List<StatisticsBreakdownItem> primary, {
  required bool secondary,
}) {
  final result = <StatisticsBreakdownItem>[
    ...(secondary ? primary.expand((item) => item.children) : primary),
  ];
  result.sort(_compareBreakdown);
  return result;
}

double statisticsCategoryShare(
  StatisticsBreakdownItem item,
  List<StatisticsBreakdownItem> items,
) {
  final total = items.fold<int>(
    0,
    (sum, value) => sum + statisticsCategoryMagnitude(value),
  );
  return total == 0 ? 0 : statisticsCategoryMagnitude(item) / total;
}

int statisticsCategoryMagnitude(StatisticsBreakdownItem item) {
  return item.amount.minorUnits < 0 ? 0 : item.amount.minorUnits;
}

String statisticsCategoryPercentageText(
  StatisticsBreakdownItem item,
  List<StatisticsBreakdownItem> items,
) {
  return '${(statisticsCategoryShare(item, items) * 100).toStringAsFixed(1)}%';
}

String statisticsCategoryValueText(
  StatisticsBreakdownItem item,
  List<StatisticsBreakdownItem> items, {
  required bool percentage,
}) {
  return percentage
      ? statisticsCategoryPercentageText(item, items)
      : item.amount.abs().format();
}

String statisticsDateLabel(DateTime date) => '${date.month}/${date.day}';

StatisticsPresentation buildStatisticsPresentation({
  required CashflowReport cashflow,
  required BalanceReport balance,
  required Map<String, Account> accountsById,
  required DateTime cashflowFrom,
  required DateTime cashflowUntil,
  required DateTime balanceUntil,
}) {
  final categoryGroups = _buildCategoryGroups(
    cashflow.categories,
    accountsById,
  );
  final balanceAccounts = [
    for (final metric in balance.accounts)
      StatisticsBreakdownItem(
        id: metric.accountId,
        title: accountsById[metric.accountId]?.name ?? '已归档账户',
        accountIds: {metric.accountId},
        accountType: metric.accountType,
        amount: metric.amount,
        progress: 0,
      ),
  ]..sort(_compareBreakdown);
  final normalizedBalanceAccounts = _withProgress(balanceAccounts);
  return StatisticsPresentation(
    cashflowComparison: cashflow.comparison,
    dailySummaries: _fillDailyCashflowDates(
      cashflow.dailySummaries,
      from: cashflowFrom,
      until: cashflowUntil,
    ),
    incomeCategories:
        categoryGroups
            .where((item) => item.accountType == AccountType.income)
            .toList(),
    expenseCategories:
        categoryGroups
            .where((item) => item.accountType == AccountType.expense)
            .toList(),
    balanceComparison: balance.comparison,
    netAssetTrend: balance.trend,
    balanceAccounts: normalizedBalanceAccounts,
    cashflowFrom: cashflowFrom,
    cashflowUntil: cashflowUntil,
    balanceUntil: balanceUntil,
    incomeChangeText: _changeText('较上月同期', cashflow.comparison.incomeChange),
    expenseChangeText: _changeText('较上月同期', cashflow.comparison.expenseChange),
    netAssetChangeText: _changeText('较上月', balance.comparison.netAssetChange),
  );
}

List<StatisticsBreakdownItem> _buildCategoryGroups(
  List<AccountMetric> metrics,
  Map<String, Account> accountsById,
) {
  final groups = <String, _MutableBreakdown>{};
  for (final metric in metrics) {
    final rootId = metric.parentAccountId ?? metric.accountId;
    final rootAccount = accountsById[rootId];
    final group = groups.putIfAbsent(
      rootId,
      () => _MutableBreakdown(
        id: rootId,
        title: rootAccount?.name ?? '已归档分类',
        accountType: metric.accountType,
      ),
    );
    group.amountMinor += metric.amountMinor;
    group.accountIds.add(metric.accountId);
    group.children.add(
      StatisticsBreakdownItem(
        id: metric.accountId,
        title: accountsById[metric.accountId]?.name ?? '已归档分类',
        accountIds: {metric.accountId},
        accountType: metric.accountType,
        amount: metric.amount,
        progress: 0,
      ),
    );
  }
  final result = [
    for (final group in groups.values)
      StatisticsBreakdownItem(
        id: group.id,
        title: group.title,
        accountIds: Set.unmodifiable(group.accountIds),
        accountType: group.accountType,
        amount: Money(minorUnits: group.amountMinor),
        progress: 0,
        children: List.unmodifiable(
          _withProgress(group.children..sort(_compareBreakdown)),
        ),
      ),
  ]..sort(_compareBreakdown);
  return _withProgress(result);
}

List<StatisticsBreakdownItem> _withProgress(
  List<StatisticsBreakdownItem> items,
) {
  final maxAmount = items
      .map((item) => item.amount.minorUnits.abs())
      .fold<int>(0, (max, value) => value > max ? value : max);
  return [
    for (final item in items)
      item.copyWith(
        progress: maxAmount == 0 ? 0 : item.amount.minorUnits.abs() / maxAmount,
      ),
  ];
}

String _changeText(String prefix, PeriodChange change) {
  final delta = change.delta;
  final sign = delta.minorUnits > 0 ? '+' : '';
  return '$prefix $sign${delta.format()}';
}

int _compareBreakdown(
  StatisticsBreakdownItem left,
  StatisticsBreakdownItem right,
) {
  return right.amount.minorUnits.abs().compareTo(left.amount.minorUnits.abs());
}

class _MutableBreakdown {
  _MutableBreakdown({
    required this.id,
    required this.title,
    required this.accountType,
  });

  final String id;
  final String title;
  final AccountType accountType;
  final Set<String> accountIds = {};
  final List<StatisticsBreakdownItem> children = [];
  int amountMinor = 0;
}
