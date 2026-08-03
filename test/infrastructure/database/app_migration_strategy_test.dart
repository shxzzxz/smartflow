import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test(
    'opening a stale v18 database rebuilds the installment constraint',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );

      final staleDatabase = _openDatabase(file);
      await staleDatabase.customStatement('DROP TABLE installment_contracts');
      await staleDatabase.customStatement(_staleInstallmentContractsSql);
      await staleDatabase.customStatement('PRAGMA user_version = 18');
      await expectLater(
        () => _insertNoTransactionContract(staleDatabase),
        throwsA(isA<Exception>()),
      );
      await staleDatabase.close();

      final upgradedDatabase = _openDatabase(file);
      addTearDown(upgradedDatabase.close);
      final version =
          await upgradedDatabase
              .customSelect('PRAGMA user_version')
              .getSingle();
      expect(version.read<int>('user_version'), 25);
      await _insertNoTransactionContract(upgradedDatabase);
    },
  );

  test(
    'opening a v19 database preserves transactions and backfills posted_at',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-posted-at-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );

      final staleDatabase = _openDatabase(file);
      await staleDatabase.customStatement('DROP TABLE transactions');
      await staleDatabase.customStatement('DROP TABLE repayments');
      await staleDatabase.customStatement(_v19TransactionsSql);
      await staleDatabase.customStatement(_v20RepaymentsSql);
      await staleDatabase.customStatement(
        "INSERT INTO transactions "
        "(id, root_transaction_id, business_purpose, occurred_at, "
        "primary_amount_minor, note, mutation_kind, business_state, "
        "is_excluded_from_stats, is_excluded_from_budget, source_kind) "
        "VALUES ('tx-1', 'tx-1', 'dailyExpense', 1735689600, 1234, "
        "'preserve me', 'original', 'current', 0, 0, 'manual')",
      );
      await staleDatabase.customStatement('PRAGMA user_version = 19');
      await staleDatabase.close();

      final upgradedDatabase = _openDatabase(file);
      addTearDown(upgradedDatabase.close);
      final version =
          await upgradedDatabase
              .customSelect('PRAGMA user_version')
              .getSingle();
      expect(version.read<int>('user_version'), 25);

      final row =
          await upgradedDatabase
              .customSelect(
                'SELECT occurred_at, posted_at, primary_amount_minor, note '
                "FROM transactions WHERE id = 'tx-1'",
              )
              .getSingle();
      expect(row.read<int>('posted_at'), row.read<int>('occurred_at'));
      expect(row.read<int>('primary_amount_minor'), 1234);
      expect(row.read<String>('note'), 'preserve me');
    },
  );

  test(
    'opening a v20 database folds current transaction versions into stable ids',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-current-transaction-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );

      final staleDatabase = _openDatabase(file);
      await staleDatabase.customStatement(
        "INSERT INTO accounts (id, name, account_type, balance_minor) "
        "VALUES ('asset-1', '测试账户', 'asset', 77777)",
      );
      await staleDatabase.customStatement('DROP TABLE transactions');
      await staleDatabase.customStatement('DROP TABLE repayments');
      await staleDatabase.customStatement(_v20TransactionsSql);
      await staleDatabase.customStatement(_v20RepaymentsSql);
      final staleRepaymentColumns =
          await staleDatabase
              .customSelect('PRAGMA table_info(repayments)')
              .get();
      expect(
        staleRepaymentColumns.map((row) => row.read<String>('name')),
        contains('root_transaction_id'),
      );
      await staleDatabase.customStatement(
        "INSERT INTO transactions "
        "(id, root_transaction_id, business_purpose, occurred_at, posted_at, "
        "primary_amount_minor, note, parent_transaction_id, mutation_kind, business_state, "
        "is_excluded_from_stats, is_excluded_from_budget, source_kind) VALUES "
        "('parent-old', 'parent-old', 'dailyExpense', 100, 100, 1000, "
        "'old version', NULL, 'original', 'replaced', 1, 1, 'manual'), "
        "('parent-middle', 'parent-old', 'dailyExpense', 150, 160, 1100, "
        "'middle version', NULL, 'correction', 'replaced', 1, 1, 'manual'), "
        "('parent-current', 'parent-old', 'dailyExpense', 200, 210, 1200, "
        "'current version', NULL, 'correction', 'current', 1, 1, 'manual'), "
        "('refund-current', 'parent-old', 'refund', 300, 310, 200, "
        "'refund', 'parent-current', 'original', 'current', 1, 1, 'manual'), "
        "('deleted-only', 'deleted-only', 'dailyExpense', 400, 400, 500, "
        "'deleted', NULL, 'original', 'canceled', 0, 0, 'manual')",
      );
      await staleDatabase.customStatement(
        "INSERT INTO transaction_details "
        "(id, transaction_id, line_no, detail_type, amount_minor) VALUES "
        "('detail-old', 'parent-old', 1, 'expenseMain', 1000), "
        "('detail-parent', 'parent-current', 1, 'expenseMain', 1200), "
        "('detail-refund', 'refund-current', 1, 'refundMain', 200), "
        "('detail-deleted', 'deleted-only', 1, 'expenseMain', 500)",
      );
      await staleDatabase.customStatement(
        "UPDATE transactions SET created_at = 10, updated_at = 11 "
        "WHERE id = 'parent-old'",
      );
      await staleDatabase.customStatement(
        "UPDATE transactions SET created_at = 20, updated_at = 21 "
        "WHERE id = 'parent-current'",
      );
      await staleDatabase.customStatement(
        "INSERT INTO entries "
        "(id, transaction_id, account_id, direction, amount_minor) VALUES "
        "('entry-old', 'parent-old', 'asset-1', 'credit', 1000), "
        "('entry-parent', 'parent-current', 'asset-1', 'credit', 1200), "
        "('entry-refund', 'refund-current', 'asset-1', 'debit', 200), "
        "('entry-deleted', 'deleted-only', 'asset-1', 'credit', 500)",
      );
      await staleDatabase.customStatement(
        "INSERT INTO repayments "
        "(id, repayment_type, target_type, target_id, root_transaction_id) "
        "VALUES ('repayment-1', 'BILL', 'BILL', 'bill-1', 'parent-old')",
      );
      await staleDatabase.customStatement(
        "INSERT INTO installment_contracts "
        "(id, liability_account_id, source_type, disbursement_account_id, "
        "disbursement_transaction_id, principal_minor, total_periods, "
        "start_date, first_repayment_date, last_repayment_date, "
        "repayment_method, interest_accrual_method, status) "
        "VALUES ('contract-1', 'liability-1', 'disbursement', 'asset-1', "
        "'parent-middle', 1200, 1, 0, 0, 0, 'equalInstallment', "
        "'daily', 'active')",
      );
      await staleDatabase.customStatement('PRAGMA user_version = 20');
      await staleDatabase.close();

      final upgradedDatabase = _openDatabase(file);
      addTearDown(upgradedDatabase.close);

      final version =
          await upgradedDatabase
              .customSelect('PRAGMA user_version')
              .getSingle();
      expect(version.read<int>('user_version'), 25);

      final transactions =
          await upgradedDatabase
              .customSelect(
                'SELECT id, parent_transaction_id, note, '
                'is_excluded_from_stats, is_excluded_from_budget, '
                'created_at, updated_at '
                'FROM transactions ORDER BY id',
              )
              .get();
      expect(transactions.map((row) => row.read<String>('id')).toList(), [
        'parent-old',
        'refund-current',
      ]);
      expect(transactions.first.read<String>('note'), 'current version');
      expect(transactions.first.read<int>('is_excluded_from_stats'), 1);
      expect(transactions.first.read<int>('is_excluded_from_budget'), 1);
      expect(transactions.first.read<int>('created_at'), 10);
      expect(transactions.first.read<int>('updated_at'), 21);
      expect(
        transactions.last.readNullable<String>('parent_transaction_id'),
        'parent-old',
      );

      final transactionColumns =
          await upgradedDatabase
              .customSelect('PRAGMA table_info(transactions)')
              .get();
      final transactionColumnNames = {
        for (final row in transactionColumns) row.read<String>('name'),
      };
      expect(transactionColumnNames, isNot(contains('root_transaction_id')));
      expect(transactionColumnNames, isNot(contains('mutation_kind')));
      expect(transactionColumnNames, isNot(contains('business_state')));

      final detailTransactionIds =
          await upgradedDatabase
              .customSelect(
                'SELECT transaction_id FROM transaction_details ORDER BY id',
              )
              .get();
      expect(
        detailTransactionIds
            .map((row) => row.read<String>('transaction_id'))
            .toList(),
        ['parent-old', 'refund-current'],
      );
      final entryTransactionIds =
          await upgradedDatabase
              .customSelect('SELECT transaction_id FROM entries ORDER BY id')
              .get();
      expect(
        entryTransactionIds
            .map((row) => row.read<String>('transaction_id'))
            .toList(),
        ['parent-old', 'refund-current'],
      );

      final repayment =
          await upgradedDatabase
              .customSelect(
                "SELECT transaction_id FROM repayments WHERE id = 'repayment-1'",
              )
              .getSingle();
      expect(repayment.read<String>('transaction_id'), 'parent-old');
      final repaymentColumns =
          await upgradedDatabase
              .customSelect('PRAGMA table_info(repayments)')
              .get();
      expect(
        repaymentColumns.map((row) => row.read<String>('name')),
        isNot(contains('root_transaction_id')),
      );

      final contract =
          await upgradedDatabase
              .customSelect(
                "SELECT disbursement_transaction_id "
                "FROM installment_contracts WHERE id = 'contract-1'",
              )
              .getSingle();
      expect(
        contract.read<String>('disbursement_transaction_id'),
        'parent-old',
      );
      final account =
          await upgradedDatabase
              .customSelect(
                "SELECT balance_minor FROM accounts WHERE id = 'asset-1'",
              )
              .getSingle();
      expect(account.read<int>('balance_minor'), 77777);
    },
  );

  test(
    'opening a v20 database rejects orphan external transaction references',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-orphan-reference-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );

      final staleDatabase = _openDatabase(file);
      await staleDatabase.customStatement('DROP TABLE transactions');
      await staleDatabase.customStatement('DROP TABLE repayments');
      await staleDatabase.customStatement(_v20TransactionsSql);
      await staleDatabase.customStatement(_v20RepaymentsSql);
      await staleDatabase.customStatement(
        "INSERT INTO installment_contracts "
        "(id, liability_account_id, source_type, disbursement_account_id, "
        "disbursement_transaction_id, principal_minor, total_periods, "
        "start_date, first_repayment_date, last_repayment_date, "
        "repayment_method, interest_accrual_method, status) "
        "VALUES ('orphan-contract', 'liability-1', 'disbursement', 'asset-1', "
        "'missing-transaction', 1200, 1, 0, 0, 0, 'equalInstallment', "
        "'daily', 'active')",
      );
      await staleDatabase.customStatement('PRAGMA user_version = 20');
      await staleDatabase.close();

      final upgradingDatabase = _openDatabase(file);
      addTearDown(upgradingDatabase.close);
      await expectLater(
        upgradingDatabase.customSelect('SELECT 1').get(),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'opening a v21 database creates import tables and indexes without foreign keys',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-import-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );

      final staleDatabase = _openDatabase(file);
      await staleDatabase.customStatement(
        'DROP INDEX IF EXISTS import_entity_mapping_unique',
      );
      await staleDatabase.customStatement(
        'DROP INDEX IF EXISTS import_batch_items_batch_idx',
      );
      await staleDatabase.customStatement(
        'DROP INDEX IF EXISTS import_batch_items_operation_idx',
      );
      await staleDatabase.customStatement(
        'DROP INDEX IF EXISTS import_batch_items_fingerprint_idx',
      );
      await staleDatabase.customStatement('DROP TABLE import_batch_items');
      await staleDatabase.customStatement('DROP TABLE import_batches');
      await staleDatabase.customStatement('DROP TABLE import_entity_mappings');
      await staleDatabase.customStatement('PRAGMA user_version = 21');
      await staleDatabase.close();

      final upgradedDatabase = _openDatabase(file);
      addTearDown(upgradedDatabase.close);
      final version =
          await upgradedDatabase
              .customSelect('PRAGMA user_version')
              .getSingle();
      expect(version.read<int>('user_version'), 25);

      for (final table in [
        'import_entity_mappings',
        'import_batches',
        'import_batch_items',
      ]) {
        final row =
            await upgradedDatabase
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$table'",
                )
                .getSingle();
        expect(row.read<String>('name'), table);
        final foreignKeys =
            await upgradedDatabase
                .customSelect('PRAGMA foreign_key_list($table)')
                .get();
        expect(foreignKeys, isEmpty);
      }

      final mappingIndexes =
          await upgradedDatabase
              .customSelect('PRAGMA index_list(import_entity_mappings)')
              .get();
      expect(
        mappingIndexes.map((row) => row.read<String>('name')),
        contains('import_entity_mapping_unique'),
      );
    },
  );

  test('opening a v24 database migrates archived category facts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-category-migration-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
    );

    final staleDatabase = _openDatabase(file);
    await staleDatabase.customStatement(
      "INSERT INTO accounts "
      "(id, name, account_type, balance_minor) VALUES "
      "('food', '餐饮', 'expense', 200), "
      "('cash', '现金', 'asset', 0)",
    );
    await staleDatabase.customStatement(
      "INSERT INTO accounts "
      "(id, name, account_type, parent_id, balance_minor, archived_at) "
      "VALUES ('old-dining', '旧聚餐', 'expense', 'food', 1000, 1)",
    );
    await staleDatabase.customStatement(
      "INSERT INTO transactions "
      "(id, business_purpose, occurred_at, posted_at, "
      "primary_amount_minor, reimbursement_expense_account_id, source_kind) "
      "VALUES ('advance', 'reimbursementAdvance', 1, 1, 1000, "
      "'old-dining', 'manual')",
    );
    await staleDatabase.customStatement(
      "INSERT INTO entries "
      "(id, transaction_id, account_id, direction, amount_minor) VALUES "
      "('category-entry', 'advance', 'old-dining', 'debit', 1000), "
      "('cash-entry', 'advance', 'cash', 'credit', 1000)",
    );
    await staleDatabase.customStatement(
      "INSERT INTO import_entity_mappings "
      "(id, source, entity_kind, source_entity_key, target_account_id) "
      "VALUES ('mapping', 'yimu', 'category', '旧聚餐', 'old-dining')",
    );
    await staleDatabase.customStatement('PRAGMA user_version = 24');
    await staleDatabase.close();

    final upgradedDatabase = _openDatabase(file);
    addTearDown(upgradedDatabase.close);
    final entry =
        await upgradedDatabase
            .customSelect(
              "SELECT account_id FROM entries WHERE id = 'category-entry'",
            )
            .getSingle();
    expect(entry.read<String>('account_id'), 'food');
    final transaction =
        await upgradedDatabase
            .customSelect(
              'SELECT reimbursement_expense_account_id FROM transactions '
              "WHERE id = 'advance'",
            )
            .getSingle();
    expect(
      transaction.read<String>('reimbursement_expense_account_id'),
      'food',
    );
    final archived =
        await upgradedDatabase
            .customSelect("SELECT id FROM accounts WHERE id = 'old-dining'")
            .get();
    expect(archived, isEmpty);
    final mapping =
        await upgradedDatabase
            .customSelect(
              "SELECT target_account_id FROM import_entity_mappings "
              "WHERE id = 'mapping'",
            )
            .getSingle();
    expect(mapping.read<String>('target_account_id'), 'food');
    final target =
        await upgradedDatabase
            .customSelect(
              "SELECT balance_minor, version FROM accounts WHERE id = 'food'",
            )
            .getSingle();
    expect(target.read<int>('balance_minor'), 1200);
    expect(target.read<int>('version'), 1);
  });
}

