import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/migration/account_profile_migration_error.dart';

void main() {
  test('v32 drops scalar contract columns and preserves authoritative staged terms', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-v32-stage-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/smartflow.sqlite');
    final old = _openDatabase(file);
    await _restoreFlatContractColumns(old);
    await old.customStatement(
      "INSERT INTO installment_contracts "
      "(id, liability_account_id, source_type, principal_minor, start_date, status, total_periods, interest_rate_ppm) "
      "VALUES ('staged', 'loan', 'disbursement', 10000, 1700000000, 'active', 999, 999999)",
    );
    await old.customStatement(
      "INSERT INTO installment_stage_configs "
      "(id, owner_type, owner_id, position, stage_kind, repayment_method, interval_months, periods, "
      "rate_period, rate_ppm, accrual, first_date, fee_minor, end_principal_minor) VALUES "
      "('stage-1', 'contract', 'staged', 0, 'repayment', 'interestFirst', 1, 2, 'annual', 36000, 'daily', 1703000000, 0, NULL), "
      "('stage-2', 'contract', 'staged', 1, 'repayment', 'equalPrincipal', 1, 3, 'monthly', 2000, 'monthly', 1709000000, 150, NULL)",
    );
    await old.customStatement(
      "INSERT INTO installment_schedules "
      "(id, contract_id, stage_id, period_no, expected_repayment_date, expected_principal_minor, status) "
      "VALUES ('period-1', 'staged', 'stage-1', 1, 1703000000, 0, 'paid')",
    );
    await old.customStatement(
      "INSERT INTO repayments "
      "(id, repayment_type, target_type, target_id, repayment_date) "
      "VALUES ('repayment-1', 'PREPAYMENT', 'CONTRACT', 'staged', 1704000000)",
    );
    await old.customStatement(
      "INSERT INTO repayment_items "
      "(id, repayment_id, allocated_principal_minor, allocated_interest_minor, allocated_fee_minor, allocated_discount_minor) "
      "VALUES ('allocation-1', 'repayment-1', 1000, 0, 0, 0)",
    );
    final before = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'installment_stage_configs',
      'installment_schedules',
      'repayments',
      'repayment_items',
    ]) {
      before[table] = (await old.customSelect('SELECT * FROM $table').get())
          .map((r) => r.data)
          .toList();
    }
    await old.customStatement('PRAGMA user_version = 32');
    await old.close();
    final current = _openDatabase(file);
    addTearDown(current.close);
    for (final entry in before.entries) {
      expect(
        (await current.customSelect('SELECT * FROM ${entry.key}').get())
            .map((r) => r.data)
            .toList(),
        entry.value,
      );
    }
    final columns =
        (await current
                .customSelect('PRAGMA table_info(installment_contracts)')
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(columns, isNot(contains('total_periods')));
    expect(columns, isNot(contains('interest_rate_ppm')));
    expect(
      (await current.select(current.installmentContracts).getSingle())
          .principalMinor,
      10000,
    );
  });

  test(
    'v31 migrates each contract to its own stage without changing schedules',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-stage-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/smartflow.sqlite');
      final stale = _openDatabase(file);
      await _restoreFlatContractColumns(stale);
      await stale.customStatement(
        "INSERT INTO installment_contracts "
        "(id, liability_account_id, source_type, principal_minor, total_periods, start_date, "
        "first_repayment_date, last_repayment_date, repayment_method, interest_rate_period, "
        "interest_rate_ppm, interest_accrual_method, total_fee_minor, status) VALUES "
        "('legacy', 'loan', 'disbursement', 10000, 2, 1700000000, 1703000000, 1706000000, "
        "'equalInstallment', 'annual', 36000, 'daily', 500, 'active')",
      );
      await stale.customStatement(
        "INSERT INTO installment_schedules "
        "(id, contract_id, period_no, expected_repayment_date, expected_principal_minor, "
        "expected_interest_minor, expected_fee_minor, status) VALUES "
        "('schedule', 'legacy', 1, 1703000010, 4999, 301, 250, 'paid')",
      );
      final before =
          (await stale
                  .customSelect("SELECT * FROM installment_schedules")
                  .get())
              .single
              .data;
      await stale.customStatement('DROP TABLE installment_stage_configs');
      await stale.customStatement('DROP TABLE installment_products');
      for (final column in [
        'product_id',
        'product_name',
        'custom_rules',
        'day_count',
        'rounding',
        'tail_difference',
      ]) {
        await stale.customStatement(
          'ALTER TABLE installment_contracts DROP COLUMN $column',
        );
      }
      await stale.customStatement(
        'ALTER TABLE installment_schedules DROP COLUMN stage_id',
      );
      await stale.customStatement('PRAGMA user_version = 31');
      await stale.close();
      final upgraded = _openDatabase(file);
      addTearDown(upgraded.close);
      final stage = await upgraded
          .select(upgraded.installmentStageConfigs)
          .getSingle();
      expect(stage.ownerType, 'contract');
      expect(stage.ownerId, 'legacy');
      expect(stage.periods, 2);
      expect(stage.ratePpm, 36000);
      expect(stage.amountAlgorithm, 'actualRate');
      expect(stage.endPrincipalMinor, null);
      expect(stage.fixedAmountMinor, null);
      final contractColumns =
          (await upgraded
                  .customSelect('PRAGMA table_info(installment_contracts)')
                  .get())
              .map((r) => r.read<String>('name'))
              .toSet();
      expect(
        contractColumns.intersection({
          'total_periods',
          'first_repayment_date',
          'last_repayment_date',
          'repayment_method',
          'interest_rate_period',
          'interest_rate_ppm',
          'interest_accrual_method',
          'total_fee_minor',
        }),
        isEmpty,
      );

      final after =
          (await upgraded
                  .customSelect('SELECT * FROM installment_schedules')
                  .get())
              .single
              .data;
      expect(after['stage_id'], stage.id);
      expect({...after}..remove('stage_id'), {...before}..remove('stage_id'));
      for (final table in [
        'installment_products',
        'installment_stage_configs',
        'installment_contracts',
      ]) {
        expect(
          await upgraded
              .customSelect("PRAGMA foreign_key_list('$table')")
              .get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'v30 backfills repayment times and preserves items and indexes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-repayment-time-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );
      final stale = _openDatabase(file);
      await stale.customStatement('DROP TABLE repayments');
      await stale.customStatement(
        _v29RepaymentsSql.replaceFirst(
          '  created_at INTEGER',
          '  repayment_date INTEGER NULL,\n  created_at INTEGER',
        ),
      );
      await stale.customStatement('''
INSERT INTO repayments
(id, repayment_type, target_type, target_id, transaction_id, repayment_date,
 created_at, updated_at) VALUES
('with-tx', 'BILL', 'BILL', 'bill', 'tx', NULL, 1700000000, 1700000100),
('no-tx', 'BILL', 'BILL', 'bill', NULL, 1700000200, 1700000000, 1700000100),
('legacy', 'BILL', 'BILL', 'bill', NULL, NULL, 1700000000, 1700000100),
('missing-tx', 'PREPAYMENT', 'CONTRACT', 'contract', 'missing', NULL,
 1700000000, 1700000100)
''');
      await stale.customStatement('''
INSERT INTO transactions
(id, business_purpose, occurred_at, posted_at, primary_amount_minor, source_kind)
VALUES ('tx', 'debtRepayment', 1700000400, 1700000500, 1000, 'manual')
''');
      await stale.customStatement('''
INSERT INTO repayment_items
(id, repayment_id, bill_item_id, allocated_principal_minor,
 allocated_interest_minor, allocated_fee_minor, allocated_discount_minor)
VALUES ('item', 'with-tx', 'bill-item', 1000, 50, 0, 0)
''');
      await stale.customStatement('PRAGMA user_version = 30');
      await stale.close();
      final upgraded = _openDatabase(file);
      addTearDown(upgraded.close);
      final rows = await upgraded.select(upgraded.repayments).get();
      expect(
        {
          for (final row in rows)
            row.id: row.repaymentDate.millisecondsSinceEpoch ~/ 1000,
        },
        {
          'with-tx': 1700000400,
          'no-tx': 1700000200,
          'legacy': 1700000000,
          'missing-tx': 1700000000,
        },
      );
      final item = await upgraded.select(upgraded.repaymentItems).getSingle();
      expect(item.repaymentId, 'with-tx');
      expect(item.allocatedPrincipalMinor, 1000);
      expect(item.allocatedInterestMinor, 50);
      final indexes = await upgraded
          .customSelect("PRAGMA index_list('repayments')")
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll(['repayments_target_idx', 'repayments_transaction_unique']),
      );
      await expectLater(
        upgraded.customStatement(
          "UPDATE repayments SET repayment_date = NULL WHERE id = 'with-tx'",
        ),
        throwsA(isA<Exception>()),
      );
      final foreignKeys = await upgraded
          .customSelect("PRAGMA foreign_key_list('repayments')")
          .get();
      expect(foreignKeys, isEmpty);
    },
  );

  test('opening a v29 database adds repayment_date and backfills it for '
      'all repayments', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-repayment-date-migration-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
    );

    final staleDatabase = _openDatabase(file);
    await staleDatabase.customStatement('DROP TABLE repayments');
    await staleDatabase.customStatement(_v29RepaymentsSql);
    await staleDatabase.customStatement(
      "INSERT INTO repayments "
      "(id, repayment_type, target_type, target_id, transaction_id, "
      "created_at, updated_at) VALUES "
      "('no-tx', 'BILL', 'BILL', 'bill-1', NULL, 1700000000, 1700000000), "
      "('with-tx', 'PREPAYMENT', 'CONTRACT', 'contract-1', 'tx-1', "
      "1700000100, 1700000100)",
    );
    await staleDatabase.customStatement(
      "INSERT INTO transactions (id, business_purpose, occurred_at, posted_at, "
      "primary_amount_minor, source_kind) VALUES "
      "('tx-1', 'debtRepayment', 1700000200, 1700000300, 1000, 'manual')",
    );
    await staleDatabase.customStatement('PRAGMA user_version = 29');
    await staleDatabase.close();

    final upgraded = _openDatabase(file);
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 33);
    final rows = await upgraded
        .customSelect('SELECT id, repayment_date FROM repayments ORDER BY id')
        .get();
    expect(
      {
        for (final row in rows)
          row.read<String>('id'): row.readNullable<int>('repayment_date'),
      },
      {'no-tx': 1700000000, 'with-tx': 1700000200},
    );
  });

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
      final version = await upgradedDatabase
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 33);
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
      await _prepareV28TransactionSchema(staleDatabase);
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
      await staleDatabase.customStatement(
        "INSERT INTO accounts (id, name, account_type) VALUES "
        "('migration-food', '迁移支出', 'expense'), "
        "('migration-cash', '迁移现金', 'asset')",
      );
      await staleDatabase.customStatement(
        "INSERT INTO transaction_details "
        "(id, transaction_id, line_no, detail_type, amount_minor) "
        "VALUES ('tx-1-detail', 'tx-1', 1, 'primaryExpense', 1234)",
      );
      await staleDatabase.customStatement(
        "INSERT INTO entries "
        "(id, transaction_id, account_id, direction, amount_minor) VALUES "
        "('tx-1-debit', 'tx-1', 'migration-food', 'debit', 1234), "
        "('tx-1-credit', 'tx-1', 'migration-cash', 'credit', 1234)",
      );
      await staleDatabase.customStatement('PRAGMA user_version = 19');
      await staleDatabase.close();

      final upgradedDatabase = _openDatabase(file);
      addTearDown(upgradedDatabase.close);
      final version = await upgradedDatabase
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 33);

      final row = await upgradedDatabase
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
      await _prepareV28TransactionSchema(staleDatabase);
      await staleDatabase.customStatement(
        "INSERT INTO accounts (id, name, account_type, balance_minor) "
        "VALUES ('asset-1', '测试账户', 'asset', 77777), "
        "('expense-1', '测试分类', 'expense', 0)",
      );
      await staleDatabase.customStatement('DROP TABLE transactions');
      await staleDatabase.customStatement('DROP TABLE repayments');
      await staleDatabase.customStatement(_v20TransactionsSql);
      await staleDatabase.customStatement(_v20RepaymentsSql);
      final staleRepaymentColumns = await staleDatabase
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
        "('entry-old-category', 'parent-old', 'expense-1', 'debit', 1000), "
        "('entry-parent', 'parent-current', 'asset-1', 'credit', 1200), "
        "('entry-parent-category', 'parent-current', 'expense-1', 'debit', 1200), "
        "('entry-refund', 'refund-current', 'asset-1', 'debit', 200), "
        "('entry-refund-offset', 'refund-current', 'expense-1', 'credit', 200), "
        "('entry-deleted', 'deleted-only', 'asset-1', 'credit', 500), "
        "('entry-deleted-category', 'deleted-only', 'expense-1', 'debit', 500)",
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

      final version = await upgradedDatabase
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 33);

      final transactions = await upgradedDatabase
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

      final transactionColumns = await upgradedDatabase
          .customSelect('PRAGMA table_info(transactions)')
          .get();
      final transactionColumnNames = {
        for (final row in transactionColumns) row.read<String>('name'),
      };
      expect(transactionColumnNames, isNot(contains('root_transaction_id')));
      expect(transactionColumnNames, isNot(contains('mutation_kind')));
      expect(transactionColumnNames, isNot(contains('business_state')));

      final lineTransactionIds = await upgradedDatabase
          .customSelect(
            'SELECT DISTINCT transaction_id FROM transaction_lines '
            'ORDER BY transaction_id',
          )
          .get();
      expect(
        lineTransactionIds
            .map((row) => row.read<String>('transaction_id'))
            .toList(),
        ['parent-old', 'refund-current'],
      );
      final entryTransactionIds = await upgradedDatabase
          .customSelect(
            'SELECT DISTINCT transaction_id FROM entries '
            'ORDER BY transaction_id',
          )
          .get();
      expect(
        entryTransactionIds
            .map((row) => row.read<String>('transaction_id'))
            .toList(),
        ['parent-old', 'refund-current'],
      );

      final repayment = await upgradedDatabase
          .customSelect(
            "SELECT transaction_id FROM repayments WHERE id = 'repayment-1'",
          )
          .getSingle();
      expect(repayment.read<String>('transaction_id'), 'parent-old');
      final repaymentColumns = await upgradedDatabase
          .customSelect('PRAGMA table_info(repayments)')
          .get();
      expect(
        repaymentColumns.map((row) => row.read<String>('name')),
        isNot(contains('root_transaction_id')),
      );

      final contract = await upgradedDatabase
          .customSelect(
            "SELECT disbursement_transaction_id "
            "FROM installment_contracts WHERE id = 'contract-1'",
          )
          .getSingle();
      expect(
        contract.read<String>('disbursement_transaction_id'),
        'parent-old',
      );
      final account = await upgradedDatabase
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
      await _prepareV28TransactionSchema(staleDatabase);
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
      await _prepareV28TransactionSchema(staleDatabase);
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
      final version = await upgradedDatabase
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 33);

      for (final table in [
        'import_entity_mappings',
        'import_batches',
        'import_batch_items',
      ]) {
        final row = await upgradedDatabase
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$table'",
            )
            .getSingle();
        expect(row.read<String>('name'), table);
        final foreignKeys = await upgradedDatabase
            .customSelect('PRAGMA foreign_key_list($table)')
            .get();
        expect(foreignKeys, isEmpty);
      }

      final mappingIndexes = await upgradedDatabase
          .customSelect('PRAGMA index_list(import_entity_mappings)')
          .get();
      expect(
        mappingIndexes.map((row) => row.read<String>('name')),
        contains('import_entity_mapping_unique'),
      );
    },
  );

  test(
    'opening a v25 database preserves budgets and adds sort order',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-budget-order-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );

      final staleDatabase = _openDatabase(file);
      await _prepareV28TransactionSchema(staleDatabase);
      await staleDatabase.customStatement('DROP TABLE budgets');
      await staleDatabase.customStatement(_v25BudgetsSql);
      await staleDatabase.customStatement(
        "INSERT INTO budgets (id, month_key, account_id, amount_minor) "
        "VALUES ('food-budget', 202608, 'food', 100000)",
      );
      await staleDatabase.customStatement('PRAGMA user_version = 25');
      await staleDatabase.close();

      final upgradedDatabase = _openDatabase(file);
      addTearDown(upgradedDatabase.close);
      final row = await upgradedDatabase
          .customSelect(
            "SELECT amount_minor, sort_order FROM budgets "
            "WHERE id = 'food-budget'",
          )
          .getSingle();
      expect(row.read<int>('amount_minor'), 100000);
      expect(row.read<int>('sort_order'), 0);
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
    await _prepareV28TransactionSchema(staleDatabase);
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
    await staleDatabase.customStatement(
      "INSERT INTO budgets "
      "(id, month_key, account_id, amount_minor, sort_order) "
      "VALUES ('old-dining-budget', 202608, 'old-dining', 50000, 0)",
    );
    await staleDatabase.customStatement('PRAGMA user_version = 24');
    await staleDatabase.close();

    final upgradedDatabase = _openDatabase(file);
    addTearDown(upgradedDatabase.close);
    final entry = await upgradedDatabase
        .customSelect(
          "SELECT account_id FROM entries WHERE id = 'category-entry'",
        )
        .getSingle();
    expect(entry.read<String>('account_id'), 'food');
    final transactionLine = await upgradedDatabase
        .customSelect(
          "SELECT account_id FROM transaction_lines "
          "WHERE transaction_id = 'advance' "
          "AND role = 'reimbursementExpenseCategory'",
        )
        .getSingle();
    expect(transactionLine.read<String>('account_id'), 'food');
    final archived = await upgradedDatabase
        .customSelect("SELECT id FROM accounts WHERE id = 'old-dining'")
        .get();
    expect(archived, isEmpty);
    final mapping = await upgradedDatabase
        .customSelect(
          "SELECT target_account_id FROM import_entity_mappings "
          "WHERE id = 'mapping'",
        )
        .getSingle();
    expect(mapping.read<String>('target_account_id'), 'food');
    final budget = await upgradedDatabase
        .customSelect(
          "SELECT account_id FROM budgets "
          "WHERE id = 'old-dining-budget'",
        )
        .getSingle();
    expect(budget.read<String>('account_id'), 'old-dining');
    final target = await upgradedDatabase
        .customSelect(
          "SELECT balance_minor, version FROM accounts WHERE id = 'food'",
        )
        .getSingle();
    expect(target.read<int>('balance_minor'), 1200);
    expect(target.read<int>('version'), 1);
  });

  test('opening a v28 database backfills replayable transaction lines', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-transaction-line-migration-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
    );
    final staleDatabase = _openDatabase(file);
    await _prepareV28TransactionSchema(staleDatabase);
    await staleDatabase.customStatement(
      "DELETE FROM accounts WHERE system_key = 'ghostAccount'",
    );
    await staleDatabase.customStatement(
      "UPDATE app_metadata SET value = '5' "
      "WHERE key = 'builtin_data_version'",
    );
    await staleDatabase.customStatement(
      "INSERT INTO accounts (id, name, account_type) VALUES "
      "('migration-cash', '现金', 'asset'), "
      "('migration-bank', '银行', 'asset'), "
      "('migration-receivable', '应收', 'asset'), "
      "('migration-liability', '负债', 'liability'), "
      "('migration-travel', '差旅', 'expense'), "
      "('migration-salary', '工资', 'income')",
    );
    await staleDatabase.customStatement(
      "INSERT INTO transactions "
      "(id, business_purpose, occurred_at, posted_at, primary_amount_minor, "
      "parent_transaction_id, reimbursement_expense_account_id, source_kind) "
      "VALUES "
      "('income', 'dailyIncome', 1, 1, 1000, NULL, NULL, 'manual'), "
      "('transfer', 'transfer', 2, 2, 1000, NULL, NULL, 'manual'), "
      "('advance', 'reimbursementAdvance', 3, 3, 1000, NULL, "
      "'migration-travel', 'manual'), "
      "('refund', 'refund', 3, 3, 100, 'advance', NULL, 'manual'), "
      "('receipt', 'reimbursementReceipt', 4, 4, 800, 'advance', NULL, 'manual'), "
      "('close', 'reimbursementClose', 5, 5, 800, 'advance', NULL, 'manual'), "
      "('close-zero', 'reimbursementClose', 5, 5, 1000, 'advance', NULL, 'manual'), "
      "('repayment', 'debtRepayment', 6, 6, 1125, NULL, NULL, 'manual'), "
      "('repayment-interest-only', 'debtRepayment', 10, 10, 14690, NULL, NULL, 'manual'), "
      "('borrowing', 'borrowing', 7, 7, 1000, NULL, NULL, 'manual'), "
      "('opening', 'openingBalance', 8, 8, 1000, NULL, NULL, 'manual'), "
      "('adjustment', 'balanceAdjustment', 9, 9, 500, NULL, NULL, 'manual')",
    );
    await staleDatabase.customStatement(
      "INSERT INTO transaction_details "
      "(id, transaction_id, line_no, detail_type, amount_minor) VALUES "
      "('income-main', 'income', 1, 'primaryIncome', 1000), "
      "('transfer-main', 'transfer', 1, 'transferMain', 1000), "
      "('transfer-fee', 'transfer', 2, 'transferFee', 50), "
      "('advance-main', 'advance', 1, 'reimbursementAdvanceMain', 1000), "
      "('refund-main', 'refund', 1, 'refundMain', 100), "
      "('receipt-main', 'receipt', 1, 'reimbursementReceiptMain', 800), "
      "('close-main', 'close', 1, 'reimbursementCloseMain', 1000), "
      "('close-gap', 'close', 2, 'reimbursementGapExpense', 200), "
      "('close-zero-main', 'close-zero', 1, 'reimbursementCloseMain', 1000), "
      "('close-zero-gap', 'close-zero', 2, 'reimbursementGapExpense', 1000), "
      "('repayment-principal', 'repayment', 1, 'repaymentPrincipal', 1000), "
      "('repayment-interest', 'repayment', 2, 'repaymentInterest', 100), "
      "('repayment-fee', 'repayment', 3, 'repaymentFee', 50), "
      "('repayment-discount', 'repayment', 4, 'repaymentDiscount', 25), "
      "('repayment-interest-only-principal', 'repayment-interest-only', 1, 'repaymentPrincipal', 0), "
      "('repayment-interest-only-interest', 'repayment-interest-only', 2, 'repaymentInterest', 14690), "
      "('borrowing-main', 'borrowing', 1, 'borrowingPrincipal', 1000), "
      "('opening-main', 'opening', 1, 'openingBalanceMain', 1000), "
      "('adjustment-main', 'adjustment', 1, 'balanceAdjustmentMain', 500)",
    );
    await staleDatabase.customStatement(
      "INSERT INTO entries "
      "(id, transaction_id, account_id, direction, amount_minor) VALUES "
      "('income-debit', 'income', 'migration-bank', 'debit', 1000), "
      "('income-credit', 'income', 'migration-salary', 'credit', 1000), "
      "('transfer-debit', 'transfer', 'migration-bank', 'debit', 1000), "
      "('transfer-fee-debit', 'transfer', "
      "(SELECT id FROM accounts WHERE system_key = 'feeExpense'), 'debit', 50), "
      "('transfer-credit', 'transfer', 'migration-cash', 'credit', 1050), "
      "('advance-debit', 'advance', 'migration-receivable', 'debit', 1000), "
      "('advance-credit', 'advance', 'migration-cash', 'credit', 1000), "
      "('refund-debit', 'refund', 'migration-bank', 'debit', 100), "
      "('refund-credit', 'refund', 'migration-receivable', 'credit', 100), "
      "('receipt-debit', 'receipt', 'migration-bank', 'debit', 800), "
      "('receipt-credit', 'receipt', 'migration-receivable', 'credit', 800), "
      "('close-bank', 'close', 'migration-bank', 'debit', 800), "
      "('close-gap', 'close', 'migration-travel', 'debit', 200), "
      "('close-receivable', 'close', 'migration-receivable', 'credit', 1000), "
      "('close-zero-gap', 'close-zero', 'migration-travel', 'debit', 1000), "
      "('close-zero-receivable', 'close-zero', 'migration-receivable', 'credit', 1000), "
      "('repayment-liability', 'repayment', 'migration-liability', 'debit', 1000), "
      "('repayment-interest-entry', 'repayment', "
      "(SELECT id FROM accounts WHERE system_key = 'interestExpense'), 'debit', 100), "
      "('repayment-fee-entry', 'repayment', "
      "(SELECT id FROM accounts WHERE system_key = 'feeExpense'), 'debit', 50), "
      "('repayment-discount-entry', 'repayment', "
      "(SELECT id FROM accounts WHERE system_key = 'discountIncome'), 'credit', 25), "
      "('repayment-cash', 'repayment', 'migration-cash', 'credit', 1125), "
      "('repayment-interest-only-liability', 'repayment-interest-only', 'migration-liability', 'debit', 0), "
      "('repayment-interest-only-interest-entry', 'repayment-interest-only', "
      "(SELECT id FROM accounts WHERE system_key = 'interestExpense'), 'debit', 14690), "
      "('repayment-interest-only-cash', 'repayment-interest-only', 'migration-cash', 'credit', 14690), "
      "('borrowing-debit', 'borrowing', 'migration-bank', 'debit', 1000), "
      "('borrowing-credit', 'borrowing', 'migration-liability', 'credit', 1000), "
      "('opening-debit', 'opening', 'migration-bank', 'debit', 1000), "
      "('opening-credit', 'opening', "
      "(SELECT id FROM accounts WHERE system_key = 'openingBalance'), 'credit', 1000), "
      "('adjustment-debit', 'adjustment', "
      "(SELECT id FROM accounts WHERE system_key = 'openingBalance'), 'debit', 500), "
      "('adjustment-credit', 'adjustment', 'migration-bank', 'credit', 500)",
    );
    await staleDatabase.customStatement('PRAGMA user_version = 28');
    await staleDatabase.close();

    final upgraded = _openDatabase(file);
    addTearDown(upgraded.close);
    final lines = await upgraded
        .customSelect(
          'SELECT transaction_id, role, account_id, amount_minor '
          'FROM transaction_lines ORDER BY transaction_id, line_no',
        )
        .get();
    final shapes = {
      for (final row in lines)
        '${row.read<String>('transaction_id')}:'
            '${row.read<String>('role')}:'
            '${row.readNullable<String>('account_id') ?? '-'}:'
            '${row.read<int>('amount_minor')}',
    };
    expect(
      shapes,
      containsAll(<String>{
        'transfer:settlementOut:migration-cash:1000',
        'transfer:settlementIn:migration-bank:1000',
        'transfer:fee:-:50',
        'close:settlementIn:migration-bank:800',
        'close:receivable:migration-receivable:1000',
        'close:reimbursementGapExpense:migration-travel:200',
        'close-zero:receivable:migration-receivable:1000',
        'close-zero:reimbursementGapExpense:migration-travel:1000',
        'refund:settlementIn:migration-bank:100',
        'refund:reimbursementExpenseCategory:migration-travel:100',
        'refund:refundOffset:migration-receivable:100',
        'repayment:liability:migration-liability:1000',
        'repayment:interest:-:100',
        'repayment:fee:-:50',
        'repayment:discount:-:25',
        'repayment:settlementOut:migration-cash:1125',
        'repayment-interest-only:liability:migration-liability:0',
        'repayment-interest-only:interest:-:14690',
        'repayment-interest-only:settlementOut:migration-cash:14690',
        'opening:openingBalance:migration-bank:1000',
        'adjustment:balanceAdjustment:migration-bank:-500',
      }),
    );
    final closePrimary = await upgraded
        .customSelect(
          "SELECT primary_amount_minor FROM transactions WHERE id = 'close'",
        )
        .getSingle();
    expect(closePrimary.read<int>('primary_amount_minor'), 800);
    final closeZeroPrimary = await upgraded
        .customSelect(
          "SELECT primary_amount_minor FROM transactions WHERE id = 'close-zero'",
        )
        .getSingle();
    expect(closeZeroPrimary.read<int>('primary_amount_minor'), 0);
    final closeZeroSettlement = await upgraded
        .customSelect(
          "SELECT account_id, amount_minor FROM transaction_lines "
          "WHERE transaction_id = 'close-zero' AND role = 'settlementIn'",
        )
        .getSingle();
    expect(
      closeZeroSettlement.readNullable<String>('account_id') != null,
      isTrue,
    );
    expect(closeZeroSettlement.read<int>('amount_minor'), 0);
    final oldDetails = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'transaction_details'",
        )
        .get();
    expect(oldDetails, isEmpty);
    final transactionColumns = await upgraded
        .customSelect('PRAGMA table_info(transactions)')
        .get();
    expect(
      transactionColumns.map((row) => row.read<String>('name')),
      isNot(contains('reimbursement_expense_account_id')),
    );
    final transactionIndexes = await upgraded
        .customSelect('PRAGMA index_list(transactions)')
        .get();
    expect(
      transactionIndexes.map((row) => row.read<String>('name')),
      containsAll(<String>{
        'transactions_top_level_occurred_idx',
        'transactions_parent_purpose_idx',
        'transactions_occurred_stats_idx',
        'transactions_posted_billing_idx',
        'transactions_owner_idx',
      }),
    );
    final ghostAccount = await upgraded
        .customSelect(
          "SELECT id FROM accounts WHERE system_key = 'ghostAccount'",
        )
        .getSingle();
    expect(ghostAccount.read<String>('id'), isNotEmpty);
  });

  test('opening a v27 database standardizes account classifications', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-account-standardization-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
    );
    final staleDatabase = _openDatabase(file);
    await _prepareV28TransactionSchema(staleDatabase);
    await staleDatabase.customStatement(
      "INSERT INTO accounts "
      "(id, name, account_type, account_subtype, account_profile_key, "
      "balance_minor, source) VALUES "
      "('reimbursement-old', '旧报销', 'asset', 'reimbursement', "
      "'ledger.reimbursement', 12345, 'user'), "
      "('reimbursement-unprofiled-old', '旧无画像报销', 'asset', "
      "'reimbursement', NULL, 15000, 'user'), "
      "('asset-old', '旧资产', 'asset', NULL, NULL, 20000, 'user'), "
      "('liability-old', '旧负债', 'liability', NULL, NULL, 30000, 'user')",
    );
    await staleDatabase.customStatement('PRAGMA user_version = 27');
    await staleDatabase.close();

    final upgraded = _openDatabase(file);
    addTearDown(upgraded.close);
    final rows = await upgraded
        .customSelect(
          'SELECT id, account_type, account_subtype, account_profile_key, '
          'balance_minor FROM accounts '
          "WHERE id LIKE '%-old' ORDER BY id",
        )
        .get();
    final byId = {for (final row in rows) row.read<String>('id'): row};
    expect(
      byId['reimbursement-old']!.read<String>('account_subtype'),
      'receivable',
    );
    expect(
      byId['reimbursement-old']!.read<String>('account_profile_key'),
      'ledger.reimbursement',
    );
    expect(byId['reimbursement-old']!.read<int>('balance_minor'), 12345);
    expect(
      byId['reimbursement-unprofiled-old']!.read<String>('account_subtype'),
      'receivable',
    );
    expect(
      byId['reimbursement-unprofiled-old']!.read<String>('account_profile_key'),
      'ledger.reimbursement',
    );
    expect(byId['asset-old']!.read<String>('account_subtype'), 'fund');
    expect(
      byId['asset-old']!.read<String>('account_profile_key'),
      'ledger.fund',
    );
    expect(byId['liability-old']!.read<String>('account_subtype'), 'payable');
    expect(
      byId['liability-old']!.read<String>('account_profile_key'),
      'ledger.payable',
    );
  });

  test('v27 account signal conflict aborts the upgrade', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-account-conflict-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
    );
    final staleDatabase = _openDatabase(file);
    await _prepareV28TransactionSchema(staleDatabase);
    await staleDatabase.customStatement(
      "INSERT INTO accounts "
      "(id, name, account_type, account_subtype, account_profile_key, source) "
      "VALUES ('conflict', '冲突', 'asset', 'fund', 'credit.credit', 'user')",
    );
    await staleDatabase.customStatement('PRAGMA user_version = 27');
    await staleDatabase.close();

    final upgrading = _openDatabase(file);
    addTearDown(upgrading.close);
    await expectLater(
      upgrading.customSelect('SELECT 1').get(),
      throwsA(
        isA<AccountProfileMigrationError>()
            .having((error) => error.accountId, 'accountId', 'conflict')
            .having(
              (error) => error.reason,
              'reason',
              AccountProfileMigrationFailureReason.accountTypeConflict,
            )
            .having((error) => error.accountType, 'accountType', 'asset')
            .having((error) => error.accountSubtype, 'accountSubtype', 'fund')
            .having(
              (error) => error.accountProfileKey,
              'accountProfileKey',
              'credit.credit',
            ),
      ),
    );
  });

  test('opening a v27 database normalizes default budget flags', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-receivable-reporting-migration-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
    );
    final staleDatabase = _openDatabase(file);
    await _prepareV28TransactionSchema(staleDatabase);
    await staleDatabase.customStatement(
      "INSERT INTO accounts (id, name, account_type) VALUES "
      "('migration-cash', '迁移现金', 'asset'), "
      "('migration-receivable', '迁移应收', 'asset'), "
      "('migration-liability', '迁移应付', 'liability')",
    );
    await staleDatabase.customStatement(
      "INSERT INTO transactions "
      "(id, business_purpose, occurred_at, posted_at, primary_amount_minor, "
      "is_excluded_from_budget, source_kind) VALUES "
      "('lending', 'lending', 1, 1, 1000, 1, 'manual'), "
      "('collection', 'receivableCollection', 1, 1, 1000, 1, 'manual'), "
      "('bad-debt', 'badDebt', 1, 1, 1000, 1, 'manual'), "
      "('debt-relief', 'debtRelief', 1, 1, 1000, 1, 'manual')",
    );
    await staleDatabase.customStatement(
      "INSERT INTO transaction_details "
      "(id, transaction_id, line_no, detail_type, amount_minor) "
      "VALUES ('collection-principal', 'collection', 1, "
      "'receivableCollectionPrincipal', 1000)",
    );
    await staleDatabase.customStatement(
      "INSERT INTO entries "
      "(id, transaction_id, account_id, direction, amount_minor) VALUES "
      "('lending-debit', 'lending', 'migration-receivable', 'debit', 1000), "
      "('lending-credit', 'lending', 'migration-cash', 'credit', 1000), "
      "('collection-debit', 'collection', 'migration-cash', 'debit', 1000), "
      "('collection-credit', 'collection', 'migration-receivable', 'credit', 1000), "
      "('bad-debt-debit', 'bad-debt', "
      "(SELECT id FROM accounts WHERE system_key = 'badDebtExpense'), "
      "'debit', 1000), "
      "('bad-debt-credit', 'bad-debt', 'migration-receivable', 'credit', 1000), "
      "('debt-relief-debit', 'debt-relief', 'migration-liability', 'debit', 1000), "
      "('debt-relief-credit', 'debt-relief', "
      "(SELECT id FROM accounts WHERE system_key = 'debtReliefIncome'), "
      "'credit', 1000)",
    );
    await staleDatabase.customStatement('PRAGMA user_version = 27');
    await staleDatabase.close();

    final upgraded = _openDatabase(file);
    addTearDown(upgraded.close);
    final rows = await upgraded
        .customSelect(
          'SELECT id, is_excluded_from_budget FROM transactions '
          'ORDER BY id',
        )
        .get();
    final flags = {
      for (final row in rows)
        row.read<String>('id'): row.read<int>('is_excluded_from_budget'),
    };
    expect(flags, {
      'bad-debt': 0,
      'collection': 0,
      'debt-relief': 0,
      'lending': 0,
    });
  });
}

