import 'dart:typed_data';

import 'biff_records.dart';

/// Shared String Table (SST) parser.
///
/// The SST contains all unique strings used in the workbook.
/// Cells reference strings by their index in this table.
class SstParser {
  final List<String> _strings = [];

  /// Parses the SST record data.
  void parse(BiffRecord record) {
    final data = record.data;
    if (data.length < 8) return;

    // First 8 bytes: total string count and unique string count
    // final totalStrings = _readUint32(data, 0);
    final uniqueStrings = _readUint32(data, 4);
    final boundaries = record.continueOffsets;

    int offset = 8;
    int stringsParsed = 0;

    while (offset < data.length && stringsParsed < uniqueStrings) {
      final result = _readUnicodeString(data, offset, boundaries);
      _strings.add(result.value);
      if (result.bytesRead <= 0) break;
      offset += result.bytesRead;
      stringsParsed++;
    }
  }

  /// Gets a string by index.
  String? getString(int index) {
    if (index < 0 || index >= _strings.length) return null;
    return _strings[index];
  }

  /// Gets all strings.
  List<String> get strings => List.unmodifiable(_strings);

  /// Number of strings in the table.
  int get count => _strings.length;

  _StringReadResult _readUnicodeString(
    Uint8List data,
    int offset,
    List<int> boundaries,
  ) {
    if (offset + 3 > data.length) {
      return _StringReadResult('', data.length - offset);
    }

    // Read character count (2 bytes)
    final charCount = data[offset] | (data[offset + 1] << 8);

    // Read option flags (1 byte)
    final optionFlags = data[offset + 2];
    bool isUnicode = (optionFlags & 0x01) != 0;
    final hasExtString = (optionFlags & 0x04) != 0;
    final hasRichText = (optionFlags & 0x08) != 0;

    int pos = offset + 3;

    // Read rich text run count if present
    int richTextRuns = 0;
    if (hasRichText) {
      if (pos + 2 > data.length) {
        return _StringReadResult('', data.length - offset);
      }
      richTextRuns = data[pos] | (data[pos + 1] << 8);
      pos += 2;
    }

    // Read extended string size if present
    int extStringSize = 0;
    if (hasExtString) {
      if (pos + 4 > data.length) {
        return _StringReadResult('', data.length - offset);
      }
      extStringSize = _readUint32(data, pos);
      pos += 4;
    }

    // Read the character data. Strings may span CONTINUE record
    // boundaries; each continued fragment restarts with a fresh
    // option-flags byte whose low bit selects the encoding of that
    // fragment (it can switch between compressed and UTF-16LE).
    final chars = <int>[];
    int remaining = charCount;
    while (remaining > 0 && pos < data.length) {
      if (boundaries.contains(pos)) {
        isUnicode = (data[pos] & 0x01) != 0;
        pos += 1;
        continue;
      }
      final nextBoundary = _nextBoundary(boundaries, pos, data.length);
      if (isUnicode) {
        final available = (nextBoundary - pos) ~/ 2;
        final take = available < remaining ? available : remaining;
        for (int i = 0; i < take; i++) {
          chars.add(data[pos] | (data[pos + 1] << 8));
          pos += 2;
        }
        remaining -= take;
        if (remaining > 0 && pos < nextBoundary) {
          // Odd trailing byte before the boundary cannot happen for a
          // well-formed file; skip it to stay aligned with the boundary.
          pos = nextBoundary;
        }
      } else {
        final available = nextBoundary - pos;
        final take = available < remaining ? available : remaining;
        for (int i = 0; i < take; i++) {
          chars.add(data[pos]);
          pos += 1;
        }
        remaining -= take;
      }
      if (remaining > 0 && pos >= data.length) break;
    }
    final value = String.fromCharCodes(chars);

    // Skip rich text formatting runs
    pos += richTextRuns * 4;

    // Skip extended string data
    pos += extStringSize;

    // Ensure we don't exceed the data length
    if (pos > data.length) pos = data.length;

    return _StringReadResult(value, pos - offset);
  }

  int _nextBoundary(List<int> boundaries, int pos, int dataLength) {
    for (final boundary in boundaries) {
      if (boundary > pos) return boundary;
    }
    return dataLength;
  }

  int _readUint32(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }
}

class _StringReadResult {
  final String value;
  final int bytesRead;

  _StringReadResult(this.value, this.bytesRead);
}

/// Utility for reading Unicode strings from BIFF records.
class BiffStringReader {
  /// Reads a Unicode string from a BIFF record at the given offset.
  static StringReadResult readString(Uint8List data, int offset) {
    if (offset + 3 > data.length) {
      return StringReadResult('', 0);
    }

    final charCount = data[offset] | (data[offset + 1] << 8);
    final optionFlags = data[offset + 2];
    final isUnicode = (optionFlags & 0x01) != 0;

    int pos = offset + 3;

    String value;
    if (isUnicode) {
      final chars = <int>[];
      for (int i = 0; i < charCount && pos + 2 <= data.length; i++) {
        chars.add(data[pos] | (data[pos + 1] << 8));
        pos += 2;
      }
      value = String.fromCharCodes(chars);
    } else {
      final endPos =
          pos + charCount > data.length ? data.length : pos + charCount;
      value = String.fromCharCodes(data.sublist(pos, endPos));
      pos = endPos;
    }

    return StringReadResult(value, pos - offset);
  }

  /// Reads a byte string (non-Unicode) from a BIFF record.
  static String readByteString(Uint8List data, int offset, int length) {
    if (offset + length > data.length) {
      length = data.length - offset;
    }
    return String.fromCharCodes(data.sublist(offset, offset + length));
  }
}

/// Result of reading a string from BIFF data.
class StringReadResult {
  final String value;
  final int bytesRead;

  StringReadResult(this.value, this.bytesRead);
}
