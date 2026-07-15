import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test(
    'opening a stale v18 database rebuilds the installment constraint',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-migration-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}smartflow.sqlite',
      );

      final staleDatabase = _openDatabase(file);
      await staleDatabase.customStatement('DROP TABLE installment_contracts');
      await staleDatabase.customStatement(_staleInstallmentContractsSql);
      await staleDatabase.customStatement('PRAGMA user_version = 18');
      await expectLater(
        () => _insertNoTransactionContract(staleDatabase),
        throwsA(isA<Exception>()),
      );
      await staleDatabase.close();

      final upgradedDatabase = _openDatabase(file);
      addTearDown(upgradedDatabase.close);
      final version =
          await upgradedDatabase
              .customSelect('PRAGMA user_version')
              .getSingle();
      expect(version.read<int>('user_version'), 19);
      await _insertNoTransactionContract(upgradedDatabase);
    },
  );
}

AppDatabase _openDatabase(File file) {
  return AppDatabase(
    DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
  );
}

Future<void> _insertNoTransactionContract(AppDatabase database) {
  return database.customStatement(
    "INSERT INTO installment_contracts "
    "(id, liability_account_id, source_type, disbursement_account_id, "
    "disbursement_transaction_id, principal_minor, total_periods, "
    "start_date, first_repayment_date, last_repayment_date, "
    "repayment_method, interest_accrual_method, status) "
    "VALUES ('migration-contract', 'loan-1', 'disbursement', NULL, NULL, "
    "120000, 12, 0, 0, 0, 'equalInstallment', 'daily', 'active')",
  );
}

const _staleInstallmentContractsSql = '''
CREATE TABLE installment_contracts (
  id TEXT NOT NULL PRIMARY KEY,
  liability_account_id TEXT NOT NULL,
  source_type TEXT NOT NULL,
  disbursement_account_id TEXT NULL,
  disbursement_transaction_id TEXT NULL,
  source_repayment_id TEXT NULL,
  principal_minor INTEGER NOT NULL,
  total_periods INTEGER NOT NULL,
  start_date INTEGER NOT NULL,
  first_repayment_date INTEGER NOT NULL,
  last_repayment_date INTEGER NOT NULL,
  repayment_method TEXT NOT NULL,
  interest_rate_period TEXT NULL,
  interest_rate_ppm INTEGER NULL,
  interest_accrual_method TEXT NOT NULL DEFAULT 'daily',
  total_fee_minor INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  note TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  CHECK (
    (source_type = 'disbursement'
      AND disbursement_account_id IS NOT NULL
      AND disbursement_transaction_id IS NOT NULL)
    OR (source_type = 'billConversion'
      AND disbursement_account_id IS NULL
      AND disbursement_transaction_id IS NULL)
  )
)
''';