AppDatabase _openDatabase(File file) {
  return AppDatabase(
    DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
  );
}

/// v29 的 repayments 结构：尚无 repayment_date 列。
const _v29RepaymentsSql = '''
CREATE TABLE repayments (
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

/// 测试先用当前 Drift schema 建库，再显式还原 v28 的交易相关结构。
/// 这样设置旧 user_version 后，升级输入与真实历史数据库一致。
Future<void> _prepareV28TransactionSchema(AppDatabase database) async {
  await _restoreFlatContractColumns(database);
  await database.customStatement(
    'DROP INDEX IF EXISTS transaction_lines_transaction_idx',
  );
  await database.customStatement(
    'DROP INDEX IF EXISTS transaction_lines_account_role_idx',
  );
  await database.customStatement('DROP TABLE transaction_lines');
  await database.customStatement(_v28TransactionDetailsSql);
  final transactionColumns = await database
      .customSelect('PRAGMA table_info(transactions)')
      .get();
  final hasReimbursementExpenseAccountId = transactionColumns.any(
    (row) => row.read<String>('name') == 'reimbursement_expense_account_id',
  );
  if (!hasReimbursementExpenseAccountId) {
    await database.customStatement(
      'ALTER TABLE transactions '
      'ADD COLUMN reimbursement_expense_account_id TEXT NULL',
    );
  }
}

Future<void> _insertNoTransactionContract(AppDatabase database) async {
  final columns = await database
      .customSelect('PRAGMA table_info(installment_contracts)')
      .get();
  if (columns.any((r) => r.read<String>('name') == 'total_periods')) {
    await database.customStatement(
      "INSERT INTO installment_contracts "
      "(id, liability_account_id, source_type, principal_minor, total_periods, start_date, "
      "first_repayment_date, last_repayment_date, repayment_method, interest_accrual_method, status) "
      "VALUES ('migration-contract', 'loan-1', 'disbursement', 120000, 12, 0, 0, 0, 'equalInstallment', 'daily', 'active')",
    );
  } else {
    await database.customStatement(
      "INSERT INTO installment_contracts "
      "(id, liability_account_id, source_type, principal_minor, start_date, status) "
      "VALUES ('migration-contract', 'loan-1', 'disbursement', 120000, 0, 'active')",
    );
  }
}

Future<void> _restoreFlatContractColumns(AppDatabase database) async {
  final columns =
      (await database
              .customSelect('PRAGMA table_info(installment_contracts)')
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();
  for (final field in {
    'total_periods': 'INTEGER NOT NULL DEFAULT 1',
    'first_repayment_date': 'INTEGER NOT NULL DEFAULT 0',
    'last_repayment_date': 'INTEGER NOT NULL DEFAULT 0',
    'repayment_method': "TEXT NOT NULL DEFAULT 'equalPrincipal'",
    'interest_rate_period': 'TEXT NULL',
    'interest_rate_ppm': 'INTEGER NULL',
    'interest_accrual_method': "TEXT NOT NULL DEFAULT 'daily'",
    'total_fee_minor': 'INTEGER NOT NULL DEFAULT 0',
  }.entries) {
    if (!columns.contains(field.key)) {
      await database.customStatement(
        'ALTER TABLE installment_contracts ADD COLUMN ${field.key} ${field.value}',
      );
    }
  }
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

const _v25BudgetsSql = '''
CREATE TABLE budgets (
  id TEXT NOT NULL PRIMARY KEY,
  month_key INTEGER NOT NULL,
  account_id TEXT NULL,
  amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''';

const _v28TransactionDetailsSql = '''
CREATE TABLE transaction_details (
  id TEXT NOT NULL PRIMARY KEY,
  transaction_id TEXT NOT NULL,
  line_no INTEGER NOT NULL,
  detail_type TEXT NOT NULL,
  amount_minor INTEGER NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  UNIQUE (transaction_id, line_no)
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
