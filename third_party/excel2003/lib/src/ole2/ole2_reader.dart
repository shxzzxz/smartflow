import 'dart:io';
import 'dart:typed_data';

/// OLE2 Compound Document Format Reader
///
/// This class parses the OLE2/Compound Document File format used by
/// Microsoft Office applications including Excel 97-2003 (.xls).
class Ole2Reader {
  static const int _headerSize = 512;
  // magic bytes for OLE2 headers
  static const List<int> _magicBytes = [
    0xD0,
    0xCF,
    0x11,
    0xE0,
    0xA1,
    0xB1,
    0x1A,
    0xE1,
  ];

  late Uint8List _data;
  late int _sectorSize;
  late int _miniSectorSize;
  late int _firstDirectorySector;
  late int _firstMiniFatSector;
  late int _firstDifatSector;
  late int _difatSectorCount;
  late int _miniStreamCutoffSize;

  late List<int> _fat; // File Allocation Table
  late List<int> _miniFat; // Mini FAT
  late List<DirectoryEntry> _directory;
  late Uint8List _miniStream;

  Ole2Reader();

  /// Opens and parses an OLE2 compound document file.
  void open(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw ArgumentError('File not found: $path');
    }
    _data = file.readAsBytesSync();
    _parseHeader();
    _buildFat();
    _buildMiniFat();
    _parseDirectory();
    _buildMiniStream();
  }

  /// Opens and parses OLE2 data from bytes.
  void openBytes(Uint8List bytes) {
    _data = bytes;
    _parseHeader();
    _buildFat();
    _buildMiniFat();
    _parseDirectory();
    _buildMiniStream();
  }

  void _parseHeader() {
    // Verify magic number
    for (int i = 0; i < 8; i++) {
      if (_data[i] != _magicBytes[i]) {
        throw FormatException('Not a valid OLE2 compound document');
      }
    }

    // Read header fields
    // ignore version fields, just consume them
    _readUint16(24); // minor version
    _readUint16(26); // major version
    final byteOrder = _readUint16(28);

    if (byteOrder != 0xFFFE) {
      throw FormatException('Unsupported byte order: $byteOrder');
    }

    final sectorSizeExponent = _readUint16(30);
    final miniSectorSizeExponent = _readUint16(32);

    _sectorSize = 1 << sectorSizeExponent;
    _miniSectorSize = 1 << miniSectorSizeExponent;

    _firstDirectorySector = _readUint32(48);
    _miniStreamCutoffSize = _readUint32(56);
    _firstMiniFatSector = _readUint32(60);
    _firstDifatSector = _readUint32(68);
    _difatSectorCount = _readUint32(72);
  }

  void _buildFat() {
    _fat = [];

    // Read DIFAT entries from header (first 109 entries)
    List<int> difatSectors = [];
    for (int i = 0; i < 109; i++) {
      final sector = _readUint32(76 + i * 4);
      if (sector != 0xFFFFFFFE && sector != 0xFFFFFFFF) {
        difatSectors.add(sector);
      }
    }

    // Read additional DIFAT sectors if needed
    if (_difatSectorCount > 0 && _firstDifatSector != 0xFFFFFFFE) {
      int difatSector = _firstDifatSector;
      for (int i = 0; i < _difatSectorCount; i++) {
        final sectorData = _readSector(difatSector);
        final entriesPerSector = (_sectorSize ~/ 4) - 1;
        for (int j = 0; j < entriesPerSector; j++) {
          final sector = _readUint32InBytes(sectorData, j * 4);
          if (sector != 0xFFFFFFFE && sector != 0xFFFFFFFF) {
            difatSectors.add(sector);
          }
        }
        difatSector = _readUint32InBytes(sectorData, _sectorSize - 4);
        if (difatSector == 0xFFFFFFFE) break;
      }
    }

    // Read FAT from DIFAT sectors
    for (final fatSector in difatSectors) {
      final sectorData = _readSector(fatSector);
      for (int i = 0; i < _sectorSize ~/ 4; i++) {
        _fat.add(_readUint32InBytes(sectorData, i * 4));
      }
    }
  }

  void _buildMiniFat() {
    _miniFat = [];
    if (_firstMiniFatSector == 0xFFFFFFFE) return;

    int sector = _firstMiniFatSector;
    while (sector != 0xFFFFFFFE && sector != 0xFFFFFFFF) {
      final sectorData = _readSector(sector);
      for (int i = 0; i < _sectorSize ~/ 4; i++) {
        _miniFat.add(_readUint32InBytes(sectorData, i * 4));
      }
      if (sector < _fat.length) {
        sector = _fat[sector];
      } else {
        break;
      }
    }
  }

  void _parseDirectory() {
    _directory = [];
    if (_firstDirectorySector == 0xFFFFFFFE) return;

    final dirStream = readStream(_firstDirectorySector);
    final entrySize = 128;
    final entryCount = dirStream.length ~/ entrySize;

    for (int i = 0; i < entryCount; i++) {
      final offset = i * entrySize;
      final entry = DirectoryEntry._parse(dirStream, offset);
      if (entry.type != DirectoryEntryType.empty) {
        _directory.add(entry);
      }
    }
  }

  void _buildMiniStream() {
    _miniStream = Uint8List(0);
    if (_directory.isEmpty) return;

    // Root entry contains the mini stream
    final root = _directory.firstWhere(
      (e) => e.type == DirectoryEntryType.rootStorage,
      orElse: () => _directory[0],
    );

    if (root.startSector != 0xFFFFFFFE && root.size > 0) {
      _miniStream = readStream(root.startSector, expectedSize: root.size);
    }
  }

  Uint8List _readSector(int sectorIndex) {
    final offset = _headerSize + sectorIndex * _sectorSize;
    if (offset + _sectorSize > _data.length) {
      return Uint8List(_sectorSize);
    }
    return Uint8List.sublistView(_data, offset, offset + _sectorSize);
  }

  Uint8List _readMiniSector(int sectorIndex) {
    final offset = sectorIndex * _miniSectorSize;
    if (offset + _miniSectorSize > _miniStream.length) {
      return Uint8List(_miniSectorSize);
    }
    return Uint8List.sublistView(_miniStream, offset, offset + _miniSectorSize);
  }

  /// Reads a stream starting from the given sector.
  Uint8List readStream(int startSector, {int? expectedSize}) {
    if (startSector == 0xFFFFFFFE || startSector == 0xFFFFFFFF) {
      return Uint8List(0);
    }

    List<int> bytes = [];
    int sector = startSector;

    while (sector != 0xFFFFFFFE && sector != 0xFFFFFFFF) {
      final sectorData = _readSector(sector);
      bytes.addAll(sectorData);
      if (sector < _fat.length) {
        sector = _fat[sector];
      } else {
        break;
      }
    }

    final result = Uint8List.fromList(bytes);
    if (expectedSize != null && expectedSize < result.length) {
      return Uint8List.sublistView(result, 0, expectedSize);
    }
    return result;
  }

  /// Reads a mini stream starting from the given mini sector.
  Uint8List readMiniStream(int startSector, int size) {
    if (startSector == 0xFFFFFFFE || startSector == 0xFFFFFFFF) {
      return Uint8List(0);
    }

    List<int> bytes = [];
    int sector = startSector;

    while (sector != 0xFFFFFFFE &&
        sector != 0xFFFFFFFF &&
        bytes.length < size) {
      final sectorData = _readMiniSector(sector);
      bytes.addAll(sectorData);
      if (sector < _miniFat.length) {
        sector = _miniFat[sector];
      } else {
        break;
      }
    }

    final result = Uint8List.fromList(bytes);
    if (size < result.length) {
      return Uint8List.sublistView(result, 0, size);
    }
    return result;
  }

  /// Returns all directory entries.
  List<DirectoryEntry> get entries => _directory;

  /// Finds a directory entry by name.
  DirectoryEntry? findEntry(String name) {
    return _directory.cast<DirectoryEntry?>().firstWhere(
      (e) => e?.name.toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );
  }

  /// Reads the content of a directory entry.
  Uint8List readEntry(DirectoryEntry entry) {
    // Use mini stream only if it exists and entry is small enough
    if (entry.size < _miniStreamCutoffSize &&
        entry.type != DirectoryEntryType.rootStorage &&
        _miniStream.isNotEmpty) {
      return readMiniStream(entry.startSector, entry.size);
    }
    return readStream(entry.startSector, expectedSize: entry.size);
  }

  int _readUint16(int offset) {
    return _data[offset] | (_data[offset + 1] << 8);
  }

  int _readUint32(int offset) {
    return _data[offset] |
        (_data[offset + 1] << 8) |
        (_data[offset + 2] << 16) |
        (_data[offset + 3] << 24);
  }

  int _readUint32InBytes(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0xFFFFFFFE;
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }
}

