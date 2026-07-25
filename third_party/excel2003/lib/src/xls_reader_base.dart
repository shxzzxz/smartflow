import 'dart:io';
import 'dart:typed_data';

import 'ole2/ole2_reader.dart';
import 'biff/biff_records.dart';
import 'biff/sst_parser.dart';
import 'biff/cell_parser.dart';

/// A lightweight Dart library for reading legacy Excel `.xls` files.
///
/// This library parses BIFF8 format (Excel 97-2003) stored in OLE2 compound
/// documents. It supports reading cell values including strings, numbers,
/// booleans, and formulas.
///
/// Example usage:
/// ```dart
/// final reader = XlsReader('path/to/book.xls');
/// reader.open();
///
/// print('Sheet count: ${reader.sheetCount}');
///
/// for (int i = 0; i < reader.sheetCount; i++) {
///   final sheet = reader.sheet(i);
///   print('Sheet "${sheet.name}": ${sheet.rowCount} rows, ${sheet.colCount} cols');
///
///   for (int r = 0; r < sheet.rowCount; r++) {
///     for (int c = 0; c < sheet.colCount; c++) {
///       final value = sheet.cell(r, c);
///       if (value != null) {
///         print('Cell($r, $c): $value');
///       }
///     }
///   }
/// }
/// ```

class XlsReader {
  final String path;

  final Ole2Reader _ole2 = Ole2Reader();
  final SstParser _sst = SstParser();
  final List<_SheetInfo> _sheets = [];
  late Uint8List _workbookStream;
  bool _opened = false;

  XlsReader(this.path);

  /// Creates an XlsReader from bytes.
  factory XlsReader.fromBytes(Uint8List bytes) {
    final reader = XlsReader('');
    reader._openBytes(bytes);
    return reader;
  }

  /// Opens and parses the workbook.
  void open() {
    if (_opened) return;

    if (!File(path).existsSync()) {
      throw ArgumentError('File not found: $path');
    }

    _ole2.open(path);
    _parseWorkbook();
    _opened = true;
  }

  void _openBytes(Uint8List bytes) {
    if (_opened) return;

    _ole2.openBytes(bytes);
    _parseWorkbook();
    _opened = true;
  }

  void _parseWorkbook() {
    // Find the Workbook stream
    final workbookEntry =
        _ole2.findEntry('Workbook') ?? _ole2.findEntry('Book'); // Older format

    if (workbookEntry == null) {
      throw FormatException('No Workbook stream found in the file');
    }

    _workbookStream = _ole2.readEntry(workbookEntry);

    // Parse workbook globals to get sheet info and SST
    final parser = BiffParser(_workbookStream);

    while (parser.hasMore) {
      final record = parser.nextRecordWithContinue();
      if (record == null) break;

      switch (record.type) {
        case BiffRecordType.boundSheet:
          _sheets.add(_SheetInfo.fromRecord(record));
          break;
        case BiffRecordType.sst:
          _sst.parse(record);
          break;
        case BiffRecordType.eof:
          // End of workbook globals, exit the loop
          return;
      }
    }
  }

  /// Returns the number of sheets in the workbook.
  int get sheetCount => _sheets.length;

  /// Returns the names of all sheets.
  List<String> get sheetNames => _sheets.map((s) => s.name).toList();

  /// Returns a sheet by index.
  XlsSheet sheet(int index) {
    if (index < 0 || index >= _sheets.length) {
      throw RangeError('Sheet index out of range: $index');
    }

    final sheetInfo = _sheets[index];
    return _parseSheet(sheetInfo);
  }

  /// Returns a sheet by name.
  XlsSheet? sheetByName(String name) {
    final index = _sheets.indexWhere(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
    );
    if (index < 0) return null;
    return sheet(index);
  }

  XlsSheet _parseSheet(sheetInfo) {
    final sheet = XlsSheet._internal(sheetInfo.name);
    final cellParser = CellParser(_sst);

    // Seek to sheet BOF position
    final parser = BiffParser(_workbookStream);
    parser.seek(sheetInfo.bofPosition);

    String? pendingString; // For STRING records following FORMULA

    while (parser.hasMore) {
      final record = parser.nextRecord();
      if (record == null) break;

      switch (record.type) {
        case BiffRecordType.dimension:
          final dim = DimensionRecord.fromRecord(record);
          sheet._firstRow = dim.firstRow;
          sheet._lastRow = dim.lastRow;
          sheet._firstCol = dim.firstCol;
          sheet._lastCol = dim.lastCol;
          break;

        case BiffRecordType.number:
          final cell = cellParser.parseNumber(record);
          if (cell != null) sheet._addCell(cell);
          break;

        case BiffRecordType.labelSst:
          final cell = cellParser.parseLabelSst(record);
          if (cell != null) sheet._addCell(cell);
          break;

        case BiffRecordType.rk:
          final cell = cellParser.parseRk(record);
          if (cell != null) sheet._addCell(cell);
          break;

        case BiffRecordType.mulRk:
          final cells = cellParser.parseMulRk(record);
          for (final cell in cells) {
            sheet._addCell(cell);
          }
          break;

        case BiffRecordType.blank:
          final cell = cellParser.parseBlank(record);
          if (cell != null) sheet._addCell(cell);
          break;

        case BiffRecordType.mulBlank:
          final cells = cellParser.parseMulBlank(record);
          for (final cell in cells) {
            sheet._addCell(cell);
          }
          break;

        case BiffRecordType.boolErr:
          final cell = cellParser.parseBoolErr(record);
          if (cell != null) sheet._addCell(cell);
          break;

        case BiffRecordType.formula:
          final cell = cellParser.parseFormula(record, pendingString);
          if (cell != null) sheet._addCell(cell);
          pendingString = null;
          break;

        case BiffRecordType.string:
          // String value following a FORMULA record
          if (record.data.length >= 3) {
            final result = BiffStringReader.readString(record.data, 0);
            pendingString = result.value;
          }
          break;

        case BiffRecordType.label:
          final cell = cellParser.parseLabel(record);
          if (cell != null) sheet._addCell(cell);
          break;

        case BiffRecordType.eof:
          // End of sheet
          return sheet;
      }
    }

    return sheet;
  }
}

