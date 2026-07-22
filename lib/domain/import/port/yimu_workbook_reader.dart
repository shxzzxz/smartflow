import '../import_models.dart';

/// A decoded worksheet intentionally contains only values needed by the
/// source parser. File names and bytes never cross this seam into the parser's
/// business model.
class YimuWorkbook {
  YimuWorkbook({required Iterable<YimuSheet> sheets})
    : sheets = List.unmodifiable(sheets);

  final List<YimuSheet> sheets;
}

class YimuSheet {
  YimuSheet({
    required this.name,
    required Iterable<Map<String, Object?>> rows,
    Iterable<String>? headers,
  }) : rows = List.unmodifiable(
         rows.map((row) => Map<String, Object?>.unmodifiable(row)),
       ),
       headers = List.unmodifiable(headers ?? const <String>[]);

  final String name;
  final List<Map<String, Object?>> rows;
  final List<String> headers;
}

abstract interface class YimuWorkbookReader {
  YimuWorkbook read(ImportFilePayload file);
}
