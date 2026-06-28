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
      await _createBillIndexes(database);
      await ensureBuiltinData(database);
    },
    beforeOpen: (_) async {
      await ensureBuiltinData(database);
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 10) {
        await migrator.addColumn(database.accounts, database.accounts.version);
      }
      if (from < 11) {
        await migrator.addColumn(
          database.accounts,
          database.accounts.accountProfileKey,
        );
        await _migrateAccountProfileKeys(database);
      }
      if (from < 12) {
        await migrator.createTable(database.creditLiabilityAccounts);
        await _migrateCreditLiabilityAccounts(database);
      }
      if (from < 13) {
        await migrator.createTable(database.bills);
        await migrator.createTable(database.billItems);
        await _createBillIndexes(database);
      }
    },
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
  await database.customStatement(
    'CREATE UNIQUE INDEX bill_items_schedule_unique '
    'ON bill_items (schedule_id) WHERE schedule_id IS NOT NULL',
  );
}

Future<void> _migrateCreditLiabilityAccounts(AppDatabase database) async {
  await database.customStatement('''
    INSERT OR IGNORE INTO credit_liability_accounts (
      id,
      account_id,
      kind,
      credit_limit_minor,
      billing_day,
      repayment_day,
      billing_start_period,
      billing_day_to_next,
      created_at,
      updated_at
    )
    SELECT
      'credit-liability-account:' || id,
      id,
      CASE WHEN account_profile_key = 'credit.loan' THEN 'loan' ELSE 'credit' END,
      credit_limit_minor,
      CASE
        WHEN account_profile_key = 'credit.loan' THEN NULL
        WHEN billing_day BETWEEN 1 AND 28 THEN billing_day
        ELSE 1
      END,
      CASE
        WHEN account_profile_key = 'credit.loan' THEN NULL
        WHEN repayment_day BETWEEN 1 AND 28 THEN repayment_day
        ELSE 28
      END,
      CASE
        WHEN account_profile_key = 'credit.loan' THEN NULL
        ELSE CAST(strftime('%Y', created_at, 'unixepoch') AS INTEGER) * 100
          + CAST(strftime('%m', created_at, 'unixepoch') AS INTEGER)
      END,
      1,
      created_at,
      updated_at
    FROM accounts
    WHERE account_type = 'liability'
    ''');
}

Future<void> _migrateAccountProfileKeys(AppDatabase database) async {
  await database.customStatement(
    "UPDATE accounts SET account_profile_key = 'ledger.reimbursement' "
    "WHERE account_type = 'asset' AND account_subtype = 'reimbursement'",
  );
  await database.customStatement(
    "UPDATE accounts SET account_profile_key = 'ledger.fund' "
    "WHERE account_type = 'asset' AND "
    "(account_subtype IS NULL OR account_subtype <> 'reimbursement')",
  );
  await database.customStatement(
    "UPDATE accounts SET account_profile_key = 'credit.loan' "
    "WHERE account_type = 'liability' AND account_subtype = 'loan'",
  );
  await database.customStatement(
    "UPDATE accounts SET account_profile_key = 'credit.credit' "
    "WHERE account_type = 'liability' AND "
    "(account_subtype IS NULL OR account_subtype <> 'loan')",
  );
  await database.customStatement(
    "UPDATE accounts SET account_subtype = NULL "
    "WHERE account_subtype IS NOT NULL AND account_subtype <> 'reimbursement'",
  );
  await database.customStatement(
    "UPDATE accounts SET account_subtype = NULL, account_profile_key = NULL "
    "WHERE account_type IN ('equity', 'income', 'expense')",
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
