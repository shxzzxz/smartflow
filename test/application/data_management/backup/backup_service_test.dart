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
              'creditLimitMinor': null,
              'billingDay': null,
              'repaymentDay': null,
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
        expect(manifest.formatVersion, 1);
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
          'counterpartyName': null,
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
}

BackupSnapshot _emptySnapshot({
  Iterable<BackupJson> accounts = const [],
  Iterable<BackupJson> transactions = const [],
  Iterable<BackupJson> entries = const [],
}) {
  return BackupSnapshot(
    tables: {
      'accounts': accounts,
      'transactions': transactions,
      'entries': entries,
    },
    preferences: const {'settings.example': 'true'},
  );
}

class FakeBackupGateway implements BackupSnapshotGateway {
  FakeBackupGateway(this.snapshot);

  BackupSnapshot snapshot;
  int replaceCount = 0;

  @override
  int get schemaVersion => 29;

  @override
  Future<BackupSnapshot> readSnapshot() async => snapshot;

  @override
  Future<void> replaceSnapshot(BackupSnapshot snapshot) async {
    replaceCount++;
    this.snapshot = snapshot;
  }
}
