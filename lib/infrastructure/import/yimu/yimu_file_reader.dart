import '../../../domain/import/import_models.dart';
import '../../../domain/import/port/import_file_reader.dart';
import '../tabular_file_readers.dart';

/// Yimu accepts CSV and XLSX files and treats the first row as headers.
class YimuFileReader implements ImportFileReader {
  YimuFileReader({
    ImportFileReader csvReader = const CsvFileReader(),
    ImportFileReader xlsxReader = const XlsxFileReader(),
  }) : _readers = {'.csv': csvReader, '.xlsx': xlsxReader};

  final Map<String, ImportFileReader> _readers;

  @override
  ImportTabularFile read(ImportFilePayload file) {
    final extension = _extension(file.name);
    final reader = _readers[extension];
    if (reader == null) {
      throw ImportFileReadException.unsupportedFormat(file.name);
    }
    try {
      return reader.read(file);
    } on ImportFileReadException {
      rethrow;
    } catch (error, stackTrace) {
      throw ImportFileReadException.decodeFailed(file.name, error, stackTrace);
    }
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    return fileName.substring(dot).trim().toLowerCase();
  }
}
