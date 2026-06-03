import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log_file_sink.dart';

StreamSubscription<LogRecord>? _rootLogSubscription;

Future<AppLogFileSink> configureAppLogging({
  Directory? logDirectory,
  bool mirrorToDeveloperLog = kDebugMode,
  int maxFileBytes = AppLogFileSink.defaultMaxFileBytes,
  int maxFiles = AppLogFileSink.defaultMaxFiles,
  Duration maxFileAge = AppLogFileSink.defaultMaxFileAge,
}) async {
  final directory =
      logDirectory ?? Directory(_logDirectoryPath(await _supportDirectory()));
  final sink = AppLogFileSink(
    directory: directory,
    maxFileBytes: maxFileBytes,
    maxFiles: maxFiles,
    maxFileAge: maxFileAge,
  );
  await sink.initialize();

  Logger.root.level = Level.ALL;
  await _rootLogSubscription?.cancel();
  _rootLogSubscription = Logger.root.onRecord.listen((record) {
    unawaited(
      sink.write(record).catchError((Object error, StackTrace stackTrace) {
        developer.log(
          'Failed to write SmartFlow log record.',
          name: 'smartflow.logging',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );

    if (mirrorToDeveloperLog) {
      developer.log(
        record.message,
        name: record.loggerName,
        level: record.level.value,
        error: record.error,
        stackTrace: record.stackTrace,
        time: record.time,
      );
    }
  });

  return sink;
}

Future<void> disposeAppLogging() async {
  await _rootLogSubscription?.cancel();
  _rootLogSubscription = null;
}

Future<Directory> _supportDirectory() {
  return getApplicationSupportDirectory();
}

String _logDirectoryPath(Directory supportDirectory) {
  final separator = Platform.pathSeparator;
  final basePath = supportDirectory.path;
  if (basePath.endsWith(separator)) return '${basePath}logs';
  return '$basePath${separator}logs';
}