AppDatabase _openDatabase(File file) {
  return AppDatabase(
    DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
  );
}

Future<void> _insertNoTransactionContract(AppDatabase database) {
  return database.customStatement(
    "INSERT INTO installment_contracts "
    "(id, liability_account_id, source_type, disbursement_account_id, "
    "disbursement_transaction_id, principal_minor, total_periods, "
    "start_date, first_repayment_date, last_repayment_date, "
    "repayment_method, interest_accrual_method, status) "
    "VALUES ('migration-contract', 'loan-1', 'disbursement', NULL, NULL, "
    "120000, 12, 0, 0, 0, 'equalInstallment', 'daily', 'active')",
  );
}

const _staleInstallmentContractsSql = '''
CREATE TABLE installment_contracts (
  id TEXT NOT NULL PRIMARY KEY,
  liability_account_id TEXT NOT NULL,
  source_type TEXT NOT NULL,
  disbursement_account_id TEXT NULL,
  disbursement_transaction_id TEXT NULL,
  source_repayment_id TEXT NULL,
  principal_minor INTEGER NOT NULL,
  total_periods INTEGER NOT NULL,
  start_date INTEGER NOT NULL,
  first_repayment_date INTEGER NOT NULL,
  last_repayment_date INTEGER NOT NULL,
  repayment_method TEXT NOT NULL,
  interest_rate_period TEXT NULL,
  interest_rate_ppm INTEGER NULL,
  interest_accrual_method TEXT NOT NULL DEFAULT 'daily',
  total_fee_minor INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  note TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  CHECK (
    (source_type = 'disbursement'
      AND disbursement_account_id IS NOT NULL
      AND disbursement_transaction_id IS NOT NULL)
    OR (source_type = 'billConversion'
      AND disbursement_account_id IS NULL
      AND disbursement_transaction_id IS NULL)
  )
)
''';

