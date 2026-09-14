import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/data_management/backup/installment_backup_migration.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  for (final scenario in [
    (
      name: 'processed result may already have been deleted',
      from: DateTime.utc(2026, 1, 1),
      reset: DateTime.utc(2026, 1, 31),
      effective: DateTime.utc(2026, 2, 1),
      progress: DateTime.utc(2026, 8, 1),
      expected: DateTime.utc(2026, 7, 31),
    ),
    (
      name: 'month-end anchors recover the corresponding reset',
      from: DateTime.utc(2026, 8, 1),
      reset: DateTime.utc(2026, 8, 30),
      effective: DateTime.utc(2026, 8, 31),
      progress: DateTime.utc(2027, 2, 28),
      expected: DateTime.utc(2027, 2, 28),
    ),
    (
      name: 'an old reset before configuration start creates no progress',
      from: DateTime.utc(2026, 6, 21),
      reset: DateTime.utc(2026, 6, 20),
      effective: DateTime.utc(2026, 6, 21),
      progress: DateTime.utc(2026, 6, 21),
      expected: null,
    ),
  ]) {
    test('v42 database and backup: ${scenario.name}', () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-v43-repricing-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/loan.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      await old.customSelect('SELECT 1').get();
      await old.customStatement(
        "INSERT INTO accounts (id, name, account_type, account_subtype, account_profile_key) VALUES ('account', 'Existing loan', 'liability', 'loan', 'credit.loan')",
      );
      await old.customStatement(
        "INSERT INTO installment_contracts (id, liability_account_id, source_type, principal_minor, borrowing_date, status) VALUES ('loan', 'account', 'disbursement', 100000, ?, 'active')",
        [_seconds(DateTime.utc(2025, 1, 1))],
      );
      await old.customStatement(
        "INSERT INTO installment_stage_configs (id, contract_id, position, stage_kind, repayment_method, interval_months, rate_period, accrual, periods, initial_rate_ppm, tail_difference, fee_minor, end_date, first_date) VALUES ('stage', 'loan', 0, 'repayment', 'interestFirst', 12, 'annual', 'daily', 3, 48000, 'lastPeriod', 0, ?, ?)",
        [
          _seconds(DateTime.utc(2028, 6, 20)),
          _seconds(DateTime.utc(2026, 6, 20)),
        ],
      );
      await old.customStatement(
        "INSERT INTO installment_repricing_configs (id, contract_id, stage_id, effective_from, reference_rate_type, spread_bp, first_reset_date, first_effective_date, cycle_months, last_generated_date) VALUES ('config', 'loan', 'stage', ?, 'lprOneYear', 0, ?, ?, 3, ?)",
        [
          _seconds(scenario.from),
          _seconds(scenario.reset),
          _seconds(scenario.effective),
          _seconds(scenario.progress),
        ],
      );
      final snapshot = await DriftBackupGateway(old).readSnapshot();
      await old.customStatement('PRAGMA user_version = 42');
      await old.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final configuration = await migrated
          .select(migrated.installmentRepricingConfigs)
          .getSingle();
      expect(configuration.lastGeneratedDate?.toUtc(), scenario.expected);
      expect(
        await migrated.select(migrated.installmentRepricingRecords).get(),
        isEmpty,
      );

      final tables = <String, Iterable<BackupJson>>{...snapshot.tables};
      migrateInstallmentBackup(tables, schemaVersion: 42, formatVersion: 2);
      final restored = snapshot.copyWith(tables: tables);
      BackupService.validateSnapshot(restored);
      expect(
        restored
            .rows('installment_repricing_configs')
            .single['lastGeneratedDate'],
        scenario.expected?.millisecondsSinceEpoch,
      );
      expect(restored.rows('installment_repricing_records'), isEmpty);
    });
  }
}

int _seconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;
