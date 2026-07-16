// ignore_for_file: experimental_member_use

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../builtin_data.dart';

MigrationStrategy buildMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await _createCurrentSchema(database, migrator);
    },
    beforeOpen: (_) async {
      await ensureBuiltinData(database);
    },
    onUpgrade: (migrator, from, _) async {
      if (from < 19) {
        // Versions before v19 still follow the development-channel rebuild
        // policy. The v19 -> v20 step below is the first compatible upgrade.
        for (final table in database.allTables.toList().reversed) {
          await migrator.drop(table);
        }
        await _createCurrentSchema(database, migrator);
        return;
      }
      if (from < 20) {
        await migrator.alterTable(
          TableMigration(
            database.transactions,
            newColumns: [database.transactions.postedAt],
            columnTransformer: {
              database.transactions.postedAt: database.transactions.occurredAt,
            },
          ),
        );
        await _createTransactionRowIndexes(database);
      }
    },
  );
}

Future<void> _createCurrentSchema(
  AppDatabase database,
  Migrator migrator,
) async {
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
    'CREATE INDEX installment_contracts_disbursement_tx_idx '
    'ON installment_contracts (disbursement_transaction_id) '
    'WHERE disbursement_transaction_id IS NOT NULL',
  );
  await _createInstallmentSourceRepaymentIndex(database);
  await _createBillIndexes(database);
  await _createRepaymentIndexes(database);
  await ensureBuiltinData(database);
}

Future<void> _createInstallmentSourceRepaymentIndex(
  AppDatabase database,
) async {
  await database.customStatement(
    'CREATE INDEX installment_contracts_source_repayment_idx '
    'ON installment_contracts (source_repayment_id) '
    'WHERE source_repayment_id IS NOT NULL',
  );
}

Future<void> _createBillIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX bills_account_period_idx ON bills (account_id, period)',
  );
  await database.customStatement(
    'CREATE INDEX bill_items_bill_idx ON bill_items (bill_id)',
  );
  await database.customStatement(
    'CREATE INDEX bill_items_contract_idx ON bill_items (contract_id) '
    'WHERE contract_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX bill_items_consumption_unique '
    'ON bill_items (bill_id) WHERE item_type = \'consumption\'',
  );
}

Future<void> _createRepaymentIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX repayments_target_idx '
    'ON repayments (target_type, target_id, created_at)',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX repayments_root_transaction_unique '
    'ON repayments (root_transaction_id) '
    'WHERE root_transaction_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE INDEX repayment_items_repayment_idx '
    'ON repayment_items (repayment_id)',
  );
  await database.customStatement(
    'CREATE INDEX repayment_items_bill_item_idx '
    'ON repayment_items (bill_item_id) '
    'WHERE bill_item_id IS NOT NULL',
  );
}

Future<void> _createTransactionRowIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_current_main_occurred_idx '
    'ON transactions (business_state, parent_transaction_id, '
    'occurred_at, id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_root_current_child_purpose_idx '
    'ON transactions (root_transaction_id, business_state, '
    'parent_transaction_id, business_purpose)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_current_occurred_stats_idx '
    'ON transactions (business_state, occurred_at, '
    'is_excluded_from_stats)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_current_posted_billing_idx '
    'ON transactions (business_state, business_purpose, posted_at)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_owner_idx '
    'ON transactions (owner_type, owner_id, owner_role)',
  );
}
