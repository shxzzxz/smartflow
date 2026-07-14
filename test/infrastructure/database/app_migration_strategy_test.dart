import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/migration/app_migration_strategy.dart';

import '../../helper/test_app_database.dart';

void main() {
  test('destructive upgrade rebuilds the current schema', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    expect(database.schemaVersion, 19);
    await database.customStatement(
      "INSERT INTO credit_liability_accounts "
      "(id, account_id, kind, billing_day, repayment_day) "
      "VALUES ('credit-1', 'account-1', 'credit', 5, 25)",
    );

    final strategy = buildMigrationStrategy(database);
    await strategy.onUpgrade(Migrator(database), 18, 19);

    final extensions =
        await database
            .customSelect(
              'SELECT COUNT(*) AS count FROM credit_liability_accounts',
            )
            .getSingle();
    expect(extensions.read<int>('count'), 0);
    final tables =
        await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name IN ('bills', 'bill_items', 'repayments', 'repayment_items')",
            )
            .get();
    expect(tables, hasLength(4));
    await database.customStatement(
      "INSERT INTO installment_contracts "
      "(id, liability_account_id, source_type, disbursement_account_id, "
      "disbursement_transaction_id, principal_minor, total_periods, "
      "start_date, first_repayment_date, last_repayment_date, "
      "repayment_method, interest_accrual_method, status) "
      "VALUES ('migration-contract', 'loan-1', 'disbursement', NULL, NULL, "
      "120000, 12, 0, 0, 0, 'equalInstallment', 'daily', 'active')",
    );
  });
}
