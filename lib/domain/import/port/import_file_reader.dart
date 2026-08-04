import '../import_models.dart';

/// Physical file formats are decoded into this source-neutral representation.
/// The source parser only sees sheet names, headers, and scalar cell values;
/// no CSV/XLSX package types cross this seam.
class ImportTabularFile {
  ImportTabularFile({required Iterable<ImportTabularSheet> sheets})
    : sheets = List.unmodifiable(sheets);

  final List<ImportTabularSheet> sheets;
}

class ImportTabularSheet {
  ImportTabularSheet({
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

enum ImportFileReadFailure { unsupportedFormat, decodeFailed }

class ImportFileReadException implements Exception {
  const ImportFileReadException({
    required this.fileName,
    required this.failure,
    this.cause,
    this.stackTrace,
  });

  const ImportFileReadException.unsupportedFormat(String fileName)
    : this(
        fileName: fileName,
        failure: ImportFileReadFailure.unsupportedFormat,
      );

  const ImportFileReadException.decodeFailed(
    String fileName,
    Object cause,
    StackTrace stackTrace,
  ) : this(
        fileName: fileName,
        failure: ImportFileReadFailure.decodeFailed,
        cause: cause,
        stackTrace: stackTrace,
      );

  final String fileName;
  final ImportFileReadFailure failure;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Unable to read import file "$fileName": $failure';
}

abstract interface class ImportFileReader {
  ImportTabularFile read(ImportFilePayload file);
}
