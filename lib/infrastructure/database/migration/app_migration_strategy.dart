// ignore_for_file: experimental_member_use

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../app_database.dart';
import '../builtin_data.dart';
import 'account_profile_migration_error.dart';

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
        await _migrateArchivedCategories(database);
      }
      if (from < 26 && !await _hasColumn(database, 'budgets', 'sort_order')) {
        await migrator.addColumn(database.budgets, database.budgets.sortOrder);
      }
      if (from < 27) {
        await migrator.createTable(database.tags);
        await migrator.createTable(database.transactionTags);
        await _createTagIndexes(database);
      }
      if (from < 28) {
        try {
          await _standardizeAccountProfiles(database);
        } on AccountProfileMigrationError catch (error, stackTrace) {
          _logger.severe(
            'Account profile migration failed: $error',
            error,
            stackTrace,
          );
          rethrow;
        }
        await _normalizeReceivablePayableBudgetFlags(database);
      }
    },
  );
}

Future<void> _normalizeReceivablePayableBudgetFlags(
  AppDatabase database,
) async {
  await database.customStatement(
    "UPDATE transactions SET is_excluded_from_budget = 0 "
    "WHERE business_purpose IN "
    "('lending', 'receivableCollection', 'badDebt', 'debtRelief')",
  );
}

Future<void> _standardizeAccountProfiles(AppDatabase database) async {
  final rows =
      await database.customSelect('''
SELECT a.id,
       a.account_type,
       a.account_subtype,
       a.account_profile_key,
       a.source,
       c.kind AS credit_kind
FROM accounts AS a
LEFT JOIN credit_liability_accounts AS c ON c.account_id = a.id
ORDER BY a.id
''').get();

  final defaultedLiabilityIds = <String>[];
  for (final row in rows) {
    final id = row.read<String>('id');
    final type = row.read<String>('account_type');
    final subtype = row.readNullable<String>('account_subtype');
    final profile = row.readNullable<String>('account_profile_key');
    final source = row.read<String>('source');
    final creditKind = row.readNullable<String>('credit_kind');

    if (!const {
      'asset',
      'liability',
      'equity',
      'income',
      'expense',
    }.contains(type)) {
      throw _accountProfileMigrationError(
        accountId: id,
        reason: AccountProfileMigrationFailureReason.unknownAccountType,
        accountType: type,
        accountSubtype: subtype,
        accountProfileKey: profile,
        creditKind: creditKind,
        source: source,
      );
    }

    if (type == 'equity' || type == 'income' || type == 'expense') {
      if (profile != null || creditKind != null) {
        throw _accountProfileMigrationError(
          accountId: id,
          reason:
              AccountProfileMigrationFailureReason.nonUserAccountSignalConflict,
          accountType: type,
          accountSubtype: subtype,
          accountProfileKey: profile,
          creditKind: creditKind,
          source: source,
        );
      }
      await database.customStatement(
        'UPDATE accounts SET account_subtype = NULL, '
        'account_profile_key = NULL WHERE id = ?',
        [id],
      );
      continue;
    }

    final candidates = <_AccountClassification>[];
    if (subtype != null) {
      final candidate = switch (subtype) {
        'reimbursement' => const _AccountClassification(
          type: 'asset',
          subtype: 'receivable',
          profile: null,
        ),
        'fund' => const _AccountClassification(
          type: 'asset',
          subtype: 'fund',
          profile: null,
        ),
        'receivable' => const _AccountClassification(
          type: 'asset',
          subtype: 'receivable',
          profile: null,
        ),
        'payable' => const _AccountClassification(
          type: 'liability',
          subtype: 'payable',
          profile: null,
        ),
        'loan' => const _AccountClassification(
          type: 'liability',
          subtype: 'loan',
          profile: null,
        ),
        _ =>
          throw _accountProfileMigrationError(
            accountId: id,
            reason: AccountProfileMigrationFailureReason.unknownAccountSubtype,
            accountType: type,
            accountSubtype: subtype,
            accountProfileKey: profile,
            creditKind: creditKind,
            source: source,
          ),
      };
      candidates.add(candidate);
    }
    if (profile != null) {
      candidates.add(
        _classificationForProfile(
          accountId: id,
          profile: profile,
          accountType: type,
          subtype: subtype,
          creditKind: creditKind,
          source: source,
        ),
      );
    }
    if (creditKind != null) {
      candidates.add(switch (creditKind) {
        'credit' => const _AccountClassification(
          type: 'liability',
          subtype: 'payable',
          profile: 'credit.credit',
        ),
        'loan' => const _AccountClassification(
          type: 'liability',
          subtype: 'loan',
          profile: 'credit.loan',
        ),
        _ =>
          throw _accountProfileMigrationError(
            accountId: id,
            reason: AccountProfileMigrationFailureReason.unknownCreditKind,
            accountType: type,
            accountSubtype: subtype,
            accountProfileKey: profile,
            creditKind: creditKind,
            source: source,
          ),
      });
    }

    for (final candidate in candidates) {
      if (candidate.type != type) {
        throw _accountProfileMigrationError(
          accountId: id,
          reason: AccountProfileMigrationFailureReason.accountTypeConflict,
          accountType: type,
          accountSubtype: subtype,
          accountProfileKey: profile,
          creditKind: creditKind,
          source: source,
        );
      }
    }
    final inferredSubtypes = candidates.map((item) => item.subtype).toSet();
    if (inferredSubtypes.length > 1) {
      throw _accountProfileMigrationError(
        accountId: id,
        reason: AccountProfileMigrationFailureReason.accountSubtypeConflict,
        accountType: type,
        accountSubtype: subtype,
        accountProfileKey: profile,
        creditKind: creditKind,
        source: source,
      );
    }
    final inferredProfiles =
        candidates.map((item) => item.profile).whereType<String>().toSet();
    if (inferredProfiles.length > 1) {
      throw _accountProfileMigrationError(
        accountId: id,
        reason: AccountProfileMigrationFailureReason.accountProfileConflict,
        accountType: type,
        accountSubtype: subtype,
        accountProfileKey: profile,
        creditKind: creditKind,
        source: source,
      );
    }

    final targetSubtype =
        inferredSubtypes.singleOrNull ?? (type == 'asset' ? 'fund' : 'payable');
    String? targetProfile = inferredProfiles.singleOrNull ?? profile;
    if (targetProfile == null && source != 'builtin') {
      targetProfile = switch ((type, subtype, targetSubtype)) {
        ('asset', 'reimbursement', _) => 'ledger.reimbursement',
        ('asset', _, 'fund') => 'ledger.fund',
        ('asset', _, 'receivable') => 'ledger.receivable',
        ('liability', _, 'payable') => 'ledger.payable',
        _ => null,
      };
      if (targetProfile == null) {
        throw _accountProfileMigrationError(
          accountId: id,
          reason: AccountProfileMigrationFailureReason.missingAccountProfile,
          accountType: type,
          accountSubtype: targetSubtype,
          accountProfileKey: profile,
          creditKind: creditKind,
          source: source,
        );
      }
      if (type == 'liability') defaultedLiabilityIds.add(id);
    }
    if (profile == 'ledger.reimbursement') {
      targetProfile = 'ledger.reimbursement';
    }

    await database.customStatement(
      'UPDATE accounts SET account_subtype = ?, account_profile_key = ? '
      'WHERE id = ?',
      [targetSubtype, targetProfile, id],
    );
  }

  if (defaultedLiabilityIds.isNotEmpty) {
    _logger.warning(
      'Defaulted legacy liabilities to payable: '
      'count=${defaultedLiabilityIds.length}, ids=$defaultedLiabilityIds.',
    );
  }
  await _validateStandardizedAccounts(database);
}

