import 'dart:convert';

import 'package:chinese_codec/chinese_codec.dart';
import 'package:csv/csv.dart';

import '../../../domain/import/import_models.dart';
import '../../../domain/import/port/import_file_reader.dart';

/// Decodes JD CSV exports and locates the transaction header after the preamble.
class JdFileReader implements ImportFileReader {
  const JdFileReader();

  static const _requiredHeaders = {
    '交易时间',
    '商户名称',
    '交易说明',
    '金额',
    '收/付款方式',
    '交易状态',
    '收/支',
    '交易分类',
    '交易订单号',
    '商家订单号',
    '备注',
  };

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
              name: '京东商城交易流水',
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
            name: '京东商城交易流水',
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
    final values = row
        .map((value) => value?.toString().trim() ?? '')
        .where((text) => text.isNotEmpty)
        .toSet();
    return values.containsAll(_requiredHeaders);
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
