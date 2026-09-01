import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

typedef AppLogClock = DateTime Function();

class AppLogFileSink {
  AppLogFileSink({
    required this.directory,
    this.maxFileBytes = defaultMaxFileBytes,
    int maxFiles = defaultMaxFiles,
    Duration maxFileAge = defaultMaxFileAge,
    AppLogClock? clock,
  }) : _maxFiles = maxFiles,
       _maxFileAge = maxFileAge,
       _clock = clock ?? DateTime.now;

  static const int defaultMaxFileBytes = 1024 * 1024;
  static const int defaultMaxFiles = 100;
  static const int defaultMaxFileAgeDays = 14;
  static const Duration defaultMaxFileAge = Duration(
    days: defaultMaxFileAgeDays,
  );
  static const String currentFileName = 'smartflow.log';

  static final RegExp _newFilePattern = RegExp(
    r'^smartflow-(\d{8})(\d{3,})\.log$',
  );
  static final RegExp _legacyArchivePattern = RegExp(
    r'^smartflow-\d+(?:-\d+)?\.log$',
  );

  final Directory directory;
  final int maxFileBytes;
  int _maxFiles;
  Duration _maxFileAge;
  final AppLogClock _clock;
  File? _currentFile;
  Future<void> _writeQueue = Future<void>.value();

  int get maxFiles => _maxFiles;

  Duration get maxFileAge => _maxFileAge;

  /// 当前正在写入的文件；首次写入前返回当天的 001 文件路径。
  File get currentFile =>
      _currentFile ??
      File(_join(directory.path, _fileName(_localDate(_clock()), 1)));

  static bool isLogFileName(String name) {
    return name == currentFileName ||
        _newFilePattern.hasMatch(name) ||
        _legacyArchivePattern.hasMatch(name);
  }

  Future<void> initialize() async {
    await directory.create(recursive: true);
    _currentFile = await _findCurrentFile(_localDate(_clock()));
    await cleanup();
  }

  /// 更新保留上限并立即执行一次清理。
  Future<void> applyRetention({
    required int maxFiles,
    required Duration maxFileAge,
  }) async {
    _maxFiles = maxFiles;
    _maxFileAge = maxFileAge;
    await cleanup();
  }

  Future<void> write(LogRecord record) {
    final operation = _writeQueue.then((_) => _writeRecord(record));
    _writeQueue = operation.catchError((_) {});
    return operation;
  }

  Future<void> _writeRecord(LogRecord record) async {
    await directory.create(recursive: true);
    final line = '${jsonEncode(_toJson(record))}\n';
    final bytes = utf8.encode(line);
    final now = _localDate(_clock());

    if (_currentFile == null ||
        !await _currentFile!.exists() ||
        !_isNewFileForDate(_currentFile!, now)) {
      _currentFile =
          await _findCurrentFile(now) ??
          File(_join(directory.path, _fileName(now, 1)));
    }
    await _rotateIfNeeded(bytes.length, now);
    await currentFile.writeAsString(line, mode: FileMode.append, flush: true);
    await cleanup();
  }

  Future<void> cleanup() async {
    if (!await directory.exists()) return;

    final now = _clock();
    final files = await _logFiles();
    for (final info in files) {
      if (await _isExpired(info, now)) await _deleteIfExists(info.file);
    }

    final remaining = <_LogFileInfo>[];
    for (final info in await _logFiles()) {
      if (await info.file.exists()) remaining.add(info);
    }
    remaining.sort((a, b) => b.compareTo(a));

    for (final info in remaining.skip(_maxFiles)) {
      await _deleteIfExists(info.file);
    }
  }

  Future<void> _rotateIfNeeded(int nextWriteBytes, DateTime date) async {
    final file = currentFile;
    if (!await file.exists()) return;

    final length = await file.length();
    if (length == 0 || length + nextWriteBytes <= maxFileBytes) return;

    final sequence = _sequenceFromNewFileName(file.uri.pathSegments.last);
    var nextSequence = (sequence ?? 0) + 1;
    var nextFile = File(_join(directory.path, _fileName(date, nextSequence)));
    while (await nextFile.exists()) {
      nextSequence += 1;
      nextFile = File(_join(directory.path, _fileName(date, nextSequence)));
    }
    _currentFile = nextFile;
  }

  Future<File?> _findCurrentFile(DateTime date) async {
    final files = await _logFiles();
    var highestSequence = 0;
    File? current;
    for (final info in files) {
      if (info.date == null || !_sameDate(info.date!, date)) continue;
      final sequence = info.sequence;
      if (sequence != null && sequence > highestSequence) {
        highestSequence = sequence;
        current = info.file;
      }
    }
    return current;
  }

  Future<List<_LogFileInfo>> _logFiles() async {
    if (!await directory.exists()) return const [];
    final files = <_LogFileInfo>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!isLogFileName(name)) continue;
      final newMatch = _newFilePattern.firstMatch(name);
      if (newMatch != null) {
        files.add(
          _LogFileInfo(
            entity,
            date: _parseDate(newMatch.group(1)!),
            sequence: int.parse(newMatch.group(2)!),
          ),
        );
      } else {
        files.add(
          _LogFileInfo(entity, modified: (await entity.stat()).modified),
        );
      }
    }
    return files;
  }

  Future<bool> _isExpired(_LogFileInfo info, DateTime now) async {
    if (info.date != null) {
      final ageDays = _localDate(now).difference(info.date!).inDays;
      return ageDays >= _maxFileAge.inDays;
    }
    final modified = await info.file.stat();
    return !now.isBefore(modified.modified.add(_maxFileAge));
  }

  Map<String, Object?> _toJson(LogRecord record) {
    return {
      'time': record.time.toUtc().toIso8601String(),
      'level': record.level.name,
      'logger': record.loggerName,
      'message': record.message,
      if (record.error != null) 'error': record.error.toString(),
      if (record.stackTrace != null) 'stackTrace': record.stackTrace.toString(),
    };
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  bool _isNewFileForDate(File file, DateTime date) {
    final match = _newFilePattern.firstMatch(file.uri.pathSegments.last);
    return match != null && _sameDate(_parseDate(match.group(1)!), date);
  }

  int? _sequenceFromNewFileName(String name) {
    final match = _newFilePattern.firstMatch(name);
    return match == null ? null : int.parse(match.group(2)!);
  }
}

class _LogFileInfo {
  const _LogFileInfo(this.file, {this.date, this.sequence, this.modified});

  final File file;
  final DateTime? date;
  final int? sequence;
  final DateTime? modified;

  int compareTo(_LogFileInfo other) {
    final dateCompare = _sortDate.compareTo(other._sortDate);
    if (dateCompare != 0) return dateCompare;
    final sequenceCompare = (sequence ?? 0).compareTo(other.sequence ?? 0);
    if (sequenceCompare != 0) return sequenceCompare;
    return (modified ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      other.modified ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  DateTime get _sortDate =>
      _localDate(date ?? modified ?? DateTime.fromMillisecondsSinceEpoch(0));
}

DateTime _localDate(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _parseDate(String value) {
  return DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(4, 6)),
    int.parse(value.substring(6, 8)),
  );
}

String _fileName(DateTime date, int sequence) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final suffix = sequence.toString().padLeft(3, '0');
  return 'smartflow-$year$month$day$suffix.log';
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _join(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) return '$parent$child';
  return '$parent${Platform.pathSeparator}$child';
}