_AccountClassification _classificationForProfile({
  required String accountId,
  required String profile,
  required String accountType,
  required String? subtype,
  required String? creditKind,
  required String source,
}) {
  return switch (profile) {
    'ledger.fund' => const _AccountClassification(
      type: 'asset',
      subtype: 'fund',
      profile: 'ledger.fund',
    ),
    'ledger.reimbursement' => const _AccountClassification(
      type: 'asset',
      subtype: 'receivable',
      profile: 'ledger.reimbursement',
    ),
    'ledger.receivable' => const _AccountClassification(
      type: 'asset',
      subtype: 'receivable',
      profile: 'ledger.receivable',
    ),
    'ledger.payable' => const _AccountClassification(
      type: 'liability',
      subtype: 'payable',
      profile: 'ledger.payable',
    ),
    'credit.credit' => const _AccountClassification(
      type: 'liability',
      subtype: 'payable',
      profile: 'credit.credit',
    ),
    'credit.loan' => const _AccountClassification(
      type: 'liability',
      subtype: 'loan',
      profile: 'credit.loan',
    ),
    _ =>
      throw _accountProfileMigrationError(
        accountId: accountId,
        reason: AccountProfileMigrationFailureReason.unknownAccountProfile,
        accountType: accountType,
        accountSubtype: subtype,
        accountProfileKey: profile,
        creditKind: creditKind,
        source: source,
      ),
  };
}

