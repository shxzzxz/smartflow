import 'dart:io';

import 'package:drift/drift.dart' show Migrator;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v49.dart' as v49;
import '../../generated_migrations/schema_v50.dart' as v50;

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
      newVersion: 51,
    );
  });

  test(
    'migrates v50 to v51 with purchase contracts and refund reductions',
    () async {
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
          expect(contractColumns, contains('purchase_transaction_id'));

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
        newVersion: 51,
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
