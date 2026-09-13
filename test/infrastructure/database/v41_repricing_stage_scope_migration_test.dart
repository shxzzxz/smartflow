import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test(
    'v40 restores stage scope and preserves snapshots and generation progress',
    () async {
      final file = await legacyDatabase();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final configurations = await (db.select(
        db.installmentRepricingConfigs,
      )..orderBy([(row) => OrderingTerm.asc(row.effectiveFrom)])).get();
      final records = await (db.select(
        db.installmentRepricingRecords,
      )..orderBy([(row) => OrderingTerm.asc(row.effectiveDate)])).get();
      expect(configurations.map((row) => row.stageId), ['first', 'second']);
      expect(records.map((row) => row.stageId), ['first', 'second']);
      expect(configurations.map((row) => row.lastGeneratedDate?.toUtc()), [
        DateTime.utc(2026, 8, 20),
        DateTime.utc(2026, 10, 8),
      ]);
      expect(records.map((row) => row.status), ['userConfirmed', 'pending']);
      expect(records.map((row) => row.referenceRatePpm), [36000, 42000]);
      expect(records.map((row) => row.source).toSet(), {'legacy'});
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        41,
      );
      await db.customStatement(
        'INSERT INTO installment_repricing_records '
        'SELECT id || ?, contract_id, ?, reset_date, effective_date, reference_rate_date, '
        'reference_rate_type, reference_rate_ppm, spread_bp, source, status, created_at '
        'FROM installment_repricing_records WHERE id = ?',
        ['-other-stage', 'second', 'first-result'],
      );
      expect(
        await db.select(db.installmentRepricingRecords).get(),
        hasLength(3),
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
    'unassignable v40 facts roll back both stage columns and all rows',
    () async {
      final file = await legacyDatabase(unassignable: true);
      final db = AppDatabase(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<StateError>()),
      );
      await db.close();
      final legacy = _LegacyInspection(NativeDatabase(file));
      addTearDown(legacy.close);
      expect(
        (await legacy.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        40,
      );
      for (final table in [
        'installment_repricing_configs',
        'installment_repricing_records',
      ]) {
        expect(
          (await legacy.customSelect('PRAGMA table_info($table)').get()).map(
            (row) => row.read<String>('name'),
          ),
          isNot(contains('stage_id')),
        );
        expect(
          (await legacy
                  .customSelect('SELECT COUNT(*) AS n FROM $table')
                  .getSingle())
              .read<int>('n'),
          2,
        );
      }
    },
  );
}

Future<File> legacyDatabase({bool unassignable = false}) async {
  final directory = await Directory.systemTemp.createTemp(
    'smartflow-v40-stage-scope-',
  );
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/loan.sqlite');
  final db = AppDatabase(NativeDatabase(file));
  await db.customSelect('SELECT 1').get();
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
  for (final (id, position, month) in [('first', 0, 9), ('second', 1, 11)]) {
    await db
        .into(db.installmentStageConfigs)
        .insert(
          InstallmentStageConfigsCompanion.insert(
            id: id,
            ownerType: 'contract',
            ownerId: 'loan',
            position: position,
            stageKind: 'repayment',
            repaymentMethod: const Value('interestFirst'),
            intervalMonths: const Value(1),
            periods: const Value(2),
            firstDate: Value(DateTime(2026, month, 8)),
            ratePeriod: const Value('annual'),
            ratePpm: const Value(36000),
            accrual: const Value('daily'),
          ),
        );
  }
  await db.customStatement('DROP TABLE installment_repricing_configs');
  await db.customStatement('DROP TABLE installment_repricing_records');
  await db.customStatement('''CREATE TABLE installment_repricing_configs (
    id TEXT PRIMARY KEY, contract_id TEXT NOT NULL, effective_from INTEGER NOT NULL,
    reference_rate_type TEXT NOT NULL, spread_bp INTEGER NOT NULL,
    first_reset_date INTEGER NOT NULL, first_effective_date INTEGER NOT NULL,
    cycle_months INTEGER NOT NULL, last_generated_date INTEGER, created_at INTEGER NOT NULL,
    UNIQUE (contract_id, effective_from))''');
  await db.customStatement('''CREATE TABLE installment_repricing_records (
    id TEXT PRIMARY KEY, contract_id TEXT NOT NULL, reset_date INTEGER NOT NULL,
    effective_date INTEGER NOT NULL, reference_rate_date INTEGER NOT NULL,
    reference_rate_type TEXT NOT NULL, reference_rate_ppm INTEGER NOT NULL,
    spread_bp INTEGER NOT NULL, source TEXT NOT NULL, status TEXT NOT NULL,
    created_at INTEGER NOT NULL, UNIQUE (contract_id, effective_date))''');
  int epoch(int month, int day) =>
      DateTime.utc(2026, month, day).millisecondsSinceEpoch ~/ 1000;
  for (final first in [true, false]) {
    final date = epoch(first ? 8 : 10, first ? 20 : 8);
    await db.customStatement(
      'INSERT INTO installment_repricing_configs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        first ? 'first:repricing' : 'loan:configuration:second',
        'loan',
        epoch(first ? 8 : 10, 8),
        'lprOneYear',
        -30,
        date,
        date,
        3,
        date,
        date,
      ],
    );
    await db.customStatement(
      'INSERT INTO installment_repricing_records VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        first ? 'first-result' : 'second-result',
        'loan',
        date,
        !first && unassignable ? epoch(12, 20) : date,
        date - 86400,
        'lprOneYear',
        first ? 36000 : 42000,
        -30,
        'legacy',
        first ? 'userConfirmed' : 'pending',
        date,
      ],
    );
  }
  await db.customStatement('PRAGMA user_version = 40');
  await db.close();
  return file;
}

class _LegacyInspection extends GeneratedDatabase {
  _LegacyInspection(super.executor);
  @override
  int get schemaVersion => 40;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  MigrationStrategy get migration =>
      MigrationStrategy(beforeOpen: (_) async {});
}
