import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/log_retention_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_log_retention_store.dart';

import '../../helper/test_app_database.dart';

void main() {
  group('DriftLogRetentionStore', () {
    test('read returns defaults when nothing is stored', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftLogRetentionStore(database);

      final settings = await store.read();

      expect(
        settings.maxFileAgeDays,
        const LogRetentionSettings().maxFileAgeDays,
      );
      expect(settings.maxFiles, const LogRetentionSettings().maxFiles);
    });

    test('save then read round-trips the settings', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftLogRetentionStore(database);

      await store.save(
        const LogRetentionSettings(maxFileAgeDays: 7, maxFiles: 3),
      );
      await store.save(
        const LogRetentionSettings(maxFileAgeDays: 30, maxFiles: 10),
      );

      final settings = await store.read();
      expect(settings.maxFileAgeDays, 30);
      expect(settings.maxFiles, 10);
    });

    test('read falls back to defaults for invalid stored values', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final store = DriftLogRetentionStore(database);
      await database
          .into(database.appMetadata)
          .insertOnConflictUpdate(
            AppMetadataCompanion.insert(
              key: 'logging.max_file_age_days',
              value: 'oops',
              updatedAt: Value(DateTime(2026, 8, 1)),
            ),
          );
      await database
          .into(database.appMetadata)
          .insertOnConflictUpdate(
            AppMetadataCompanion.insert(
              key: 'logging.max_files',
              value: '0',
              updatedAt: Value(DateTime(2026, 8, 1)),
            ),
          );

      final settings = await store.read();

      expect(
        settings.maxFileAgeDays,
        const LogRetentionSettings().maxFileAgeDays,
      );
      expect(settings.maxFiles, const LogRetentionSettings().maxFiles);
    });
  });
}
