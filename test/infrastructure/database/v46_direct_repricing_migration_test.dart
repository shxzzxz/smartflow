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
    'v45 database and backup preserve reference facts while allowing direct repricing',
    () async {
      final directory = await Directory.systemTemp.createTemp('smartflow-v46-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/loan.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      var closed = false;
      addTearDown(() async {
        if (!closed) await old.close();
      });
      int seconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;
      final borrowed = seconds(DateTime.utc(2025, 12, 20));
      final quoted = seconds(DateTime.utc(2025, 12, 19));
      await old.customStatement(
        "INSERT INTO accounts (id, name, account_type, account_subtype, account_profile_key) VALUES ('account', 'loan', 'liability', 'loan', 'credit.loan')",
      );
      await old.customStatement(
        "INSERT INTO installment_contracts (id, liability_account_id, source_type, principal_minor, borrowing_date, status) VALUES ('loan', 'account', 'disbursement', 100000, ?, 'active')",
        [borrowed],
      );
      await old.customStatement(
        "INSERT INTO installment_stage_configs (id, contract_id, position, stage_kind, repayment_method, interval_months, rate_period, accrual, periods, initial_rate_ppm, tail_difference, fee_minor, first_date, end_date) VALUES ('stage', 'loan', 0, 'repayment', 'interestFirst', 1, 'annual', 'monthly', 3, 36000, 'lastPeriod', 0, ?, ?)",
        [
          seconds(DateTime.utc(2026, 1, 20)),
          seconds(DateTime.utc(2026, 3, 20)),
        ],
      );
      await old.customStatement(
        "INSERT INTO reference_rates (type, rate_date, rate_ppm, source) VALUES ('lprOneYear', ?, 30000, 'fixture')",
        [quoted],
      );
      await old.customStatement('DROP TABLE installment_repricing_records');
      await old.customStatement('''
CREATE TABLE installment_repricing_records (
  id TEXT NOT NULL PRIMARY KEY,
  contract_id TEXT NOT NULL,
  stage_id TEXT NOT NULL,
  reset_date INTEGER NOT NULL,
  effective_date INTEGER NOT NULL,
  reference_rate_date INTEGER NOT NULL,
  reference_rate_type TEXT NOT NULL,
  reference_rate_ppm INTEGER NOT NULL,
  spread_bp INTEGER NOT NULL,
  source TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL,
  UNIQUE (contract_id, stage_id, effective_date),
  CHECK (status IN ('pending', 'applied', 'userConfirmed')),
  CHECK (reference_rate_ppm >= 0 AND reference_rate_ppm + spread_bp * 100 >= 0),
  CHECK (reference_rate_date <= reset_date AND reset_date <= effective_date)
)
''');
      const statuses = ['pending', 'applied', 'userConfirmed'];
      for (var i = 0; i < statuses.length; i++) {
        final effective = seconds(DateTime.utc(2026, i + 1, 1));
        await old.customStatement(
          "INSERT INTO installment_repricing_records VALUES (?, 'loan', 'stage', ?, ?, ?, 'lprOneYear', 30000, -30, 'fixture', ?, ?)",
          [
            'rate-$i',
            effective - 86400,
            effective,
            quoted,
            statuses[i],
            borrowed + i,
          ],
        );
      }
      await old.customStatement(
        "CREATE INDEX installment_repricing_records_pending_idx ON installment_repricing_records (contract_id) WHERE status = 'pending'",
      );
      await old.customStatement('PRAGMA user_version = 45');
      await old.close();
      closed = true;

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final rows = await db.select(db.installmentRepricingRecords).get();
      expect(rows, hasLength(3));
      for (var i = 0; i < statuses.length; i++) {
        final row = rows.singleWhere((row) => row.id == 'rate-$i');
        expect(row.pricingMethod, 'reference');
        expect(row.status, statuses[i]);
        expect(row.stageId, 'stage');
        expect(row.referenceRatePpm, 30000);
        expect(row.referenceRateType, 'lprOneYear');
        expect(row.spreadBp, -30);
        expect(row.source, 'fixture');
        expect(row.referenceRateDate!.toUtc(), DateTime.utc(2025, 12, 19));
        expect(row.effectiveDate.toUtc(), DateTime.utc(2026, i + 1, 1));
        expect(seconds(row.resetDate!), seconds(row.effectiveDate) - 86400);
        expect(seconds(row.createdAt), borrowed + i);
        expect(row.ratePpm, isNull);
        expect(row.ratePeriod, isNull);
      }
      final snapshot = await DriftBackupGateway(db).readSnapshot();
      final legacy = <String, Iterable<BackupJson>>{
        ...snapshot.tables,
        'installment_repricing_records': [
          for (final row in snapshot.rows('installment_repricing_records'))
            {...row}
              ..remove('pricingMethod')
              ..remove('ratePpm')
              ..remove('ratePeriod'),
        ],
      };
      migrateInstallmentBackup(legacy, schemaVersion: 45, formatVersion: 3);
      final restored = snapshot.copyWith(tables: legacy);
      BackupService.validateSnapshot(restored);
      expect(
        restored.rows('installment_repricing_records'),
        snapshot.rows('installment_repricing_records'),
      );
      await DriftBackupGateway(db).replaceSnapshot(restored);

      Future<void> insertDirect(
        String id,
        DateTime effective,
      ) => db.customStatement(
        "INSERT INTO installment_repricing_records (id, contract_id, stage_id, pricing_method, effective_date, rate_ppm, rate_period) VALUES (?, 'loan', 'stage', 'direct', ?, 2000, 'monthly')",
        [id, seconds(effective)],
      );
      await insertDirect('direct', DateTime.utc(2026, 2, 15));
      final direct = (await db.select(db.installmentRepricingRecords).get())
          .singleWhere((row) => row.id == 'direct');
      expect(direct.resetDate, isNull);
      expect(direct.referenceRatePpm, isNull);
      expect(direct.ratePpm, 2000);
      expect(direct.ratePeriod, 'monthly');
      await expectLater(
        insertDirect('duplicate', DateTime.utc(2026, 1, 1)),
        throwsA(isA<Exception>()),
      );
      for (final assignment in [
        'rate_ppm = NULL',
        'rate_ppm = -1',
        "rate_period = 'weekly'",
        'reset_date = 0',
        'reference_rate_ppm = 30000',
        "pricing_method = 'reference'",
      ]) {
        await expectLater(
          db.customStatement(
            "UPDATE installment_repricing_records SET $assignment WHERE id = 'direct'",
          ),
          throwsA(isA<Exception>()),
        );
      }
      await expectLater(
        db.customStatement(
          "UPDATE installment_repricing_records SET reference_rate_ppm = NULL WHERE id = 'rate-0'",
        ),
        throwsA(isA<Exception>()),
      );
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'installment_repricing_records'",
          )
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        contains('installment_repricing_records_pending_idx'),
      );
      expect(
        await db
            .customSelect(
              'PRAGMA foreign_key_list(installment_repricing_records)',
            )
            .get(),
        isEmpty,
      );
    },
  );
}
