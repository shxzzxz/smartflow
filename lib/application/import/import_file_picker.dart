import '../../domain/import/import_models.dart';

/// Platform-neutral file selection seam used by the import page.
abstract interface class ImportFilePicker {
  Future<ImportBundle?> pickYimuBundle();
}
