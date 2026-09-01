import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
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
}
