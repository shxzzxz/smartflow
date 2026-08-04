import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test(
    'intersects independent category and settlement-entry filters',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await database.batch((batch) {
        batch.insertAll(database.transactions, [
          _transactionCompanion('matches-both'),
          _transactionCompanion('matches-category'),
          _transactionCompanion('matches-settlement'),
        ]);
        batch.insertAll(database.entries, [
          _entryCompanion('both-food', 'matches-both', 'food'),
          _entryCompanion('both-cash', 'matches-both', 'cash'),
          _entryCompanion('category-food', 'matches-category', 'food'),
          _entryCompanion('category-bank', 'matches-category', 'bank'),
          _entryCompanion('settlement-travel', 'matches-settlement', 'travel'),
          _entryCompanion('settlement-cash', 'matches-settlement', 'cash'),
        ]);
      });

      final page =
          await DriftTransactionReadRepository(database)
              .watchPage(
                const TransactionPageQuery(
                  categoryAccountIds: {'food'},
                  settlementAccountIds: {'cash'},
                ),
              )
              .first;

      expect(page.map((transaction) => transaction.id), ['matches-both']);
    },
  );

  test('applies set OR filters before pagination', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database.batch((batch) {
      batch.insertAll(database.transactions, [
        _transactionCompanionAt('newest-unmatched', DateTime(2026, 4, 4)),
        _transactionCompanionAt('food-cash', DateTime(2026, 4, 3)),
        _transactionCompanionAt('travel-bank', DateTime(2026, 4, 2)),
        _transactionCompanionAt('old-unmatched', DateTime(2026, 4, 1)),
      ]);
      batch.insertAll(database.entries, [
        _entryCompanion('newest-other', 'newest-unmatched', 'other'),
        _entryCompanion('food', 'food-cash', 'food'),
        _entryCompanion('cash', 'food-cash', 'cash'),
        _entryCompanion('travel', 'travel-bank', 'travel'),
        _entryCompanion('bank', 'travel-bank', 'bank'),
        _entryCompanion('old-food', 'old-unmatched', 'food'),
        _entryCompanion('old-card', 'old-unmatched', 'card'),
      ]);
    });

    final page =
        await DriftTransactionReadRepository(database)
            .watchPage(
              const TransactionPageQuery(
                categoryAccountIds: {'food', 'travel'},
                settlementAccountIds: {'cash', 'bank'},
                limit: 2,
              ),
            )
            .first;

    expect(page.map((transaction) => transaction.id), [
      'food-cash',
      'travel-bank',
    ]);
  });
}

TransactionsCompanion _transactionCompanion(String id) =>
    _transactionCompanionAt(id, DateTime(2026, 4, 1));

TransactionsCompanion _transactionCompanionAt(String id, DateTime occurredAt) =>
    TransactionsCompanion.insert(
      id: id,
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: occurredAt,
      postedAt: occurredAt,
      primaryAmountMinor: 100,
      sourceKind: SourceKind.manual,
    );

EntriesCompanion _entryCompanion(
  String id,
  String transactionId,
  String accountId,
) => EntriesCompanion.insert(
  id: id,
  transactionId: transactionId,
  accountId: accountId,
  direction: EntryDirection.debit,
  amountMinor: 100,
);
