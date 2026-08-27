// ignore_for_file: experimental_member_use

import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/entry.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../app_database.dart';
import 'v29_transaction_line_backfiller.dart';

/// v29: 把 transaction_details 重建为 transaction_lines。
///
/// This file owns only Drift/SQL orchestration. The old v28 conversion rules
/// live in [V29TransactionLineBackfiller] and must remain independent from the
/// current domain posting implementation.
Future<void> migrateTransactionLines(
  AppDatabase database,
  Migrator migrator,
) async {
  await migrator.createTable(database.transactionLines);
  await createTransactionLineIndexes(database);
  await _backfillTransactionLines(database);
  await database.customStatement('DROP TABLE transaction_details');
  await _dropReimbursementExpenseColumn(database);
}

Future<void> createTransactionLineIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_lines_transaction_idx '
    'ON transaction_lines (transaction_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_lines_account_role_idx '
    'ON transaction_lines (account_id, role)',
  );
}

Future<void> _backfillTransactionLines(AppDatabase database) async {
  final accountTypes = await _loadAccountTypes(database);
  final systemAccountIds = await _loadSystemAccountIds(database);
  final entriesByTransaction = await _loadEntries(database);
  final legacyAmountsByTransaction = await _loadLegacyAmounts(database);
  final backfiller = V29TransactionLineBackfiller();

  final transactionRows = await database.customSelect('''
SELECT transaction_row.id,
       transaction_row.business_purpose,
       transaction_row.primary_amount_minor,
       transaction_row.reimbursement_expense_account_id,
       parent_row.business_purpose AS parent_business_purpose,
       parent_row.reimbursement_expense_account_id
         AS parent_reimbursement_expense_account_id
FROM transactions AS transaction_row
LEFT JOIN transactions AS parent_row
  ON parent_row.id = transaction_row.parent_transaction_id
ORDER BY transaction_row.id
''').get();

  final companions = <TransactionLinesCompanion>[];
  final primaryAmountCorrections = <String, int>{};
  for (final row in transactionRows) {
    final transactionId = row.read<String>('id');
    final snapshot = V29TransactionSnapshot(
      transactionId: transactionId,
      businessPurpose: BusinessPurpose.values.byName(
        row.read<String>('business_purpose'),
      ),
      primaryAmount: Money(minorUnits: row.read<int>('primary_amount_minor')),
      reimbursementExpenseAccountId: row.readNullable<String>(
        'reimbursement_expense_account_id',
      ),
      parentBusinessPurpose: switch (row.readNullable<String>(
        'parent_business_purpose',
      )) {
        final value? => BusinessPurpose.values.byName(value),
        null => null,
      },
      parentReimbursementExpenseAccountId: row.readNullable<String>(
        'parent_reimbursement_expense_account_id',
      ),
      entries: entriesByTransaction[transactionId] ?? const <Entry>[],
      legacyAmounts:
          legacyAmountsByTransaction[transactionId] ?? const <String, int>{},
      accountTypes: accountTypes,
      systemAccountIds: systemAccountIds,
    );
    final result = backfiller.convert(snapshot);
    final correction = result.primaryAmountCorrectionMinor;
    if (correction != null) {
      primaryAmountCorrections[transactionId] = correction;
    }
    companions.addAll([
      for (final line in result.lines)
        TransactionLinesCompanion.insert(
          id: line.id,
          transactionId: transactionId,
          lineNo: line.lineNo,
          role: line.role,
          accountId: Value(line.accountId),
          amountMinor: line.amount.minorUnits,
        ),
    ]);
  }

  if (companions.isNotEmpty) {
    await database.batch(
      (batch) => batch.insertAll(database.transactionLines, companions),
    );
  }
  for (final correction in primaryAmountCorrections.entries) {
    await database.customStatement(
      'UPDATE transactions SET primary_amount_minor = ? WHERE id = ?',
      [correction.value, correction.key],
    );
  }
}

Future<Map<String, AccountType>> _loadAccountTypes(AppDatabase database) async {
  final rows = await database
      .customSelect('SELECT id, account_type FROM accounts')
      .get();
  return {
    for (final row in rows)
      row.read<String>('id'): AccountType.values.byName(
        row.read<String>('account_type'),
      ),
  };
}

Future<Map<SystemKey, String>> _loadSystemAccountIds(
  AppDatabase database,
) async {
  final rows = await database
      .customSelect(
        'SELECT id, system_key FROM accounts WHERE system_key IS NOT NULL',
      )
      .get();
  return {
    for (final row in rows)
      SystemKey.values.byName(row.read<String>('system_key')): row.read<String>(
        'id',
      ),
  };
}

Future<Map<String, List<Entry>>> _loadEntries(AppDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT id, transaction_id, account_id, direction, amount_minor '
        'FROM entries ORDER BY transaction_id, id',
      )
      .get();
  final result = <String, List<Entry>>{};
  for (final row in rows) {
    final transactionId = row.read<String>('transaction_id');
    result
        .putIfAbsent(transactionId, () => <Entry>[])
        .add(
          Entry(
            id: row.read<String>('id'),
            transactionId: transactionId,
            accountId: row.read<String>('account_id'),
            direction: EntryDirection.values.byName(
              row.read<String>('direction'),
            ),
            amount: Money(minorUnits: row.read<int>('amount_minor')),
          ),
        );
  }
  return result;
}

/// 旧分项只有类型与金额,不含账户;账户在版本化转换器中从分录反推。
Future<Map<String, Map<String, int>>> _loadLegacyAmounts(
  AppDatabase database,
) async {
  final rows = await database
      .customSelect(
        'SELECT transaction_id, detail_type, SUM(amount_minor) AS total '
        'FROM transaction_details GROUP BY transaction_id, detail_type',
      )
      .get();
  final result = <String, Map<String, int>>{};
  for (final row in rows) {
    result.putIfAbsent(
      row.read<String>('transaction_id'),
      () => <String, int>{},
    )[row.read<String>('detail_type')] = row.read<int>(
      'total',
    );
  }
  return result;
}

Future<void> _dropReimbursementExpenseColumn(AppDatabase database) async {
  await database.customStatement('''
CREATE TABLE transactions_v29 (
  id TEXT NOT NULL PRIMARY KEY,
  business_purpose TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  posted_at INTEGER NOT NULL,
  primary_amount_minor INTEGER NOT NULL,
  counterparty_name TEXT NULL,
  note TEXT NULL,
  parent_transaction_id TEXT NULL,
  is_excluded_from_stats INTEGER NOT NULL DEFAULT 0
    CHECK (is_excluded_from_stats IN (0, 1)),
  is_excluded_from_budget INTEGER NOT NULL DEFAULT 0
    CHECK (is_excluded_from_budget IN (0, 1)),
  source_kind TEXT NOT NULL,
  owner_type TEXT NULL,
  owner_id TEXT NULL,
  owner_role TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''');
  await database.customStatement('''
INSERT INTO transactions_v29 (
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  counterparty_name, note, parent_transaction_id, is_excluded_from_stats,
  is_excluded_from_budget, source_kind, owner_type, owner_id, owner_role,
  created_at, updated_at
)
SELECT
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  counterparty_name, note, parent_transaction_id, is_excluded_from_stats,
  is_excluded_from_budget, source_kind, owner_type, owner_id, owner_role,
  created_at, updated_at
FROM transactions
''');
  await database.customStatement('DROP TABLE transactions');
  await database.customStatement(
    'ALTER TABLE transactions_v29 RENAME TO transactions',
  );
}
