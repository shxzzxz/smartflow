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
    dailySummaries: report.dailySummaries,
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

class StatisticsCashflowBucket {
  const StatisticsCashflowBucket({
    required this.date,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime date;
  final int incomeMinor;
  final int expenseMinor;
  int get netMinor => incomeMinor - expenseMinor;
  String get label => '${date.month}/${date.day}';
}

List<StatisticsCashflowBucket> buildStatisticsCashflowBuckets(
  List<DailyCashflowSummary> items,
) {
  return [
    for (final item in items)
      StatisticsCashflowBucket(
        date: item.date,
        incomeMinor: item.income.minorUnits,
        expenseMinor: item.expense.minorUnits,
      ),
  ];
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
    dailySummaries: cashflow.dailySummaries,
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
