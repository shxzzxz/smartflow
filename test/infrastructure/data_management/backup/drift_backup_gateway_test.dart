import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'dart:io';
import '../../../helper/test_app_database.dart';

void main() {
  late AppDatabase database;
  late DriftBackupGateway gateway;

  setUp(() {
    database = createTestDatabase();
    gateway = DriftBackupGateway(database);
  });

  tearDown(() async => database.close());

  test(
    'backup restores detached repayment items with their amounts and original bill',
    () async {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'loan',
              name: '贷款',
              accountType: AccountType.liability,
              accountSubtype: const Value(AccountSubtype.loan),
              accountProfileKey: const Value('credit.loan'),
            ),
          );
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'old-bill',
              accountId: 'loan',
              period: 202607,
              status: BillStatus.settled,
            ),
          );
      await database
          .into(database.repayments)
          .insert(
            RepaymentsCompanion.insert(
              id: 'repayment',
              repaymentType: 'BILL',
              targetType: 'BILL',
              targetId: 'old-bill',
              repaymentDate: DateTime(2026, 7, 15),
            ),
          );
      await database
          .into(database.repaymentItems)
          .insert(
            RepaymentItemsCompanion.insert(
              id: 'detached-item',
              repaymentId: 'repayment',
              allocatedPrincipalMinor: 20000,
              allocatedInterestMinor: 100,
              allocatedFeeMinor: 50,
              allocatedDiscountMinor: 20,
            ),
          );
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-detached-repayment-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = BackupService(
        gateway: gateway,
        packageStore: const FileBackupPackageStore(),
      );
      await service.createBackup(directory);
      await database.delete(database.repaymentItems).go();
      await database.delete(database.repayments).go();
      await service.restore(directory);
      final restored = (await DriftRepaymentRepository(
        database,
      ).findRepayment('repayment'))!;
      expect(restored.targetId, 'old-bill');
      expect(restored.repaymentDate, DateTime(2026, 7, 15));
      final item = restored.items.single;
      expect(item.id, 'detached-item');
      expect(item.billItemId, isNull);
      expect(item.allocated.principal.minorUnits, 20000);
      expect(item.allocated.interest.minorUnits, 100);
      expect(item.allocated.fee.minorUnits, 50);
      expect(item.allocated.discount.minorUnits, 20);
    },
  );

  test('reads and replaces all business tables in one gateway', () async {
    final before = await gateway.readSnapshot();

    expect(
      before.tables.keys,
      containsAll(<String>[
        'accounts',
        'transactions',
        'entries',
        'bills',
        'repayments',
        'import_batches',
      ]),
    );

    await gateway.replaceSnapshot(before);
    final after = await gateway.readSnapshot();

    for (final table in before.tables.keys) {
      expect(after.rows(table), hasLength(before.rows(table).length));
    }
    expect(after.preferences, before.preferences);
  });

  test(
    'serializes settings preferences without exporting metadata internals',
    () async {
      await database
          .into(database.appMetadata)
          .insert(
            AppMetadataCompanion.insert(key: 'settings.example', value: 'true'),
          );
      await database
          .into(database.appMetadata)
          .insertOnConflictUpdate(
            AppMetadataCompanion.insert(
              key: 'builtin_data_version',
              value: '10',
            ),
          );

      final snapshot = await gateway.readSnapshot();
      expect(snapshot.preferences, {'settings.example': 'true'});
    },
  );

  test('exports a real migrated database snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'smartflow-real-backup-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = BackupService(
      gateway: gateway,
      packageStore: const FileBackupPackageStore(),
    );

    final manifest = await service.createBackup(directory);
    expect(manifest.files, isNotEmpty);
    expect(
      (await service.inspect(directory)).snapshot.rows('accounts'),
      isNotEmpty,
    );
  });

  test('exports soft references whose targets were deleted', () async {
    await database
        .into(database.importEntityMappings)
        .insert(
          ImportEntityMappingsCompanion.insert(
            id: 'mapping',
            source: ImportSource.yimu,
            entityKind: ImportEntityKind.account,
            sourceEntityKey: 'account:deleted',
            targetAccountId: 'deleted-account',
          ),
        );
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: 'budget',
            monthKey: 202601,
            accountId: const Value('deleted-category'),
            amountMinor: 100,
          ),
        );

    final directory = await Directory.systemTemp.createTemp(
      'smartflow-soft-reference-backup-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final service = BackupService(
      gateway: gateway,
      packageStore: const FileBackupPackageStore(),
    );

    await service.createBackup(directory);

    final snapshot = (await service.inspect(directory)).snapshot;
    expect(snapshot.rows('import_entity_mappings'), hasLength(1));
    expect(snapshot.rows('budgets'), hasLength(1));
  });
}
