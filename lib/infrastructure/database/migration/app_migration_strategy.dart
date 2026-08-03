// ignore_for_file: experimental_member_use

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../app_database.dart';
import '../builtin_data.dart';

final _logger = Logger('infra.database');

MigrationStrategy buildMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      _logger.info('Creating database schema at v${database.schemaVersion}.');
      await _createCurrentSchema(database, migrator);
    },
    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        _logger.info(
          'Database opened after upgrade: '
          'v${details.versionBefore} -> v${details.versionNow}.',
        );
      } else {
        _logger.fine('Database opened at v${details.versionNow}.');
      }
      await ensureBuiltinData(database);
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 19) {
        // Versions before v19 still follow the development-channel rebuild
        // policy. The v19 -> v20 step below is the first compatible upgrade.
        _logger.warning(
          'Database schema v$from predates v19; rebuilding all tables.',
        );
        for (final table in database.allTables.toList().reversed) {
          await migrator.drop(table);
        }
        await _createCurrentSchema(database, migrator);
        return;
      }
      _logger.info('Upgrading database schema: v$from -> v$to.');
      if (from < 20) {
        await database.customStatement(
          'ALTER TABLE transactions ADD COLUMN posted_at INTEGER',
        );
        await database.customStatement(
          'UPDATE transactions SET posted_at = occurred_at',
        );
      }
      if (from < 21) {
        await _migrateCurrentStateTransactions(database);
      }
      if (from < 22) {
        await _createImportTables(database, migrator);
        await _createImportIndexes(database);
      }
      if (from < 23) {
        await migrator.createTable(database.billGenerationSuppressions);
      }
      if (from < 24) {
        await migrator.createTable(database.accountGroups);
        if (!await _hasColumn(database, 'accounts', 'group_id')) {
          await migrator.addColumn(
            database.accounts,
            database.accounts.groupId,
          );
        }
      }
      if (from < 25) {
        await _reactivateArchivedCategories(database);
      }
    },
  );
}

/// 测试夹具或开发库可能已含 v24 列但仍保留旧 user_version；避免重复加列。
Future<bool> _hasColumn(
  AppDatabase database,
  String tableName,
  String columnName,
) async {
  final columns =
      await database.customSelect('PRAGMA table_info($tableName)').get();
  return columns.any((row) => row.read<String>('name') == columnName);
}

/// v25：分类删除语义从“归档挂载归并”改为“有引用禁止删除”。
/// 历史库中被分录或报销垫付引用的归档分类节点重新转为活跃分类；
/// 挂载在二级分类下的节点重挂到其一级分类，维持活跃树恒为两层。
Future<void> _reactivateArchivedCategories(AppDatabase database) async {
  await database.customStatement('''
UPDATE accounts
SET parent_id = (
  SELECT CASE
    WHEN parent.parent_id IS NULL THEN parent.id
    ELSE parent.parent_id
  END
  FROM accounts AS parent
  WHERE parent.id = accounts.parent_id
),
    archived_at = NULL
WHERE archived_at IS NOT NULL
  AND account_type IN ('income', 'expense')
''');
}

Future<void> _createCurrentSchema(
  AppDatabase database,
  Migrator migrator,
) async {
  await migrator.createAll();
  await database.customStatement(
    'CREATE UNIQUE INDEX budgets_total_unique '
    'ON budgets (month_key) '
    'WHERE account_id IS NULL',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX budgets_account_unique '
    'ON budgets (month_key, account_id) '
    'WHERE account_id IS NOT NULL',
  );
  await _createTransactionRowIndexes(database);
  await database.customStatement(
    'CREATE INDEX entries_transaction_idx ON entries (transaction_id)',
  );
  await database.customStatement(
    'CREATE INDEX entries_account_transaction_idx '
    'ON entries (account_id, transaction_id)',
  );
  await database.customStatement(
    'CREATE INDEX installment_contracts_liability_status_idx '
    'ON installment_contracts (liability_account_id, status)',
  );
  await database.customStatement(
    'CREATE INDEX installment_schedules_contract_period_idx '
    'ON installment_schedules (contract_id, period_no)',
  );
  await database.customStatement(
    'CREATE INDEX installment_contracts_disbursement_tx_idx '
    'ON installment_contracts (disbursement_transaction_id) '
    'WHERE disbursement_transaction_id IS NOT NULL',
  );
  await _createInstallmentSourceRepaymentIndex(database);
  await _createBillIndexes(database);
  await _createRepaymentIndexes(database);
  await _createImportIndexes(database);
  await ensureBuiltinData(database);
}

Future<void> _createImportTables(
  AppDatabase database,
  Migrator migrator,
) async {
  await migrator.createTable(database.importEntityMappings);
  await migrator.createTable(database.importBatches);
  await migrator.createTable(database.importBatchItems);
}

Future<void> _createInstallmentSourceRepaymentIndex(
  AppDatabase database,
) async {
  await database.customStatement(
    'CREATE INDEX installment_contracts_source_repayment_idx '
    'ON installment_contracts (source_repayment_id) '
    'WHERE source_repayment_id IS NOT NULL',
  );
}

