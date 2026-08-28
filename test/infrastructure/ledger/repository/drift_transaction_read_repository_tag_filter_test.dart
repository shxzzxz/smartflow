import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('tag filter matches any selected tag (OR)', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _seedTransactions(database);
    await _link(database, 'tx-travel', 'tag-travel');
    await _link(database, 'tx-both', 'tag-travel');
    await _link(database, 'tx-both', 'tag-work');

    final page =
        await DriftTransactionReadRepository(database)
            .watchPage(
              const TransactionPageQuery(tagIds: {'tag-travel', 'tag-work'}),
            )
            .first;

    expect(page.map((transaction) => transaction.id), ['tx-both', 'tx-travel']);
  });

  test(
    'tag filter matches child transactions through their group root',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await _seedTransactions(database);
      await _link(database, 'tx-travel', 'tag-travel');

      final page =
          await DriftTransactionReadRepository(database)
              .watchPage(
                const TransactionPageQuery(
                  tagIds: {'tag-travel'},
                  topLevelOnly: false,
                ),
              )
              .first;

      expect(page.map((transaction) => transaction.id), [
        'refund-child',
        'tx-travel',
      ]);
    },
  );

  test('untagged filter matches transactions without any tag', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _seedTransactions(database);
    await _link(database, 'tx-travel', 'tag-travel');

    final page =
        await DriftTransactionReadRepository(
          database,
        ).watchPage(const TransactionPageQuery(untaggedOnly: true)).first;

    expect(page.map((transaction) => transaction.id), [
      'tx-both',
      'tx-untagged-1',
      'tx-untagged-2',
    ]);
  });

  test(
    'untagged filter excludes groups whose top-level carries a tag',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await _seedTransactions(database);
      await _link(database, 'tx-travel', 'tag-travel');

      final page =
          await DriftTransactionReadRepository(database)
              .watchPage(
                const TransactionPageQuery(
                  untaggedOnly: true,
                  topLevelOnly: false,
                ),
              )
              .first;

      expect(page.map((transaction) => transaction.id), [
        'tx-both',
        'tx-untagged-1',
        'tx-untagged-2',
      ]);
    },
  );

  test('tag dimension intersects with the category dimension', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _seedTransactions(database);
    await _link(database, 'tx-travel', 'tag-travel');
    await _link(database, 'tx-untagged-1', 'tag-travel');

    final page =
        await DriftTransactionReadRepository(database)
            .watchPage(
              const TransactionPageQuery(
                match: TransactionImpactMatch(
                  categoryAccountIds: {'travel'},
                ),
                tagIds: {'tag-travel'},
              ),
            )
            .first;

    expect(page.map((transaction) => transaction.id), [
      'tx-travel',
      'tx-untagged-1',
    ]);
  });
}

Future<void> _seedTransactions(AppDatabase database) async {
  await database.batch((batch) {
    batch.insertAll(database.transactions, [
      _transactionAt('tx-both', DateTime(2026, 4, 6)),
      _transactionAt('tx-travel', DateTime(2026, 4, 5)),
      _transactionAt('tx-untagged-1', DateTime(2026, 4, 4)),
      _transactionAt('tx-untagged-2', DateTime(2026, 4, 3)),
    ]);
    batch.insertAll(database.entries, [
      _entryAt('both-1', 'tx-both', 'travel'),
      _entryAt('travel-1', 'tx-travel', 'travel'),
      _entryAt('untagged-1-1', 'tx-untagged-1', 'travel'),
      _entryAt('untagged-2-1', 'tx-untagged-2', 'other'),
    ]);
  });
  await database
      .into(database.transactions)
      .insert(
        _transactionAt(
          'refund-child',
          DateTime(2026, 4, 6),
          businessPurpose: BusinessPurpose.refund,
          parentTransactionId: 'tx-travel',
        ),
      );
}

TransactionsCompanion _transactionAt(
  String id,
  DateTime occurredAt, {
  BusinessPurpose businessPurpose = BusinessPurpose.dailyExpense,
  String? parentTransactionId,
}) => TransactionsCompanion.insert(
  id: id,
  businessPurpose: businessPurpose,
  occurredAt: occurredAt,
  postedAt: occurredAt,
  primaryAmountMinor: 100,
  sourceKind: SourceKind.manual,
  parentTransactionId: Value(parentTransactionId),
);

EntriesCompanion _entryAt(String id, String transactionId, String accountId) =>
    EntriesCompanion.insert(
      id: id,
      transactionId: transactionId,
      accountId: accountId,
      direction: EntryDirection.debit,
      amountMinor: 100,
    );

Future<void> _link(
  AppDatabase database,
  String transactionId,
  String tagId,
) async {
  await database
      .into(database.transactionTags)
      .insert(
        TransactionTagsCompanion.insert(
          transactionId: transactionId,
          tagId: tagId,
        ),
      );
}
