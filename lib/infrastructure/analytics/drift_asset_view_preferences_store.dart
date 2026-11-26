import 'package:drift/drift.dart';
import '../../application/analytics/asset_view/port/asset_view_preferences_store.dart';
import '../database/app_database.dart';

class DriftAssetViewPreferencesStore implements AssetViewPreferencesStore {
  const DriftAssetViewPreferencesStore(this._database);
  static const _selectedViewKey = 'assets.selected_view';
  final AppDatabase _database;
  @override
  Future<String?> readSelectedViewId() async =>
      (await (_database.select(_database.appMetadata)
                ..where((row) => row.key.equals(_selectedViewKey)))
              .getSingleOrNull())
          ?.value;
  @override
  Future<void> saveSelectedViewId(String id) async {
    await _database
        .into(_database.appMetadata)
        .insertOnConflictUpdate(
          AppMetadataCompanion.insert(
            key: _selectedViewKey,
            value: id,
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
