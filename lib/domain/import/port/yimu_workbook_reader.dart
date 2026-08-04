import 'import_file_reader.dart';

export 'import_file_reader.dart';

/// Compatibility aliases for the first-release Yimu-specific reader seam.
/// New format adapters should implement [ImportFileReader] directly.
typedef YimuWorkbook = ImportTabularFile;
typedef YimuSheet = ImportTabularSheet;
typedef YimuWorkbookReader = ImportFileReader;