/// Represents a worksheet in an Excel workbook.
class XlsSheet {
  final String name;

  int _firstRow = 0;
  int _lastRow = 0;
  int _firstCol = 0;
  int _lastCol = 0;

  // Sparse cell storage: Map<row, Map<col, cell>>
  final Map<int, Map<int, XlsCell>> _cells = {};

  XlsSheet._internal(this.name);

  /// Number of rows with data.
  int get rowCount => _lastRow - _firstRow;

  /// Number of columns with data.
  int get colCount => _lastCol - _firstCol;

  /// First row index.
  int get firstRow => _firstRow;

  /// Last row index (exclusive).
  int get lastRow => _lastRow;

  /// First column index.
  int get firstCol => _firstCol;

  /// Last column index (exclusive).
  int get lastCol => _lastCol;

  void _addCell(XlsCell cell) {
    _cells.putIfAbsent(cell.row, () => {});
    _cells[cell.row]![cell.col] = cell;
  }

  /// Gets the cell at the specified row and column.
  /// Returns null if the cell is empty or doesn't exist.
  XlsCell? getCell(int row, int col) {
    return _cells[row]?[col];
  }

  /// Gets the cell value at the specified row and column.
  /// Returns null if the cell is empty or doesn't exist.
  dynamic cell(int row, int col) {
    return _cells[row]?[col]?.value;
  }

  /// Gets a row as a list of cell values.
  List<dynamic> row(int rowIndex) {
    final result = <dynamic>[];
    for (int c = _firstCol; c < _lastCol; c++) {
      result.add(cell(rowIndex, c));
    }
    return result;
  }

  /// Gets a column as a list of cell values.
  List<dynamic> column(int colIndex) {
    final result = <dynamic>[];
    for (int r = _firstRow; r < _lastRow; r++) {
      result.add(cell(r, colIndex));
    }
    return result;
  }

  /// Gets all rows as a 2D list.
  List<List<dynamic>> get rows {
    final result = <List<dynamic>>[];
    for (int r = _firstRow; r < _lastRow; r++) {
      result.add(row(r));
    }
    return result;
  }

  /// Iterates over all non-empty cells.
  Iterable<XlsCell> get cells sync* {
    for (final rowMap in _cells.values) {
      for (final cell in rowMap.values) {
        if (cell.type != CellType.empty) {
          yield cell;
        }
      }
    }
  }

  /// Converts the sheet to a list of maps (each row as a map).
  /// Uses the first row as headers.
  List<Map<String, dynamic>> toMaps() {
    if (_lastRow <= _firstRow) return [];

    // Get headers from first row
    final headers = <String>[];
    for (int c = _firstCol; c < _lastCol; c++) {
      final value = cell(_firstRow, c);
      headers.add(value?.toString() ?? 'Column$c');
    }

    // Convert remaining rows to maps
    final result = <Map<String, dynamic>>[];
    for (int r = _firstRow + 1; r < _lastRow; r++) {
      final map = <String, dynamic>{};
      for (int c = 0; c < headers.length; c++) {
        map[headers[c]] = cell(r, _firstCol + c);
      }
      result.add(map);
    }

    return result;
  }

  @override
  String toString() => 'XlsSheet("$name", rows: $rowCount, cols: $colCount)';
}

/// Internal class to hold sheet information from BOUNDSHEET record.
class _SheetInfo {
  final String name;
  final int bofPosition;
  final int visibility;
  final int type;

  _SheetInfo({
    required this.name,
    required this.bofPosition,
    required this.visibility,
    required this.type,
  });

  factory _SheetInfo.fromRecord(BiffRecord record) {
    final boundSheet = BoundSheetRecord.fromRecord(record);
    return _SheetInfo(
      name: boundSheet.name,
      bofPosition: boundSheet.bofPosition,
      visibility: boundSheet.visibility,
      type: boundSheet.type,
    );
  }
}
