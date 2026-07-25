import 'dart:typed_data';

/// BIFF (Binary Interchange File Format) record types.
///
/// These are the record type identifiers used in Excel BIFF8 format.
class BiffRecordType {
  // Workbook globals
  static const int bof = 0x0809; // Beginning of File
  static const int eof = 0x000A; // End of File
  static const int boundSheet = 0x0085; // Sheet information
  static const int sst = 0x00FC; // Shared String Table
  static const int continueRec = 0x003C; // Continue record
  static const int dateMode = 0x0022; // Date system (1900 or 1904)
  static const int codePage = 0x0042; // Code page
  static const int format = 0x041E; // Number format
  static const int xf = 0x00E0; // Extended format
  static const int font = 0x0031; // Font record
  static const int palette = 0x0092; // Color palette
  static const int style = 0x0293; // Style record

  // Cell records
  static const int dimension = 0x0200; // Sheet dimensions
  static const int blank = 0x0201; // Empty cell
  static const int number = 0x0203; // Number cell
  static const int label = 0x0204; // String cell (BIFF2-7)
  static const int boolErr = 0x0205; // Boolean/Error cell
  static const int formula = 0x0006; // Formula cell
  static const int string = 0x0207; // String value of formula
  static const int row = 0x0208; // Row description
  static const int rk = 0x027E; // RK number
  static const int mulRk = 0x00BD; // Multiple RK numbers
  static const int mulBlank = 0x00BE; // Multiple blank cells
  static const int labelSst = 0x00FD; // Cell with SST index

  // Sheet structure
  static const int index = 0x020B; // Index record
  static const int dbCell = 0x00D7; // Stream offsets
  static const int defColWidth = 0x0055; // Default column width
  static const int colInfo = 0x007D; // Column information
  static const int window2 = 0x023E; // Sheet window settings
  static const int mergedCells = 0x00E5; // Merged cells
}

/// A single BIFF record.
class BiffRecord {
  final int type;
  final Uint8List data;
  final int offset;

  /// Offsets within [data] where each merged CONTINUE record's payload
  /// begins. BIFF8 strings split across CONTINUE records restart with a
  /// fresh option-flags byte at these positions, so parsers that decode
  /// strings from merged data need the original segment boundaries.
  final List<int> continueOffsets;

  BiffRecord({
    required this.type,
    required this.data,
    required this.offset,
    this.continueOffsets = const [],
  });

  int get length => data.length;

  /// Read a 16-bit unsigned integer from the record data.
  int readUint16(int offset) {
    if (offset + 2 > data.length) return 0;
    return data[offset] | (data[offset + 1] << 8);
  }

  /// Read a 32-bit unsigned integer from the record data.
  int readUint32(int offset) {
    if (offset + 4 > data.length) return 0;
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  /// Read a 64-bit floating point number from the record data.
  double readDouble(int offset) {
    if (offset + 8 > data.length) return 0.0;
    final bytes = ByteData.sublistView(data, offset, offset + 8);
    return bytes.getFloat64(0, Endian.little);
  }

  /// Read bytes from the record data.
  Uint8List readBytes(int offset, int length) {
    if (offset + length > data.length) {
      return Uint8List(length);
    }
    return Uint8List.sublistView(data, offset, offset + length);
  }

  @override
  String toString() =>
      'BiffRecord(type: 0x${type.toRadixString(16).padLeft(4, '0')}, length: $length)';
}

/// BIFF stream parser.
///
/// Parses BIFF records from the Excel Workbook stream.
class BiffParser {
  final Uint8List _data;
  int _position = 0;

  BiffParser(this._data);

  /// Whether there are more records to read.
  bool get hasMore => _position + 4 <= _data.length;

  /// Current position in the stream.
  int get position => _position;

  /// Reads the next BIFF record.
  ///
  /// Returns null if no more records are available.
  BiffRecord? nextRecord() {
    if (!hasMore) return null;

    final recordOffset = _position;
    final type = _readUint16();
    final length = _readUint16();

    if (_position + length > _data.length) {
      // Incomplete record at end of stream
      return null;
    }

    final data = Uint8List.sublistView(_data, _position, _position + length);
    _position += length;

    return BiffRecord(type: type, data: data, offset: recordOffset);
  }

