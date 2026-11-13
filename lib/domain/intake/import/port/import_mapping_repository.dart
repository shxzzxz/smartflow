import '../import_models.dart';
import '../import_persistence_models.dart';

abstract interface class ImportMappingRepository {
  Future<List<ImportEntityMapping>> findBySource(ImportSource source);

  Future<ImportEntityMapping?> find({
    required ImportSource source,
    required ImportEntityKind entityKind,
    required String sourceEntityKey,
  });

  Future<void> upsert(ImportEntityMapping mapping);
}
