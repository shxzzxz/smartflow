import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/core/logging/app_log_reader.dart';

void main() {
  group('AppLogReader', () {
    test('merges entries across files newest first', () async {
      final directory = await _tempDirectory();
      await _writeLines(directory, 'smartflow.log', [
        _line(time: '2026-07-02T10:00:00.000Z', message: 'current'),
      ]);
      await _writeLines(directory, 'smartflow-1000.log', [
        _line(time: '2026-07-01T10:00:00.000Z', message: 'archived old'),
        _line(time: '2026-07-01T12:00:00.000Z', message: 'archived new'),
      ]);

      final entries =
          await AppLogReader(directory: directory).readEntries();

      expect(entries.map((entry) => entry.message), [
        'current',
        'archived new',
        'archived old',
      ]);
    });

    test('parses level, logger, error and stack trace fields', () async {
      final directory = await _tempDirectory();
      await _writeLines(directory, 'smartflow.log', [
        '{"time":"2026-07-02T10:00:00.000Z","level":"SEVERE",'
            '"logger":"app.error","message":"boom",'
            '"error":"StateError: bad","stackTrace":"stack line"}',
      ]);

      final entries =
          await AppLogReader(directory: directory).readEntries();

      final entry = entries.single;
      expect(entry.level, Level.SEVERE);
      expect(entry.loggerName, 'app.error');
      expect(entry.message, 'boom');
      expect(entry.error, 'StateError: bad');
      expect(entry.stackTrace, 'stack line');
      expect(entry.time, DateTime.utc(2026, 7, 2, 10));
    });

    test('skips malformed lines and unknown files', () async {
      final directory = await _tempDirectory();
      await _writeLines(directory, 'smartflow.log', [
        'not json',
        '[1,2]',
        '{"level":"INFO","message":"missing time"}',
        _line(time: '2026-07-02T10:00:00.000Z', message: 'valid'),
        '',
      ]);
      await _writeLines(directory, 'other.txt', [
        _line(time: '2026-07-03T10:00:00.000Z', message: 'ignored'),
      ]);

      final entries =
          await AppLogReader(directory: directory).readEntries();

      expect(entries.map((entry) => entry.message), ['valid']);
    });

    test('falls back to INFO for unknown levels', () async {
      final directory = await _tempDirectory();
      await _writeLines(directory, 'smartflow.log', [
        _line(
          time: '2026-07-02T10:00:00.000Z',
          message: 'custom',
          level: 'NOT_A_LEVEL',
        ),
      ]);

      final entries =
          await AppLogReader(directory: directory).readEntries();

      expect(entries.single.level, Level.INFO);
    });

    test('returns empty list when directory is missing', () async {
      final directory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}absent_logs',
      );

      final entries =
          await AppLogReader(directory: directory).readEntries();

      expect(entries, isEmpty);
    });

    test('clearEntries removes current and archived log files', () async {
      final directory = await _tempDirectory();
      await _writeLines(directory, 'smartflow.log', [
        _line(time: '2026-07-02T10:00:00.000Z', message: 'current'),
      ]);
      await _writeLines(directory, 'smartflow-1000.log', [
        _line(time: '2026-07-01T10:00:00.000Z', message: 'archived'),
      ]);
      await _writeLines(directory, 'other.txt', ['keep']);

      final reader = AppLogReader(directory: directory);
      await reader.clearEntries();

      expect(await reader.readEntries(), isEmpty);
      expect(
        File(
          '${directory.path}${Platform.pathSeparator}other.txt',
        ).existsSync(),
        isTrue,
      );
    });
  });
}

String _line({
  required String time,
  required String message,
  String level = 'INFO',
}) {
  return '{"time":"$time","level":"$level","logger":"test","message":"$message"}';
}

Future<void> _writeLines(
  Directory directory,
  String name,
  List<String> lines,
) async {
  final file = File('${directory.path}${Platform.pathSeparator}$name');
  await file.writeAsString(lines.map((line) => '$line\n').join());
}

Future<Directory> _tempDirectory() async {
  final directory = await Directory.systemTemp.createTemp(
    'smartflow_log_reader_test_',
  );
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}
