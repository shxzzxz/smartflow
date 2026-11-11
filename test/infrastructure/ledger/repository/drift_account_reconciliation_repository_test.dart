import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_reconciliation_repository.dart';

void main() {
  late AppDatabase database;
  late DriftAccountReconciliationRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftAccountReconciliationRepository(database);
  });

  tearDown(() => database.close());

  test('derives daily state and replaces snapshots for the range', () async {
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'cash',
            name: '现金',
            accountType: AccountType.asset,
          ),
        );
    final firstUpdate = DateTime(2026, 7, 2, 10);
    final secondUpdate = DateTime(2026, 7, 2, 11);
    await _insertTransaction(
      database,
      id: 'tx-1',
      occurredAt: DateTime(2026, 7, 2, 9),
      updatedAt: firstUpdate,
    );
    await _insertTransaction(
      database,
      id: 'tx-2',
      occurredAt: DateTime(2026, 7, 2, 18),
      updatedAt: secondUpdate,
    );
    await _insertTransaction(
      database,
      id: 'tx-3',
      occurredAt: DateTime(2026, 7, 3, 8),
      updatedAt: DateTime(2026, 7, 3, 8),
    );
    await _insertEntry(database, id: 'entry-1', transactionId: 'tx-1');
    await _insertEntry(database, id: 'entry-2', transactionId: 'tx-2');
    await _insertEntry(database, id: 'entry-2b', transactionId: 'tx-2');
    await _insertEntry(database, id: 'entry-3', transactionId: 'tx-3');

    final query = AccountReconciliationQuery(
      accountId: 'cash',
      from: DateTime(2026, 7, 1),
      untilInclusive: DateTime(2026, 7, 3),
    );
    final current = await repository.findCurrentDays(query);
    expect(current.map((day) => day.ledgerDateKey), [20260703, 20260702]);
    expect(current.last.transactionCount, 2);
    expect(current.last.latestTransactionUpdatedAt, secondUpdate);

    final confirmedAt = DateTime(2026, 7, 4, 12);
    await repository.replaceSnapshots(
      query: query,
      currentDays: current,
      confirmedAt: confirmedAt,
    );
    final snapshots = await repository.watchSnapshots(query).first;
    expect(snapshots, hasLength(2));
    expect(snapshots.first.confirmedAt, confirmedAt);

    await (database.update(
      database.transactions,
    )..where((row) => row.id.equals('tx-1'))).write(
      TransactionsCompanion(updatedAt: Value(DateTime(2026, 7, 4, 9))),
    );
    final changed = await repository.findCurrentDays(query);
    final day = changed.firstWhere((day) => day.ledgerDateKey == 20260702);
    expect(day.transactionCount, 2);
    expect(day.latestTransactionUpdatedAt, DateTime(2026, 7, 4, 9));
  });

  test(
    'removes old snapshots when a confirmed day has no transactions',
    () async {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'cash',
              name: '现金',
              accountType: AccountType.asset,
            ),
          );
      await database
          .into(database.accountReconciliationSnapshots)
          .insert(
            AccountReconciliationSnapshotsCompanion.insert(
              accountId: 'cash',
              ledgerDateKey: 20260702,
              latestTransactionUpdatedAt: DateTime(2026, 7, 2, 10),
              transactionCount: 1,
              confirmedAt: DateTime(2026, 7, 3),
            ),
          );
      final query = AccountReconciliationQuery(
        accountId: 'cash',
        from: DateTime(2026, 7, 1),
        untilInclusive: DateTime(2026, 7, 3),
      );

      await repository.replaceSnapshots(
        query: query,
        currentDays: const [],
        confirmedAt: DateTime(2026, 7, 4),
      );

      expect(await repository.watchSnapshots(query).first, isEmpty);
    },
  );
}

Future<void> _insertTransaction(
  AppDatabase database, {
  required String id,
  required DateTime occurredAt,
  required DateTime updatedAt,
}) {
  return database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: occurredAt,
          postedAt: occurredAt,
          primaryAmountMinor: 100,
          sourceKind: SourceKind.manual,
          createdAt: Value(updatedAt),
          updatedAt: Value(updatedAt),
        ),
      );
}

Future<void> _insertEntry(
  AppDatabase database, {
  required String id,
  required String transactionId,
}) {
  return database
      .into(database.entries)
      .insert(
        EntriesCompanion.insert(
          id: id,
          transactionId: transactionId,
          accountId: 'cash',
          direction: EntryDirection.credit,
          amountMinor: 100,
        ),
      );
}
