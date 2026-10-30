import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:crypto/crypto.dart';

import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'dart:io';
import 'dart:convert';
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
        'counterparties',
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

  test('round-trips counterparties and transaction references', () async {
    await database
        .into(database.counterparties)
        .insert(CounterpartiesCompanion.insert(id: 'cp-ziroom', name: '自如'));
    await database
        .into(database.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'tx-1',
            businessPurpose: BusinessPurpose.transfer,
            occurredAt: DateTime(2026, 1, 1),
            postedAt: DateTime(2026, 1, 1),
            primaryAmountMinor: 100,
            counterpartyId: const Value('cp-ziroom'),
            sourceKind: SourceKind.manual,
          ),
        );

    final snapshot = await gateway.readSnapshot();
    await database.delete(database.transactions).go();
    await database.delete(database.counterparties).go();
    await gateway.replaceSnapshot(snapshot);

    final transaction = await database
        .select(database.transactions)
        .getSingle();
    expect(transaction.counterpartyId, 'cp-ziroom');
    expect(
      (await database.select(database.counterparties).getSingle()).name,
      '自如',
    );
  });

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

  test(
    'round-trips installment sources and generated contract links',
    () async {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'credit',
              name: '信用卡',
              accountType: AccountType.liability,
              accountSubtype: const Value(AccountSubtype.payable),
              accountProfileKey: const Value('credit.credit'),
            ),
          );
      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'bill',
              accountId: 'credit',
              period: 202607,
              status: BillStatus.billed,
            ),
          );
      await DriftInstallmentRepository(database).insertAggregate(
        InstallmentContract(
          id: 'contract',
          liabilityAccountId: 'credit',
          installmentType: InstallmentType.billConversion,
          sourceRefId: 'repayment',
          principal: const Money(minorUnits: 10000),
          borrowingDate: DateTime(2026, 7, 1),
          status: InstallmentContractStatus.active,
          createdAt: DateTime(2026, 7, 1),
          stageTerms: InstallmentContractTerms.singleStage(
            id: 'contract:stage:1',
            totalPeriods: 1,
            firstDate: DateTime(2026, 8, 1),
            lastDate: DateTime(2026, 8, 1),
            method: InstallmentRepaymentMethod.equalPrincipal,
            feeMinor: 0,
            accrual: InterestAccrualMethod.monthly,
          ),
        ),
        const [],
      );
      await database
          .into(database.repayments)
          .insert(
            RepaymentsCompanion.insert(
              id: 'repayment',
              repaymentType: 'INSTALLMENT',
              targetType: 'BILL',
              targetId: 'bill',
              generatedContractId: const Value('contract'),
              repaymentDate: DateTime(2026, 7, 1),
            ),
          );
      await database
          .into(database.repaymentItems)
          .insert(
            RepaymentItemsCompanion.insert(
              id: 'repayment-item',
              repaymentId: 'repayment',
              allocatedPrincipalMinor: 10000,
              allocatedInterestMinor: 0,
              allocatedFeeMinor: 0,
              allocatedDiscountMinor: 0,
            ),
          );

      final directory = await Directory.systemTemp.createTemp(
        'smartflow-installment-source-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = BackupService(
        gateway: gateway,
        packageStore: const FileBackupPackageStore(),
      );
      await service.createBackup(directory);
      await _rewriteTableAsV3(directory, 'installment_contracts', (row) {
        final installmentType = row['installmentType'];
        final sourceRefId = row['sourceRefId'];
        return Map<String, Object?>.from(row)
          ..remove('installmentType')
          ..remove('sourceRefId')
          ..['sourceType'] = installmentType
          ..['disbursementAccountId'] =
              installmentType == 'disbursement' && sourceRefId != null
              ? 'unused-asset'
              : null
          ..['disbursementTransactionId'] = installmentType == 'disbursement'
              ? sourceRefId
              : null
          ..['sourceRepaymentId'] = installmentType == 'billConversion'
              ? sourceRefId
              : null
          ..['purchaseTransactionId'] = installmentType == 'purchase'
              ? sourceRefId
              : null;
      });
      await _rewriteTableAsV3(
        directory,
        'repayments',
        (row) => Map<String, Object?>.from(row)..remove('generatedContractId'),
      );
      await database.delete(database.repaymentItems).go();
      await database.delete(database.repayments).go();
      await DriftInstallmentRepository(database).deleteContract('contract');
      await service.restore(directory);

      final contract = await DriftInstallmentRepository(
        database,
      ).findContract('contract');
      final repayment = await DriftRepaymentRepository(
        database,
      ).findRepayment('repayment');
      expect(contract?.installmentType, InstallmentType.billConversion);
      expect(contract?.sourceRefId, 'repayment');
      expect(repayment?.generatedContractId, 'contract');
    },
  );
}

Future<void> _rewriteTableAsV3(
  Directory directory,
  String table,
  BackupJson Function(BackupJson row) transform,
) async {
  final manifestFile = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final descriptors = (manifest['requiredFiles'] as List)
      .cast<Map<String, dynamic>>()
      .where((descriptor) => descriptor['table'] == table);
  for (final descriptor in descriptors) {
    final file = File('${directory.path}/${descriptor['path']}');
    final rows = const LineSplitter()
        .convert(await file.readAsString())
        .where((line) => line.trim().isNotEmpty)
        .map((line) => (jsonDecode(line) as Map).cast<String, Object?>())
        .map(transform)
        .toList();
    final buffer = StringBuffer();
    for (final row in rows) {
      buffer.writeln(jsonEncode(row));
    }
    final bytes = utf8.encode(buffer.toString());
    await file.writeAsBytes(bytes);
    descriptor['rowCount'] = rows.length;
    descriptor['byteCount'] = bytes.length;
    descriptor['sha256'] = sha256.convert(bytes).toString();
  }
  manifest['backupSchemaVersion'] = 3;
  manifest['schemaVersion'] = 51;
  await manifestFile.writeAsString(jsonEncode(manifest));
}