Future<void> _validateStandardizedAccounts(AppDatabase database) async {
  final invalid =
      await database.customSelect('''
SELECT id, account_type, account_subtype, account_profile_key, source
FROM accounts
WHERE (account_type = 'asset' AND account_subtype NOT IN ('fund', 'receivable'))
   OR (account_type = 'liability' AND account_subtype NOT IN ('payable', 'loan'))
   OR (account_type IN ('equity', 'income', 'expense')
       AND (account_subtype IS NOT NULL OR account_profile_key IS NOT NULL))
   OR (account_type IN ('asset', 'liability') AND account_subtype IS NULL)
   OR (account_type IN ('asset', 'liability') AND source != 'builtin'
       AND account_profile_key IS NULL)
   OR (source != 'builtin' AND account_type IN ('asset', 'liability') AND NOT (
        (account_type = 'asset' AND account_subtype = 'fund'
         AND account_profile_key = 'ledger.fund')
     OR (account_type = 'asset' AND account_subtype = 'receivable'
         AND account_profile_key IN ('ledger.reimbursement', 'ledger.receivable'))
     OR (account_type = 'liability' AND account_subtype = 'payable'
         AND account_profile_key IN ('ledger.payable', 'credit.credit'))
     OR (account_type = 'liability' AND account_subtype = 'loan'
         AND account_profile_key = 'credit.loan')
   ))
LIMIT 1
''').getSingleOrNull();
  if (invalid != null) {
    throw _accountProfileMigrationError(
      accountId: invalid.read<String>('id'),
      reason:
          AccountProfileMigrationFailureReason.standardizedInvariantViolation,
      accountType: invalid.read<String>('account_type'),
      accountSubtype: invalid.readNullable<String>('account_subtype'),
      accountProfileKey: invalid.readNullable<String>('account_profile_key'),
      creditKind: null,
      source: invalid.read<String>('source'),
    );
  }
}

AccountProfileMigrationError _accountProfileMigrationError({
  required String accountId,
  required AccountProfileMigrationFailureReason reason,
  required String? accountType,
  required String? accountSubtype,
  required String? accountProfileKey,
  required String? creditKind,
  required String? source,
}) {
  return AccountProfileMigrationError(
    accountId: accountId,
    reason: reason,
    accountType: accountType,
    accountSubtype: accountSubtype,
    accountProfileKey: accountProfileKey,
    creditKind: creditKind,
    source: source,
  );
}

class _AccountClassification {
  const _AccountClassification({
    required this.type,
    required this.subtype,
    required this.profile,
  });

  final String type;
  final String subtype;
  final String? profile;
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

/// v25：旧归档分类的 parent_id 是其活跃归并目标。将历史分类事实改写为
/// 目标分类后删除旧节点，使升级数据与“先迁移交易、再删除分类”语义一致。
Future<void> _migrateArchivedCategories(AppDatabase database) async {
  await database.customStatement('''
CREATE TEMP TABLE archived_category_migrations (
  source_id TEXT NOT NULL PRIMARY KEY,
  target_id TEXT NOT NULL
)
''');
  await database.customStatement('''
INSERT INTO archived_category_migrations (source_id, target_id)
SELECT archived.id, target.id
FROM accounts AS archived
JOIN accounts AS target ON target.id = archived.parent_id
WHERE archived.archived_at IS NOT NULL
  AND archived.account_type IN ('income', 'expense')
  AND target.archived_at IS NULL
  AND target.account_type = archived.account_type
''');
  await database.customStatement('''
UPDATE accounts
SET balance_minor = balance_minor + (
      SELECT COALESCE(SUM(source.balance_minor), 0)
      FROM archived_category_migrations AS migration
      JOIN accounts AS source ON source.id = migration.source_id
      WHERE migration.target_id = accounts.id
    ),
    version = version + 1,
    updated_at = strftime('%s', CURRENT_TIMESTAMP)
WHERE id IN (
  SELECT target_id FROM archived_category_migrations
)
''');
  await database.customStatement('''
UPDATE entries
SET account_id = (
  SELECT migration.target_id
  FROM archived_category_migrations AS migration
  WHERE migration.source_id = entries.account_id
)
WHERE account_id IN (
  SELECT source_id FROM archived_category_migrations
)
''');
  await database.customStatement('''
UPDATE transactions
SET reimbursement_expense_account_id = (
  SELECT migration.target_id
  FROM archived_category_migrations AS migration
  WHERE migration.source_id = transactions.reimbursement_expense_account_id
)
WHERE reimbursement_expense_account_id IN (
  SELECT source_id FROM archived_category_migrations
)
''');
  await database.customStatement('''
UPDATE import_entity_mappings
SET target_account_id = (
  SELECT migration.target_id
  FROM archived_category_migrations AS migration
  WHERE migration.source_id = import_entity_mappings.target_account_id
)
WHERE entity_kind = 'category'
  AND target_account_id IN (
    SELECT source_id FROM archived_category_migrations
  )
''');
  await database.customStatement('''
DELETE FROM accounts
WHERE id IN (SELECT source_id FROM archived_category_migrations)
''');
  await database.customStatement('DROP TABLE archived_category_migrations');
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
  await _createTagIndexes(database);
  await ensureBuiltinData(database);
}

Future<void> _createTagIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS tags_name_unique ON tags (name)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_tags_tag_idx '
    'ON transaction_tags (tag_id)',
  );
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
