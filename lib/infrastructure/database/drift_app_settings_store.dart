import 'package:drift/drift.dart' show Value;

import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

class DriftAppSettingsStore implements AppSettingsStore {
  const DriftAppSettingsStore(this._database);

  static const _showAddTransactionFabKey = 'settings.show_add_transaction_fab';
  static const _showBottomNavLabelsKey = 'settings.show_bottom_nav_labels';
  static const _pullToCreateSensitivityKey =
      'settings.pull_to_create_sensitivity';

  final AppDatabase _database;

  @override
  Future<AppSettings> read() async {
    final rows =
        await (_database.select(_database.appMetadata)..where(
          (table) => table.key.isIn(const [
            _showAddTransactionFabKey,
            _showBottomNavLabelsKey,
            _pullToCreateSensitivityKey,
          ]),
        )).get();
    final values = {for (final row in rows) row.key: row.value};
    const defaults = AppSettings();
    return AppSettings(
      showAddTransactionFab:
          _parseBool(values[_showAddTransactionFabKey]) ??
          defaults.showAddTransactionFab,
      showBottomNavLabels:
          _parseBool(values[_showBottomNavLabelsKey]) ??
          defaults.showBottomNavLabels,
      pullToCreateSensitivity:
          PullToCreateSensitivity.fromStorageValue(
            values[_pullToCreateSensitivityKey],
          ) ??
          defaults.pullToCreateSensitivity,
    );
  }

  @override
  Future<void> save(AppSettings settings) {
    return _database.batch((batch) {
      batch.insertAllOnConflictUpdate(_database.appMetadata, [
        _entry(_showAddTransactionFabKey, settings.showAddTransactionFab),
        _entry(_showBottomNavLabelsKey, settings.showBottomNavLabels),
        _entry(
          _pullToCreateSensitivityKey,
          settings.pullToCreateSensitivity.storageValue,
        ),
      ]);
    });
  }

  AppMetadataCompanion _entry(String key, Object value) {
    return AppMetadataCompanion.insert(
      key: key,
      value: '$value',
      updatedAt: Value(DateTime.now()),
    );
  }

  bool? _parseBool(String? value) {
    return value == null ? null : value == 'true';
  }
}
