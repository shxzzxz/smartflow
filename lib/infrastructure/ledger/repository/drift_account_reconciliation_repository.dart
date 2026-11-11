import 'package:drift/drift.dart';

import '../../../application/ledger/reconciliation/port/account_reconciliation_repository.dart';
import '../../../application/ledger/reconciliation/query/account_reconciliation_queries.dart';
import '../../../application/ledger/reconciliation/query/account_reconciliation_read_models.dart';
import '../../database/app_database.dart';

class DriftAccountReconciliationRepository
    implements AccountReconciliationRepository {
  const DriftAccountReconciliationRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<DailyAccountLedgerState>> watchCurrentDays(
    AccountReconciliationQuery query,
  ) {
    return _currentDaysSelect(query).watch().map(_mapCurrentDays);
  }

  @override
  Future<List<DailyAccountLedgerState>> findCurrentDays(
    AccountReconciliationQuery query,
  ) async {
    return _mapCurrentDays(await _currentDaysSelect(query).get());
  }

  @override
  Stream<List<AccountReconciliationDaySnapshot>> watchSnapshots(
    AccountReconciliationQuery query,
  ) {
    final snapshots = _db.accountReconciliationSnapshots;
    return (_db.select(snapshots)
          ..where(
            (row) =>
                row.accountId.equals(query.accountId) &
                row.ledgerDateKey.isBiggerOrEqualValue(
                  reconciliationDateKey(query.from),
                ) &
                row.ledgerDateKey.isSmallerOrEqualValue(
                  reconciliationDateKey(query.untilInclusive),
                ),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.ledgerDateKey)]))
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              AccountReconciliationDaySnapshot(
                accountId: row.accountId,
                ledgerDateKey: row.ledgerDateKey,
                latestTransactionUpdatedAt: row.latestTransactionUpdatedAt,
                transactionCount: row.transactionCount,
                confirmedAt: row.confirmedAt,
              ),
          ],
        );
  }

  @override
  Future<void> replaceSnapshots({
    required AccountReconciliationQuery query,
    required Iterable<DailyAccountLedgerState> currentDays,
    required DateTime confirmedAt,
  }) async {
    final snapshots = _db.accountReconciliationSnapshots;
    await (_db.delete(snapshots)..where(
          (row) =>
              row.accountId.equals(query.accountId) &
              row.ledgerDateKey.isBiggerOrEqualValue(
                reconciliationDateKey(query.from),
              ) &
              row.ledgerDateKey.isSmallerOrEqualValue(
                reconciliationDateKey(query.untilInclusive),
              ),
        ))
        .go();

    final rows = [
      for (final day in currentDays)
        AccountReconciliationSnapshotsCompanion.insert(
          accountId: query.accountId,
          ledgerDateKey: day.ledgerDateKey,
          latestTransactionUpdatedAt: day.latestTransactionUpdatedAt,
          transactionCount: day.transactionCount,
          confirmedAt: confirmedAt,
        ),
    ];
    if (rows.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAll(snapshots, rows);
      });
    }
  }

  @override
  Future<void> deleteForAccount(String accountId) async {
    await (_db.delete(
      _db.accountReconciliationSnapshots,
    )..where((row) => row.accountId.equals(accountId))).go();
  }

  JoinedSelectStatement<$TransactionsTable, TransactionRow> _currentDaysSelect(
    AccountReconciliationQuery query,
  ) {
    final transactions = _db.transactions;
    final entries = _db.entries;
    return _db.selectOnly(transactions, distinct: true)
      ..addColumns([
        transactions.id,
        transactions.occurredAt,
        transactions.updatedAt,
      ])
      ..join([
        innerJoin(entries, entries.transactionId.equalsExp(transactions.id)),
      ])
      ..where(
        entries.accountId.equals(query.accountId) &
            transactions.occurredAt.isBiggerOrEqualValue(query.from) &
            transactions.occurredAt.isSmallerThanValue(query.untilExclusive),
      );
  }

  List<DailyAccountLedgerState> _mapCurrentDays(List<TypedResult> rows) {
    final byDate = <int, ({DateTime latest, int count})>{};
    for (final row in rows) {
      final occurredAt = row.read(_db.transactions.occurredAt);
      final updatedAt = row.read(_db.transactions.updatedAt);
      if (occurredAt == null || updatedAt == null) continue;
      final dateKey = reconciliationDateKey(occurredAt);
      final existing = byDate[dateKey];
      byDate[dateKey] = (
        latest: existing == null || updatedAt.isAfter(existing.latest)
            ? updatedAt
            : existing.latest,
        count: (existing?.count ?? 0) + 1,
      );
    }
    final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        DailyAccountLedgerState(
          ledgerDateKey: key,
          latestTransactionUpdatedAt: byDate[key]!.latest,
          transactionCount: byDate[key]!.count,
        ),
    ];
  }
}
