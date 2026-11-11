import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';

import '../../shared/presentation/account_lookup.dart';
import '../../shared/presentation/transaction_list_presentation.dart';
import 'account_transaction_balance.dart';

List<TransactionDayGroup> buildAccountReconciliationDayGroups({
  required List<TransactionFeedEntry> entries,
  required AccountReconciliationState reconciliation,
  required String accountId,
  required AccountLookup accountLookup,
  required Money? expectedBalance,
}) {
  final groups = groupTransactionFeedEntriesByDay(
    entries: entries,
    accountLookup: accountLookup,
    amountSource: TransactionAccountImpactAmountSource(accountId),
  );
  final groupByDate = {
    for (final group in groups) normalizeDate(group.date): group,
  };
  final closingBalances = expectedBalance == null
      ? const <DateTime, Money>{}
      : accountDailyClosingBalances(
          transactions: entries.map((entry) => entry.transaction),
          accountId: accountId,
          currentBalance: expectedBalance,
        );
  final reconciliationByDate = {
    for (final day in reconciliation.days) normalizeDate(day.ledgerDate): day,
  };
  final dates = <DateTime>{
    ...groups.map((group) => normalizeDate(group.date)),
    for (final day in reconciliation.days)
      if (!day.hasCurrentTransactions) normalizeDate(day.ledgerDate),
  }.toList()..sort((a, b) => b.compareTo(a));

  return [
    for (final date in dates)
      (groupByDate[date] ??
              TransactionDayGroup(
                date: date,
                rows: const [],
                incomeMinor: 0,
                expenseMinor: 0,
              ))
          .copyWith(
            closingBalance: closingBalances[date],
            closingBalanceLabel: '期望余额',
            warning: reconciliationWarningFor(
              reconciliationByDate[date],
              showUnconfirmed: reconciliation.hasSnapshots,
            ),
          ),
  ];
}

String? reconciliationWarningFor(
  AccountReconciliationDay? day, {
  required bool showUnconfirmed,
}) {
  if (day == null) return null;
  return switch (day.status) {
    AccountReconciliationDayStatus.unchanged => null,
    AccountReconciliationDayStatus.changed =>
      day.current == null ? '该日原流水已删除' : '该日流水与上次确认时不同',
    AccountReconciliationDayStatus.unconfirmed =>
      showUnconfirmed ? '新增流水，尚未对账' : null,
  };
}
