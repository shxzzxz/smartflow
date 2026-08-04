import 'package:excel2003/excel2003.dart';

import '../../domain/import/import_models.dart';
import '../../domain/import/port/import_file_reader.dart';

/// Adapts legacy OLE/BIFF workbooks to the source-neutral tabular model.
class XlsFileReader implements ImportFileReader {
  const XlsFileReader();

  @override
  ImportTabularFile read(ImportFilePayload file) {
    try {
      final reader = XlsReader.fromBytes(file.bytes);
      final sheets = <ImportTabularSheet>[];
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
          ImportTabularSheet(
            name: sourceSheet.name,
            rows: rows,
            headers: headers,
          ),
        );
      }
      return ImportTabularFile(sheets: sheets);
    } catch (error, stackTrace) {
      throw ImportFileReadException.decodeFailed(file.name, error, stackTrace);
    }
  }
}
