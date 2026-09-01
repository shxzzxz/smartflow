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
      final sink = AppLogFileSink(
        directory: directory,
        clock: () => DateTime(2026, 6, 3, 12),
      );
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
      expect(sink.currentFile.path, endsWith('smartflow-20260603001.log'));
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
      expect(names, contains('smartflow-20260603002.log'));
      expect(
        names.where((name) => name.startsWith('smartflow-')),
        hasLength(2),
      );
      expect(await sink.currentFile.readAsString(), contains('second'));
    });

    test('starts a new sequence when the calendar day changes', () async {
      final directory = await _tempDirectory();
      var now = DateTime(2026, 6, 3, 23, 59);
      final sink = AppLogFileSink(directory: directory, clock: () => now);

      await sink.write(_record('before midnight'));
      now = DateTime(2026, 6, 4, 0, 1);
      await sink.write(_record('after midnight'));

      expect(await _fileNames(directory), [
        'smartflow-20260603001.log',
        'smartflow-20260604001.log',
      ]);
      expect(await sink.currentFile.readAsString(), contains('after midnight'));
    });

    test('continues the latest sequence after initialization', () async {
      final directory = await _tempDirectory();
      await _writeLogFile(directory, 'smartflow-20260603001.log');
      await _writeLogFile(directory, 'smartflow-20260603002.log');
      final sink = AppLogFileSink(
        directory: directory,
        maxFileBytes: 1,
        clock: () => DateTime(2026, 6, 3, 12),
      );
      await sink.initialize();
      await sink.write(_record('next'));

      expect(await _fileNames(directory), [
        'smartflow-20260603001.log',
        'smartflow-20260603002.log',
        'smartflow-20260603003.log',
      ]);
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
      await _writeLogFile(
        directory,
        'smartflow-20260603001.log',
        modified: now,
      );
      await _writeLogFile(
        directory,
        'smartflow-20260602001.log',
        modified: now.subtract(const Duration(days: 1)),
      );
      await _writeLogFile(
        directory,
        'smartflow-20260601001.log',
        modified: now.subtract(const Duration(days: 2)),
      );
      await _writeLogFile(
        directory,
        'smartflow-20260514001.log',
        modified: now.subtract(const Duration(days: 20)),
      );

      await sink.cleanup();

      final names = await _fileNames(directory);
      expect(names, ['smartflow-20260602001.log', 'smartflow-20260603001.log']);
    });

    test('applyRetention tightens limits and prunes immediately', () async {
      final directory = await _tempDirectory();
      final now = DateTime(2026, 6, 3, 12);
      final sink = AppLogFileSink(directory: directory, clock: () => now);
      await directory.create(recursive: true);
      await _writeLogFile(
        directory,
        'smartflow-20260603001.log',
        modified: now,
      );
      await _writeLogFile(
        directory,
        'smartflow-20260602001.log',
        modified: now.subtract(const Duration(days: 1)),
      );
      await _writeLogFile(
        directory,
        'smartflow-20260529001.log',
        modified: now.subtract(const Duration(days: 5)),
      );
      await _writeLogFile(
        directory,
        'smartflow-20260524001.log',
        modified: now.subtract(const Duration(days: 10)),
      );
      await sink.cleanup();
      expect(await _fileNames(directory), hasLength(4));

      await sink.applyRetention(
        maxFiles: 2,
        maxFileAge: const Duration(days: 7),
      );

      expect(sink.maxFiles, 2);
      expect(sink.maxFileAge, const Duration(days: 7));
      expect(await _fileNames(directory), [
        'smartflow-20260602001.log',
        'smartflow-20260603001.log',
      ]);
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
  DateTime? modified,
}) async {
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsString('log\n');
  if (modified != null) await file.setLastModified(modified);
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
