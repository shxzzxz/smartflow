import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import '../../../core/logging/app_log_reader.dart';
import '../view_model/log_viewer_view_model.dart';

List<AppLogEntry> filterLogEntries(
  List<AppLogEntry> entries, {
  required LogLevelFilter levelFilter,
  required String query,
}) {
  final minLevel = switch (levelFilter) {
    LogLevelFilter.all => Level.ALL,
    LogLevelFilter.fine => Level.FINE,
    LogLevelFilter.info => Level.INFO,
    LogLevelFilter.warning => Level.WARNING,
    LogLevelFilter.severe => Level.SEVERE,
  };
  final keyword = query.trim().toLowerCase();
  return entries
      .where((entry) {
        if (entry.level < minLevel) return false;
        if (keyword.isEmpty) return true;
        return entry.message.toLowerCase().contains(keyword) ||
            entry.loggerName.toLowerCase().contains(keyword) ||
            (entry.error?.toLowerCase().contains(keyword) ?? false);
      })
      .toList(growable: false);
}

String logLevelLabel(Level level) {
  if (level >= Level.SEVERE) return '错误';
  if (level >= Level.WARNING) return '警告';
  if (level >= Level.INFO) return '信息';
  return '调试';
}

String logEntryTimeLabel(DateTime time) {
  return _listTimeFormat.format(time.toLocal());
}

String logEntryDetailTimeLabel(DateTime time) {
  return _detailTimeFormat.format(time.toLocal());
}

/// 详情页复制用的完整文本。
String logEntryCopyText(AppLogEntry entry) {
  final buffer =
      StringBuffer()
        ..writeln(
          '${logEntryDetailTimeLabel(entry.time)} '
          '[${entry.level.name}] ${entry.loggerName}',
        )
        ..writeln(entry.message);
  if (entry.error != null) {
    buffer.writeln(entry.error);
  }
  if (entry.stackTrace != null) {
    buffer.writeln(entry.stackTrace);
  }
  return buffer.toString().trimRight();
}

final DateFormat _listTimeFormat = DateFormat('MM-dd HH:mm:ss');
final DateFormat _detailTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
