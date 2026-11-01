import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../app_database.dart';
import '../builtin_data.dart';
import 'current_schema.dart';
import 'schema_versions.dart';

final _logger = Logger('infra.database');

/// Database schema compatibility starts at v49; the current version is
/// defined by `AppDatabase.schemaVersion`.
///
/// Pre-release databases are intentionally unsupported. Schema changes must
/// add immutable one-step migrations backed by Drift schema snapshots.
MigrationStrategy buildMigrationStrategy(AppDatabase database) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      _logger.info('Creating database schema at v${database.schemaVersion}.');
      await createCurrentSchema(database, migrator);
    },
    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        _logger.info(
          'Database opened after upgrade: '
          'v${details.versionBefore} -> v${details.versionNow}.',
        );
      } else {
        _logger.fine('Database opened at v${details.versionNow}.');
      }
      await ensureBuiltinData(database);
    },
    onUpgrade: (migrator, from, to) =>
        _upgrade(migrator, from, to, currentVersion: database.schemaVersion),
  );
}

Future<void> _upgrade(
  Migrator migrator,
  int from,
  int to, {
  required int currentVersion,
}) async {
  if (from < 49 || to > currentVersion) {
    _logger.severe(
      'Rejected unsupported database schema upgrade: v$from -> v$to.',
    );
    throw UnsupportedError(
      'Database schema v$from is no longer supported. '
      'This build supports v49 through v$currentVersion.',
    );
  }

  await migrator.database.transaction(() async {
    await stepByStep(
      from49To50: (migration, schema) async {
        await migration.alterTable(TableMigration(schema.accounts));
      },
      from50To51: (migration, schema) async {
        await migration.alterTable(
          TableMigration(
            schema.installmentContracts,
            newColumns: [schema.installmentContracts.purchaseTransactionId],
            columnTransformer: {
              schema.installmentContracts.purchaseTransactionId: const Constant(
                null,
              ),
            },
          ),
        );
        await migration.createTable(schema.installmentRefundReductions);
        await migration.database.customStatement(
          'CREATE INDEX installment_refund_reductions_contract_idx '
          'ON installment_refund_reductions (contract_id)',
        );
      },
      from51To52: (migration, schema) async {
        for (final indexName in const [
          'installment_contracts_liability_status_idx',
          'installment_contracts_disbursement_tx_idx',
          'installment_contracts_source_repayment_idx',
          'repayments_target_idx',
          'repayments_transaction_unique',
        ]) {
          await migration.database.customStatement(
            'DROP INDEX IF EXISTS $indexName',
          );
        }
        await migration.alterTable(
          TableMigration(
            schema.installmentContracts,
            columnTransformer: {
              schema.installmentContracts.installmentType:
                  const CustomExpression<String>(
                    "CASE source_type "
                    "WHEN 'billConversion' THEN 'billConversion' "
                    "WHEN 'purchase' THEN 'purchase' "
                    "ELSE 'disbursement' END",
                  ),
              schema.installmentContracts.sourceRefId:
                  const CustomExpression<String>(
                    "CASE source_type "
                    "WHEN 'billConversion' THEN source_repayment_id "
                    "WHEN 'purchase' THEN purchase_transaction_id "
                    "ELSE disbursement_transaction_id END",
                  ),
            },
          ),
        );
        await migration.database.customStatement(
          'CREATE INDEX installment_contracts_liability_status_idx '
          'ON installment_contracts (liability_account_id, status)',
        );
        await migration.alterTable(
          TableMigration(
            schema.repayments,
            columnTransformer: {
              schema.repayments.generatedContractId: const Constant(null),
            },
          ),
        );
        await migration.database.customStatement(
          'UPDATE repayments '
          'SET generated_contract_id = ('
          'SELECT installment_contracts.id '
          'FROM installment_contracts '
          "WHERE installment_contracts.installment_type = 'billConversion' "
          'AND installment_contracts.source_ref_id = repayments.id'
          ') '
          'WHERE EXISTS ('
          'SELECT 1 FROM installment_contracts '
          "WHERE installment_contracts.installment_type = 'billConversion' "
          'AND installment_contracts.source_ref_id = repayments.id'
          ')',
        );
        await migration.database.customStatement(
          'CREATE INDEX repayments_target_idx '
          'ON repayments (target_type, target_id, created_at)',
        );
        await migration.database.customStatement(
          'CREATE UNIQUE INDEX repayments_transaction_unique '
          'ON repayments (transaction_id) '
          'WHERE transaction_id IS NOT NULL',
        );
        await migration.database.customStatement(
          'CREATE UNIQUE INDEX repayments_generated_contract_unique '
          'ON repayments (generated_contract_id) '
          'WHERE generated_contract_id IS NOT NULL',
        );
      },
      from52To53: (migration, schema) async {
        await migration.createTable(schema.amortizationPlans);
        await migration.createTable(schema.amortizationEntries);
        await migration.database.customStatement(
          'CREATE INDEX amortization_entries_pending_idx '
          'ON amortization_entries (due_at) '
          'WHERE transaction_id IS NULL AND canceled_at IS NULL',
        );
      },
      from53To54: (migration, schema) async {
        await migration.createTable(schema.amortizationEntryAllocations);
        await migration.database.customStatement(
          'INSERT INTO amortization_entry_allocations '
          '(id, entry_id, line_no, account_id, amount_minor) '
          'SELECT entry.id || \':allocation:1\', entry.id, 1, '
          'plan.category_account_id, entry.amount_minor '
          'FROM amortization_entries entry '
          'JOIN amortization_plans plan ON plan.id = entry.plan_id',
        );
        await migration.alterTable(TableMigration(schema.amortizationPlans));
      },
      from54To55: (migration, schema) async {
        await migration.createTable(schema.amortizationPeriods);
        await migration.createTable(schema.amortizationRefunds);
        await migration.createTable(schema.amortizationTerminations);
        await migration.createTable(schema.amortizationAllocations);

        await migration.database.customStatement(
          'INSERT INTO amortization_periods '
          '(id, plan_id, sequence_no, due_at, amount_minor, transaction_id, '
          'status, created_at, updated_at) '
          'SELECT id, plan_id, sequence_no, due_at, amount_minor, '
          'transaction_id, '
          "CASE WHEN canceled_at IS NOT NULL THEN 'canceled' "
          "WHEN transaction_id IS NOT NULL THEN 'posted' "
          "WHEN amount_minor = 0 THEN 'zero' ELSE 'pending' END, "
          'created_at, updated_at '
          'FROM amortization_entries',
        );
        await migration.database.customStatement(
          'INSERT INTO amortization_allocations '
          '(id, subject_type, subject_id, dimension, line_no, account_id, '
          'amount_minor) '
          'SELECT \'plan:\' || p.id || \':category:\' || a.account_id, '
          "'plan', p.id, 'category', "
          'ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY a.account_id), '
          'a.account_id, SUM(a.amount_minor) '
          'FROM amortization_entry_allocations a '
          'JOIN amortization_entries e ON e.id = a.entry_id '
          'JOIN amortization_plans p ON p.id = e.plan_id '
          'GROUP BY p.id, a.account_id',
        );
        await migration.database.customStatement(
          'WITH funding AS ('
          'SELECT p.id AS plan_id, tl.account_id, tl.amount_minor, '
          'ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY tl.line_no) AS line_no '
          'FROM amortization_plans p '
          'JOIN transaction_lines tl '
          'ON tl.transaction_id = p.initial_transaction_id '
          'WHERE tl.role = CASE WHEN p.kind = \'prepaidExpense\' '
          "THEN 'settlementOut' ELSE 'settlementIn' END"
          ') '
          'INSERT INTO amortization_allocations '
          '(id, subject_type, subject_id, dimension, line_no, account_id, '
          'amount_minor) '
          'SELECT \'plan:\' || plan_id || \':funding:\' || line_no, '
          "'plan', plan_id, 'funding', line_no, account_id, amount_minor "
          'FROM funding',
        );
        await migration.database.customStatement(
          'INSERT INTO amortization_allocations '
          '(id, subject_type, subject_id, dimension, line_no, account_id, '
          'amount_minor) '
          'SELECT \'period:\' || entry_id || \':category:\' || line_no, '
          "'period', entry_id, 'category', line_no, account_id, amount_minor "
          'FROM amortization_entry_allocations',
        );

        await migration.database.customStatement(
          'INSERT INTO amortization_terminations '
          '(id, plan_id, terminated_at, recognition_transaction_id, '
          'return_transaction_id) '
          'SELECT id || \':termination\', id, terminated_at, '
          'termination_recognition_transaction_id, refund_transaction_id '
          'FROM amortization_plans WHERE terminated_at IS NOT NULL',
        );
        await migration.database.customStatement(
          'INSERT INTO amortization_allocations '
          '(id, subject_type, subject_id, dimension, line_no, account_id, '
          'amount_minor) '
          'SELECT \'termination:\' || p.id || \':termination:category:1\', '
          "'termination', p.id || ':termination', 'category', 1, "
          'MIN(ca.account_id), p.refund_amount_minor '
          'FROM amortization_plans p '
          'JOIN amortization_allocations ca '
          'ON ca.subject_type = \'plan\' AND ca.subject_id = p.id '
          'AND ca.dimension = \'category\' '
          'WHERE p.refund_amount_minor > 0 '
          'GROUP BY p.id, p.refund_amount_minor',
        );
        await migration.database.customStatement(
          'WITH settlements AS ('
          'SELECT p.id AS plan_id, tl.account_id, tl.amount_minor, '
          'ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY tl.line_no) AS line_no '
          'FROM amortization_plans p '
          'JOIN transaction_lines tl '
          'ON tl.transaction_id = p.refund_transaction_id '
          'WHERE tl.role = CASE WHEN p.kind = \'prepaidExpense\' '
          "THEN 'settlementIn' ELSE 'settlementOut' END"
          ') '
          'INSERT INTO amortization_allocations '
          '(id, subject_type, subject_id, dimension, line_no, account_id, '
          'amount_minor) '
          'SELECT \'termination:\' || plan_id || '
          '\':termination:settlement:\' || line_no, '
          "'termination', plan_id || ':termination', 'settlement', line_no, "
          'account_id, amount_minor '
          'FROM settlements',
        );

        await migration.database.customStatement(
          'DROP INDEX IF EXISTS amortization_entries_pending_idx',
        );
        await migration.database.customStatement(
          'DROP TABLE amortization_entry_allocations',
        );
        await migration.database.customStatement(
          'DROP TABLE amortization_entries',
        );
        await migration.alterTable(TableMigration(schema.amortizationPlans));
        await migration.database.customStatement(
          'CREATE INDEX amortization_periods_pending_idx '
          'ON amortization_periods (due_at) '
          "WHERE status = 'pending' AND amount_minor > 0",
        );
        await migration.database.customStatement(
          'CREATE INDEX amortization_allocations_subject_idx '
          'ON amortization_allocations (subject_type, subject_id, dimension)',
        );
      },
      from55To56: (migration, schema) async {
        for (final table in const [
          'amortization_terminations',
          'amortization_allocations',
        ]) {
          await migration.database.customStatement(
            'UPDATE $table SET '
            'created_at = CASE WHEN typeof(created_at) = \'text\' '
            'THEN CAST(strftime(\'%s\', created_at) AS INTEGER) '
            'ELSE created_at END, '
            'updated_at = CASE WHEN typeof(updated_at) = \'text\' '
            'THEN CAST(strftime(\'%s\', updated_at) AS INTEGER) '
            'ELSE updated_at END '
            'WHERE typeof(created_at) = \'text\' '
            'OR typeof(updated_at) = \'text\'',
          );
        }
      },
    )(migrator, from, to);
  });
}
