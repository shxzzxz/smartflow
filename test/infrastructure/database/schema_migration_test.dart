import 'dart:io';

import 'package:drift/drift.dart' show Migrator, OrderingTerm;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/insurance/valobj/insurance_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v60.dart' as v60;
import '../../generated_migrations/schema_v61.dart' as v61;
import '../../generated_migrations/schema_v62.dart' as v62;
import '../../generated_migrations/schema_v63.dart' as v63;
import '../../generated_migrations/schema_v64.dart' as v64;
import '../../generated_migrations/schema_v65.dart' as v65;
import '../../generated_migrations/schema_v66.dart' as v66;

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
        expect(
          (await db.select(db.insuredPeople).getSingle()).avatarPreset,
          MemberAvatarPreset.male,
        );
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
      newVersion: 67,
    );
  });

  test('migrates v61 data with the reconciliation snapshot table', () async {
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
      newVersion: 66,
    );
  });

  test(
    'v62 insurance migration preserves amounts and legacy contribution facts',
    () async {
      await verifier.testWithDataIntegrity<v62.DatabaseAtV62, AppDatabase>(
        createOld: v62.DatabaseAtV62.new,
        createNew: AppDatabase.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, _) {
          batch.customStatement(
            'INSERT INTO commercial_insurances '
            '(id, name, insurer_name, category, coverage_start_date, coverage_amount_minor) '
            "VALUES ('policy-1', '医疗险', '示例保险', 'medical', ?, 12345600)",
            [DateTime(2025, 1, 1).millisecondsSinceEpoch],
          );
          batch.customStatement(
            'INSERT INTO social_contribution_records '
            '(social_insurance_id, year_month, contribution_base_minor) '
            "VALUES ('social-1', '2026-01', 800000)",
          );
        },
        validateItems: (db) async {
          final policy = await db.select(db.commercialInsurances).getSingle();
          expect(policy.coverageAmountMinor, 12345600);
          expect(policy.coverageAmountDescription, isNull);
          expect(policy.coverageSummary, isNull);
          expect(policy.coverageHighlights, isNull);
          final contribution = await db
              .select(db.socialContributionRecords)
              .getSingle();
          expect(contribution.period, '2026-01');
          expect(contribution.contributionBaseMinor, 800000);
          expect(contribution.contributionAmountMinor, isNull);
          expect(contribution.note, isNull);
        },
        oldVersion: 62,
        newVersion: 66,
      );
    },
  );

  test('v63 responsibilities keep their names, points and order', () async {
    const legacyResponsibilities = [
      ('medical', '一般医疗'),
      ('criticalIllness', '重疾'),
      ('accident', '意外责任'),
      ('life', '身故'),
      ('disability', '全残'),
      ('other', '住院津贴'),
    ];
    await verifier.testWithDataIntegrity<v63.DatabaseAtV63, AppDatabase>(
      createOld: v63.DatabaseAtV63.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        batch.customStatement(
          'INSERT INTO commercial_insurances '
          '(id, name, insurer_name, category, coverage_start_date) '
          "VALUES ('policy-1', '示例寿险', '示例保险', 'life', ?)",
          [DateTime(2025, 1, 1).millisecondsSinceEpoch],
        );
        for (var index = 0; index < legacyResponsibilities.length; index++) {
          final (kind, name) = legacyResponsibilities[index];
          batch.customStatement(
            'INSERT INTO coverage_responsibilities '
            '(id, commercial_insurance_id, kind, name, sort_order) '
            'VALUES (?, ?, ?, ?, ?)',
            ['responsibility-$index', 'policy-1', kind, name, index],
          );
          batch.customStatement(
            'INSERT INTO responsibility_points '
            '(id, responsibility_id, label, value, sort_order) '
            'VALUES (?, ?, ?, ?, ?)',
            [
              'point-$index',
              'responsibility-$index',
              '保留要点$index',
              '保留内容$index',
              5 - index,
            ],
          );
        }
      },
      validateItems: (db) async {
        final responsibilities = await (db.select(
          db.coverageResponsibilities,
        )..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).get();
        expect(responsibilities.map((row) => row.kind), [
          ResponsibilityKind.medical,
          ResponsibilityKind.other,
          ResponsibilityKind.other,
          ResponsibilityKind.other,
          ResponsibilityKind.disability,
          ResponsibilityKind.other,
        ]);
        expect(responsibilities.map((row) => row.name), [
          '一般医疗',
          '重疾',
          '意外责任',
          '身故',
          '全残',
          '住院津贴',
        ]);
        expect(responsibilities.map((row) => row.sortOrder), [
          0,
          1,
          2,
          3,
          4,
          5,
        ]);
        expect(
          responsibilities.map((row) => row.description),
          everyElement(isNull),
        );
        final points = await (db.select(
          db.responsibilityPoints,
        )..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).get();
        expect(points.map((row) => row.id), [
          'point-5',
          'point-4',
          'point-3',
          'point-2',
          'point-1',
          'point-0',
        ]);
        for (var index = 0; index < points.length; index++) {
          final originalIndex = 5 - index;
          expect(
            points[index].responsibilityId,
            'responsibility-$originalIndex',
          );
          expect(points[index].label, '保留要点$originalIndex');
          expect(points[index].value, '保留内容$originalIndex');
        }
        expect(
          (await db.select(db.commercialInsurances).getSingle()).category,
          CommercialInsuranceCategory.life,
        );
      },
      oldVersion: 63,
      newVersion: 66,
    );
  });

  test(
    'v64 contract fields start unrecorded and preserve existing policy facts',
    () async {
      await verifier.testWithDataIntegrity<v64.DatabaseAtV64, AppDatabase>(
        createOld: v64.DatabaseAtV64.new,
        createNew: AppDatabase.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, _) {
          batch.customStatement(
            'INSERT INTO commercial_insurances '
            '(id, name, insurer_name, category, coverage_start_date, coverage_amount_minor, '
            'coverage_amount_description, coverage_summary, coverage_highlights) '
            "VALUES ('policy-1', '示例医疗险', '示例保险', 'medical', ?, 12340000, "
            "'共享保额', '保留总结', '保留亮点')",
            [DateTime(2025, 1, 1).millisecondsSinceEpoch],
          );
          batch.customStatement(
            'INSERT INTO coverage_responsibilities '
            '(id, commercial_insurance_id, kind, name, description, sort_order) '
            "VALUES ('responsibility-1', 'policy-1', 'medical', '一般医疗', '保留责任说明', 3)",
          );
          batch.customStatement(
            'INSERT INTO responsibility_points '
            '(id, responsibility_id, label, value, sort_order) '
            "VALUES ('point-1', 'responsibility-1', '等待期', '30天', 1)",
          );
        },
        validateItems: (db) async {
          final policy = await db.select(db.commercialInsurances).getSingle();
          expect([
            policy.policyholderName,
            policy.beneficiaryDescription,
            policy.waitingPeriodDescription,
            policy.exclusionsDescription,
          ], everyElement(isNull));
          expect(policy.name, '示例医疗险');
          expect(policy.coverageAmountMinor, 12340000);
          expect(policy.coverageAmountDescription, '共享保额');
          expect(policy.coverageSummary, '保留总结');
          expect(policy.coverageHighlights, '保留亮点');
          final responsibility = await db
              .select(db.coverageResponsibilities)
              .getSingle();
          expect(responsibility.description, '保留责任说明');
          expect(responsibility.sortOrder, 3);
          final point = await db.select(db.responsibilityPoints).getSingle();
          expect(point.label, '等待期');
          expect(point.value, '30天');
          expect(point.sortOrder, 1);
        },
        oldVersion: 64,
        newVersion: 66,
      );
    },
  );

  test('v65 exclusions are merged once and the old column is removed', () async {
    const cases = <(String?, String?, String?)>[
      (null, null, null),
      ('既往症相关约定', null, '既往症相关约定'),
      (null, '指定疾病除外', '指定疾病除外'),
      ('既往症相关约定', '指定疾病除外', '既往症相关约定\n指定疾病除外'),
      ('  同一除外约定  ', '同一除外约定', '同一除外约定'),
      (' \t\r\n ', ' \r\n ', null),
      ('既往症一\n既往症二', '除外一\n除外二', '既往症一\n既往症二\n除外一\n除外二'),
    ];
    await verifier.testWithDataIntegrity<v65.DatabaseAtV65, AppDatabase>(
      createOld: v65.DatabaseAtV65.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        for (var index = 0; index < cases.length; index++) {
          batch.customStatement(
            'INSERT INTO commercial_insurances '
            '(id, name, insurer_name, category, coverage_start_date, '
            'pre_existing_condition_description, exclusions_description, '
            'waiting_period_description, policyholder_name, beneficiary_description, '
            'coverage_summary, coverage_highlights, premium_frequency, '
            'premium_amount_minor, premium_term_count) '
            "VALUES (?, '保留保单', '示例保险', 'medical', ?, ?, ?, '30天', "
            "'投保人甲', '受益人甲', '保留概要', '保留亮点', 'annual', 120000, 20)",
            [
              'policy-$index',
              DateTime(2025, 1, 1).millisecondsSinceEpoch,
              cases[index].$1,
              cases[index].$2,
            ],
          );
        }
        batch.customStatement(
          'INSERT INTO coverage_responsibilities '
          '(id, commercial_insurance_id, kind, name, sort_order) '
          "VALUES ('responsibility', 'policy-0', 'medical', '住院医疗', 0)",
        );
      },
      validateItems: (db) async {
        final policies = await (db.select(
          db.commercialInsurances,
        )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
        expect(
          policies.map((row) => row.exclusionsDescription),
          cases.map((item) => item.$3),
        );
        for (final policy in policies) {
          expect(policy.waitingPeriodDescription, '30天');
          expect(policy.policyholderName, '投保人甲');
          expect(policy.beneficiaryDescription, '受益人甲');
          expect(policy.coverageSummary, '保留概要');
          expect(policy.coverageHighlights, '保留亮点');
          expect(policy.premiumFrequency, PremiumFrequency.annual);
          expect(policy.premiumAmountMinor, 120000);
          expect(policy.premiumTermCount, 20);
        }
        final columns = await db
            .customSelect('PRAGMA table_info(commercial_insurances)')
            .get();
        expect(
          columns.map((row) => row.read<String>('name')),
          isNot(contains('pre_existing_condition_description')),
        );
        expect(
          (await db.select(db.coverageResponsibilities).getSingle())
              .commercialInsuranceId,
          'policy-0',
        );
        await db.customStatement(
          'UPDATE commercial_insurances SET exclusions_description = ? WHERE id = ?',
          ['用户修改后的除外约定', 'policy-3'],
        );
        expect(
          (await (db.select(
                db.commercialInsurances,
              )..where((row) => row.id.equals('policy-3'))).getSingle())
              .exclusionsDescription,
          '用户修改后的除外约定',
        );
      },
      oldVersion: 65,
      newVersion: 66,
    );
  });

  test('v66 member avatars match relationships and genders once', () async {
    const cases = <(String, String, String, MemberAvatarPreset)>[
      ('self', 'male', 'blue', MemberAvatarPreset.male),
      ('self', 'female', 'green', MemberAvatarPreset.female),
      ('self', 'unknown', 'orange', MemberAvatarPreset.male),
      ('spouse', 'male', 'pink', MemberAvatarPreset.male),
      ('spouse', 'female', 'purple', MemberAvatarPreset.female),
      ('spouse', 'unknown', 'teal', MemberAvatarPreset.male),
      ('parent', 'male', 'green', MemberAvatarPreset.father),
      ('parent', 'female', 'orange', MemberAvatarPreset.mother),
      ('parent', 'unknown', 'pink', MemberAvatarPreset.male),
      ('child', 'male', 'purple', MemberAvatarPreset.son),
      ('child', 'female', 'teal', MemberAvatarPreset.daughter),
      ('child', 'unknown', 'blue', MemberAvatarPreset.male),
      ('other', 'male', 'orange', MemberAvatarPreset.male),
      ('other', 'female', 'pink', MemberAvatarPreset.female),
      ('other', 'unknown', 'purple', MemberAvatarPreset.male),
      ('parent', 'male', 'sister', MemberAvatarPreset.sister),
      ('spouse', 'female', 'brother', MemberAvatarPreset.brother),
    ];
    final birthDate = DateTime(1990, 6, 15);
    final createdAt = DateTime(2026, 1, 1);
    await verifier.testWithDataIntegrity<v66.DatabaseAtV66, AppDatabase>(
      createOld: v66.DatabaseAtV66.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, _) {
        for (final (index, values) in cases.indexed) {
          batch.customStatement(
            'INSERT INTO insured_people '
            '(id, name, birth_date, relationship, gender, note, avatar_preset, '
            'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'member-$index',
              '保留成员$index',
              birthDate.millisecondsSinceEpoch ~/ 1000,
              values.$1,
              values.$2,
              '保留备注',
              values.$3,
              createdAt.millisecondsSinceEpoch ~/ 1000,
              createdAt.millisecondsSinceEpoch ~/ 1000,
            ],
          );
        }
      },
      validateItems: (db) async {
        final people = {
          for (final person in await db.select(db.insuredPeople).get())
            person.id: person,
        };
        expect(people, hasLength(cases.length));
        for (final (index, values) in cases.indexed) {
          final person = people['member-$index']!;
          expect(person.avatarPreset, values.$4);
          expect(person.relationship.name, values.$1);
          expect(person.gender.name, values.$2);
          expect(person.name, '保留成员$index');
          expect(person.birthDate, birthDate);
          expect(person.note, '保留备注');
          expect(person.createdAt, createdAt);
          expect(person.updatedAt, createdAt);
        }
        await db.customStatement(
          'INSERT INTO insured_people (id, name, birth_date) '
          "VALUES ('default-avatar', '默认头像', ?)",
          [birthDate.millisecondsSinceEpoch ~/ 1000],
        );
        final defaultPerson = await (db.select(
          db.insuredPeople,
        )..where((row) => row.id.equals('default-avatar'))).getSingle();
        expect(defaultPerson.avatarPreset, MemberAvatarPreset.male);
      },
      oldVersion: 66,
      newVersion: 67,
    );
  });

  test('failed avatar migration preserves the old data and default', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow_avatar_migration_rollback_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/schema.sqlite');
    final oldDatabase = v66.DatabaseAtV66(NativeDatabase(file));
    final oldMigrator = Migrator(oldDatabase);
    for (final table in oldDatabase.allTables) {
      await oldMigrator.createTable(table);
    }
    await oldDatabase.customStatement('PRAGMA ignore_check_constraints = ON');
    await oldDatabase.customStatement(
      'INSERT INTO insured_people (id, name, birth_date, note, avatar_preset) '
      "VALUES ('person-1', '', ?, '保留备注', 'blue')",
      [DateTime(1990, 6, 15).millisecondsSinceEpoch ~/ 1000],
    );
    await oldDatabase.customStatement('PRAGMA user_version = 66');
    await oldDatabase.close();

    final target = AppDatabase(NativeDatabase(file));
    await expectLater(
      () => target.customSelect('SELECT 1').get(),
      throwsA(anything),
    );
    await target.close();

    final inspection = v66.DatabaseAtV66(NativeDatabase(file));
    addTearDown(inspection.close);
    final version = await inspection
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 66);
    final person = await inspection
        .customSelect('SELECT avatar_preset, note FROM insured_people')
        .getSingle();
    expect(person.read<String>('avatar_preset'), 'blue');
    expect(person.read<String>('note'), '保留备注');
    final avatarColumn =
        (await inspection
                .customSelect('PRAGMA table_info(insured_people)')
                .get())
            .singleWhere((row) => row.read<String>('name') == 'avatar_preset');
    expect(avatarColumn.read<String>('dflt_value'), "'blue'");
  });

  test(
    'failed exclusions migration retains both old fields and the version',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow_exclusions_rollback_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/schema.sqlite');
      final oldDatabase = v65.DatabaseAtV65(NativeDatabase(file));
      final oldMigrator = Migrator(oldDatabase);
      for (final table in oldDatabase.allTables) {
        await oldMigrator.createTable(table);
      }
      await oldDatabase.customStatement('PRAGMA ignore_check_constraints = ON');
      await oldDatabase.customStatement(
        'INSERT INTO commercial_insurances '
        '(id, name, insurer_name, category, coverage_start_date, '
        'pre_existing_condition_description, exclusions_description) '
        "VALUES ('policy-1', '', '示例保险', 'medical', ?, '既往症约定', '除外约定')",
        [DateTime(2025, 1, 1).millisecondsSinceEpoch],
      );
      await oldDatabase.customStatement('PRAGMA user_version = 65');
      await oldDatabase.close();
      final target = AppDatabase(NativeDatabase(file));
      await expectLater(
        () => target.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await target.close();
      final inspection = v65.DatabaseAtV65(NativeDatabase(file));
      addTearDown(inspection.close);
      expect(
        (await inspection.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        65,
      );
      final policy = await inspection
          .customSelect(
            'SELECT pre_existing_condition_description, exclusions_description '
            'FROM commercial_insurances',
          )
          .getSingle();
      expect(
        policy.read<String>('pre_existing_condition_description'),
        '既往症约定',
      );
      expect(policy.read<String>('exclusions_description'), '除外约定');
    },
  );

  test(
    'failed contract-field migration rolls back earlier added columns',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow_contract_migration_rollback_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/schema.sqlite');
      final oldDatabase = v64.DatabaseAtV64(NativeDatabase(file));
      final oldMigrator = Migrator(oldDatabase);
      for (final table in oldDatabase.allTables) {
        await oldMigrator.createTable(table);
      }
      await oldDatabase.customStatement(
        'INSERT INTO commercial_insurances '
        '(id, name, insurer_name, category, coverage_start_date) '
        "VALUES ('policy-1', '保留保单', '示例保险', 'medical', ?)",
        [DateTime(2025, 1, 1).millisecondsSinceEpoch],
      );
      await oldDatabase.customStatement(
        'ALTER TABLE commercial_insurances ADD COLUMN waiting_period_description TEXT',
      );
      await oldDatabase.customStatement('PRAGMA user_version = 64');
      await oldDatabase.close();
      final target = AppDatabase(NativeDatabase(file));
      await expectLater(
        () => target.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await target.close();
      final inspection = v64.DatabaseAtV64(NativeDatabase(file));
      addTearDown(inspection.close);
      final version = await inspection
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 64);
      final policy = await inspection
          .customSelect('SELECT name FROM commercial_insurances')
          .getSingle();
      expect(policy.read<String>('name'), '保留保单');
      final columns =
          (await inspection
                  .customSelect('PRAGMA table_info(commercial_insurances)')
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(columns, contains('waiting_period_description'));
      for (final name in const [
        'policyholder_name',
        'beneficiary_description',
        'pre_existing_condition_description',
        'exclusions_description',
      ]) {
        expect(columns, isNot(contains(name)));
      }
    },
  );

  test(
    'failed responsibility migration rolls back the added column and codes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow_responsibility_migration_rollback_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/schema.sqlite');
      final oldDatabase = v63.DatabaseAtV63(NativeDatabase(file));
      final oldMigrator = Migrator(oldDatabase);
      for (final table in oldDatabase.allTables) {
        await oldMigrator.createTable(table);
      }
      await oldDatabase.customStatement(
        'INSERT INTO coverage_responsibilities '
        '(id, commercial_insurance_id, kind, name, sort_order) '
        "VALUES ('responsibility-1', 'policy-1', 'criticalIllness', '保留名称', 0)",
      );
      await oldDatabase.customStatement(
        'CREATE TRIGGER fail_responsibility_upgrade '
        'BEFORE UPDATE OF kind ON coverage_responsibilities '
        "BEGIN SELECT RAISE(ABORT, 'injected migration failure'); END",
      );
      await oldDatabase.customStatement('PRAGMA user_version = 63');
      await oldDatabase.close();

      final target = AppDatabase(NativeDatabase(file));
      await expectLater(
        () => target.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await target.close();

      final inspection = v63.DatabaseAtV63(NativeDatabase(file));
      addTearDown(inspection.close);
      final version = await inspection
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 63);
      final responsibility = await inspection
          .customSelect('SELECT kind, name FROM coverage_responsibilities')
          .getSingle();
      expect(responsibility.read<String>('kind'), 'criticalIllness');
      expect(responsibility.read<String>('name'), '保留名称');
      final columns = await inspection
          .customSelect('PRAGMA table_info(coverage_responsibilities)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        isNot(contains('description')),
      );
    },
  );

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
