import 'dart:typed_data';

import 'biff_records.dart';
import 'sst_parser.dart';

/// Represents a cell value type.
enum CellType { empty, string, number, boolean, error, formula }

/// Represents a cell in a worksheet.
class XlsCell {
  final int row;
  final int col;
  final CellType type;
  final dynamic value;
  final int xfIndex; // Extended format index

  XlsCell({
    required this.row,
    required this.col,
    required this.type,
    required this.value,
    this.xfIndex = 0,
  });

  /// Returns the cell value as a string.
  String get stringValue {
    if (value == null) return '';
    return value.toString();
  }

  /// Returns the cell value as a number, or null if not a number.
  double? get numericValue {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  String toString() => 'Cell($row, $col): $value';
}

/// Parser for cell records in a worksheet.
class CellParser {
  final SstParser _sst;

  CellParser(this._sst);

  /// Parses a NUMBER record.
  XlsCell? parseNumber(BiffRecord record) {
    if (record.data.length < 14) return null;

    final row = record.readUint16(0);
    final col = record.readUint16(2);
    final xfIndex = record.readUint16(4);
    final value = record.readDouble(6);

    return XlsCell(
      row: row,
      col: col,
      type: CellType.number,
      value: value,
      xfIndex: xfIndex,
    );
  }

  /// Parses a LABELSST record (cell with SST string reference).
  XlsCell? parseLabelSst(BiffRecord record) {
    if (record.data.length < 10) return null;

    final row = record.readUint16(0);
    final col = record.readUint16(2);
    final xfIndex = record.readUint16(4);
    final sstIndex = record.readUint32(6);

    final value = _sst.getString(sstIndex) ?? '';

    return XlsCell(
      row: row,
      col: col,
      type: CellType.string,
      value: value,
      xfIndex: xfIndex,
    );
  }

  /// Parses an RK record (compressed number).
  XlsCell? parseRk(BiffRecord record) {
    if (record.data.length < 10) return null;

    final row = record.readUint16(0);
    final col = record.readUint16(2);
    final xfIndex = record.readUint16(4);
    final rkValue = record.readUint32(6);
    final value = _decodeRk(rkValue);

    return XlsCell(
      row: row,
      col: col,
      type: CellType.number,
      value: value,
      xfIndex: xfIndex,
    );
  }

  /// Parses a MULRK record (multiple RK numbers in a row).
  List<XlsCell> parseMulRk(BiffRecord record) {
    final cells = <XlsCell>[];
    if (record.data.length < 6) return cells;

    final row = record.readUint16(0);
    final firstCol = record.readUint16(2);

    // Each RK cell is 6 bytes (2 for XF index + 4 for RK value)
    // Last 2 bytes are the last column index
    final dataLen = record.data.length - 6; // Exclude header and last col
    final cellCount = dataLen ~/ 6;

    int offset = 4;
    for (int i = 0; i < cellCount; i++) {
      final xfIndex = record.readUint16(offset);
      final rkValue = record.readUint32(offset + 2);
      final value = _decodeRk(rkValue);

      cells.add(
        XlsCell(
          row: row,
          col: firstCol + i,
          type: CellType.number,
          value: value,
          xfIndex: xfIndex,
        ),
      );

      offset += 6;
    }

    return cells;
  }

  /// Parses a BLANK record.
  XlsCell? parseBlank(BiffRecord record) {
    if (record.data.length < 6) return null;

    final row = record.readUint16(0);
    final col = record.readUint16(2);
    final xfIndex = record.readUint16(4);

    return XlsCell(
      row: row,
      col: col,
      type: CellType.empty,
      value: null,
      xfIndex: xfIndex,
    );
  }

  /// Parses a MULBLANK record (multiple blank cells).
  List<XlsCell> parseMulBlank(BiffRecord record) {
    final cells = <XlsCell>[];
    if (record.data.length < 6) return cells;

    final row = record.readUint16(0);
    final firstCol = record.readUint16(2);
    final lastCol = record.readUint16(record.data.length - 2);

    // XF indices are 2 bytes each
    int offset = 4;
    for (
      int col = firstCol;
      col <= lastCol && offset + 2 <= record.data.length - 2;
      col++
    ) {
      final xfIndex = record.readUint16(offset);
      cells.add(
        XlsCell(
          row: row,
          col: col,
          type: CellType.empty,
          value: null,
          xfIndex: xfIndex,
        ),
      );
      offset += 2;
    }

    return cells;
  }

