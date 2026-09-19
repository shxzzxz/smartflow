import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test(
    'v44 database removes legacy zero-amount entries before backup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-v45-zero-entry-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/smartflow.sqlite');
      final old = AppDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO accounts "
        "(id, name, account_type, balance_minor) VALUES "
        "('loan', '贷款', 'liability', 0), "
        "('interest', '利息', 'expense', 100), "
        "('cash', '现金', 'asset', -100)",
      );
      await old.customStatement(
        "INSERT INTO transactions "
        "(id, business_purpose, occurred_at, posted_at, "
        "primary_amount_minor, source_kind) VALUES "
        "('repayment', 'debtRepayment', ?, ?, 100, 'manual')",
        [
          _seconds(DateTime.utc(2026, 7, 20)),
          _seconds(DateTime.utc(2026, 7, 20)),
        ],
      );
      await old.customStatement(
        "INSERT INTO entries "
        "(id, transaction_id, account_id, direction, amount_minor) VALUES "
        "('zero-principal', 'repayment', 'loan', 'debit', 0), "
        "('interest', 'repayment', 'interest', 'debit', 100), "
        "('cash', 'repayment', 'cash', 'credit', 100)",
      );
      await old.customStatement('PRAGMA user_version = 44');
      await old.close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);

      final entries = await migrated.select(migrated.entries).get();
      expect(
        entries.map((entry) => entry.id),
        unorderedEquals(['interest', 'cash']),
      );
      expect(entries.every((entry) => entry.amountMinor > 0), isTrue);

      final snapshot = await DriftBackupGateway(migrated).readSnapshot();
      expect(() => BackupService.validateSnapshot(snapshot), returnsNormally);
    },
  );
}

int _seconds(DateTime date) => date.millisecondsSinceEpoch ~/ 1000;
