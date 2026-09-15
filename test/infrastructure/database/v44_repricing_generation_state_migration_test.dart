import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/data_management/backup/installment_backup_migration.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test(
    'v43 database and backup retain generation progress without creating records',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-v44-repricing-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/loan.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      var oldClosed = false;
      addTearDown(() async {
        if (!oldClosed) await old.close();
      });
      await old.customStatement(
        "INSERT INTO accounts (id, name, account_type, account_subtype, account_profile_key) VALUES ('account', 'loan', 'liability', 'loan', 'credit.loan')",
      );
      await old.customStatement(
        "INSERT INTO installment_contracts (id, liability_account_id, source_type, principal_minor, borrowing_date, status) VALUES ('loan', 'account', 'disbursement', 100000, 1735689600, 'active')",
      );
      await old.customStatement(
        "INSERT INTO installment_stage_configs (id, contract_id, position, stage_kind, repayment_method, interval_months, rate_period, accrual, periods, initial_rate_ppm, tail_difference, fee_minor, first_date, end_date) VALUES ('stage', 'loan', 0, 'repayment', 'interestFirst', 12, 'annual', 'daily', 3, 48000, 'lastPeriod', 0, 1767225600, ?)",
        [DateTime.utc(2028, 1, 1).millisecondsSinceEpoch ~/ 1000],
      );
      final progress = DateTime.utc(2025, 12, 21);
      await old.customStatement(
        "INSERT INTO installment_repricing_configs (id, contract_id, stage_id, effective_from, reference_rate_type, spread_bp, first_reset_date, first_effective_date, cycle_months, last_generated_date) VALUES ('config', 'loan', 'stage', 1735689600, 'lprOneYear', 0, 1737417600, 1737417600, 12, ?)",
        [progress.millisecondsSinceEpoch ~/ 1000],
      );
      final snapshot = await DriftBackupGateway(old).readSnapshot();
      await old.customStatement(
        'DROP INDEX installment_repricing_configs_active_idx',
      );
      await old.customStatement(
        'DROP INDEX installment_repricing_records_pending_idx',
      );
      await old.customStatement(
        'ALTER TABLE installment_repricing_configs DROP COLUMN generation_completed',
      );
      await old.customStatement('PRAGMA user_version = 43');
      await old.close();
      oldClosed = true;

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final config = await migrated
          .select(migrated.installmentRepricingConfigs)
          .getSingle();
      expect(config.lastGeneratedDate?.toUtc(), progress);
      expect(config.generationCompleted, isFalse);
      expect(
        await migrated.select(migrated.installmentRepricingRecords).get(),
        isEmpty,
      );
      final indexes = await migrated
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      expect(
        indexes.map((r) => r.read<String>('name')),
        containsAll([
          'installment_repricing_configs_active_idx',
          'installment_repricing_records_pending_idx',
        ]),
      );

      final tables = <String, Iterable<BackupJson>>{
        ...snapshot.tables,
        'installment_repricing_configs': [
          for (final row in snapshot.rows('installment_repricing_configs'))
            {...row}..remove('generationCompleted'),
        ],
      };
      migrateInstallmentBackup(tables, schemaVersion: 43, formatVersion: 3);
      final restored = snapshot.copyWith(tables: tables);
      BackupService.validateSnapshot(restored);
      expect(
        restored
            .rows('installment_repricing_configs')
            .single['lastGeneratedDate'],
        progress.millisecondsSinceEpoch,
      );
      expect(
        restored
            .rows('installment_repricing_configs')
            .single['generationCompleted'],
        isFalse,
      );
      await DriftBackupGateway(migrated).replaceSnapshot(restored);
      await migrated.customStatement(
        'UPDATE installment_repricing_configs SET generation_completed = 1',
      );
      final completed = await DriftBackupGateway(migrated).readSnapshot();
      BackupService.validateSnapshot(completed);
      await DriftBackupGateway(migrated).replaceSnapshot(completed);
      expect(
        (await migrated
                .select(migrated.installmentRepricingConfigs)
                .getSingle())
            .generationCompleted,
        isTrue,
      );
      expect(
        await migrated.select(migrated.installmentRepricingRecords).get(),
        isEmpty,
      );
    },
  );
}