const _v19TransactionsSql = '''
CREATE TABLE transactions (
  id TEXT NOT NULL PRIMARY KEY,
  root_transaction_id TEXT NULL,
  business_purpose TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  primary_amount_minor INTEGER NOT NULL,
  counterparty_name TEXT NULL,
  note TEXT NULL,
  parent_transaction_id TEXT NULL,
  reimbursement_expense_account_id TEXT NULL,
  mutation_kind TEXT NOT NULL,
  mutation_previous_transaction_id TEXT NULL,
  mutation_reason TEXT NULL,
  business_state TEXT NOT NULL,
  is_excluded_from_stats INTEGER NOT NULL DEFAULT 0,
  is_excluded_from_budget INTEGER NOT NULL DEFAULT 0,
  source_kind TEXT NOT NULL,
  owner_type TEXT NULL,
  owner_id TEXT NULL,
  owner_role TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''';

const _v20TransactionsSql = '''
CREATE TABLE transactions (
  id TEXT NOT NULL PRIMARY KEY,
  root_transaction_id TEXT NULL,
  business_purpose TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  posted_at INTEGER NOT NULL,
  primary_amount_minor INTEGER NOT NULL,
  counterparty_name TEXT NULL,
  note TEXT NULL,
  parent_transaction_id TEXT NULL,
  reimbursement_expense_account_id TEXT NULL,
  mutation_kind TEXT NOT NULL,
  mutation_previous_transaction_id TEXT NULL,
  mutation_reason TEXT NULL,
  business_state TEXT NOT NULL,
  is_excluded_from_stats INTEGER NOT NULL DEFAULT 0,
  is_excluded_from_budget INTEGER NOT NULL DEFAULT 0,
  source_kind TEXT NOT NULL,
  owner_type TEXT NULL,
  owner_id TEXT NULL,
  owner_role TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''';

const _v20RepaymentsSql = '''
CREATE TABLE repayments (
  id TEXT NOT NULL PRIMARY KEY,
  repayment_type TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  root_transaction_id TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''';
