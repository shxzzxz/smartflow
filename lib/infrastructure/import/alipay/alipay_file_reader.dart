import 'dart:convert';

import 'package:chinese_codec/chinese_codec.dart';
import 'package:csv/csv.dart';

import '../../../domain/import/import_models.dart';
import '../../../domain/import/port/import_file_reader.dart';

/// Decodes Alipay CSVs and locates the transaction header after the preamble.
class AlipayFileReader implements ImportFileReader {
  const AlipayFileReader();

  @override
  ImportTabularFile read(ImportFilePayload file) {
    if (_extension(file.name) != '.csv') {
      throw ImportFileReadException.unsupportedFormat(file.name);
    }
    try {
      final text = _stripBom(_decodeText(file.bytes));
      final rows = Csv().decode(text);
      final headerIndex = rows.indexWhere(_isTransactionHeader);
      if (headerIndex < 0) {
        return ImportTabularFile(
          sheets: [
            ImportTabularSheet(
              name: '支付宝交易明细',
              headers: const [],
              rows: const [],
            ),
          ],
        );
      }

      final headerCells = [
        for (final value in rows[headerIndex]) value?.toString().trim() ?? '',
      ];
      final columns = <({int index, String name})>[
        for (var index = 0; index < headerCells.length; index++)
          if (headerCells[index].isNotEmpty)
            (index: index, name: headerCells[index]),
      ];
      final dataRows = <Map<String, Object?>>[];
      for (final row in rows.skip(headerIndex + 1)) {
        dataRows.add({
          for (final column in columns)
            column.name: column.index < row.length ? row[column.index] : null,
        });
      }
      return ImportTabularFile(
        sheets: [
          ImportTabularSheet(
            name: '支付宝交易明细',
            headers: [for (final column in columns) column.name],
            rows: dataRows,
          ),
        ],
      );
    } on ImportFileReadException {
      rethrow;
    } catch (error, stackTrace) {
      throw ImportFileReadException.decodeFailed(file.name, error, stackTrace);
    }
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return gb18030.decode(bytes);
    }
  }

  bool _isTransactionHeader(List<dynamic> row) {
    return row.any((value) => value?.toString().trim() == '交易时间');
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    return fileName.substring(dot).trim().toLowerCase();
  }

  String _stripBom(String value) {
    return value.startsWith('\uFEFF') ? value.substring(1) : value;
  }
}
