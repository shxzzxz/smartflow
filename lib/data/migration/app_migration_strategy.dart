// ignore_for_file: experimental_member_use

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../builtin_data.dart';

MigrationStrategy buildMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await database.customStatement(
        'CREATE UNIQUE INDEX budgets_total_unique '
        'ON budgets (month_key) '
        'WHERE account_id IS NULL',
      );
      await database.customStatement(
        'CREATE UNIQUE INDEX budgets_account_unique '
        'ON budgets (month_key, account_id) '
        'WHERE account_id IS NOT NULL',
      );
      await _createTransactionRowIndexes(database);
      await database.customStatement(
        'CREATE INDEX entries_transaction_idx ON entries (transaction_id)',
      );
      await database.customStatement(
        'CREATE INDEX entries_account_transaction_idx '
        'ON entries (account_id, transaction_id)',
      );
      await database.customStatement(
        'CREATE INDEX installment_contracts_liability_status_idx '
        'ON installment_contracts (liability_account_id, status)',
      );
      await database.customStatement(
        'CREATE INDEX installment_schedules_contract_period_idx '
        'ON installment_schedules (contract_id, period_no)',
      );
      await database.customStatement(
        'CREATE UNIQUE INDEX installment_repayments_contract_schedule_unique '
        'ON installment_repayments (contract_id, schedule_id) '
        'WHERE schedule_id IS NOT NULL',
      );
      await database.customStatement(
        'CREATE INDEX installment_repayments_transaction_idx '
        'ON installment_repayments (transaction_id)',
      );
      await database.customStatement(
        'CREATE INDEX installment_contracts_disbursement_tx_idx '
        'ON installment_contracts (disbursement_transaction_id) '
        'WHERE disbursement_transaction_id IS NOT NULL',
      );
      await ensureBuiltinData(database);
    },
    beforeOpen: (_) async {
      await ensureBuiltinData(database);
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 10) {
        await migrator.addColumn(database.accounts, database.accounts.version);
      }
    },
  );
}

Future<void> _createTransactionRowIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX transactions_current_main_occurred_idx '
    'ON transactions (business_state, parent_transaction_id, '
    'occurred_at, id)',
  );
  await database.customStatement(
    'CREATE INDEX transactions_root_current_child_purpose_idx '
    'ON transactions (root_transaction_id, business_state, '
    'parent_transaction_id, business_purpose)',
  );
  await database.customStatement(
    'CREATE INDEX transactions_current_occurred_stats_idx '
    'ON transactions (business_state, occurred_at, '
    'is_excluded_from_stats)',
  );
  await database.customStatement(
    'CREATE INDEX transactions_owner_idx '
    'ON transactions (owner_type, owner_id, owner_role)',
  );
}
