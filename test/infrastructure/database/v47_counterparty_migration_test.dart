import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

void main() {
  test(
    'v46 counterparty names migrate to a stable vocabulary and ids',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-v47-counterparty-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/smartflow.sqlite');
      final current = _open(file);
      await current.customSelect('SELECT 1').get();
      await current.customStatement(
        'ALTER TABLE transactions ADD COLUMN owner_role TEXT NULL',
      );
      await current.customStatement('''
INSERT INTO transactions (
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  source_kind
) VALUES
  ('tx-1', 'transfer', 1, 1, 100, 'manual'),
  ('tx-2', 'transfer', 2, 2, 100, 'manual'),
  ('tx-3', 'transfer', 3, 3, 100, 'manual')
''');

      for (final index in [
        'transactions_top_level_occurred_idx',
        'transactions_parent_purpose_idx',
        'transactions_occurred_stats_idx',
        'transactions_posted_billing_idx',
        'transactions_owner_idx',
        'transactions_counterparty_idx',
        'counterparties_name_unique',
      ]) {
        await current.customStatement('DROP INDEX IF EXISTS $index');
      }
      await current.customStatement('DROP TABLE counterparties');
      await current.customStatement(
        'ALTER TABLE transactions RENAME TO transactions_with_counterparty_id',
      );
      await current.customStatement(_v46TransactionsSql);
      await current.customStatement('''
INSERT INTO transactions (
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  counterparty_name, note, parent_transaction_id, is_excluded_from_stats,
  is_excluded_from_budget, source_kind, owner_type, owner_id, owner_role,
  created_at, updated_at
)
SELECT
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  CASE id
    WHEN 'tx-1' THEN ' 自如 '
    WHEN 'tx-2' THEN '自如'
    ELSE '   '
  END,
  note, parent_transaction_id, is_excluded_from_stats,
  is_excluded_from_budget, source_kind, owner_type, owner_id, owner_role,
  created_at, updated_at
FROM transactions_with_counterparty_id
''');
      await current.customStatement(
        'DROP TABLE transactions_with_counterparty_id',
      );
      await current.customStatement('PRAGMA user_version = 46');
      await current.close();

      final upgraded = _open(file);
      addTearDown(upgraded.close);
      final rows = await upgraded.customSelect('''
SELECT transaction_row.id, transaction_row.counterparty_id,
       counterparty.name
FROM transactions AS transaction_row
LEFT JOIN counterparties AS counterparty
  ON counterparty.id = transaction_row.counterparty_id
ORDER BY transaction_row.id
''').get();
      expect(rows, hasLength(3));
      expect(rows[0].readNullable<String>('counterparty_id'), isNotNull);
      expect(rows[0].readNullable<String>('name'), '自如');
      expect(
        rows[1].readNullable<String>('counterparty_id'),
        rows[0].readNullable<String>('counterparty_id'),
      );
      expect(rows[2].readNullable<String>('counterparty_id'), isNull);

      final counterparties = await upgraded
          .select(upgraded.counterparties)
          .get();
      expect(counterparties, hasLength(1));
      expect(counterparties.single.name, '自如');

      final columns = await upgraded
          .customSelect('PRAGMA table_info(transactions)')
          .get();
      final names = columns.map((row) => row.read<String>('name')).toSet();
      expect(names, contains('counterparty_id'));
      expect(names, isNot(contains('counterparty_name')));
      expect(
        await upgraded
            .customSelect('PRAGMA foreign_key_list(transactions)')
            .get(),
        isEmpty,
      );
    },
  );
}

AppDatabase _open(File file) {
  return AppDatabase(
    DatabaseConnection(NativeDatabase(file), closeStreamsSynchronously: true),
  );
}

const _v46TransactionsSql = '''
CREATE TABLE transactions (
  id TEXT NOT NULL PRIMARY KEY,
  business_purpose TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  posted_at INTEGER NOT NULL,
  primary_amount_minor INTEGER NOT NULL,
  counterparty_name TEXT NULL,
  note TEXT NULL,
  parent_transaction_id TEXT NULL,
  is_excluded_from_stats INTEGER NOT NULL DEFAULT 0,
  is_excluded_from_budget INTEGER NOT NULL DEFAULT 0,
  source_kind TEXT NOT NULL,
  owner_type TEXT NULL,
  owner_id TEXT NULL,
  owner_role TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''';