Future<void> _createBillIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX bills_account_period_idx ON bills (account_id, period)',
  );
  await database.customStatement(
    'CREATE INDEX bill_items_bill_idx ON bill_items (bill_id)',
  );
  await database.customStatement(
    'CREATE INDEX bill_items_contract_idx ON bill_items (contract_id) '
    'WHERE contract_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX bill_items_consumption_unique '
    'ON bill_items (bill_id) WHERE item_type = \'consumption\'',
  );
}

Future<void> _createRepaymentIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS repayments_target_idx '
    'ON repayments (target_type, target_id, created_at)',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS repayments_transaction_unique '
    'ON repayments (transaction_id) '
    'WHERE transaction_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS repayment_items_repayment_idx '
    'ON repayment_items (repayment_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS repayment_items_bill_item_idx '
    'ON repayment_items (bill_item_id) '
    'WHERE bill_item_id IS NOT NULL',
  );
}

Future<void> _createTransactionRowIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_top_level_occurred_idx '
    'ON transactions (parent_transaction_id, occurred_at, id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_parent_purpose_idx '
    'ON transactions (parent_transaction_id, business_purpose, '
    'occurred_at, id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_occurred_stats_idx '
    'ON transactions (occurred_at, is_excluded_from_stats)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_posted_billing_idx '
    'ON transactions (business_purpose, posted_at)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_owner_idx '
    'ON transactions (owner_type, owner_id, owner_role)',
  );
}

Future<void> _migrateCurrentStateTransactions(AppDatabase database) async {
  await database.customStatement('''
CREATE TEMP TABLE transaction_id_map (
  old_id TEXT NOT NULL PRIMARY KEY,
  new_id TEXT NOT NULL,
  parent_id TEXT NULL
)
''');
  await database.customStatement('''
INSERT INTO transaction_id_map (old_id, new_id, parent_id)
SELECT id, COALESCE(root_transaction_id, id), NULL
FROM transactions
WHERE business_state = 'current'
  AND parent_transaction_id IS NULL
''');
  await database.customStatement('''
INSERT INTO transaction_id_map (old_id, new_id, parent_id)
SELECT child.id, child.id, parent.new_id
FROM transactions AS child
JOIN transaction_id_map AS parent
  ON parent.parent_id IS NULL
 AND parent.new_id = COALESCE(
   child.root_transaction_id,
   (SELECT old_parent.root_transaction_id
    FROM transactions AS old_parent
    WHERE old_parent.id = child.parent_transaction_id),
   child.parent_transaction_id
 )
WHERE child.business_state = 'current'
  AND child.parent_transaction_id IS NOT NULL
''');
  await database.customStatement('''
CREATE TEMP TABLE transaction_reference_map (
  old_id TEXT NOT NULL PRIMARY KEY,
  new_id TEXT NOT NULL
)
''');
  await database.customStatement('''
INSERT INTO transaction_reference_map (old_id, new_id)
SELECT version.id, current_parent.new_id
FROM transactions AS version
JOIN transaction_id_map AS current_parent
  ON current_parent.parent_id IS NULL
 AND current_parent.new_id = COALESCE(version.root_transaction_id, version.id)
WHERE version.parent_transaction_id IS NULL
''');
  await _validateExternalTransactionReferences(database);

  await database.customStatement(_transactionsV21Sql);
  await database.customStatement('''
INSERT INTO transactions_v21 (
  id,
  business_purpose,
  occurred_at,
  posted_at,
  primary_amount_minor,
  counterparty_name,
  note,
  parent_transaction_id,
  reimbursement_expense_account_id,
  is_excluded_from_stats,
  is_excluded_from_budget,
  source_kind,
  owner_type,
  owner_id,
  owner_role,
  created_at,
  updated_at
)
SELECT
  mapping.new_id,
  transaction_row.business_purpose,
  transaction_row.occurred_at,
  transaction_row.posted_at,
  transaction_row.primary_amount_minor,
  transaction_row.counterparty_name,
  transaction_row.note,
  mapping.parent_id,
  transaction_row.reimbursement_expense_account_id,
  transaction_row.is_excluded_from_stats,
  transaction_row.is_excluded_from_budget,
  transaction_row.source_kind,
  transaction_row.owner_type,
  transaction_row.owner_id,
  transaction_row.owner_role,
  CASE
    WHEN mapping.parent_id IS NULL THEN COALESCE(
      (SELECT original.created_at
       FROM transactions AS original
       WHERE original.id = mapping.new_id),
      transaction_row.created_at
    )
    ELSE transaction_row.created_at
  END,
  transaction_row.updated_at
FROM transaction_id_map AS mapping
JOIN transactions AS transaction_row ON transaction_row.id = mapping.old_id
''');

  await database.customStatement('''
DELETE FROM transaction_details
WHERE transaction_id NOT IN (SELECT old_id FROM transaction_id_map)
''');
  await database.customStatement('''
UPDATE transaction_details
SET transaction_id = (
  SELECT new_id
  FROM transaction_id_map
  WHERE old_id = transaction_details.transaction_id
)
''');
  await database.customStatement('''
DELETE FROM entries
WHERE transaction_id NOT IN (SELECT old_id FROM transaction_id_map)
''');
  await database.customStatement('''
UPDATE entries
SET transaction_id = (
  SELECT new_id
  FROM transaction_id_map
  WHERE old_id = entries.transaction_id
)
''');

  await database.customStatement(_repaymentsV21Sql);
  await database.customStatement('''
INSERT INTO repayments_v21 (
  id,
  repayment_type,
  target_type,
  target_id,
  transaction_id,
  created_at,
  updated_at
)
SELECT
  repayment.id,
  repayment.repayment_type,
  repayment.target_type,
  repayment.target_id,
  CASE
    WHEN repayment.root_transaction_id IS NULL THEN NULL
    ELSE (
      SELECT mapping.new_id
      FROM transaction_reference_map AS mapping
      WHERE mapping.old_id = repayment.root_transaction_id
         OR mapping.new_id = repayment.root_transaction_id
      LIMIT 1
    )
  END,
  repayment.created_at,
  repayment.updated_at
FROM repayments AS repayment
''');

  await database.customStatement('''
UPDATE installment_contracts
SET disbursement_transaction_id = (
  SELECT mapping.new_id
  FROM transaction_reference_map AS mapping
  WHERE mapping.old_id = installment_contracts.disbursement_transaction_id
     OR mapping.new_id = installment_contracts.disbursement_transaction_id
  LIMIT 1
)
WHERE disbursement_transaction_id IS NOT NULL
''');

  await database.customStatement('DROP TABLE transactions');
  await database.customStatement(
    'ALTER TABLE transactions_v21 RENAME TO transactions',
  );
  await database.customStatement('DROP TABLE repayments');
  await database.customStatement(
    'ALTER TABLE repayments_v21 RENAME TO repayments',
  );
  await database.customStatement('DROP TABLE transaction_reference_map');
  await database.customStatement('DROP TABLE transaction_id_map');

  await _createTransactionRowIndexes(database);
  await _createRepaymentIndexes(database);
}

