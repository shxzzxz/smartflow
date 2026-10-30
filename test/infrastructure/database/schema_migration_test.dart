import 'dart:io';

import 'package:drift/drift.dart' show Migrator;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v49.dart' as v49;
import '../../generated_migrations/schema_v50.dart' as v50;
import '../../generated_migrations/schema_v51.dart' as v51;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates v49 to v50 without losing account data', () async {
    await verifier.testWithDataIntegrity<v49.DatabaseAtV49, AppDatabase>(
      createOld: v49.DatabaseAtV49.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        batch.customStatement(
          '''
          INSERT INTO accounts (
            id,
            name,
            account_type,
            account_subtype,
            account_profile_key,
            balance_minor,
            credit_limit_minor,
            billing_day,
            repayment_day
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            'credit',
            '信用卡',
            'liability',
            'payable',
            'credit.credit',
            1200,
            100000,
            5,
            25,
          ],
        );
        batch.customStatement(
          '''
          INSERT INTO credit_liability_accounts (
            id,
            account_id,
            kind,
            credit_limit_minor,
            billing_day,
            repayment_day,
            billing_day_to_next
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          ['credit-extension', 'credit', 'credit', 100000, 5, 25, 1],
        );
      },
      validateItems: (db) async {
        final accountQuery = db.select(db.accounts)
          ..where((row) => row.id.equals('credit'));
        final account = await accountQuery.getSingle();
        expect(account.name, '信用卡');
        expect(account.balanceMinor, 1200);
        expect(account.accountProfileKey, 'credit.credit');

        final extensionQuery = db.select(db.creditLiabilityAccounts)
          ..where((row) => row.accountId.equals('credit'));
        final extension = await extensionQuery.getSingle();
        expect(extension.creditLimitMinor, 100000);
        expect(extension.billingDay, 5);
        expect(extension.repaymentDay, 25);

        final columnNames =
            (await db.customSelect('PRAGMA table_info(accounts)').get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(columnNames, isNot(contains('credit_limit_minor')));
        expect(columnNames, isNot(contains('billing_day')));
        expect(columnNames, isNot(contains('repayment_day')));
      },
      oldVersion: 49,
      newVersion: 52,
    );
  });

  test('migrates v50 through v52 with refund reductions', () async {
    await verifier.testWithDataIntegrity<v50.DatabaseAtV50, AppDatabase>(
      createOld: v50.DatabaseAtV50.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {},
      validateItems: (db) async {
        final contractColumns =
            (await db
                    .customSelect('PRAGMA table_info(installment_contracts)')
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(contractColumns, isNot(contains('purchase_transaction_id')));
        expect(contractColumns, contains('installment_type'));
        expect(contractColumns, contains('source_ref_id'));
        expect(contractColumns, isNot(contains('source_type')));
        expect(contractColumns, isNot(contains('disbursement_account_id')));

        final refundTables = await db
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'table' "
              "AND name = 'installment_refund_reductions'",
            )
            .get();
        expect(refundTables, hasLength(1));
        final refundIndexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master "
              "WHERE type = 'index' "
              "AND name = 'installment_refund_reductions_contract_idx'",
            )
            .get();
        expect(refundIndexes, hasLength(1));
      },
      oldVersion: 50,
      newVersion: 52,
    );
  });

  test(
    'migrates v51 installment sources and generated contract links',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow_installment_source_migration_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/schema.sqlite');

      final oldDatabase = v51.DatabaseAtV51(NativeDatabase(file));
      final oldMigrator = Migrator(oldDatabase);
      for (final table in oldDatabase.allTables) {
        await oldMigrator.createTable(table);
      }
      await _createV51CustomIndexes(oldDatabase);
      for (final row in [
        (
          id: 'disbursement',
          sourceType: 'disbursement',
          disbursementAccountId: 'cash',
          disbursementTransactionId: 'borrow-tx',
          sourceRepaymentId: null,
          purchaseTransactionId: null,
          sourceRefId: 'borrow-tx',
        ),
        (
          id: 'bill',
          sourceType: 'billConversion',
          disbursementAccountId: null,
          disbursementTransactionId: null,
          sourceRepaymentId: 'repayment',
          purchaseTransactionId: null,
          sourceRefId: 'repayment',
        ),
        (
          id: 'purchase',
          sourceType: 'purchase',
          disbursementAccountId: null,
          disbursementTransactionId: null,
          sourceRepaymentId: null,
          purchaseTransactionId: 'purchase-tx',
          sourceRefId: 'purchase-tx',
        ),
      ]) {
        await oldDatabase.customStatement(
          'INSERT INTO installment_contracts ('
          'id, name, day_count, rounding, liability_account_id, source_type, '
          'disbursement_account_id, disbursement_transaction_id, '
          'source_repayment_id, purchase_transaction_id, principal_minor, '
          'borrowing_date, status, note, created_at, updated_at'
          ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            row.id,
            row.id,
            'thirty360',
            'halfUp',
            'credit',
            row.sourceType,
            row.disbursementAccountId,
            row.disbursementTransactionId,
            row.sourceRepaymentId,
            row.purchaseTransactionId,
            10000,
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
            'active',
            null,
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
          ],
        );
      }
      await oldDatabase.customStatement(
        'INSERT INTO repayments ('
        'id, repayment_type, target_type, target_id, transaction_id, '
        'repayment_date, created_at, updated_at'
        ') VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'repayment',
          'INSTALLMENT',
          'BILL',
          'bill',
          null,
          DateTime(2026, 1, 1).millisecondsSinceEpoch,
          DateTime(2026, 1, 1).millisecondsSinceEpoch,
          DateTime(2026, 1, 1).millisecondsSinceEpoch,
        ],
      );
      await oldDatabase.customStatement('PRAGMA user_version = 51');
      await oldDatabase.close();

      final database = AppDatabase(NativeDatabase(file));
      addTearDown(database.close);
      final contracts = await database
          .select(database.installmentContracts)
          .get();
      expect(
        {
          for (final contract in contracts)
            contract.id: (contract.installmentType.name, contract.sourceRefId),
        },
        {
          'disbursement': ('disbursement', 'borrow-tx'),
          'bill': ('billConversion', 'repayment'),
          'purchase': ('purchase', 'purchase-tx'),
        },
      );
      final repayment = await database.select(database.repayments).getSingle();
      expect(repayment.generatedContractId, 'bill');

      final columns =
          (await database
                  .customSelect('PRAGMA table_info(installment_contracts)')
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(columns, containsAll(['installment_type', 'source_ref_id']));
      expect(
        columns,
        isNot(
          anyOf(contains('source_type'), contains('disbursement_account_id')),
        ),
      );
      final indexNames =
          (await database
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'index'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(
        indexNames,
        isNot(
          anyOf(
            contains('installment_contracts_disbursement_tx_idx'),
            contains('installment_contracts_source_repayment_idx'),
          ),
        ),
      );
      expect(
        indexNames,
        containsAll({
          'installment_contracts_liability_status_idx',
          'repayments_target_idx',
          'repayments_transaction_unique',
          'repayments_generated_contract_unique',
        }),
      );
    },
  );

  test('failed v50 to v51 migration keeps version and data intact', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow_migration_rollback_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/schema.sqlite');

    final oldDatabase = v50.DatabaseAtV50(NativeDatabase(file));
    final oldMigrator = Migrator(oldDatabase);
    for (final table in oldDatabase.allTables) {
      await oldMigrator.createTable(table);
    }
    await oldDatabase.customStatement(
      'INSERT INTO app_metadata (key, value, updated_at) VALUES (?, ?, ?)',
      ['sentinel', 'kept', DateTime(2026, 1, 1).millisecondsSinceEpoch],
    );
    await oldDatabase.customStatement('PRAGMA user_version = 50');
    await oldDatabase.customStatement(
      'CREATE INDEX installment_refund_reductions_contract_idx '
      'ON app_metadata (key)',
    );
    await oldDatabase.close();

    final target = AppDatabase(NativeDatabase(file));
    await expectLater(
      () => target.customSelect('SELECT 1').get(),
      throwsA(anything),
    );
    await target.close();

    final inspection = v50.DatabaseAtV50(NativeDatabase(file));
    final version = await inspection.customSelect('PRAGMA user_version').get();
    expect(version.single.read<int>('user_version'), 50);
    final contractColumns =
        (await inspection
                .customSelect('PRAGMA table_info(installment_contracts)')
                .get())
            .map((row) => row.read<String>('name'))
            .toSet();
    expect(contractColumns, isNot(contains('purchase_transaction_id')));
    final sentinel = await inspection
        .customSelect("SELECT value FROM app_metadata WHERE key = 'sentinel'")
        .getSingle();
    expect(sentinel.read<String>('value'), 'kept');
    await inspection.close();
  });
}

Future<void> _createV51CustomIndexes(v51.DatabaseAtV51 database) async {
  await database.customStatement(
    'CREATE INDEX installment_contracts_liability_status_idx '
    'ON installment_contracts (liability_account_id, status)',
  );
  await database.customStatement(
    'CREATE INDEX installment_contracts_disbursement_tx_idx '
    'ON installment_contracts (disbursement_transaction_id) '
    'WHERE disbursement_transaction_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE INDEX installment_contracts_source_repayment_idx '
    'ON installment_contracts (source_repayment_id) '
    'WHERE source_repayment_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE INDEX repayments_target_idx '
    'ON repayments (target_type, target_id, created_at)',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX repayments_transaction_unique '
    'ON repayments (transaction_id) '
    'WHERE transaction_id IS NOT NULL',
  );
}
