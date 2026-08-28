import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_ledger_metrics_source.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test(
    'aggregates current parent and child transaction entries by account',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await _insertAccounts(database);
      await _insertTransactions(database);

      final repository = DriftLedgerMetricsSource(database);
      final rows = await repository.aggregateByAccount(
        accountTypes: const {AccountType.income, AccountType.expense},
        scope: TransactionScopeFilter.stats,
        window: DateTimeWindow(
          from: DateTime(2026, 1),
          until: DateTime(2026, 2),
        ),
      );

      expect(rows, hasLength(2));
      expect(
        rows.singleWhere((row) => row.accountId == 'dining'),
        const AccountAggregate(
          accountId: 'dining',
          accountType: AccountType.expense,
          amountMinor: 700,
        ),
      );
      expect(
        rows.singleWhere((row) => row.accountId == 'salary'),
        const AccountAggregate(
          accountId: 'salary',
          accountType: AccountType.income,
          amountMinor: 2000,
        ),
      );
    },
  );

  test(
    'lists parent and child transactions contributing to accounts',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await _insertAccounts(database);
      await _insertTransactions(database);

      final repository = DriftTransactionReadRepository(database);
      final rows =
          await repository
              .watchPage(
                TransactionPageQuery(
                  match: const TransactionImpactMatch(
                    categoryAccountIds: {'dining'},
                  ),
                  occurredFrom: DateTime(2026, 1),
                  occurredUntil: DateTime(2026, 2),
                  topLevelOnly: false,
                  scope: TransactionScopeFilter.stats,
                ),
              )
              .first;

      expect(rows.map((row) => row.id), ['refund', 'expense']);
    },
  );

  test('groups monthly aggregates by the local calendar month', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertAccounts(database);
    final occurredAt = DateTime.utc(2025, 12, 31, 16, 30);
    await _insertTransaction(
      database,
      id: 'year-boundary',
      purpose: BusinessPurpose.dailyExpense,
      occurredAt: occurredAt,
      entries: const [
        ('boundary-cash', 'cash', EntryDirection.debit, 100),
        ('boundary-expense', 'food', EntryDirection.credit, 100),
      ],
    );
    final result = await DriftLedgerMetricsSource(
      database,
    ).aggregateByAccountTypeByMonth(
      accountTypes: const {AccountType.asset},
      scope: TransactionScopeFilter.assetLiability,
      window: DateTimeWindow(
        from: DateTime(2025, 12),
        until: DateTime(2026, 2),
      ),
    );

    expect(result.keys, [MonthKey.fromDate(occurredAt.toLocal())]);
    expect(result.values.single[AccountType.asset], 100);
  });

  test('excludes archived accounts from every statistics aggregate', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database.batch((batch) {
      batch.insertAll(database.accounts, [
        AccountsCompanion.insert(
          id: 'active-cash',
          name: '活跃资金',
          accountType: AccountType.asset,
        ),
        AccountsCompanion.insert(
          id: 'archived-cash',
          name: '已归档资金',
          accountType: AccountType.asset,
          archivedAt: Value(DateTime(2026, 2)),
        ),
        AccountsCompanion.insert(
          id: 'archived-food',
          name: '已归档餐饮',
          accountType: AccountType.expense,
          archivedAt: Value(DateTime(2026, 2)),
        ),
        AccountsCompanion.insert(
          id: 'opening-equity',
          name: '期初权益',
          accountType: AccountType.equity,
        ),
      ]);
    });
    await _insertTransaction(
      database,
      id: 'active-balance',
      purpose: BusinessPurpose.openingBalance,
      occurredAt: DateTime(2026, 1, 1),
      entries: const [
        ('active-asset', 'active-cash', EntryDirection.debit, 1000),
        ('active-equity', 'opening-equity', EntryDirection.credit, 1000),
      ],
    );
    await _insertTransaction(
      database,
      id: 'archived-balance',
      purpose: BusinessPurpose.openingBalance,
      occurredAt: DateTime(2026, 1, 2),
      entries: const [
        ('archived-asset', 'archived-cash', EntryDirection.debit, 300),
        ('archived-equity', 'opening-equity', EntryDirection.credit, 300),
      ],
    );
    await _insertTransaction(
      database,
      id: 'archived-expense',
      purpose: BusinessPurpose.dailyExpense,
      occurredAt: DateTime(2026, 1, 3),
      entries: const [
        (
          'archived-expense-category',
          'archived-food',
          EntryDirection.debit,
          200,
        ),
        ('archived-expense-cash', 'archived-cash', EntryDirection.credit, 200),
      ],
    );

    final repository = DriftLedgerMetricsSource(database);
    const accountTypes = {AccountType.asset};
    const scope = TransactionScopeFilter.assetLiability;
    final window = DateTimeWindow(
      from: DateTime(2026, 1),
      until: DateTime(2026, 2),
    );

    final byAccount = await repository.aggregateByAccount(
      accountTypes: accountTypes,
      scope: scope,
      window: window,
    );
    final byType = await repository.aggregateByAccountType(
      accountTypes: accountTypes,
      scope: scope,
      window: window,
    );
    final byDay = await repository.aggregateByAccountTypeByDay(
      accountTypes: accountTypes,
      scope: scope,
      window: window,
    );
    final byMonth = await repository.aggregateByAccountTypeByMonth(
      accountTypes: accountTypes,
      scope: scope,
      window: window,
    );

    expect(byAccount, [
      const AccountAggregate(
        accountId: 'active-cash',
        accountType: AccountType.asset,
        amountMinor: 1000,
      ),
    ]);
    expect(byType, {AccountType.asset: 1000});
    expect(byDay, {
      DateTime(2026, 1, 1): {AccountType.asset: 1000},
    });
    expect(byMonth, {
      MonthKey(year: 2026, month: 1): {AccountType.asset: 1000},
    });

    final expenseByAccount = await repository.aggregateByAccount(
      accountTypes: const {AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    final expenseByType = await repository.aggregateByAccountType(
      accountTypes: const {AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: window,
    );
    expect(expenseByAccount, isEmpty);
    expect(expenseByType, isEmpty);
  });
}

Future<void> _insertAccounts(AppDatabase database) async {
  await database.batch((batch) {
    batch.insertAll(database.accounts, [
      AccountsCompanion.insert(
        id: 'cash',
        name: '现金',
        accountType: AccountType.asset,
      ),
      AccountsCompanion.insert(
        id: 'food',
        name: '餐饮',
        accountType: AccountType.expense,
      ),
      AccountsCompanion.insert(
        id: 'dining',
        name: '聚餐',
        accountType: AccountType.expense,
        parentId: const Value('food'),
      ),
      AccountsCompanion.insert(
        id: 'salary',
        name: '工资',
        accountType: AccountType.income,
      ),
    ]);
  });
}

Future<void> _insertTransactions(AppDatabase database) async {
  await _insertTransaction(
    database,
    id: 'expense',
    purpose: BusinessPurpose.dailyExpense,
    occurredAt: DateTime(2026, 1, 5),
    entries: const [
      ('expense-category', 'dining', EntryDirection.debit, 1000),
      ('expense-cash', 'cash', EntryDirection.credit, 1000),
    ],
  );
  await _insertTransaction(
    database,
    id: 'refund',
    purpose: BusinessPurpose.refund,
    occurredAt: DateTime(2026, 1, 6),
    parentTransactionId: 'expense',
    entries: const [
      ('refund-cash', 'cash', EntryDirection.debit, 300),
      ('refund-category', 'dining', EntryDirection.credit, 300),
    ],
  );
  await _insertTransaction(
    database,
    id: 'excluded-expense',
    purpose: BusinessPurpose.dailyExpense,
    occurredAt: DateTime(2026, 1, 7),
    excludedFromStats: true,
    entries: const [
      ('excluded-category', 'dining', EntryDirection.debit, 500),
      ('excluded-cash', 'cash', EntryDirection.credit, 500),
    ],
  );
  await _insertTransaction(
    database,
    id: 'income',
    purpose: BusinessPurpose.dailyIncome,
    occurredAt: DateTime(2026, 1, 8),
    entries: const [
      ('income-cash', 'cash', EntryDirection.debit, 2000),
      ('income-category', 'salary', EntryDirection.credit, 2000),
    ],
  );
}

Future<void> _insertTransaction(
  AppDatabase database, {
  required String id,
  required BusinessPurpose purpose,
  required DateTime occurredAt,
  required List<(String, String, EntryDirection, int)> entries,
  String? parentTransactionId,
  bool excludedFromStats = false,
}) async {
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          businessPurpose: purpose,
          occurredAt: occurredAt,
          postedAt: occurredAt,
          primaryAmountMinor: entries.first.$4,
          parentTransactionId: Value(parentTransactionId),
          isExcludedFromStats: Value(excludedFromStats),
          sourceKind: SourceKind.manual,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(
      database.entries,
      entries
          .map(
            (entry) => EntriesCompanion.insert(
              id: entry.$1,
              transactionId: id,
              accountId: entry.$2,
              direction: entry.$3,
              amountMinor: entry.$4,
            ),
          )
          .toList(),
    );
  });
}
