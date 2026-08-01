import '../../core/logging/app_log_file_sink.dart';

class LogRetentionSettings {
  const LogRetentionSettings({
    this.maxFileAgeDays = AppLogFileSink.defaultMaxFileAgeDays,
    this.maxFiles = AppLogFileSink.defaultMaxFiles,
  });

  final int maxFileAgeDays;
  final int maxFiles;

  Duration get maxFileAge => Duration(days: maxFileAgeDays);

  LogRetentionSettings copyWith({int? maxFileAgeDays, int? maxFiles}) {
    return LogRetentionSettings(
      maxFileAgeDays: maxFileAgeDays ?? this.maxFileAgeDays,
      maxFiles: maxFiles ?? this.maxFiles,
    );
  }
}

abstract interface class LogRetentionStore {
  Future<LogRetentionSettings> read();

  Future<void> save(LogRetentionSettings settings);
}
