import 'account_reconciliation_queries.dart';

enum AccountReconciliationDayStatus { unconfirmed, unchanged, changed }

class DailyAccountLedgerState {
  DailyAccountLedgerState({
    required this.ledgerDateKey,
    required this.latestTransactionUpdatedAt,
    required this.transactionCount,
  }) : ledgerDate = reconciliationDateFromKey(ledgerDateKey);

  final int ledgerDateKey;
  final DateTime ledgerDate;
  final DateTime latestTransactionUpdatedAt;
  final int transactionCount;
}

class AccountReconciliationDaySnapshot {
  AccountReconciliationDaySnapshot({
    required this.accountId,
    required this.ledgerDateKey,
    required this.latestTransactionUpdatedAt,
    required this.transactionCount,
    required this.confirmedAt,
  }) : ledgerDate = reconciliationDateFromKey(ledgerDateKey);

  final String accountId;
  final int ledgerDateKey;
  final DateTime ledgerDate;
  final DateTime latestTransactionUpdatedAt;
  final int transactionCount;
  final DateTime confirmedAt;

  bool matches(DailyAccountLedgerState? current) {
    return current != null &&
        current.latestTransactionUpdatedAt == latestTransactionUpdatedAt &&
        current.transactionCount == transactionCount;
  }
}

class AccountReconciliationDay {
  const AccountReconciliationDay({
    required this.ledgerDate,
    required this.status,
    this.current,
    this.snapshot,
  });

  final DateTime ledgerDate;
  final AccountReconciliationDayStatus status;
  final DailyAccountLedgerState? current;
  final AccountReconciliationDaySnapshot? snapshot;

  bool get hasCurrentTransactions => current != null;
  bool get hasSnapshot => snapshot != null;
}

class AccountReconciliationState {
  AccountReconciliationState({
    required Map<int, DailyAccountLedgerState> currentDays,
    required Map<int, AccountReconciliationDaySnapshot> snapshotDays,
  }) : currentDays = Map.unmodifiable(currentDays),
       snapshotDays = Map.unmodifiable(snapshotDays),
       days = _buildDays(currentDays, snapshotDays);

  final Map<int, DailyAccountLedgerState> currentDays;
  final Map<int, AccountReconciliationDaySnapshot> snapshotDays;
  final List<AccountReconciliationDay> days;

  bool get hasSnapshots => snapshotDays.isNotEmpty;

  bool get hasChanges =>
      days.any((day) => day.status == AccountReconciliationDayStatus.changed);

  int get changedDayCount => days
      .where((day) => day.status == AccountReconciliationDayStatus.changed)
      .length;

  int get unconfirmedDayCount => days
      .where((day) => day.status == AccountReconciliationDayStatus.unconfirmed)
      .length;

  static List<AccountReconciliationDay> _buildDays(
    Map<int, DailyAccountLedgerState> currentDays,
    Map<int, AccountReconciliationDaySnapshot> snapshotDays,
  ) {
    final keys = {...currentDays.keys, ...snapshotDays.keys}.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        AccountReconciliationDay(
          ledgerDate: reconciliationDateFromKey(key),
          current: currentDays[key],
          snapshot: snapshotDays[key],
          status: _statusFor(currentDays[key], snapshotDays[key]),
        ),
    ];
  }

  static AccountReconciliationDayStatus _statusFor(
    DailyAccountLedgerState? current,
    AccountReconciliationDaySnapshot? snapshot,
  ) {
    if (snapshot == null) return AccountReconciliationDayStatus.unconfirmed;
    return snapshot.matches(current)
        ? AccountReconciliationDayStatus.unchanged
        : AccountReconciliationDayStatus.changed;
  }
}
