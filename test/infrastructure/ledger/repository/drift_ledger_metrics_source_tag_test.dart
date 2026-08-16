import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_ledger_metrics_source.dart';

import '../../../helper/test_app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = createTestDatabase();
    await _insertAccounts(database);
  });

  tearDown(() async => database.close());

  test('aggregates tag buckets with the stats scope', () async {
    await _insertTransaction(
      database,
      id: 'expense',
      occurredAt: DateTime(2026, 1, 5),
      entries: const [
        ('expense-category', 'dining', EntryDirection.debit, 1000),
        ('expense-cash', 'cash', EntryDirection.credit, 1000),
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
    await _link(database, 'expense', 'tag-travel');
    await _link(database, 'income', 'tag-travel');

    final rows = await DriftLedgerMetricsSource(database).aggregateByTag(
      accountTypes: const {AccountType.income, AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: DateTimeWindow(from: DateTime(2026, 1), until: DateTime(2026, 2)),
    );

    expect(rows, hasLength(2));
    expect(
      rows.singleWhere((row) => row.accountType == AccountType.expense),
      const TagAggregate(
        tagId: 'tag-travel',
        accountType: AccountType.expense,
        amountMinor: 1000,
      ),
    );
    expect(
      rows.singleWhere((row) => row.accountType == AccountType.income),
      const TagAggregate(
        tagId: 'tag-travel',
        accountType: AccountType.income,
        amountMinor: 2000,
      ),
    );
  });

  test('untagged transactions fall into the null bucket', () async {
    await _insertTransaction(
      database,
      id: 'untagged',
      occurredAt: DateTime(2026, 1, 5),
      entries: const [
        ('untagged-category', 'dining', EntryDirection.debit, 500),
        ('untagged-cash', 'cash', EntryDirection.credit, 500),
      ],
    );

    final rows = await DriftLedgerMetricsSource(database).aggregateByTag(
      accountTypes: const {AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: DateTimeWindow(from: DateTime(2026, 1), until: DateTime(2026, 2)),
    );

    expect(rows, hasLength(1));
    expect(
      rows.single,
      const TagAggregate(
        tagId: null,
        accountType: AccountType.expense,
        amountMinor: 500,
      ),
    );
  });

  test('multi-tag transactions count into every tag bucket', () async {
    await _insertTransaction(
      database,
      id: 'expense',
      occurredAt: DateTime(2026, 1, 5),
      entries: const [
        ('expense-category', 'dining', EntryDirection.debit, 800),
        ('expense-cash', 'cash', EntryDirection.credit, 800),
      ],
    );
    await _link(database, 'expense', 'tag-travel');
    await _link(database, 'expense', 'tag-work');

    final rows = await DriftLedgerMetricsSource(database).aggregateByTag(
      accountTypes: const {AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: DateTimeWindow(from: DateTime(2026, 1), until: DateTime(2026, 2)),
    );

    expect(
      {for (final row in rows) row.tagId: row.amountMinor},
      {'tag-travel': 800, 'tag-work': 800},
    );
  });

  test('refund children offset the tag bucket of their group root', () async {
    await _insertTransaction(
      database,
      id: 'expense',
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
    await _link(database, 'expense', 'tag-travel');

    final rows = await DriftLedgerMetricsSource(database).aggregateByTag(
      accountTypes: const {AccountType.expense},
      scope: TransactionScopeFilter.stats,
      window: DateTimeWindow(from: DateTime(2026, 1), until: DateTime(2026, 2)),
    );

    expect(
      rows.single,
      const TagAggregate(
        tagId: 'tag-travel',
        accountType: AccountType.expense,
        amountMinor: 700,
      ),
    );
  });

  test(
    'stats-excluded transactions and out-of-window rows are dropped',
    () async {
      await _insertTransaction(
        database,
        id: 'excluded',
        occurredAt: DateTime(2026, 1, 5),
        excludedFromStats: true,
        entries: const [
          ('excluded-category', 'dining', EntryDirection.debit, 500),
          ('excluded-cash', 'cash', EntryDirection.credit, 500),
        ],
      );
      await _insertTransaction(
        database,
        id: 'outside-window',
        occurredAt: DateTime(2026, 2, 5),
        entries: const [
          ('outside-category', 'dining', EntryDirection.debit, 200),
          ('outside-cash', 'cash', EntryDirection.credit, 200),
        ],
      );
      await _link(database, 'excluded', 'tag-travel');
      await _link(database, 'outside-window', 'tag-travel');

      final rows = await DriftLedgerMetricsSource(database).aggregateByTag(
        accountTypes: const {AccountType.expense},
        scope: TransactionScopeFilter.stats,
        window: DateTimeWindow(
          from: DateTime(2026, 1),
          until: DateTime(2026, 2),
        ),
      );

      expect(rows, isEmpty);
    },
  );
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
        id: 'dining',
        name: '聚餐',
        accountType: AccountType.expense,
      ),
      AccountsCompanion.insert(
        id: 'salary',
        name: '工资',
        accountType: AccountType.income,
      ),
    ]);
  });
}

Future<void> _insertTransaction(
  AppDatabase database, {
  required String id,
  required DateTime occurredAt,
  required List<(String, String, EntryDirection, int)> entries,
  BusinessPurpose purpose = BusinessPurpose.dailyExpense,
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
    batch.insertAll(database.entries, [
      for (final (entryId, accountId, direction, amount) in entries)
        EntriesCompanion.insert(
          id: entryId,
          transactionId: id,
          accountId: accountId,
          direction: direction,
          amountMinor: amount,
        ),
    ]);
  });
}

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