/// Directory entry type
enum DirectoryEntryType { empty, storage, stream, rootStorage, unknown }

/// Represents a directory entry in the OLE2 compound document.
class DirectoryEntry {
  final String name;
  final DirectoryEntryType type;
  final int startSector;
  final int size;

  DirectoryEntry({
    required this.name,
    required this.type,
    required this.startSector,
    required this.size,
  });

  factory DirectoryEntry._parse(Uint8List data, int offset) {
    // Read name (64 bytes, UTF-16LE)
    final nameSize = data[offset + 64] | (data[offset + 65] << 8);
    final nameBytes = nameSize > 2 ? nameSize - 2 : 0;
    final nameChars = <int>[];
    for (int i = 0; i < nameBytes ~/ 2; i++) {
      final char = data[offset + i * 2] | (data[offset + i * 2 + 1] << 8);
      if (char != 0) nameChars.add(char);
    }
    final name = String.fromCharCodes(nameChars);

    // Read type
    final typeValue = data[offset + 66];
    DirectoryEntryType type;
    switch (typeValue) {
      case 0:
        type = DirectoryEntryType.empty;
        break;
      case 1:
        type = DirectoryEntryType.storage;
        break;
      case 2:
        type = DirectoryEntryType.stream;
        break;
      case 5:
        type = DirectoryEntryType.rootStorage;
        break;
      default:
        type = DirectoryEntryType.unknown;
    }

    // Read start sector (4 bytes at offset 116)
    final startSector =
        data[offset + 116] |
        (data[offset + 117] << 8) |
        (data[offset + 118] << 16) |
        (data[offset + 119] << 24);

    // Read size (4 bytes at offset 120)
    final size =
        data[offset + 120] |
        (data[offset + 121] << 8) |
        (data[offset + 122] << 16) |
        (data[offset + 123] << 24);

    return DirectoryEntry(
      name: name,
      type: type,
      startSector: startSector,
      size: size,
    );
  }

  @override
  String toString() => 'DirectoryEntry(name: $name, type: $type, size: $size)';
}
