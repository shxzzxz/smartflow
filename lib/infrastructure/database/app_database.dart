import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/ledger/valobj/ledger_enum.dart';
import '../../domain/credit/valobj/installment_enums.dart';
import 'migration/app_migration_strategy.dart';
import 'table/ledger/accounts.dart';
import 'table/app_metadata.dart';
import 'table/budget/budgets.dart';
import 'table/ledger/entries.dart';
import 'table/credit/installment_contracts.dart';
import 'table/credit/installment_repayments.dart';
import 'table/credit/installment_schedules.dart';
import 'table/ledger/transaction_details.dart';
import 'table/ledger/transactions.dart';

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
  int get schemaVersion => 10;

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
