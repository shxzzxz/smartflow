import '../../../application/ledger/ledger_query_api.dart';

/// 同一日的主交易聚合，用于按日分组卡片。
class HomeTransactionDayGroup {
  const HomeTransactionDayGroup({
    required this.date,
    required this.items,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime date;
  final List<TransactionListItem> items;
  final int incomeMinor;
  final int expenseMinor;
}

List<HomeTransactionDayGroup> groupTransactionsByDay(
  List<TransactionListItem> items,
  List<DailyCashflowSummary> dailySummaries,
) {
  final groups = <DateTime, List<TransactionListItem>>{};
  for (final item in items) {
    final date = DateTime(
      item.occurredAt.year,
      item.occurredAt.month,
      item.occurredAt.day,
    );
    groups.putIfAbsent(date, () => []).add(item);
  }

  final totalsByDate = _dailySummariesByDate(dailySummaries);
  final dates =
      {...groups.keys, ...totalsByDate.keys}.toList()
        ..sort((a, b) => b.compareTo(a));
  return [
    for (final date in dates)
      HomeTransactionDayGroup(
        date: date,
        items: groups[date] ?? const [],
        incomeMinor: totalsByDate[date]?.income.minorUnits ?? 0,
        expenseMinor: totalsByDate[date]?.expense.minorUnits ?? 0,
      ),
  ];
}

Map<DateTime, DailyCashflowSummary> _dailySummariesByDate(
  List<DailyCashflowSummary> summaries,
) {
  return {
    for (final summary in summaries)
      DateTime(summary.date.year, summary.date.month, summary.date.day):
          summary,
  };
}

/// 主交易级别的"收入"判定。
///
/// 退款 / 报销到账 / 结束报销属于子交易，已在数据层折叠到主交易行的 badge，
/// 因此不再纳入此处的"主级收入"统计。
bool isIncomePurpose(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyIncome => true,
    _ => false,
  };
}

bool isExpensePurpose(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyExpense => true,
    _ => false,
  };
}
