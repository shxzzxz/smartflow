import 'package:drift/drift.dart';

import '../app_database.dart';
import '../builtin_data.dart';

MigrationStrategy buildMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await database.customStatement(
        'CREATE UNIQUE INDEX budgets_total_unique '
        'ON budgets (month_key, currency_code) '
        'WHERE account_id IS NULL',
      );
      await database.customStatement(
        'CREATE UNIQUE INDEX budgets_account_unique '
        'ON budgets (month_key, account_id, currency_code) '
        'WHERE account_id IS NOT NULL',
      );
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
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(database.appMetadata);
        await migrator.addColumn(database.accounts, database.accounts.source);
        await ensureBuiltinData(database);
      }
      if (from < 3) {
        await migrator.createTable(database.installmentContracts);
        await migrator.createTable(database.installmentSchedules);
        await migrator.createTable(database.installmentRepayments);
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
      }
      if (from < 4) {
        // 拓展合同表：首期/末期还款日、总手续费。
        // 旧数据按"旧 generator 行为"回填：首期 = 起算日+1月，末期 = 起算日+N月。
        await database.customStatement(
          'ALTER TABLE installment_contracts ADD COLUMN '
          'first_repayment_date INTEGER NOT NULL DEFAULT 0',
        );
        await database.customStatement(
          'ALTER TABLE installment_contracts ADD COLUMN '
          'last_repayment_date INTEGER NOT NULL DEFAULT 0',
        );
        await database.customStatement(
          'ALTER TABLE installment_contracts ADD COLUMN '
          'total_fee_minor INTEGER NOT NULL DEFAULT 0',
        );
        await database.customStatement(
          "UPDATE installment_contracts SET "
          "first_repayment_date = CAST(strftime('%s', "
          "datetime(start_date, 'unixepoch', '+1 month')) AS INTEGER), "
          "last_repayment_date = CAST(strftime('%s', "
          "datetime(start_date, 'unixepoch', "
          "'+' || total_periods || ' month')) AS INTEGER) "
          "WHERE first_repayment_date = 0",
        );
      }
      if (from < 5) {
        // 新增"计息方式"列。存量合同默认 'daily'，保留 balance × monthlyRate × days/30
        // 的等价行为（仅 equalInstallment 在下次按配置重算时切换为现金流折现公式）。
        await database.customStatement(
          "ALTER TABLE installment_contracts ADD COLUMN "
          "interest_accrual_method TEXT NOT NULL DEFAULT 'daily'",
        );
      }
      if (from < 6) {
        // 放款交易反查索引：交易详情页要识别"该 transaction 是某分期合同的放款"。
        await database.customStatement(
          'CREATE INDEX installment_contracts_disbursement_tx_idx '
          'ON installment_contracts (disbursement_transaction_id) '
          'WHERE disbursement_transaction_id IS NOT NULL',
        );
      }
      if (from < 7) {
        await migrator.addColumn(
          database.transactions,
          database.transactions.ownerType,
        );
        await migrator.addColumn(
          database.transactions,
          database.transactions.ownerId,
        );
        await migrator.addColumn(
          database.transactions,
          database.transactions.ownerRole,
        );
        await database.customStatement(
          'CREATE INDEX transactions_owner_idx '
          'ON transactions (owner_type, owner_id, owner_role)',
        );
        await database.customStatement(
          "UPDATE transactions "
          "SET owner_type = 'installment', "
          "owner_id = ("
          "SELECT c.id FROM installment_contracts c "
          "WHERE c.disbursement_transaction_id = transactions.id"
          "), "
          "owner_role = 'disbursement' "
          "WHERE EXISTS ("
          "SELECT 1 FROM installment_contracts c "
          "WHERE c.disbursement_transaction_id = transactions.id"
          ")",
        );
        await database.customStatement(
          "UPDATE transactions "
          "SET owner_type = 'installment', "
          "owner_id = ("
          "SELECT r.contract_id FROM installment_repayments r "
          "WHERE r.transaction_id = transactions.id"
          "), "
          "owner_role = ("
          "SELECT CASE r.repayment_type "
          "WHEN 'scheduled' THEN 'scheduled_repayment' "
          "WHEN 'extraPrincipal' THEN 'extra_principal' "
          "WHEN 'earlySettlement' THEN 'early_settlement' "
          "END FROM installment_repayments r "
          "WHERE r.transaction_id = transactions.id"
          ") "
          "WHERE EXISTS ("
          "SELECT 1 FROM installment_repayments r "
          "WHERE r.transaction_id = transactions.id"
          ")",
        );
      }
    },
    beforeOpen: (_) async {
      await ensureBuiltinData(database);
    },
  );
}
