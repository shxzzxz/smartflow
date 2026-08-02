import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/core/logging/app_log_reader.dart';
import 'package:smartflow/feature/profile/presentation/log_viewer_presentation.dart';
import 'package:smartflow/feature/profile/view_model/log_viewer_view_model.dart';

void main() {
  final entries = [
    _entry(
      level: Level.FINE,
      message: 'Database opened',
      logger: 'infra.database',
    ),
    _entry(level: Level.INFO, message: 'App started', logger: 'app.bootstrap'),
    _entry(
      level: Level.WARNING,
      message: 'Manifest fetch failed',
      logger: 'core.update',
    ),
    _entry(
      level: Level.SEVERE,
      message: 'Provider failed',
      logger: 'app.provider',
      error: 'StateError: boom',
    ),
  ];

  group('filterLogEntries', () {
    test('level filter keeps selected level and above', () {
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.fine,
          query: '',
        ).map((entry) => entry.level),
        [Level.FINE, Level.INFO, Level.WARNING, Level.SEVERE],
      );
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.info,
          query: '',
        ).map((entry) => entry.level),
        [Level.INFO, Level.WARNING, Level.SEVERE],
      );
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.warning,
          query: '',
        ).map((entry) => entry.level),
        [Level.WARNING, Level.SEVERE],
      );
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.severe,
          query: '',
        ).map((entry) => entry.level),
        [Level.SEVERE],
      );
      expect(
        filterLogEntries(entries, levelFilter: LogLevelFilter.all, query: ''),
        hasLength(4),
      );
    });

    test('query matches message, logger and error case-insensitively', () {
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.all,
          query: 'MANIFEST',
        ).single.message,
        'Manifest fetch failed',
      );
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.all,
          query: 'app.bootstrap',
        ).single.message,
        'App started',
      );
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.all,
          query: 'stateerror',
        ).single.message,
        'Provider failed',
      );
      expect(
        filterLogEntries(
          entries,
          levelFilter: LogLevelFilter.all,
          query: 'no match',
        ),
        isEmpty,
      );
    });

    test('blank query keeps everything', () {
      expect(
        filterLogEntries(entries, levelFilter: LogLevelFilter.all, query: '  '),
        hasLength(4),
      );
    });
  });

  test('logLevelLabel maps levels to Chinese labels', () {
    expect(logLevelLabel(Level.SEVERE), '错误');
    expect(logLevelLabel(Level.SHOUT), '错误');
    expect(logLevelLabel(Level.WARNING), '警告');
    expect(logLevelLabel(Level.INFO), '信息');
    expect(logLevelLabel(Level.FINE), '调试');
  });

  test('logEntryCopyText includes meta, error and stack trace', () {
    final text = logEntryCopyText(
      _entry(
        level: Level.SEVERE,
        message: 'Provider failed',
        logger: 'app.provider',
        error: 'StateError: boom',
        stackTrace: 'stack line',
      ),
    );

    expect(text, contains('[SEVERE] app.provider'));
    expect(text, contains('Provider failed'));
    expect(text, contains('StateError: boom'));
    expect(text, contains('stack line'));
  });
}

AppLogEntry _entry({
  required Level level,
  required String message,
  required String logger,
  String? error,
  String? stackTrace,
}) {
  return AppLogEntry(
    time: DateTime.utc(2026, 7, 2, 10),
    level: level,
    loggerName: logger,
    message: message,
    error: error,
    stackTrace: stackTrace,
  );
}
