import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';

void main() {
  group('BackupService', () {
    late Directory tempDirectory;
    late FakeBackupGateway gateway;
    late BackupService service;

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync(
        'smartflow-backup-test-',
      );
      gateway = FakeBackupGateway(_emptySnapshot());
      service = BackupService(
        gateway: gateway,
        packageStore: const FileBackupPackageStore(),
        appVersion: 'test',
      );
    });

    tearDown(() => tempDirectory.delete(recursive: true));

    test('exports and inspects a complete multi-file snapshot', () async {
      final manifest = await service.createBackup(tempDirectory);

      expect(manifest.files.length, BackupTables.all.length + 1);
      expect(
        await File('${tempDirectory.path}/manifest.json').exists(),
        isTrue,
      );
      expect(
        await File('${tempDirectory.path}/ledger/accounts.ndjson').exists(),
        isTrue,
      );
      final inspected = await service.inspect(tempDirectory);
      expect(inspected.manifest.backupId, manifest.backupId);
      expect(inspected.manifest.backupSchemaVersion, 4);
      expect(inspected.manifest.schemaVersion, 52);
      expect(inspected.snapshot.preferences['settings.example'], 'true');
    });

    test('rejects a file after its bytes change', () async {
      await service.createBackup(tempDirectory);
      final file = File('${tempDirectory.path}/ledger/accounts.ndjson');
      await file.writeAsString('{"id":"tampered"}\n');

      expect(
        () => service.inspect(tempDirectory),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test(
      'uses the backup contract instead of the source database version',
      () async {
        final oldDirectory = Directory('${tempDirectory.path}/v49-backup')
          ..createSync();
        final v49Service = BackupService(
          gateway: FakeBackupGateway(_emptySnapshot(), schemaVersion: 49),
          packageStore: const FileBackupPackageStore(),
        );
        await v49Service.createBackup(oldDirectory);
        final v50Gateway = FakeBackupGateway(
          BackupSnapshot(),
          schemaVersion: 50,
        );
        final v50Service = BackupService(
          gateway: v50Gateway,
          packageStore: const FileBackupPackageStore(),
        );

        final inspection = await v50Service.inspect(oldDirectory);
        final diff = await v50Service.restore(oldDirectory);

        expect(inspection.manifest.backupSchemaVersion, 4);
        expect(inspection.manifest.schemaVersion, 49);
        expect(diff.itemFor('preferences').added, 1);
        expect(v50Gateway.replaceCount, 1);
      },
    );

    test('migrates v1 backups without legacy account credit columns', () async {
      final legacyDirectory = Directory('${tempDirectory.path}/v1-backup')
        ..createSync();
      final legacySnapshot = _emptySnapshot(
        accounts: [
          {
            'id': 'credit',
            'name': '信用卡',
            'accountType': 'liability',
            'accountSubtype': 'payable',
            'accountProfileKey': 'credit.credit',
            'groupId': null,
            'parentId': null,
            'balanceMinor': 0,
            'iconKey': null,
            'note': null,
            'creditLimitMinor': 100000,
            'billingDay': 5,
            'repaymentDay': 25,
            'sortOrder': 0,
            'isHidden': false,
            'archivedAt': null,
            'systemKey': null,
            'source': 'user',
            'version': 0,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      );
      final legacyService = BackupService(
        gateway: FakeBackupGateway(legacySnapshot, schemaVersion: 49),
        packageStore: const FileBackupPackageStore(),
      );
      await legacyService.createBackup(legacyDirectory);
      await _rewriteBackupSchemaVersion(legacyDirectory, 1);

      final inspection = await service.inspect(legacyDirectory);
      final account = inspection.snapshot.rows('accounts').single;

      expect(inspection.manifest.backupSchemaVersion, 1);
      expect(account.containsKey('creditLimitMinor'), isFalse);
      expect(account.containsKey('billingDay'), isFalse);
      expect(account.containsKey('repaymentDay'), isFalse);
      expect(account['accountProfileKey'], 'credit.credit');
    });

    test(
      'migrates v2 backups before requiring refund reduction data',
      () async {
        await service.createBackup(tempDirectory);
        await _removeBackupTable(
          tempDirectory,
          'installment_refund_reductions',
        );
        await _rewriteBackupSchemaVersion(tempDirectory, 2);

        final inspection = await service.inspect(tempDirectory);

        expect(inspection.manifest.backupSchemaVersion, 2);
        expect(
          inspection.snapshot.rows('installment_refund_reductions'),
          isEmpty,
        );
      },
    );

    test('rejects obsolete backup format versions', () async {
      await service.createBackup(tempDirectory);
      final manifestFile = File('${tempDirectory.path}/manifest.json');
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
      manifest['formatVersion'] = 2;
      await manifestFile.writeAsString(jsonEncode(manifest));

      expect(
        () => service.inspect(tempDirectory),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects unsupported backup schema versions', () async {
      await service.createBackup(tempDirectory);
      final manifestFile = File('${tempDirectory.path}/manifest.json');
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, Object?>;
      manifest['backupSchemaVersion'] = 5;
      await manifestFile.writeAsString(jsonEncode(manifest));

      expect(
        () => service.inspect(tempDirectory),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.message,
            'message',
            contains('backupSchemaVersion 5'),
          ),
        ),
      );
    });

    test(
      'compares and restores the snapshot, while equal data is a no-op',
      () async {
        final manifest = await service.createBackup(tempDirectory);
        expect((await service.compare(tempDirectory)).isNoop, isTrue);

        final incoming = _emptySnapshot(
          accounts: [
            {
              'id': 'cash',
              'name': '现金',
              'accountType': 'asset',
              'accountSubtype': 'fund',
              'accountProfileKey': 'ledger.fund',
              'groupId': null,
              'parentId': null,
              'balanceMinor': 0,
              'iconKey': null,
              'note': null,
              'sortOrder': 0,
              'isHidden': false,
              'archivedAt': null,
              'systemKey': null,
              'source': 'user',
              'version': 0,
              'createdAt': '2026-01-01T00:00:00.000Z',
              'updatedAt': '2026-01-01T00:00:00.000Z',
            },
          ],
        );
        final incomingDirectory = Directory('${tempDirectory.path}-incoming')
          ..createSync();
        addTearDown(() => incomingDirectory.delete(recursive: true));
        final incomingService = BackupService(
          gateway: FakeBackupGateway(incoming),
          packageStore: const FileBackupPackageStore(),
        );
        await incomingService.createBackup(incomingDirectory);
        gateway.snapshot = _emptySnapshot();
        final diff = await service.restore(incomingDirectory);
        expect(diff.itemFor('accounts').added, 1);
        expect(gateway.replaceCount, 1);
        expect(manifest.formatVersion, 3);
        expect(manifest.backupSchemaVersion, 4);
      },
    );
  });

  test('rejects dangling references and unbalanced account balances', () {
    final snapshot = _emptySnapshot(
      transactions: [
        {
          'id': 'tx',
          'businessPurpose': 'dailyExpense',
          'occurredAt': '2026-01-01T00:00:00.000Z',
          'postedAt': '2026-01-01T00:00:00.000Z',
          'primaryAmountMinor': 100,
          'counterpartyId': null,
          'note': null,
          'parentTransactionId': null,
          'isExcludedFromStats': false,
          'isExcludedFromBudget': false,
          'sourceKind': 'manual',
          'ownerType': null,
          'ownerId': null,
          'ownerRole': null,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
      entries: [
        {
          'id': 'entry',
          'transactionId': 'tx',
          'accountId': 'missing',
          'direction': 'debit',
          'amountMinor': 100,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
    );

    expect(
      () => BackupService.validateSnapshot(snapshot),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rejects account parent cycles and counts preference diffs by key', () {
    final cyclic = _emptySnapshot(
      accounts: [
        {'id': 'a', 'groupId': null, 'parentId': 'b', 'balanceMinor': 0},
        {'id': 'b', 'groupId': null, 'parentId': 'a', 'balanceMinor': 0},
      ],
    );
    expect(
      () => BackupService.validateSnapshot(cyclic),
      throwsA(isA<BackupValidationException>()),
    );

    final current = BackupSnapshot(preferences: const {'a': '1', 'b': '2'});
    final incoming = BackupSnapshot(preferences: const {'a': '3', 'c': '4'});
    final diff = BackupDiff.compare(current, incoming);
    final preferences = diff.itemFor('preferences');
    expect(preferences.added, 1);
    expect(preferences.removed, 1);
    expect(preferences.changed, 1);
  });

  test('allows historical import items whose transaction was deleted', () {
    final snapshot = _emptySnapshot();
    final withHistory = snapshot.copyWith(
      tables: {
        ...snapshot.tables,
        'import_batches': [
          {
            'id': 'batch',
            'source': 'yimu',
            'status': 'reverted',
            'importedGroupCount': 1,
            'createdTransactionCount': 1,
            'skippedGroupCount': 0,
            'importedAt': '2026-01-01T00:00:00.000Z',
            'revertedAt': '2026-01-02T00:00:00.000Z',
          },
        ],
        'import_batch_items': [
          {
            'id': 'item',
            'batchId': 'batch',
            'sourceOperationKey': null,
            'sourceOperationFingerprint': 'fingerprint',
            'fingerprintVersion': 1,
            'topLevelTransactionId': 'deleted-transaction',
          },
        ],
      },
    );

    expect(() => BackupService.validateSnapshot(withHistory), returnsNormally);
  });

  test('allows unavailable import mapping and budget targets', () {
    final snapshot = _emptySnapshot(
      tables: {
        'import_entity_mappings': [
          {
            'id': 'mapping',
            'source': 'yimu',
            'entityKind': 'account',
            'sourceEntityKey': 'account:deleted',
            'targetAccountId': 'deleted-account',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        'budgets': [
          {
            'id': 'budget',
            'monthKey': 202601,
            'accountId': 'deleted-category',
            'amountMinor': 100,
            'sortOrder': 0,
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
      },
    );

    expect(() => BackupService.validateSnapshot(snapshot), returnsNormally);
  });
}

BackupSnapshot _emptySnapshot({
  Iterable<BackupJson> accounts = const [],
  Iterable<BackupJson> transactions = const [],
  Iterable<BackupJson> entries = const [],
  Map<String, List<BackupJson>>? tables,
}) {
  return BackupSnapshot(
    tables: {
      'accounts': accounts,
      'transactions': transactions,
      'entries': entries,
      ...?tables,
    },
    preferences: const {'settings.example': 'true'},
  );
}

class FakeBackupGateway implements BackupSnapshotGateway {
  FakeBackupGateway(this.snapshot, {this.schemaVersion = 52});

  BackupSnapshot snapshot;
  int replaceCount = 0;

  @override
  final int schemaVersion;

  @override
  Future<BackupSnapshot> readSnapshot() async => snapshot;

  @override
  Future<void> replaceSnapshot(BackupSnapshot snapshot) async {
    replaceCount++;
    this.snapshot = snapshot;
  }
}

Future<void> _rewriteBackupSchemaVersion(
  Directory directory,
  int version,
) async {
  final file = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, Object?>;
  manifest['backupSchemaVersion'] = version;
  await file.writeAsString(jsonEncode(manifest));
}

Future<void> _removeBackupTable(Directory directory, String table) async {
  final file = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, Object?>;
  final files = (manifest['requiredFiles'] as List).cast<Map>();
  Map? removed;
  files.removeWhere((entry) {
    if (entry['table'] != table) return false;
    removed = entry;
    return true;
  });
  if (removed == null) {
    throw StateError('Backup table $table was not found.');
  }
  final path = removed!['path'] as String;
  await File('${directory.path}/$path').delete();
  await file.writeAsString(jsonEncode(manifest));
}