Future<void> _createImportIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS import_entity_mapping_unique '
    'ON import_entity_mappings (source, entity_kind, source_entity_key)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS import_batch_items_batch_idx '
    'ON import_batch_items (batch_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS import_batch_items_operation_idx '
    'ON import_batch_items (source_operation_key)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS import_batch_items_fingerprint_idx '
    'ON import_batch_items (source_operation_fingerprint, fingerprint_version)',
  );
}

Future<void> _validateExternalTransactionReferences(
  AppDatabase database,
) async {
  final row =
      await database.customSelect('''
SELECT
  (SELECT COUNT(*)
   FROM repayments AS repayment
   WHERE repayment.root_transaction_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM transaction_reference_map AS mapping
       WHERE mapping.old_id = repayment.root_transaction_id
          OR mapping.new_id = repayment.root_transaction_id
     )) AS orphan_repayments,
  (SELECT COUNT(*)
   FROM installment_contracts AS contract
   WHERE contract.disbursement_transaction_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM transaction_reference_map AS mapping
       WHERE mapping.old_id = contract.disbursement_transaction_id
          OR mapping.new_id = contract.disbursement_transaction_id
     )) AS orphan_contracts
''').getSingle();
  final orphanRepayments = row.read<int>('orphan_repayments');
  final orphanContracts = row.read<int>('orphan_contracts');
  if (orphanRepayments > 0 || orphanContracts > 0) {
    throw StateError(
      'Cannot migrate orphan ledger transaction references: '
      '$orphanRepayments repayments, $orphanContracts installment contracts.',
    );
  }
}

const _transactionsV21Sql = '''
CREATE TABLE transactions_v21 (
  id TEXT NOT NULL PRIMARY KEY,
  business_purpose TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  posted_at INTEGER NOT NULL,
  primary_amount_minor INTEGER NOT NULL,
  counterparty_name TEXT NULL,
  note TEXT NULL,
  parent_transaction_id TEXT NULL,
  reimbursement_expense_account_id TEXT NULL,
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
''';

const _repaymentsV21Sql = '''
CREATE TABLE repayments_v21 (
  id TEXT NOT NULL PRIMARY KEY,
  repayment_type TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  transaction_id TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  CHECK (repayment_type IN (
    'BILL', 'INSTALLMENT', 'PREPAYMENT', 'UNATTRIBUTED'
  )),
  CHECK (target_type IN ('BILL', 'CONTRACT', 'ACCOUNT')),
  CHECK (
    (repayment_type IN ('BILL', 'INSTALLMENT') AND target_type = 'BILL')
    OR (repayment_type = 'PREPAYMENT' AND target_type = 'CONTRACT')
    OR (repayment_type = 'UNATTRIBUTED' AND target_type = 'ACCOUNT')
  ),
  CHECK (repayment_type <> 'INSTALLMENT' OR transaction_id IS NULL)
)
''';
