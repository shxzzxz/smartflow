import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'app_log_file_sink.dart';

class AppLogEntry {
  const AppLogEntry({
    required this.time,
    required this.level,
    required this.loggerName,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime time;
  final Level level;
  final String loggerName;
  final String message;
  final String? error;
  final String? stackTrace;
}

/// 读取 [AppLogFileSink] 写出的 JSONL 日志文件。
class AppLogReader {
  const AppLogReader({required this.directory});

  final Directory directory;

  /// 合并当前文件与归档文件的全部条目，按时间倒序返回；无法解析的行跳过。
  Future<List<AppLogEntry>> readEntries() async {
    final entries = <AppLogEntry>[];
    for (final file in await _logFiles()) {
      final List<String> lines;
      try {
        lines = await file.readAsLines();
      } on FileSystemException {
        continue;
      }
      for (final line in lines) {
        final entry = _parseLine(line);
        if (entry != null) entries.add(entry);
      }
    }
    entries.sort((a, b) => b.time.compareTo(a.time));
    return entries;
  }

  Future<void> clearEntries() async {
    for (final file in await _logFiles()) {
      try {
        await file.delete();
      } on FileSystemException {
        // 正在写入的文件删除失败时保留，下次清空再处理。
      }
    }
  }

  Future<List<File>> _logFiles() async {
    if (!await directory.exists()) return const [];
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name == AppLogFileSink.currentFileName ||
          (name.startsWith('smartflow-') && name.endsWith('.log'))) {
        files.add(entity);
      }
    }
    return files;
  }

  AppLogEntry? _parseLine(String line) {
    if (line.trim().isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;

    final time = DateTime.tryParse(json['time'] as String? ?? '');
    final message = json['message'];
    if (time == null || message is! String) return null;

    return AppLogEntry(
      time: time,
      level: _levelFromName(json['level'] as String? ?? ''),
      loggerName: json['logger'] as String? ?? '',
      message: message,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  Level _levelFromName(String name) {
    for (final level in Level.LEVELS) {
      if (level.name == name) return level;
    }
    return Level.INFO;
  }
}
