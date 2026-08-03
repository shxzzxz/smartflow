import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_ledger_metrics_source.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test(
    'loads the next page exclusively after an occurred-at and id cursor',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await database.batch((batch) {
        batch.insertAll(database.transactions, [
          TransactionsCompanion.insert(
            id: 'tx-newest',
            businessPurpose: BusinessPurpose.dailyExpense,
            occurredAt: DateTime(2026, 4, 3),
            postedAt: DateTime(2026, 4, 3),
            primaryAmountMinor: 100,
            sourceKind: SourceKind.manual,
          ),
          TransactionsCompanion.insert(
            id: 'tx-same-time-b',
            businessPurpose: BusinessPurpose.dailyExpense,
            occurredAt: DateTime(2026, 4, 2),
            postedAt: DateTime(2026, 4, 2),
            primaryAmountMinor: 100,
            sourceKind: SourceKind.manual,
          ),
          TransactionsCompanion.insert(
            id: 'tx-same-time-a',
            businessPurpose: BusinessPurpose.dailyExpense,
            occurredAt: DateTime(2026, 4, 2),
            postedAt: DateTime(2026, 4, 2),
            primaryAmountMinor: 100,
            sourceKind: SourceKind.manual,
          ),
          TransactionsCompanion.insert(
            id: 'tx-oldest',
            businessPurpose: BusinessPurpose.dailyExpense,
            occurredAt: DateTime(2026, 4, 1),
            postedAt: DateTime(2026, 4, 1),
            primaryAmountMinor: 100,
            sourceKind: SourceKind.manual,
          ),
        ]);
      });
      final transactions = DriftTransactionReadRepository(database);

      final firstPage =
          await transactions
              .watchPage(const TransactionPageQuery(limit: 2))
              .first;
      final nextPage =
          await transactions
              .watchPage(
                TransactionPageQuery(
                  limit: 2,
                  before: TransactionListCursor(
                    occurredAt: firstPage.last.occurredAt,
                    id: firstPage.last.id,
                  ),
                ),
              )
              .first;

      expect(firstPage.map((transaction) => transaction.id), [
        'tx-newest',
        'tx-same-time-b',
      ]);
      expect(nextPage.map((transaction) => transaction.id), [
        'tx-same-time-a',
        'tx-oldest',
      ]);
    },
  );

  test('keeps transaction lists and stats on occurred_at', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertAccounts(database);
    await _insertExpense(database);

    final transactions = DriftTransactionReadRepository(database);
    final page =
        await transactions
            .watchPage(
              TransactionPageQuery(
                occurredFrom: DateTime(2026, 4, 1),
                occurredUntil: DateTime(2026, 5, 1),
              ),
            )
            .first;
    expect(page, isEmpty);

    final balances = await DriftLedgerMetricsSource(
      database,
    ).aggregateByAccountType(
      accountTypes: const {AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: DateTimeWindow(
        from: DateTime(2026, 4, 1),
        until: DateTime(2026, 5, 1),
      ),
    );
    expect(balances, isEmpty);
  });

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
}

TransactionsCompanion _transactionCompanion(String id) =>
    TransactionsCompanion.insert(
      id: id,
      businessPurpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 4, 1),
      postedAt: DateTime(2026, 4, 1),
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

Future<void> _insertAccounts(AppDatabase database) async {
  await database.batch((batch) {
    batch.insertAll(database.accounts, [
      AccountsCompanion.insert(
        id: 'test-cash',
        name: '测试现金',
        accountType: AccountType.asset,
      ),
      AccountsCompanion.insert(
        id: 'test-food',
        name: '测试餐饮',
        accountType: AccountType.expense,
      ),
    ]);
  });
}

Future<void> _insertExpense(AppDatabase database) async {
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: 'tx-occurred-march',
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: DateTime(2026, 3, 31),
          postedAt: DateTime(2026, 4, 1),
          primaryAmountMinor: 1200,
          sourceKind: SourceKind.manual,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.entries, [
      EntriesCompanion.insert(
        id: 'tx-expense',
        transactionId: 'tx-occurred-march',
        accountId: 'test-food',
        direction: EntryDirection.debit,
        amountMinor: 1200,
      ),
      EntriesCompanion.insert(
        id: 'tx-cash',
        transactionId: 'tx-occurred-march',
        accountId: 'test-cash',
        direction: EntryDirection.credit,
        amountMinor: 1200,
      ),
    ]);
  });
}