  /// Parses a BOOLERR record (boolean or error).
  XlsCell? parseBoolErr(BiffRecord record) {
    if (record.data.length < 8) return null;

    final row = record.readUint16(0);
    final col = record.readUint16(2);
    final xfIndex = record.readUint16(4);
    final value = record.data[6];
    final isError = record.data[7] == 1;

    if (isError) {
      return XlsCell(
        row: row,
        col: col,
        type: CellType.error,
        value: _decodeError(value),
        xfIndex: xfIndex,
      );
    } else {
      return XlsCell(
        row: row,
        col: col,
        type: CellType.boolean,
        value: value != 0,
        xfIndex: xfIndex,
      );
    }
  }

  /// Parses a FORMULA record.
  XlsCell? parseFormula(BiffRecord record, String? cachedString) {
    if (record.data.length < 20) return null;

    final row = record.readUint16(0);
    final col = record.readUint16(2);
    final xfIndex = record.readUint16(4);

    // Result value (8 bytes at offset 6)
    // If bytes 6-7 are 0xFFFF, it's a string, boolean, or error
    final resultType = record.readUint16(6);

    dynamic value;
    CellType type;

    if (resultType == 0xFFFF) {
      // Special value
      final specialType = record.data[8];
      switch (specialType) {
        case 0: // String - value is in following STRING record
          value = cachedString ?? '';
          type = CellType.string;
          break;
        case 1: // Boolean
          value = record.data[10] != 0;
          type = CellType.boolean;
          break;
        case 2: // Error
          value = _decodeError(record.data[10]);
          type = CellType.error;
          break;
        default:
          value = null;
          type = CellType.empty;
      }
    } else {
      // Floating point number
      value = record.readDouble(6);
      type = CellType.number;
    }

    return XlsCell(
      row: row,
      col: col,
      type: type,
      value: value,
      xfIndex: xfIndex,
    );
  }

  /// Parses a LABEL record (BIFF2-7 string cell).
  XlsCell? parseLabel(BiffRecord record) {
    if (record.data.length < 8) return null;

    final row = record.readUint16(0);
    final col = record.readUint16(2);
    final xfIndex = record.readUint16(4);

    // Read string
    final result = BiffStringReader.readString(record.data, 6);

    return XlsCell(
      row: row,
      col: col,
      type: CellType.string,
      value: result.value,
      xfIndex: xfIndex,
    );
  }

  /// Decodes an RK value to a double.
  double _decodeRk(int rkValue) {
    final isInteger = (rkValue & 0x02) != 0;
    final div100 = (rkValue & 0x01) != 0;

    double result;

    if (isInteger) {
      // Value is a 30-bit signed integer
      int intValue = rkValue >> 2;
      // Sign extend if negative
      if ((intValue & 0x20000000) != 0) {
        intValue |= 0xC0000000;
        intValue = intValue.toSigned(32);
      }
      result = intValue.toDouble();
    } else {
      // Value is the high 30 bits of a 64-bit IEEE float
      final bytes = ByteData(8);
      bytes.setUint32(4, rkValue & 0xFFFFFFFC, Endian.little);
      result = bytes.getFloat64(0, Endian.little);
    }

    if (div100) {
      result /= 100;
    }

    return result;
  }

  /// Decodes an error value.
  String _decodeError(int errorCode) {
    switch (errorCode) {
      case 0x00:
        return '#NULL!';
      case 0x07:
        return '#DIV/0!';
      case 0x0F:
        return '#VALUE!';
      case 0x17:
        return '#REF!';
      case 0x1D:
        return '#NAME?';
      case 0x24:
        return '#NUM!';
      case 0x2A:
        return '#N/A';
      default:
        return '#ERROR';
    }
  }
}
