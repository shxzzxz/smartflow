import '../import_models.dart';

/// Source seam used by the import application layer.
///
/// A parser owns all file recognition and ParseUnit orchestration for one
/// external source. It is deterministic and side-effect free.
abstract interface class ImportSourceParser {
  ImportSource get source;

  ImportParseResult parse(ImportBundle bundle);
}
