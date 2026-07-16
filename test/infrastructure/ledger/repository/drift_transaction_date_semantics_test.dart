import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/application/ledger/transaction/query/transaction_queries.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_balance_aggregate_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('keeps transaction lists and stats on occurred_at', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertAccounts(database);
    await _insertExpense(database);

    final transactions = DriftTransactionReadRepository(database);
    final page =
        await transactions
            .watchPage(
          TransactionListQuery(
                occurredFrom: DateTime(2026, 4, 1),
                occurredUntil: DateTime(2026, 5, 1),
              ),
            )
            .first;
    expect(page, isEmpty);

    final balances = await DriftBalanceAggregateRepository(
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
}

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
          rootTransactionId: const Value('tx-occurred-march'),
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: DateTime(2026, 3, 31),
          postedAt: DateTime(2026, 4, 1),
          primaryAmountMinor: 1200,
          mutationKind: MutationKind.original,
          businessState: BusinessState.current,
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
