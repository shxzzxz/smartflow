import '../../domain/import/import_models.dart';

/// Source-aware file selection seam used by the import page.
abstract interface class ImportFilePicker {
  Future<ImportBundle?> pickBundle({required ImportSource source});
}
