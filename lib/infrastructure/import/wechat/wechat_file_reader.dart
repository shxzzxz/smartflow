import 'package:excel_community/excel_community.dart';

import '../../../domain/import/import_models.dart';
import '../../../domain/import/port/import_file_reader.dart';

/// Decodes a WeChat XLSX bill and locates its table after the preamble.
class WechatFileReader implements ImportFileReader {
  const WechatFileReader();

  static const _requiredHeaders = {
    '交易时间',
    '交易类型',
    '交易对方',
    '商品',
    '收/支',
    '金额(元)',
    '支付方式',
    '当前状态',
    '交易单号',
    '商户单号',
    '备注',
  };

  @override
  ImportTabularFile read(ImportFilePayload file) {
    if (_extension(file.name) != '.xlsx') {
      throw ImportFileReadException.unsupportedFormat(file.name);
    }
    try {
      final workbook = Excel.decodeBytes(file.bytes);
      for (final entry in workbook.tables.entries) {
        final sheet = _findTransactionSheet(entry.key, entry.value);
        if (sheet != null) {
          return ImportTabularFile(sheets: [sheet]);
        }
      }
      return ImportTabularFile(
        sheets: [ImportTabularSheet(name: '微信支付账单', headers: [], rows: [])],
      );
    } on ImportFileReadException {
      rethrow;
    } catch (error, stackTrace) {
      throw ImportFileReadException.decodeFailed(file.name, error, stackTrace);
    }
  }

  ImportTabularSheet? _findTransactionSheet(String name, Sheet sheet) {
    final sourceRows = sheet.rows;
    final headerIndex = sourceRows.indexWhere(
      (row) => _requiredHeaders.every(
        (header) => row.any(
          (cell) => _cellValue(cell?.value)?.toString().trim() == header,
        ),
      ),
    );
    if (headerIndex < 0) return null;

    final headerRow = sourceRows[headerIndex];
    final columns = <({int index, String name})>[
      for (var index = 0; index < headerRow.length; index++)
        if (_cellValue(headerRow[index]?.value) case final value?)
          if (value.toString().trim() case final label when label.isNotEmpty)
            (index: index, name: label),
    ];
    final rows = <Map<String, Object?>>[];
    for (final sourceRow in sourceRows.skip(headerIndex + 1)) {
      rows.add({
        for (final column in columns)
          column.name: column.index < sourceRow.length
              ? _cellValue(sourceRow[column.index]?.value)
              : null,
      });
    }
    return ImportTabularSheet(
      name: name,
      headers: [for (final column in columns) column.name],
      rows: rows,
    );
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

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    return fileName.substring(dot).trim().toLowerCase();
  }
}
