import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test(
    'v39 preserves stage scopes, progress and same-day records without foreign keys',
    () async {
      final file = await _legacyDatabase();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final configs = await (db.select(
        db.installmentRepricingConfigs,
      )..orderBy([(row) => OrderingTerm.asc(row.effectiveFrom)])).get();
      expect(configs.map((row) => row.effectiveFrom.toUtc()), [
        DateTime.utc(2026, 8, 16),
        DateTime.utc(2026, 11, 8),
      ]);
      expect(configs.map((row) => row.lastGeneratedDate?.toUtc()), [
        DateTime.utc(2026, 8, 20),
        DateTime.utc(2026, 11, 8),
      ]);
      expect(configs.map((row) => row.spreadBp), [-30, -10]);
      final records =
          await (db.select(db.installmentRepricingRecords)..orderBy([
                (row) => OrderingTerm.asc(row.effectiveDate),
                (row) => OrderingTerm.asc(row.id),
              ]))
              .get();
      expect(records.map((row) => row.id), ['confirmed', 'pending', 'next']);
      expect(records.map((row) => row.stageId), ['second', 'first', 'second']);
      expect(configs.map((row) => row.stageId), ['first', 'second']);
      expect(records.map((row) => row.status), [
        'userConfirmed',
        'pending',
        'pending',
      ]);
      expect(records.first.referenceRatePpm, 36000);
      expect(records.first.createdAt.toUtc(), DateTime.utc(2026, 8, 20));
      expect(
        (await db
                .customSelect(
                  'PRAGMA table_info(installment_repricing_records)',
                )
                .get())
            .map((row) => row.read<String>('name')),
        contains('stage_id'),
      );
      final stages = await db.select(db.installmentStageConfigs).get();
      expect(
        stages.every(
          (stage) =>
              stage.referenceRateType == null && stage.firstResetDate == null,
        ),
        isTrue,
      );
      expect(
        stages
            .where((stage) => stage.id == 'first')
            .single
            .repricingPaymentTiming,
        'currentPeriod',
      );
      expect(
        (await db.select(db.installmentSchedules).getSingle()).id,
        'old-schedule',
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        41,
      );
      for (final table in db.allTables) {
        expect(
          await db
              .customSelect('PRAGMA foreign_key_list(${table.actualTableName})')
              .get(),
          isEmpty,
        );
      }
      await expectLater(
        db.customStatement(
          'INSERT INTO installment_repricing_records SELECT id || ?, contract_id, stage_id, reset_date, effective_date, '
          'reference_rate_date, reference_rate_type, reference_rate_ppm, spread_bp, source, status, created_at '
          'FROM installment_repricing_records WHERE id = ?',
          ['-duplicate', 'confirmed'],
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'conflicting legacy facts roll back schema and rows, then upgrade succeeds after correction',
    () async {
      final file = await _legacyDatabase(conflict: true);
      final db = AppDatabase(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<StateError>()),
      );
      await db.close();
      final raw = NativeDatabase(file);
      final connection = _LegacyInspection(raw);
      expect(
        (await connection.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        39,
      );
      final tables =
          (await connection
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table'",
                  )
                  .get())
              .map((row) => row.read<String>('name'));
      expect(tables, isNot(contains('installment_repricing_configs')));
      expect(tables, isNot(contains('installment_interest_adjustments')));
      expect(
        (await connection
                .customSelect(
                  'SELECT COUNT(*) AS count FROM installment_repricing_records',
                )
                .getSingle())
            .read<int>('count'),
        3,
      );
      expect(
        (await connection
                .customSelect(
                  "SELECT reference_rate_type AS type FROM installment_stage_configs WHERE id = 'first'",
                )
                .getSingle())
            .read<String>('type'),
        'lprOneYear',
      );
      await connection.customStatement(
        "DELETE FROM installment_repricing_records WHERE id = 'confirmed'",
      );
      await connection.close();
      final retry = AppDatabase(NativeDatabase(file));
      addTearDown(retry.close);
      expect(
        await retry.select(retry.installmentRepricingConfigs).get(),
        hasLength(2),
      );
      expect(
        await retry.select(retry.installmentRepricingRecords).get(),
        hasLength(2),
      );
    },
  );
}

Future<File> _legacyDatabase({bool conflict = false}) async {
  final directory = await Directory.systemTemp.createTemp(
    'smartflow-v39-operations-',
  );
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/loan.sqlite');
  final db = AppDatabase(NativeDatabase(file));
  await db.customSelect('SELECT 1').get();
  await db.customStatement('DROP TABLE installment_repricing_configs');
  await db.customStatement('DROP TABLE installment_interest_adjustments');
  await db.customStatement('DROP TABLE installment_repricing_records');
  await db.customStatement('''CREATE TABLE installment_repricing_records (
    id TEXT NOT NULL PRIMARY KEY, contract_id TEXT NOT NULL, stage_id TEXT NOT NULL,
    reset_date INTEGER NOT NULL, effective_date INTEGER NOT NULL,
    reference_rate_date INTEGER NOT NULL, reference_rate_type TEXT NOT NULL,
    reference_rate_ppm INTEGER NOT NULL, spread_bp INTEGER NOT NULL, source TEXT NOT NULL,
    status TEXT NOT NULL, created_at INTEGER NOT NULL,
    UNIQUE (contract_id, stage_id, reset_date))''');
  await db
      .into(db.installmentContracts)
      .insert(
        InstallmentContractsCompanion.insert(
          id: 'loan',
          liabilityAccountId: 'account',
          sourceType: InstallmentSourceType.disbursement,
          principalMinor: 10000000,
          borrowingDate: DateTime(2026, 8, 8),
          status: InstallmentContractStatus.active,
        ),
      );
  await db
      .into(db.installmentStageConfigs)
      .insert(
        InstallmentStageConfigsCompanion.insert(
          id: 'deferment',
          ownerType: 'contract',
          ownerId: 'loan',
          position: 0,
          stageKind: 'deferment',
          untilDate: Value(DateTime(2026, 8, 15)),
        ),
      );
  for (final first in [true, false]) {
    await db
        .into(db.installmentStageConfigs)
        .insert(
          InstallmentStageConfigsCompanion.insert(
            id: first ? 'first' : 'second',
            ownerType: 'contract',
            ownerId: 'loan',
            position: first ? 1 : 2,
            stageKind: 'repayment',
            repaymentMethod: const Value('equalPrincipal'),
            intervalMonths: const Value(1),
            ratePeriod: const Value('annual'),
            ratePpm: const Value(36000),
            accrual: const Value('monthly'),
            periods: Value(first ? 3 : 2),
            firstDate: Value(DateTime(2026, first ? 9 : 12, 8)),
            accrualStartDate: Value(first ? DateTime(2026, 8, 16) : null),
            endPrincipalMinor: Value(first ? 5000000 : 0),
            referenceRateType: const Value('lprOneYear'),
            spreadBp: Value(first ? -30 : -10),
            firstResetDate: Value(
              DateTime(2026, first ? 8 : 11, first ? 20 : 1),
            ),
            firstEffectiveDate: Value(
              DateTime(2026, first ? 8 : 11, first ? 20 : 8),
            ),
            repricingCycleMonths: const Value(3),
            repricingPaymentTiming: const Value('currentPeriod'),
          ),
        );
  }
  await db
      .into(db.installmentSchedules)
      .insert(
        InstallmentSchedulesCompanion.insert(
          id: 'old-schedule',
          contractId: 'loan',
          stageId: const Value('first'),
          periodNo: 1,
          expectedRepaymentDate: DateTime(2026, 9, 8),
          expectedPrincipalMinor: const Value(1000000),
          expectedInterestMinor: const Value(30000),
          expectedFeeMinor: const Value(0),
          status: InstallmentScheduleStatus.pending,
        ),
      );
  int epoch(int month, int day) =>
      DateTime.utc(2026, month, day).millisecondsSinceEpoch ~/ 1000;
  for (final id in ['pending', 'confirmed', 'next']) {
    final next = id == 'next';
    await db.customStatement(
      'INSERT INTO installment_repricing_records VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        'loan',
        id == 'pending' || (conflict && id == 'confirmed') ? 'first' : 'second',
        epoch(
          next ? 11 : 8,
          next
              ? 1
              : conflict && id == 'confirmed'
              ? 19
              : 20,
        ),
        epoch(next ? 11 : 8, next ? 8 : 20),
        epoch(next ? 10 : 8, next ? 31 : 19),
        'lprOneYear',
        conflict && id == 'confirmed' ? 35000 : 36000,
        next ? -10 : -30,
        'legacy',
        id == 'confirmed' ? 'userConfirmed' : 'pending',
        epoch(next ? 11 : 8, next ? 1 : 20),
      ],
    );
  }
  await db.customStatement('PRAGMA user_version = 39');
  await db.close();
  return file;
}

class _LegacyInspection extends GeneratedDatabase {
  _LegacyInspection(super.executor);
  @override
  int get schemaVersion => 39;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(beforeOpen: (_) async {});
}
