import 'dart:io';

import 'package:drift/drift.dart' show Migrator;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v60.dart' as v60;
import '../../generated_migrations/schema_v61.dart' as v61;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('migrates the v60 release baseline to the current schema', () async {
    await verifier.testWithDataIntegrity<v60.DatabaseAtV60, AppDatabase>(
      createOld: v60.DatabaseAtV60.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        batch.customStatement(
          'INSERT INTO insured_people '
          '(id, name, birth_date, relationship, gender, avatar_preset) '
          "VALUES ('person-1', '张一', ?, 'self', 'unknown', 'blue')",
          [DateTime(1990, 6, 15).millisecondsSinceEpoch],
        );
        batch.customStatement(
          'INSERT INTO commercial_insurances '
          '(id, name, insurer_name, category, coverage_start_date, '
          'premium_frequency) '
          "VALUES ('commercial-1', '医疗险', '示例保险', 'medical', ?, "
          "'quarterly')",
          [DateTime(2025, 1, 1).millisecondsSinceEpoch],
        );
        batch.customStatement(
          'INSERT INTO coverage_responsibilities '
          '(id, commercial_insurance_id, kind, name, sort_order) '
          "VALUES ('responsibility-1', 'commercial-1', 'custom', "
          "'质子重离子医疗', 0)",
        );
        batch.customStatement(
          'INSERT INTO social_medical_insurances '
          '(id, insured_person_id, region, participant_type) '
          "VALUES ('medical-1', 'person-1', '上海', 'employee')",
        );
        batch.customStatement(
          'INSERT INTO social_medical_contribution_records '
          '(social_medical_insurance_id, year_month, contribution_base_minor) '
          "VALUES ('medical-1', '2026-01', 800000)",
        );
        batch.customStatement(
          'INSERT INTO social_pension_insurances '
          '(id, insured_person_id, region, participant_type) '
          "VALUES ('pension-1', 'person-1', '北京', 'resident')",
        );
        batch.customStatement(
          'INSERT INTO social_pension_contribution_records '
          '(social_pension_insurance_id, year_month, contribution_base_minor) '
          "VALUES ('pension-1', '2026-02', 500000)",
        );
      },
      validateItems: (db) async {
        final commercial = await db.select(db.commercialInsurances).getSingle();
        expect(commercial.premiumTermCount, isNull);
        expect(commercial.premiumFrequency, PremiumFrequency.other);

        final responsibility = await db
            .select(db.coverageResponsibilities)
            .getSingle();
        expect(responsibility.kind, ResponsibilityKind.other);
        expect(responsibility.name, '质子重离子医疗');

        final social = await db.select(db.socialInsurances).get();
        expect(social.map((row) => row.insuranceType), [
          SocialInsuranceType.medical,
          SocialInsuranceType.pension,
        ]);
        expect(
          await db.select(db.socialContributionRecords).get(),
          hasLength(2),
        );

        final tables =
            (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type = 'table'",
                    )
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(tables, contains('social_insurances'));
        expect(
          tables,
          isNot(
            anyOf(
              contains('social_medical_insurances'),
              contains('social_pension_insurances'),
            ),
          ),
        );
      },
      oldVersion: 60,
      newVersion: 62,
    );
  });

  test('migrates v61 data to the v62 reconciliation snapshot table', () async {
    await verifier.testWithDataIntegrity<v61.DatabaseAtV61, AppDatabase>(
      createOld: v61.DatabaseAtV61.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {},
      validateItems: (db) async {
        final tables =
            (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type = 'table'",
                    )
                    .get())
                .map((row) => row.read<String>('name'))
                .toSet();
        expect(tables, contains('account_reconciliation_snapshots'));
      },
      oldVersion: 61,
      newVersion: 62,
    );
  });

  test('failed baseline migration keeps the version and data intact', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow_migration_rollback_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/schema.sqlite');

    final oldDatabase = v60.DatabaseAtV60(NativeDatabase(file));
    final oldMigrator = Migrator(oldDatabase);
    for (final table in oldDatabase.allTables) {
      await oldMigrator.createTable(table);
    }
    await oldDatabase.customStatement(
      'INSERT INTO app_metadata (key, value, updated_at) VALUES (?, ?, ?)',
      ['sentinel', 'kept', DateTime(2026, 1, 1).millisecondsSinceEpoch],
    );
    await oldDatabase.customStatement(
      'CREATE TABLE social_insurances (id TEXT NOT NULL)',
    );
    await oldDatabase.customStatement('PRAGMA user_version = 60');
    await oldDatabase.close();

    final target = AppDatabase(NativeDatabase(file));
    await expectLater(
      () => target.customSelect('SELECT 1').get(),
      throwsA(anything),
    );
    await target.close();

    final inspection = v60.DatabaseAtV60(NativeDatabase(file));
    final version = await inspection.customSelect('PRAGMA user_version').get();
    expect(version.single.read<int>('user_version'), 60);
    final sentinel = await inspection
        .customSelect("SELECT value FROM app_metadata WHERE key = 'sentinel'")
        .getSingle();
    expect(sentinel.read<String>('value'), 'kept');
    final commercialColumns =
        (await inspection
                .customSelect('PRAGMA table_info(commercial_insurances)')
                .get())
            .map((row) => row.read<String>('name'))
            .toSet();
    expect(commercialColumns, isNot(contains('premium_term_count')));
    await inspection.close();
  });
}
