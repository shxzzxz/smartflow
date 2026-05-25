import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/accounting/enums/accounting_enums.dart';
import '../domain/credit/enums/installment_enums.dart';
import 'migrations/app_migration_strategy.dart';
import 'accounting/tables/accounts.dart';
import 'app_metadata.dart';
import 'budgeting/tables/budgets.dart';
import 'accounting/tables/entries.dart';
import 'credit/tables/installment_contracts.dart';
import 'credit/tables/installment_repayments.dart';
import 'credit/tables/installment_schedules.dart';
import 'accounting/tables/transaction_details.dart';
import 'accounting/tables/transactions.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    AppMetadata,
    Transactions,
    TransactionDetails,
    Entries,
    Budgets,
    InstallmentContracts,
    InstallmentSchedules,
    InstallmentRepayments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => buildMigrationStrategy(this);

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'smartflow.sqlite',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
