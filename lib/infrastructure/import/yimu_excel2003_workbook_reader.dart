import 'package:excel2003/excel2003.dart';

import '../../domain/import/import_models.dart';
import '../../domain/import/port/yimu_workbook_reader.dart';

/// Infrastructure adapter for the legacy OLE/BIFF reader. No spreadsheet
/// package types escape this narrow seam.
class YimuExcel2003WorkbookReader implements YimuWorkbookReader {
  const YimuExcel2003WorkbookReader();

  @override
  YimuWorkbook read(ImportFilePayload file) {
    try {
      final reader = XlsReader.fromBytes(file.bytes);
      final sheets = <YimuSheet>[];
      for (var sheetIndex = 0; sheetIndex < reader.sheetCount; sheetIndex++) {
        final sourceSheet = reader.sheet(sheetIndex);
        final headers = <String>[];
        for (
          var column = sourceSheet.firstCol;
          column < sourceSheet.lastCol;
          column++
        ) {
          final value = sourceSheet.cell(sourceSheet.firstRow, column);
          final header = value?.toString().trim();
          headers.add(
            header == null || header.isEmpty ? 'Column$column' : header,
          );
        }

        final rows = <Map<String, Object?>>[];
        for (
          var rowIndex = sourceSheet.firstRow + 1;
          rowIndex < sourceSheet.lastRow;
          rowIndex++
        ) {
          final row = <String, Object?>{};
          for (var offset = 0; offset < headers.length; offset++) {
            row[headers[offset]] = sourceSheet.cell(
              rowIndex,
              sourceSheet.firstCol + offset,
            );
          }
          rows.add(row);
        }
        sheets.add(
          YimuSheet(name: sourceSheet.name, rows: rows, headers: headers),
        );
      }
      return YimuWorkbook(sheets: sheets);
    } catch (error, stackTrace) {
      throw YimuWorkbookReadException(file.name, error, stackTrace);
    }
  }
}

class YimuWorkbookReadException implements Exception {
  const YimuWorkbookReadException(this.fileName, this.cause, this.stackTrace);

  final String fileName;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'Unable to decode Yimu workbook "$fileName": $cause';
}
