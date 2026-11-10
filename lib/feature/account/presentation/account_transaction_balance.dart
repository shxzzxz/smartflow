import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart'
    show normalizeDate;

/// Derives end-of-day balances for one account from a newest-first transaction
/// prefix. Every transaction after a returned date must be present in
/// [transactions] for the corresponding closing balance to be complete.
Map<DateTime, Money> accountDailyClosingBalances({
  required Iterable<TransactionReadModel> transactions,
  required String accountId,
  required Money currentBalance,
}) {
  final netChangeByDate = <DateTime, int>{};
  for (final transaction in transactions) {
    final impact = transaction.impactsByAccountId[accountId];
    if (impact == null) continue;
    final date = normalizeDate(transaction.occurredAt);
    netChangeByDate.update(
      date,
      (value) => value + impact.netChange.minorUnits,
      ifAbsent: () => impact.netChange.minorUnits,
    );
  }

  final dates = netChangeByDate.keys.toList()..sort((a, b) => b.compareTo(a));
  var runningMinor = currentBalance.minorUnits;
  final result = <DateTime, Money>{};
  for (final date in dates) {
    result[date] = Money(minorUnits: runningMinor);
    runningMinor -= netChangeByDate[date]!;
  }
  return Map.unmodifiable(result);
}
