import 'package:drift/drift.dart' show Value;

import 'package:smartflow/application/shared/asset_section_collapse_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

class DriftAssetSectionCollapseStore implements AssetSectionCollapseStore {
  const DriftAssetSectionCollapseStore(this._database);

  static const _collapsedSectionsKey = 'assets.collapsed_sections';

  final AppDatabase _database;

  @override
  Future<Set<String>> read() async {
    final row =
        await (_database.select(_database.appMetadata)
          ..where((table) => table.key.equals(_collapsedSectionsKey))).getSingleOrNull();
    final value = row?.value;
    if (value == null || value.isEmpty) return const {};
    return value.split(',').where((key) => key.isNotEmpty).toSet();
  }

  @override
  Future<void> save(Set<String> collapsedSectionKeys) async {
    await _database
        .into(_database.appMetadata)
        .insertOnConflictUpdate(
          AppMetadataCompanion.insert(
            key: _collapsedSectionsKey,
            value: collapsedSectionKeys.join(','),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
