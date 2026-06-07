import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

typedef AppLogClock = DateTime Function();

class AppLogFileSink {
  AppLogFileSink({
    required this.directory,
    this.maxFileBytes = defaultMaxFileBytes,
    this.maxFiles = defaultMaxFiles,
    this.maxFileAge = defaultMaxFileAge,
    AppLogClock? clock,
  }) : _clock = clock ?? DateTime.now;

  static const int defaultMaxFileBytes = 1024 * 1024;
  static const int defaultMaxFiles = 5;
  static const Duration defaultMaxFileAge = Duration(days: 14);
  static const String currentFileName = 'smartflow.log';

  final Directory directory;
  final int maxFileBytes;
  final int maxFiles;
  final Duration maxFileAge;
  final AppLogClock _clock;

  File get currentFile => File(_join(directory.path, currentFileName));

  Future<void> initialize() async {
    await directory.create(recursive: true);
    await cleanup();
  }

  Future<void> write(LogRecord record) async {
    await directory.create(recursive: true);
    final line = '${jsonEncode(_toJson(record))}\n';
    final bytes = utf8.encode(line);
    await _rotateIfNeeded(bytes.length);
    await currentFile.writeAsString(line, mode: FileMode.append, flush: true);
    await cleanup();
  }

  Future<void> cleanup() async {
    if (!await directory.exists()) return;

    final now = _clock();
    final files = await _logFiles();
    for (final file in files) {
      final stat = await file.stat();
      if (now.difference(stat.modified) > maxFileAge) {
        await _deleteIfExists(file);
      }
    }

    final remaining = await _logFiles();
    remaining.sort((a, b) {
      final modifiedCompare = b.statSync().modified.compareTo(
        a.statSync().modified,
      );
      if (modifiedCompare != 0) return modifiedCompare;
      return b.path.compareTo(a.path);
    });

    for (final file in remaining.skip(maxFiles)) {
      await _deleteIfExists(file);
    }
  }

  Future<void> _rotateIfNeeded(int nextWriteBytes) async {
    final file = currentFile;
    if (!await file.exists()) return;

    final length = await file.length();
    if (length == 0 || length + nextWriteBytes <= maxFileBytes) return;

    await file.rename(await _nextArchivePath());
  }

  Future<String> _nextArchivePath() async {
    final baseName = 'smartflow-${_clock().toUtc().millisecondsSinceEpoch}';
    var candidate = _join(directory.path, '$baseName.log');
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = _join(directory.path, '$baseName-$suffix.log');
      suffix += 1;
    }
    return candidate;
  }

  Future<List<File>> _logFiles() async {
    if (!await directory.exists()) return const [];
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name == currentFileName ||
          (name.startsWith('smartflow-') && name.endsWith('.log'))) {
        files.add(entity);
      }
    }
    return files;
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
    if (await file.exists()) {
      await file.delete();
    }
  }
}

String _join(String parent, String child) {
  if (parent.endsWith(Platform.pathSeparator)) return '$parent$child';
  return '$parent${Platform.pathSeparator}$child';
}
