import 'package:drift/drift.dart' show Value;

import 'package:smartflow/application/shared/log_retention_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

class DriftLogRetentionStore implements LogRetentionStore {
  const DriftLogRetentionStore(this._database);

  static const _maxFileAgeDaysKey = 'logging.max_file_age_days';
  static const _maxFilesKey = 'logging.max_files';

  final AppDatabase _database;

  @override
  Future<LogRetentionSettings> read() async {
    final rows =
        await (_database.select(_database.appMetadata)..where(
          (table) => table.key.isIn(const [_maxFileAgeDaysKey, _maxFilesKey]),
        )).get();
    final values = {for (final row in rows) row.key: row.value};
    const defaults = LogRetentionSettings();
    return LogRetentionSettings(
      maxFileAgeDays:
          _parsePositiveInt(values[_maxFileAgeDaysKey]) ??
          defaults.maxFileAgeDays,
      maxFiles: _parsePositiveInt(values[_maxFilesKey]) ?? defaults.maxFiles,
    );
  }

  @override
  Future<void> save(LogRetentionSettings settings) {
    return _database.batch((batch) {
      batch.insertAllOnConflictUpdate(_database.appMetadata, [
        _entry(_maxFileAgeDaysKey, settings.maxFileAgeDays),
        _entry(_maxFilesKey, settings.maxFiles),
      ]);
    });
  }

  AppMetadataCompanion _entry(String key, int value) {
    return AppMetadataCompanion.insert(
      key: key,
      value: '$value',
      updatedAt: Value(DateTime.now()),
    );
  }

  int? _parsePositiveInt(String? value) {
    if (value == null) return null;
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
