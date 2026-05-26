import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/ledger/valobj/ledger_enum.dart';
import '../domain/credit/valobj/installment_enums.dart';
import 'migration/app_migration_strategy.dart';
import 'ledger/table/accounts.dart';
import 'app_metadata.dart';
import 'budget/table/budgets.dart';
import 'ledger/table/entries.dart';
import 'credit/table/installment_contracts.dart';
import 'credit/table/installment_repayments.dart';
import 'credit/table/installment_schedules.dart';
import 'ledger/table/transaction_details.dart';
import 'ledger/table/transactions.dart';

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
