import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../../application/data_management/backup/backup_models.dart';
import '../../../application/data_management/backup/backup_service.dart';
import '../../database/app_database.dart';
import '../../database/builtin_data.dart';

/// Reads and writes the complete logical snapshot through one database gateway.
/// No repository is used here: a backup must observe all tables consistently.
class DriftBackupGateway
    implements BackupSnapshotGateway, BackupRestoreCoordinator {
  DriftBackupGateway(this.database);

  final AppDatabase database;
  Future<void>? _restoreTail;

  @override
  Future<T> runRestoreExclusive<T>(Future<T> Function() action) {
    Future<T> run() async {
      final waitForPrevious = _restoreTail ?? Future<void>.value();
      await waitForPrevious;
      return action();
    }

    final result = run();
    _restoreTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  int get schemaVersion => database.schemaVersion;

  @override
  Future<BackupSnapshot> readSnapshot() async {
    return database.transaction(() async {
      final tables = <String, Iterable<BackupJson>>{
        'accounts': (await database.select(database.accounts).get()).map(_json),
        'account_groups': (await database.select(database.accountGroups).get())
            .map(_json),
        'transactions': (await database.select(database.transactions).get())
            .map(_json),
        'transaction_lines':
            (await database.select(database.transactionLines).get()).map(_json),
        'entries': (await database.select(database.entries).get()).map(_json),
        'tags': (await database.select(database.tags).get()).map(_json),
        'transaction_tags':
            (await database.select(database.transactionTags).get()).map(_json),
        'budgets': (await database.select(database.budgets).get()).map(_json),
        'credit_liability_accounts':
            (await database.select(database.creditLiabilityAccounts).get()).map(
              _json,
            ),
        'bills': (await database.select(database.bills).get()).map(_json),
        'bill_items': (await database.select(database.billItems).get()).map(
          _json,
        ),
        'bill_generation_suppressions':
            (await database.select(database.billGenerationSuppressions).get())
                .map(_json),
        'installment_products':
            (await database.select(database.installmentProducts).get()).map(
              _json,
            ),
        'installment_stage_configs':
            (await database.select(database.installmentStageConfigs).get()).map(
              _json,
            ),
        'installment_contracts':
            (await database.select(database.installmentContracts).get()).map(
              _json,
            ),
        'installment_schedules':
            (await database.select(database.installmentSchedules).get()).map(
              _json,
            ),
        'repayments': (await database.select(database.repayments).get()).map(
          _json,
        ),
        'repayment_items':
            (await database.select(database.repaymentItems).get()).map(_json),
        'import_entity_mappings':
            (await database.select(database.importEntityMappings).get()).map(
              _json,
            ),
        'import_batches': (await database.select(database.importBatches).get())
            .map(_json),
        'import_batch_items':
            (await database.select(database.importBatchItems).get()).map(_json),
      };
      final metadata = await (database.select(
        database.appMetadata,
      )..where((row) => row.key.like('settings.%'))).get();
      return BackupSnapshot(
        tables: tables,
        preferences: {for (final row in metadata) row.key: row.value},
      );
    });
  }

  @override
  Future<void> replaceSnapshot(BackupSnapshot snapshot) async {
    // Validate all row converters and SQLite constraints in an isolated
    // database before touching the live connection.
    final temporaryDatabase = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    try {
      await DriftBackupGateway(
        temporaryDatabase,
      )._replaceSnapshotContents(snapshot);
    } finally {
      await temporaryDatabase.close();
    }
    await _replaceSnapshotContents(snapshot);
  }

  Future<void> _replaceSnapshotContents(BackupSnapshot snapshot) async {
    await database.transaction(() async {
      // Delete dependants first. References are intentionally application-level,
      // but this ordering also makes the operation work if SQLite enforcement is
      // enabled by a host application in the future.
      for (final table in [
        'repayment_items',
        'repayments',
        'installment_schedules',
        'installment_stage_configs',
        'installment_contracts',
        'installment_products',
        'bill_items',
        'bills',
        'bill_generation_suppressions',
        'credit_liability_accounts',
        'import_batch_items',
        'import_batches',
        'import_entity_mappings',
        'transaction_tags',
        'entries',
        'transaction_lines',
        'transactions',
        'budgets',
        'tags',
        'accounts',
        'account_groups',
      ]) {
        await database.customStatement('DELETE FROM "$table"');
      }

      await database.batch((batch) {
        batch.insertAll(
          database.accountGroups,
          snapshot
              .rows('account_groups')
              .map((row) => AccountGroupRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.accounts,
          snapshot
              .rows('accounts')
              .map((row) => AccountRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.tags,
          snapshot
              .rows('tags')
              .map((row) => TagRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.transactions,
          snapshot
              .rows('transactions')
              .map((row) => TransactionRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.transactionLines,
          snapshot
              .rows('transaction_lines')
              .map((row) => TransactionLineRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.entries,
          snapshot
              .rows('entries')
              .map((row) => EntryRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.transactionTags,
          snapshot
              .rows('transaction_tags')
              .map((row) => TransactionTagRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.budgets,
          snapshot
              .rows('budgets')
              .map((row) => BudgetRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.creditLiabilityAccounts,
          snapshot
              .rows('credit_liability_accounts')
              .map(
                (row) =>
                    CreditLiabilityAccountRow.fromJson(row).toCompanion(true),
              ),
        );
        batch.insertAll(
          database.bills,
          snapshot
              .rows('bills')
              .map((row) => BillRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.billItems,
          snapshot
              .rows('bill_items')
              .map((row) => BillItemRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.billGenerationSuppressions,
          snapshot
              .rows('bill_generation_suppressions')
              .map(
                (row) => BillGenerationSuppressionRow.fromJson(
                  row,
                ).toCompanion(true),
              ),
        );
        batch.insertAll(
          database.installmentProducts,
          snapshot
              .rows('installment_products')
              .map(
                (row) => InstallmentProductRow.fromJson(row).toCompanion(true),
              ),
        );
        batch.insertAll(
          database.installmentStageConfigs,
          snapshot
              .rows('installment_stage_configs')
              .map(
                (row) =>
                    InstallmentStageConfigRow.fromJson(row).toCompanion(true),
              ),
        );
        batch.insertAll(
          database.installmentContracts,
          snapshot
              .rows('installment_contracts')
              .map(
                (row) => InstallmentContractRow.fromJson(row).toCompanion(true),
              ),
        );
        batch.insertAll(
          database.installmentSchedules,
          snapshot
              .rows('installment_schedules')
              .map(
                (row) => InstallmentScheduleRow.fromJson(row).toCompanion(true),
              ),
        );
        batch.insertAll(
          database.repayments,
          snapshot
              .rows('repayments')
              .map((row) => RepaymentRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.repaymentItems,
          snapshot
              .rows('repayment_items')
              .map((row) => RepaymentItemRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.importEntityMappings,
          snapshot
              .rows('import_entity_mappings')
              .map(
                (row) => ImportEntityMappingRow.fromJson(row).toCompanion(true),
              ),
        );
        batch.insertAll(
          database.importBatches,
          snapshot
              .rows('import_batches')
              .map((row) => ImportBatchRow.fromJson(row).toCompanion(true)),
        );
        batch.insertAll(
          database.importBatchItems,
          snapshot
              .rows('import_batch_items')
              .map((row) => ImportBatchItemRow.fromJson(row).toCompanion(true)),
        );
      });

      await (database.delete(
        database.appMetadata,
      )..where((row) => row.key.like('settings.%'))).go();
      if (snapshot.preferences.isNotEmpty) {
        await database.batch((batch) {
          batch.insertAll(
            database.appMetadata,
            snapshot.preferences.entries.map(
              (entry) => AppMetadataCompanion.insert(
                key: entry.key,
                value: '${entry.value}',
                updatedAt: Value(DateTime.now()),
              ),
            ),
          );
        });
      }
      await ensureBuiltinData(database);
    });
  }

  BackupJson _json(Object row) {
    if (row is AccountRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is AccountGroupRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is TransactionRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is TransactionLineRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is EntryRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is TagRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is TransactionTagRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is BudgetRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is CreditLiabilityAccountRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is BillRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is BillItemRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is BillGenerationSuppressionRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is InstallmentProductRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is InstallmentStageConfigRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is InstallmentContractRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is InstallmentScheduleRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is RepaymentRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is RepaymentItemRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is ImportEntityMappingRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is ImportBatchRow) {
      return row.toJson().cast<String, Object?>();
    }
    if (row is ImportBatchItemRow) {
      return row.toJson().cast<String, Object?>();
    }
    throw ArgumentError('Unsupported backup row: ${row.runtimeType}');
  }
}
