import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

void main() {
  test(
    'v48 ownership migrates to orchestration cases without balance writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-v49-orchestration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/smartflow.sqlite');
      final old = _open(file);
      await old.customSelect('SELECT 1').get();
      await old.customStatement('DROP TABLE advance_cases');
      await old.customStatement(
        'ALTER TABLE transactions ADD COLUMN owner_role TEXT NULL',
      );
      await old.customStatement('''
INSERT INTO transactions (
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  source_kind, owner_type, owner_id, owner_role
)
VALUES
  ('aa-parent', 'advance', 1, 1, 30000, 'manual',
   'advance.itemized', 'aa-parent', 'aa'),
  ('aa-refund', 'refund', 2, 2, 2000, 'manual',
   'advance.itemized', 'aa-parent', 'aa'),
  ('account-advance', 'advance', 3, 3, 1000, 'manual',
   'advance.account', 'receivable', 'reimbursement'),
  ('account-aa-1', 'advance', 3, 3, 3000, 'manual',
   'advance.account', 'receivable', 'aa'),
  ('account-aa-2', 'advance', 4, 4, 3000, 'manual',
   'advance.account', 'receivable', 'aa'),
  ('account-receipt', 'advanceCollection', 4, 4, 500, 'manual',
   'advance.account', 'receivable', 'aa'),
  ('repayment', 'debtRepayment', 4, 4, 500, 'manual',
   'credit_repayment', 'repayment-1', 'BILL'),
  ('plain-expense', 'dailyExpense', 5, 5, 100, 'manual', NULL, NULL, NULL)
''');
      await old.customStatement('''
INSERT INTO transaction_lines (
  id, transaction_id, line_no, role, account_id, amount_minor
)
VALUES
  ('aa-receivable', 'aa-parent', 1, 'receivable', 'receivable', 20000),
  ('account-aa-1-receivable', 'account-aa-1', 1, 'receivable', 'receivable', 1500),
  ('account-aa-2-receivable', 'account-aa-2', 1, 'receivable', 'receivable', 1500)
''');
      await old.customStatement('PRAGMA user_version = 48');
      await old.close();

      final upgraded = _open(file);
      addTearDown(upgraded.close);
      final transactions = await upgraded.customSelect('''
SELECT id, owner_type, owner_id
FROM transactions
ORDER BY id
''').get();
      final byId = {
        for (final row in transactions)
          row.read<String>('id'): (
            row.readNullable<String>('owner_type'),
            row.readNullable<String>('owner_id'),
          ),
      };
      expect(byId['aa-parent'], (
        'orchestration.advance',
        'orchestration:advance:itemized:aa-parent',
      ));
      expect(byId['aa-refund'], byId['aa-parent']);
      expect(byId['account-advance'], (
        'orchestration.advance',
        'orchestration:advance:account:account-advance',
      ));
      expect(byId['account-aa-1'], (
        'orchestration.advance',
        'orchestration:advance:account:account-aa-1',
      ));
      expect(byId['account-aa-2'], (
        'orchestration.advance',
        'orchestration:advance:account:account-aa-2',
      ));
      expect(byId['account-receipt'], (null, null));
      expect(byId['repayment'], ('credit.repayment', 'repayment-1'));
      expect(byId['plain-expense'], (null, null));

      final cases = await upgraded.select(upgraded.advanceCases).get();
      final caseById = {for (final row in cases) row.id: row};
      final aaCase = caseById['orchestration:advance:itemized:aa-parent']!;
      expect(aaCase.scenario.name, 'aa');
      expect(aaCase.trackingMode.name, 'itemized');
      expect(aaCase.aaPeopleCount, 3);
      final accountCase =
          caseById['orchestration:advance:account:account-advance']!;
      expect(accountCase.trackingMode.name, 'account');
      expect(accountCase.receivableAccountId, 'receivable');
      final accountAaCase =
          caseById['orchestration:advance:account:account-aa-1']!;
      expect(accountAaCase.aaPeopleCount, 2);

      final columns = await upgraded
          .customSelect('PRAGMA table_info(transactions)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        isNot(contains('owner_role')),
      );
      final indexColumns = await upgraded
          .customSelect('PRAGMA index_info(transactions_owner_idx)')
          .get();
      expect(indexColumns.map((row) => row.read<String>('name')), [
        'owner_type',
        'owner_id',
      ]);

      await expectLater(
        upgraded
            .into(upgraded.advanceCases)
            .insert(
              AdvanceCasesCompanion.insert(
                id: 'invalid-account-aa',
                scenario: AdvanceScenario.aa,
                trackingMode: AdvanceTrackingMode.account,
                receivableAccountId: const Value('receivable'),
              ),
            ),
        throwsA(anything),
      );
    },
  );
}

AppDatabase _open(File file) {
  return AppDatabase(
    DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
  );
}
