import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../helper/legacy_installment_tables.dart';

void main() {
  test(
    'v41 splits product rules, resolves end dates and preserves contract facts',
    () async {
      final file = await _legacyDatabase();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final stages =
          await (db.select(db.installmentStageConfigs)
                ..where((row) => row.contractId.equals('loan'))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      expect(stages.map((row) => row.id), ['loan-deferment', 'loan-repayment']);
      expect(stages.map((row) => row.endDate), [
        DateTime(2025, 12, 31),
        DateTime(2026, 3, 31),
      ]);
      expect(stages.last.initialRatePpm, 36000);
      expect(stages.last.inPeriodRepricingPolicy, 'dynamicPeriodRate');
      expect(stages.last.tailDifference, 'lastPeriod');
      final productStages =
          await (db.select(db.installmentProductStageConfigs)
                ..where((row) => row.productId.equals('template'))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      expect(productStages.map((row) => row.id), [
        'template-deferment',
        'template-repayment',
      ]);
      expect(productStages.last.rateType, 'fixed');
      expect(productStages.last.tailDifference, 'lastPeriod');

      final contract = await (db.select(
        db.installmentContracts,
      )..where((row) => row.id.equals('loan'))).getSingle();
      expect(contract.name, '既有合同');
      expect(contract.principalMinor, 100000);
      expect(contract.borrowingDate, DateTime(2025, 12, 1));
      final schedule = await db.select(db.installmentSchedules).getSingle();
      expect(schedule.id, 'saved-schedule');
      expect(schedule.stageId, 'loan-repayment');
      expect(schedule.expectedPrincipalMinor, 12345);
      expect(schedule.expectedInterestMinor, 234);
      expect(schedule.status, InstallmentScheduleStatus.partiallyPaid);
      expect(schedule.manuallyAdjusted, isTrue);
      final config = await db
          .select(db.installmentRepricingConfigs)
          .getSingle();
      expect(config.stageId, 'loan-repayment');
      expect(config.lastGeneratedDate?.toUtc(), DateTime.utc(2026, 1, 20));
      final record = await db
          .select(db.installmentRepricingRecords)
          .getSingle();
      expect(record.id, 'saved-repricing');
      expect(record.stageId, 'loan-repayment');
      expect(record.referenceRatePpm, 40000);
      expect(record.spreadBp, -30);
      expect(record.status, 'userConfirmed');
      final contractColumns =
          (await db
                  .customSelect('PRAGMA table_info(installment_contracts)')
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(
        contractColumns.intersection({
          'product_id',
          'product_name',
          'custom_rules',
          'tail_difference',
          'start_date',
        }),
        isEmpty,
      );
      final stageColumns = await db
          .customSelect('PRAGMA table_info(installment_stage_configs)')
          .get();
      expect(
        stageColumns
            .map((row) => row.read<String>('name'))
            .toSet()
            .intersection({
              'owner_type',
              'owner_id',
              'rate_ppm',
              'until_date',
              'last_date',
              'reference_rate_type',
            }),
        isEmpty,
      );
      expect(
        stageColumns
            .singleWhere((row) => row.read<String>('name') == 'end_date')
            .read<int>('notnull'),
        1,
      );
      for (final table in db.allTables) {
        expect(
          await db
              .customSelect('PRAGMA foreign_key_list(${table.actualTableName})')
              .get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'v42 failure after copying products restores the complete v41 schema',
    () async {
      final file = await _legacyDatabase(orphanStage: true);
      final db = AppDatabase(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<StateError>()),
      );
      await db.close();
      final old = _LegacyInspection(NativeDatabase(file));
      addTearDown(old.close);
      expect(
        (await old.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        41,
      );
      expect(
        await old
            .customSelect(
              "SELECT name FROM sqlite_master WHERE name = 'installment_product_stage_configs'",
            )
            .get(),
        isEmpty,
      );
      expect(
        (await old
                .customSelect(
                  "SELECT COUNT(*) AS n FROM installment_stage_configs WHERE owner_id = 'template'",
                )
                .getSingle())
            .read<int>('n'),
        2,
      );
      expect(
        (await old
                .customSelect(
                  "SELECT rate_ppm FROM installment_stage_configs WHERE id = 'loan-repayment'",
                )
                .getSingle())
            .read<int>('rate_ppm'),
        36000,
      );
      expect(
        (await old
                .customSelect(
                  'SELECT status FROM installment_repricing_records',
                )
                .getSingle())
            .read<String>('status'),
        'userConfirmed',
      );
    },
  );
}

Future<File> _legacyDatabase({bool orphanStage = false}) async {
  final directory = await Directory.systemTemp.createTemp(
    'smartflow-v41-product-split-',
  );
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/loan.sqlite');
  final db = AppDatabase(NativeDatabase(file));
  await prepareLegacyInstallmentTables(db);
  await db
      .into(db.installmentProducts)
      .insert(
        InstallmentProductsCompanion.insert(id: 'template', name: '分期模板'),
      );
  await db
      .into(db.installmentContracts)
      .insert(
        InstallmentContractsCompanion.insert(
          id: 'loan',
          name: const Value('既有合同'),
          liabilityAccountId: 'loan-account',
          sourceType: InstallmentSourceType.disbursement,
          principalMinor: 100000,
          borrowingDate: DateTime(2025, 12, 1),
          status: InstallmentContractStatus.active,
        ),
      );
  await db.customStatement(
    "UPDATE installment_contracts SET product_id = 'template', product_name = '旧模板名称' WHERE id = 'loan'",
  );
  for (final product in [true, false]) {
    final owner = product ? 'template' : 'loan';
    await insertLegacyInstallmentStage(db, {
      'id': '$owner-deferment',
      'owner_type': product ? 'product' : 'contract',
      'owner_id': owner,
      'position': 0,
      'stage_kind': 'deferment',
      if (!product) 'until_date': DateTime(2025, 12, 31),
    });
    await insertLegacyInstallmentStage(db, {
      'id': '$owner-repayment',
      'owner_type': product ? 'product' : 'contract',
      'owner_id': !product && orphanStage ? 'missing-contract' : owner,
      'position': 1,
      'stage_kind': 'repayment',
      'repayment_method': 'equalInstallment',
      'interval_months': 1,
      'rate_period': 'annual',
      'accrual': 'daily',
      'amount_algorithm': 'actualRate',
      if (!product) ...{
        'periods': 3,
        'first_date': DateTime(2026, 1, 31),
        'rate_ppm': 36000,
        'repricing_payment_timing': 'currentPeriod',
      },
    });
  }
  await db
      .into(db.installmentSchedules)
      .insert(
        InstallmentSchedulesCompanion.insert(
          id: 'saved-schedule',
          contractId: 'loan',
          stageId: const Value('loan-repayment'),
          periodNo: 1,
          expectedRepaymentDate: DateTime(2026, 1, 31),
          expectedPrincipalMinor: const Value(12345),
          expectedInterestMinor: const Value(234),
          status: InstallmentScheduleStatus.partiallyPaid,
          manuallyAdjusted: const Value(true),
        ),
      );
  await db
      .into(db.installmentRepricingConfigs)
      .insert(
        InstallmentRepricingConfigsCompanion.insert(
          id: 'saved-config',
          contractId: 'loan',
          stageId: 'loan-repayment',
          effectiveFrom: DateTime.utc(2025, 12, 31),
          referenceRateType: 'lprOneYear',
          spreadBp: -30,
          firstResetDate: DateTime.utc(2026, 1, 20),
          firstEffectiveDate: DateTime.utc(2026, 2, 1),
          cycleMonths: 12,
          lastGeneratedDate: Value(DateTime.utc(2026, 2, 1)),
        ),
      );
  await db
      .into(db.installmentRepricingRecords)
      .insert(
        InstallmentRepricingRecordsCompanion.insert(
          id: 'saved-repricing',
          contractId: 'loan',
          stageId: 'loan-repayment',
          resetDate: DateTime.utc(2026, 1, 20),
          effectiveDate: DateTime.utc(2026, 2, 1),
          referenceRateDate: DateTime.utc(2026, 1, 19),
          referenceRateType: 'lprOneYear',
          referenceRatePpm: 40000,
          spreadBp: -30,
          source: 'legacy',
          status: const Value('userConfirmed'),
        ),
      );
  await finishLegacyInstallmentTables(db);
  await db.customStatement('PRAGMA user_version = 41');
  await db.close();
  return file;
}

class _LegacyInspection extends GeneratedDatabase {
  _LegacyInspection(super.executor);
  @override
  int get schemaVersion => 41;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(beforeOpen: (_) async {});
}
