import 'dart:io';

import 'package:drift/drift.dart' show Migrator, OrderingTerm;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v49.dart' as v49;
import '../../generated_migrations/schema_v50.dart' as v50;
import '../../generated_migrations/schema_v51.dart' as v51;
import '../../generated_migrations/schema_v52.dart' as v52;
import '../../generated_migrations/schema_v53.dart' as v53;
import '../../generated_migrations/schema_v54.dart' as v54;
import '../../generated_migrations/schema_v55.dart' as v55;
import '../../generated_migrations/schema_v56.dart' as v56;
import '../../generated_migrations/schema_v57.dart' as v57;
import '../../generated_migrations/schema_v58.dart' as v58;
import '../../generated_migrations/schema_v59.dart' as v59;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates v49 to current without losing account data', () async {
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
      newVersion: 60,
    );
  });

  test('migrates v50 through current with refund reductions', () async {
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
      newVersion: 60,
    );
  });

  test('migrates v52 through current with amortization tables', () async {
    await verifier.testWithDataIntegrity<v52.DatabaseAtV52, AppDatabase>(
      createOld: v52.DatabaseAtV52.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {},
      validateItems: (db) async {
        final tables =
            (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type = 'table' "
                      "AND name IN ('amortization_plans', "
                      "'amortization_periods', 'amortization_refunds', "
                      "'amortization_terminations', "
                      "'amortization_allocations')",
                    )
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(tables, {
          'amortization_plans',
          'amortization_periods',
          'amortization_refunds',
          'amortization_terminations',
          'amortization_allocations',
        });
        final indexes = (await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'amortization_periods_pending_idx'",
            )
            .get());
        expect(indexes, hasLength(1));
      },
      oldVersion: 52,
      newVersion: 60,
    );
  });

  test(
    'migrates legacy amortization categories to shared allocations',
    () async {
      await verifier.testWithDataIntegrity<v53.DatabaseAtV53, AppDatabase>(
        createOld: v53.DatabaseAtV53.new,
        createNew: AppDatabase.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, _) {
          batch.customStatement(
            'INSERT INTO amortization_plans ('
            'id, kind, deferral_account_id, category_account_id, '
            'total_amount_minor, cadence_unit, cadence_interval, '
            'first_recognition_at, recognition_count, initial_transaction_id'
            ") VALUES ('plan', 'prepaidExpense', 'prepaid', 'rent', "
            '300000, \'monthly\', 1, 1769788800, 3, \'initial\')',
          );
          batch.customStatement(
            'INSERT INTO amortization_entries ('
            'id, plan_id, sequence_no, due_at, amount_minor'
            ") VALUES ('entry-1', 'plan', 1, 1769788800, 100000), "
            "('entry-2', 'plan', 2, 1772377200, 100000), "
            "('entry-3', 'plan', 3, 1774965600, 100000)",
          );
        },
        validateItems: (db) async {
          final planColumns =
              (await db
                      .customSelect('PRAGMA table_info(amortization_plans)')
                      .get())
                  .map((row) => row.read<String>('name'))
                  .toSet();
          expect(planColumns, isNot(contains('category_account_id')));

          final allocations = await db
              .customSelect(
                'SELECT subject_id, line_no, account_id, amount_minor '
                'FROM amortization_allocations '
                "WHERE subject_type = 'period' ORDER BY subject_id",
              )
              .get();
          expect(allocations, hasLength(3));
          expect(
            allocations.map(
              (row) => (
                row.read<String>('subject_id'),
                row.read<int>('line_no'),
                row.read<String>('account_id'),
                row.read<int>('amount_minor'),
              ),
            ),
            [
              ('entry-1', 1, 'rent', 100000),
              ('entry-2', 1, 'rent', 100000),
              ('entry-3', 1, 'rent', 100000),
            ],
          );
        },
        oldVersion: 53,
        newVersion: 54,
      );
    },
  );

  test('migrates v54 amortization plan to refund-safe model', () async {
    await verifier.testWithDataIntegrity<v54.DatabaseAtV54, AppDatabase>(
      createOld: v54.DatabaseAtV54.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        batch.customStatement(
          'INSERT INTO amortization_plans ('
          'id, kind, deferral_account_id, total_amount_minor, cadence_unit, '
          'cadence_interval, first_recognition_at, recognition_count, '
          'default_is_excluded_from_stats, default_is_excluded_from_budget, '
          'initial_transaction_id, terminated_at, refund_amount_minor, '
          'termination_recognition_transaction_id, refund_transaction_id) '
          "VALUES ('plan', 'prepaidExpense', 'prepaid', 60000, 'monthly', "
          "1, 1767225600, 2, 0, 0, 'initial', 1769904000, 5000, "
          "'termination-recognition', 'termination-return')",
        );
        batch.customStatement(
          'INSERT INTO amortization_entries '
          '(id, plan_id, sequence_no, due_at, amount_minor) '
          "VALUES ('period-1', 'plan', 1, 1767225600, 30000), "
          "('period-2', 'plan', 2, 1769904000, 30000)",
        );
        batch.customStatement(
          'INSERT INTO amortization_entry_allocations '
          '(id, entry_id, line_no, account_id, amount_minor) '
          "VALUES ('allocation-1', 'period-1', 1, 'category-a', 10000), "
          "('allocation-2', 'period-1', 2, 'category-b', 20000), "
          "('allocation-3', 'period-2', 1, 'category-a', 10000), "
          "('allocation-4', 'period-2', 2, 'category-b', 20000)",
        );
      },
      validateItems: (db) async {
        final terminations = await db.select(db.amortizationTerminations).get();
        expect(terminations, hasLength(1));
        expect(
          terminations.single.terminatedAt,
          DateTime.fromMillisecondsSinceEpoch(1769904000 * 1000),
        );

        final planColumns =
            (await db
                    .customSelect('PRAGMA table_info(amortization_plans)')
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(planColumns, isNot(contains('counterparty_id')));
        expect(planColumns, isNot(contains('note')));
        expect(planColumns, isNot(contains('default_is_excluded_from_stats')));
        expect(planColumns, isNot(contains('refund_amount_minor')));

        final periods = await db
            .customSelect(
              'SELECT id, amount_minor, status FROM amortization_periods '
              'ORDER BY sequence_no',
            )
            .get();
        expect(
          periods.map(
            (row) => (
              row.read<String>('id'),
              row.read<int>('amount_minor'),
              row.read<String>('status'),
            ),
          ),
          [('period-1', 30000, 'pending'), ('period-2', 30000, 'pending')],
        );
        final planAllocations = await db
            .customSelect(
              'SELECT account_id, amount_minor FROM amortization_allocations '
              "WHERE subject_type = 'plan' AND dimension = 'category' "
              'ORDER BY account_id',
            )
            .get();
        expect(
          planAllocations.map(
            (row) =>
                (row.read<String>('account_id'), row.read<int>('amount_minor')),
          ),
          [('category-a', 20000), ('category-b', 40000)],
        );
      },
      oldVersion: 54,
      newVersion: 55,
    );
  });

  test(
    'repairs text timestamps written by the v55 amortization migration',
    () async {
      const malformedTimestamp = '2026-11-01 17:18:31';
      final repairedInstant = DateTime.utc(2026, 11, 1, 17, 18, 31);

      await verifier.testWithDataIntegrity<v55.DatabaseAtV55, AppDatabase>(
        createOld: v55.DatabaseAtV55.new,
        createNew: AppDatabase.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, _) {
          batch.customStatement(
            'INSERT INTO amortization_terminations ('
            'id, plan_id, terminated_at, recognition_transaction_id, '
            'return_transaction_id, created_at, updated_at'
            ") VALUES ('termination', 'plan', 1769904000, 'recognition', NULL, "
            "'$malformedTimestamp', '$malformedTimestamp')",
          );
          batch.customStatement(
            'INSERT INTO amortization_allocations ('
            'id, subject_type, subject_id, dimension, line_no, account_id, '
            'amount_minor, created_at, updated_at'
            ") VALUES ('allocation', 'termination', 'termination', 'category', "
            "1, 'rent', 5000, '$malformedTimestamp', '$malformedTimestamp')",
          );
        },
        validateItems: (db) async {
          final termination = await db
              .select(db.amortizationTerminations)
              .getSingle();
          expect(
            termination.createdAt.millisecondsSinceEpoch,
            repairedInstant.millisecondsSinceEpoch,
          );
          expect(
            termination.updatedAt.millisecondsSinceEpoch,
            repairedInstant.millisecondsSinceEpoch,
          );

          final allocation = await db
              .select(db.amortizationAllocations)
              .getSingle();
          expect(
            allocation.createdAt.millisecondsSinceEpoch,
            repairedInstant.millisecondsSinceEpoch,
          );
          expect(
            allocation.updatedAt.millisecondsSinceEpoch,
            repairedInstant.millisecondsSinceEpoch,
          );
        },
        oldVersion: 55,
        newVersion: 60,
      );
    },
  );

  test('migrates v56 to current with business-activity indexes', () async {
    await verifier.testWithDataIntegrity<v56.DatabaseAtV56, AppDatabase>(
      createOld: v56.DatabaseAtV56.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {},
      validateItems: (db) async {
        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'transactions_top_level_owner_occurred_idx'",
            )
            .get();
        expect(
          indexes.map((row) => row.read<String>('name')),
          contains('transactions_top_level_owner_occurred_idx'),
        );
      },
      oldVersion: 56,
      newVersion: 60,
    );
  });

  test('migrates v57 to current with insurance tables and indexes', () async {
    await verifier.testWithDataIntegrity<v57.DatabaseAtV57, AppDatabase>(
      createOld: v57.DatabaseAtV57.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {},
      validateItems: (db) async {
        const expectedTables = {
          'insured_people',
          'commercial_insurances',
          'commercial_insurance_insured_people',
          'coverage_responsibilities',
          'responsibility_points',
          'insurance_attachments',
          'social_medical_insurances',
          'social_medical_contribution_records',
          'social_pension_insurances',
          'social_pension_contribution_records',
        };
        final tables =
            (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type = 'table'",
                    )
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(tables, containsAll(expectedTables));

        const expectedIndexes = {
          'commercial_insurance_insured_people_person_idx',
          'coverage_responsibilities_insurance_idx',
          'responsibility_points_responsibility_idx',
          'insurance_attachments_insurance_idx',
          'social_medical_insurances_person_idx',
          'social_pension_insurances_person_idx',
        };
        final indexes =
            (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type = 'index'",
                    )
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(indexes, containsAll(expectedIndexes));
      },
      oldVersion: 57,
      newVersion: 60,
    );
  });

  test('migrates v58 members with profile defaults', () async {
    await verifier.testWithDataIntegrity<v58.DatabaseAtV58, AppDatabase>(
      createOld: v58.DatabaseAtV58.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        batch.customStatement(
          'INSERT INTO insured_people (id, name, birth_date) '
          'VALUES (?, ?, ?)',
          ['person-1', '张三', DateTime(1990, 6, 15).millisecondsSinceEpoch],
        );
      },
      validateItems: (db) async {
        final person = await db.select(db.insuredPeople).getSingle();
        expect(person.relationship, MemberRelationship.other);
        expect(person.gender, MemberGender.unknown);
        expect(person.note, isNull);
        expect(person.avatarPreset, MemberAvatarPreset.blue);
      },
      oldVersion: 58,
      newVersion: 59,
    );
  });

  test('migrates legacy v59 member birth parts to birth_date', () async {
    final schema = await verifier.schemaAt(59);
    final oldDb = v59.DatabaseAtV59(schema.newConnection());
    await oldDb.customStatement('DROP TABLE insured_people');
    await oldDb.customStatement(
      'CREATE TABLE insured_people ('
      'id TEXT NOT NULL, '
      'name TEXT NOT NULL, '
      'birth_year INTEGER NOT NULL, '
      'birth_month INTEGER NOT NULL, '
      'birth_day INTEGER NULL, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      "relationship TEXT NOT NULL DEFAULT 'other', "
      "gender TEXT NOT NULL DEFAULT 'unknown', "
      'note TEXT NULL, '
      "avatar_preset TEXT NOT NULL DEFAULT 'blue', "
      'PRIMARY KEY(id), '
      'CHECK(length(trim(name)) > 0), '
      'CHECK(birth_year BETWEEN 1900 AND 2100), '
      'CHECK(birth_month BETWEEN 1 AND 12), '
      'CHECK(birth_day IS NULL OR birth_day BETWEEN 1 AND 31)'
      ')',
    );
    await oldDb.customStatement(
      'INSERT INTO insured_people '
      '(id, name, birth_year, birth_month, birth_day, created_at, '
      'updated_at, relationship, gender, note, avatar_preset) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'legacy-1',
        '旧成员一',
        2000,
        6,
        15,
        1793893840,
        1793893840,
        'parent',
        'female',
        '旧备注',
        'green',
      ],
    );
    await oldDb.customStatement(
      'INSERT INTO insured_people '
      '(id, name, birth_year, birth_month, birth_day, created_at, '
      'updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      ['legacy-2', '旧成员二', 1995, 2, null, 1793893840, 1793893840],
    );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 60);
    final people = await (db.select(
      db.insuredPeople,
    )..orderBy([(row) => OrderingTerm(expression: row.id)])).get();
    expect(people, hasLength(2));
    expect(people.first.birthDate.year, 2000);
    expect(people.first.birthDate.month, 6);
    expect(people.first.birthDate.day, 15);
    expect(people.first.relationship, MemberRelationship.parent);
    expect(people.first.gender, MemberGender.female);
    expect(people.first.note, '旧备注');
    expect(people.first.avatarPreset, MemberAvatarPreset.green);
    expect(people.last.birthDate.year, 1995);
    expect(people.last.birthDate.month, 2);
    expect(people.last.birthDate.day, 1);
    await db.close();
  });

  test('keeps current v59 member data when migrating to v60', () async {
    await verifier.testWithDataIntegrity<v59.DatabaseAtV59, AppDatabase>(
      createOld: v59.DatabaseAtV59.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        batch.customStatement(
          'INSERT INTO insured_people '
          '(id, name, birth_date, relationship, gender, avatar_preset) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          [
            'person-1',
            '当前成员',
            DateTime(1992, 8, 9).millisecondsSinceEpoch ~/ 1000,
            'self',
            'male',
            'green',
          ],
        );
      },
      validateItems: (db) async {
        final person = await db.select(db.insuredPeople).getSingle();
        expect(person.birthDate.year, 1992);
        expect(person.birthDate.month, 8);
        expect(person.birthDate.day, 9);
        expect(person.relationship, MemberRelationship.self);
        expect(person.gender, MemberGender.male);
        expect(person.avatarPreset, MemberAvatarPreset.green);
      },
      oldVersion: 59,
      newVersion: 60,
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