  /// Reads a record and any following CONTINUE records.
  BiffRecord? nextRecordWithContinue() {
    final record = nextRecord();
    if (record == null) return null;

    // Check for CONTINUE records
    List<int> allData = record.data.toList();
    final continueOffsets = <int>[];

    while (hasMore) {
      final nextType = _peekUint16();

      if (nextType == BiffRecordType.continueRec) {
        final continueRecord = nextRecord();
        if (continueRecord != null) {
          continueOffsets.add(allData.length);
          allData.addAll(continueRecord.data);
        }
      } else {
        break;
      }
    }

    if (allData.length == record.data.length) {
      return record;
    }

    return BiffRecord(
      type: record.type,
      data: Uint8List.fromList(allData),
      offset: record.offset,
      continueOffsets: continueOffsets,
    );
  }

  /// Resets the parser to the beginning of the stream.
  void reset() {
    _position = 0;
  }

  /// Seeks to a specific position in the stream.
  void seek(int position) {
    _position = position;
  }

  int _readUint16() {
    final value = _data[_position] | (_data[_position + 1] << 8);
    _position += 2;
    return value;
  }

  int _peekUint16() {
    return _data[_position] | (_data[_position + 1] << 8);
  }
}

/// BOF (Beginning of File) record data.
class BofRecord {
  final int version;
  final int type; // 0x05 = Workbook globals, 0x10 = Sheet
  final int buildId;
  final int buildYear;

  BofRecord({
    required this.version,
    required this.type,
    required this.buildId,
    required this.buildYear,
  });

  factory BofRecord.fromRecord(BiffRecord record) {
    return BofRecord(
      version: record.readUint16(0),
      type: record.readUint16(2),
      buildId: record.readUint16(4),
      buildYear: record.readUint16(6),
    );
  }

  bool get isWorkbookGlobals => type == 0x0005;
  bool get isSheet => type == 0x0010;

  @override
  String toString() =>
      'BOF(version: 0x${version.toRadixString(16)}, type: 0x${type.toRadixString(16)})';
}

/// BOUNDSHEET record - contains information about a worksheet.
class BoundSheetRecord {
  final int bofPosition;
  final int visibility;
  final int type;
  final String name;

  BoundSheetRecord({
    required this.bofPosition,
    required this.visibility,
    required this.type,
    required this.name,
  });

  factory BoundSheetRecord.fromRecord(BiffRecord record) {
    final bofPosition = record.readUint32(0);
    final visibility = record.data[4];
    final type = record.data[5];

    // Read sheet name (byte string or Unicode string)
    final nameLength = record.data[6];
    final optionFlags = record.data[7];
    final isUnicode = (optionFlags & 0x01) != 0;

    String name;
    if (isUnicode) {
      final chars = <int>[];
      for (int i = 0; i < nameLength; i++) {
        chars.add(record.readUint16(8 + i * 2));
      }
      name = String.fromCharCodes(chars);
    } else {
      name = String.fromCharCodes(record.data.sublist(8, 8 + nameLength));
    }

    return BoundSheetRecord(
      bofPosition: bofPosition,
      visibility: visibility,
      type: type,
      name: name,
    );
  }

  bool get isVisible => visibility == 0;
  bool get isWorksheet => type == 0;

  @override
  String toString() => 'BoundSheet(name: $name, position: $bofPosition)';
}

/// DIMENSION record - contains the used range of a worksheet.
class DimensionRecord {
  final int firstRow;
  final int lastRow;
  final int firstCol;
  final int lastCol;

  DimensionRecord({
    required this.firstRow,
    required this.lastRow,
    required this.firstCol,
    required this.lastCol,
  });

  factory DimensionRecord.fromRecord(BiffRecord record) {
    return DimensionRecord(
      firstRow: record.readUint32(0),
      lastRow: record.readUint32(4),
      firstCol: record.readUint16(8),
      lastCol: record.readUint16(10),
    );
  }

  int get rowCount => lastRow - firstRow;
  int get colCount => lastCol - firstCol;

  @override
  String toString() =>
      'Dimension(rows: $firstRow-$lastRow, cols: $firstCol-$lastCol)';
}
