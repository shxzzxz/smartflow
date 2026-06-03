import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/core/logging/app_log_file_sink.dart';

void main() {
  group('AppLogFileSink', () {
    test('writes structured JSON lines with error and stack trace', () async {
      final directory = await _tempDirectory();
      final sink = AppLogFileSink(directory: directory);
      await sink.initialize();

      await sink.write(
        LogRecord(
          Level.SEVERE,
          'Unhandled async error.',
          'app.error',
          StateError('boom'),
          StackTrace.fromString('stack line'),
          Zone.current,
        ),
      );

      final lines = await sink.currentFile.readAsLines();
      expect(lines, hasLength(1));
      final json = jsonDecode(lines.single) as Map<String, Object?>;
      expect(json['level'], 'SEVERE');
      expect(json['logger'], 'app.error');
      expect(json['message'], 'Unhandled async error.');
      expect(json['error'], contains('boom'));
      expect(json['stackTrace'], contains('stack line'));
      expect(json['time'], isA<String>());
    });

    test('rotates current log when the next write exceeds max bytes', () async {
      final directory = await _tempDirectory();
      final sink = AppLogFileSink(
        directory: directory,
        maxFileBytes: 120,
        clock: () => DateTime.utc(2026, 6, 3, 12),
      );
      await sink.initialize();

      await sink.write(_record('first ${'x' * 80}'));
      await sink.write(_record('second'));

      final names = await _fileNames(directory);
      expect(names, contains(AppLogFileSink.currentFileName));
      expect(
        names.where((name) => name.startsWith('smartflow-')),
        hasLength(1),
      );
      expect(await sink.currentFile.readAsString(), contains('second'));
    });

    test('keeps newest files within count and age limits', () async {
      final directory = await _tempDirectory();
      final now = DateTime(2026, 6, 3, 12);
      final sink = AppLogFileSink(
        directory: directory,
        maxFiles: 2,
        maxFileAge: const Duration(days: 14),
        clock: () => now,
      );
      await directory.create(recursive: true);
      await _writeLogFile(directory, 'smartflow.log', modified: now);
      await _writeLogFile(
        directory,
        'smartflow-new.log',
        modified: now.subtract(const Duration(days: 1)),
      );
      await _writeLogFile(
        directory,
        'smartflow-old.log',
        modified: now.subtract(const Duration(days: 2)),
      );
      await _writeLogFile(
        directory,
        'smartflow-expired.log',
        modified: now.subtract(const Duration(days: 20)),
      );

      await sink.cleanup();

      final names = await _fileNames(directory);
      expect(names, ['smartflow-new.log', 'smartflow.log']);
    });
  });
}

LogRecord _record(String message) {
  return LogRecord(Level.INFO, message, 'test.logger');
}

Future<Directory> _tempDirectory() async {
  final directory = await Directory.systemTemp.createTemp(
    'smartflow_log_test_',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

Future<void> _writeLogFile(
  Directory directory,
  String name, {
  required DateTime modified,
}) async {
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsString('log\n');
  await file.setLastModified(modified);
}

Future<List<String>> _fileNames(Directory directory) async {
  final names = <String>[];
  await for (final entity in directory.list()) {
    if (entity is File) {
      names.add(entity.uri.pathSegments.last);
    }
  }
  names.sort();
  return names;
}
