import 'package:drift/drift.dart';
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

  test('finds the latest top-level transaction for a category', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database.batch((batch) {
      batch.insertAll(database.transactions, [
        _transactionCompanionAt(
          'newest-child',
          DateTime(2026, 4, 5),
          parentTransactionId: 'old-expense',
        ),
        _transactionCompanionAt(
          'latest-reimbursement',
          DateTime(2026, 4, 4),
          businessPurpose: BusinessPurpose.reimbursementAdvance,
        ),
        _transactionCompanionAt('newer-unrelated', DateTime(2026, 4, 3)),
        _transactionCompanionAt('old-expense', DateTime(2026, 4, 2)),
      ]);
      batch.insertAll(database.entries, [
        _entryCompanion('child-food', 'newest-child', 'food'),
        _entryCompanion('child-bank', 'newest-child', 'bank'),
        _entryCompanion(
          'latest-receivable',
          'latest-reimbursement',
          'company-receivable',
        ),
        _entryCompanion('latest-card', 'latest-reimbursement', 'credit-card'),
        _entryCompanion('unrelated-travel', 'newer-unrelated', 'travel'),
        _entryCompanion('unrelated-cash', 'newer-unrelated', 'cash'),
        _entryCompanion('old-food', 'old-expense', 'food'),
        _entryCompanion('old-cash', 'old-expense', 'cash'),
      ]);
      // 报销垫付的支出分类只在分项上,不产生分录。
      batch.insert(
        database.transactionLines,
        TransactionLinesCompanion.insert(
          id: 'latest-category-line',
          transactionId: 'latest-reimbursement',
          lineNo: 1,
          role: TransactionRole.reimbursementExpenseCategory,
          accountId: const Value('food'),
          amountMinor: 100,
        ),
      );
    });

    final transaction = await DriftTransactionReadRepository(
      database,
    ).findLatestByCategory(
      const CategoryTransactionQuery(
        categoryId: 'food',
        hierarchy: TransactionHierarchyFilter.topLevel,
      ),
    );

    expect(transaction?.id, 'latest-reimbursement');
  });

  test('finds the latest child transaction for a category', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database.batch((batch) {
      batch.insertAll(database.transactions, [
        _transactionCompanionAt('parent', DateTime(2026, 4, 3)),
        _transactionCompanionAt(
          'new-refund',
          DateTime(2026, 4, 5),
          businessPurpose: BusinessPurpose.refund,
          parentTransactionId: 'parent',
        ),
        _transactionCompanionAt(
          'old-refund',
          DateTime(2026, 4, 4),
          businessPurpose: BusinessPurpose.refund,
          parentTransactionId: 'parent',
        ),
      ]);
      batch.insertAll(database.entries, [
        _entryCompanion('parent-food', 'parent', 'food'),
        _entryCompanion('new-food', 'new-refund', 'food'),
        _entryCompanion('old-food', 'old-refund', 'food'),
      ]);
    });

    final transaction = await DriftTransactionReadRepository(
      database,
    ).findLatestByCategory(
      const CategoryTransactionQuery(
        categoryId: 'food',
        hierarchy: TransactionHierarchyFilter.child,
      ),
    );

    expect(transaction?.id, 'new-refund');
  });

  test('uses descending id to break equal occurred-at ties', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final occurredAt = DateTime(2026, 4, 5);
    await database.batch((batch) {
      batch.insertAll(database.transactions, [
        _transactionCompanionAt('same-time-a', occurredAt),
        _transactionCompanionAt('same-time-z', occurredAt),
      ]);
      batch.insertAll(database.entries, [
        _entryCompanion('same-time-a-food', 'same-time-a', 'food'),
        _entryCompanion('same-time-z-food', 'same-time-z', 'food'),
      ]);
    });

    final transaction = await DriftTransactionReadRepository(
      database,
    ).findLatestByCategory(
      const CategoryTransactionQuery(categoryId: 'food'),
    );

    expect(transaction?.id, 'same-time-z');
  });
}

TransactionsCompanion _transactionCompanion(String id) =>
    _transactionCompanionAt(id, DateTime(2026, 4, 1));

TransactionsCompanion _transactionCompanionAt(
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
