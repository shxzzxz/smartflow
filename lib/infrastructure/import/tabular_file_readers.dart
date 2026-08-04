import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel_community/excel_community.dart';

import '../../domain/import/import_models.dart';
import '../../domain/import/port/import_file_reader.dart';

/// Dispatches physical file formats without exposing decoder packages to the
/// source parser.
class ImportFileReaderRegistry implements ImportFileReader {
  ImportFileReaderRegistry({
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

class CsvFileReader implements ImportFileReader {
  const CsvFileReader();

  @override
  ImportTabularFile read(ImportFilePayload file) {
    try {
      final text = _decodeText(file.bytes);
      final rows = Csv().decode(_stripBom(text));
      if (rows.isEmpty) return ImportTabularFile(sheets: const []);

      final headers = _headers(rows.first);
      final dataRows = <Map<String, Object?>>[];
      for (var index = 1; index < rows.length; index++) {
        final values = rows[index];
        dataRows.add({
          for (var column = 0; column < headers.length; column++)
            headers[column]: column < values.length ? values[column] : null,
        });
      }
      return ImportTabularFile(
        sheets: [
          ImportTabularSheet(name: 'default', headers: headers, rows: dataRows),
        ],
      );
    } on ImportFileReadException {
      rethrow;
    } catch (error, stackTrace) {
      throw ImportFileReadException.decodeFailed(file.name, error, stackTrace);
    }
  }

  static String _decodeText(Uint8List bytes) {
    return utf8.decode(bytes);
  }

  static String _stripBom(String value) {
    return value.startsWith('\uFEFF') ? value.substring(1) : value;
  }

  static List<String> _headers(List<dynamic> row) {
    return [
      for (var index = 0; index < row.length; index++)
        _headerName(row[index], index),
    ];
  }
}

/// Adapts XLSX package values to the source-neutral tabular model.
class XlsxFileReader implements ImportFileReader {
  const XlsxFileReader();

  @override
  ImportTabularFile read(ImportFilePayload file) {
    try {
      final workbook = Excel.decodeBytes(file.bytes);
      return ImportTabularFile(
        sheets: [
          for (final entry in workbook.tables.entries)
            _readSheet(entry.key, entry.value),
        ],
      );
    } on ImportFileReadException {
      rethrow;
    } catch (error, stackTrace) {
      throw ImportFileReadException.decodeFailed(file.name, error, stackTrace);
    }
  }

  ImportTabularSheet _readSheet(String name, Sheet sheet) {
    final sourceRows = sheet.rows;
    if (sourceRows.isEmpty) {
      return ImportTabularSheet(name: name, headers: const [], rows: const []);
    }

    final headers = [
      for (var index = 0; index < sourceRows.first.length; index++)
        _headerName(_cellValue(sourceRows.first[index]?.value), index),
    ];
    final rows = <Map<String, Object?>>[];
    for (final sourceRow in sourceRows.skip(1)) {
      rows.add({
        for (var index = 0; index < headers.length; index++)
          headers[index]:
              index < sourceRow.length
                  ? _cellValue(sourceRow[index]?.value)
                  : null,
      });
    }
    return ImportTabularSheet(name: name, headers: headers, rows: rows);
  }

  Object? _cellValue(CellValue? value) {
    return switch (value) {
      null => null,
      TextCellValue value => value.value.toString(),
      IntCellValue value => value.value,
      DoubleCellValue value => value.value,
      BoolCellValue value => value.value,
      DateCellValue value => value.asDateTimeLocal(),
      DateTimeCellValue value => value.asDateTimeLocal(),
      TimeCellValue value => value.asDuration(),
      FormulaCellValue value => value.formula,
    };
  }
}

String _headerName(Object? value, int index) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? 'Column$index' : text;
}
