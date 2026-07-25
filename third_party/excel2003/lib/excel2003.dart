/// A lightweight Dart library for reading legacy Excel (.xls) files.
///
/// This package provides a simple [XlsReader] class that can open and
/// iterate through worksheets in a BIFF8-format workbook (Excel 97-2003).
///
/// ## Features
///
/// - Read sheet names and navigate between sheets
/// - Access cell values by row/column index
/// - Support for various cell types: strings, numbers, booleans, errors
/// - Support for formulas (cached values)
/// - Sparse cell storage for efficiency
///
/// ## Usage
///
/// ```dart
/// import 'package:excel2003/excel2003.dart';
///
/// void main() {
///   final reader = XlsReader('path/to/workbook.xls');
///   reader.open();
///
///   // List all sheets
///   print('Sheets: ${reader.sheetNames}');
///
///   // Access first sheet
///   final sheet = reader.sheet(0);
///   print('Sheet "${sheet.name}": ${sheet.rowCount} rows');
///
///   // Read cell values
///   for (int row = sheet.firstRow; row < sheet.lastRow; row++) {
///     for (int col = sheet.firstCol; col < sheet.lastCol; col++) {
///       final value = sheet.cell(row, col);
///       if (value != null) {
///         print('Cell($row, $col) = $value');
///       }
///     }
///   }
///
///   // Or convert to maps using first row as headers
///   final data = sheet.toMaps();
///   for (final row in data) {
///     print(row);
///   }
/// }
/// ```

library;

export 'src/xls_reader_base.dart';
export 'src/biff/cell_parser.dart' show XlsCell, CellType;
