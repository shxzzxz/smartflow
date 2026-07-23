import 'package:drift/drift.dart';

import '../../../domain/import/import_models.dart';
import '../../../domain/import/import_persistence_models.dart';
import '../../../domain/import/port/import_mapping_repository.dart';
import '../../database/app_database.dart';

class DriftImportMappingRepository implements ImportMappingRepository {
  const DriftImportMappingRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<ImportEntityMapping>> findBySource(ImportSource source) async {
    final rows =
        await (_database.select(_database.importEntityMappings)
              ..where((row) => row.source.equals(source.name))
              ..orderBy([
                (row) => OrderingTerm.asc(row.entityKind),
                (row) => OrderingTerm.asc(row.sourceEntityKey),
              ]))
            .get();
    return rows.map(_map).toList(growable: false);
  }

  @override
  Future<ImportEntityMapping?> find({
    required ImportSource source,
    required ImportEntityKind entityKind,
    required String sourceEntityKey,
  }) async {
    final row =
        await (_database.select(_database.importEntityMappings)..where(
          (mapping) =>
              mapping.source.equals(source.name) &
              mapping.entityKind.equals(entityKind.name) &
              mapping.sourceEntityKey.equals(sourceEntityKey),
        )).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  @override
  Future<void> upsert(ImportEntityMapping mapping) async {
    final existing = await find(
      source: mapping.source,
      entityKind: mapping.entityKind,
      sourceEntityKey: mapping.sourceEntityKey,
    );
    if (existing == null) {
      await _database
          .into(_database.importEntityMappings)
          .insert(
            ImportEntityMappingsCompanion.insert(
              id: mapping.id,
              source: mapping.source,
              entityKind: mapping.entityKind,
              sourceEntityKey: mapping.sourceEntityKey,
              targetAccountId: mapping.targetAccountId,
              createdAt: Value(mapping.createdAt),
              updatedAt: Value(mapping.updatedAt),
            ),
          );
      return;
    }

    await (_database.update(_database.importEntityMappings)
      ..where((row) => row.id.equals(existing.id))).write(
      ImportEntityMappingsCompanion(
        targetAccountId: Value(mapping.targetAccountId),
        updatedAt: Value(mapping.updatedAt),
      ),
    );
  }

  ImportEntityMapping _map(ImportEntityMappingRow row) {
    return ImportEntityMapping(
      id: row.id,
      source: row.source,
      entityKind: row.entityKind,
      sourceEntityKey: row.sourceEntityKey,
      targetAccountId: row.targetAccountId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
