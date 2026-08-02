import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/shared/log_retention_store.dart';
import '../../../core/logging/app_log_reader.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'log_viewer_view_model.g.dart';

final _logger = Logger('feature.profile.log_viewer');

/// 日志级别过滤，阈值语义：显示选中级别及以上的条目。
enum LogLevelFilter { all, fine, info, warning, severe }

class LogViewerState {
  const LogViewerState({
    this.levelFilter = LogLevelFilter.all,
    this.query = '',
  });

  final LogLevelFilter levelFilter;
  final String query;

  LogViewerState copyWith({LogLevelFilter? levelFilter, String? query}) {
    return LogViewerState(
      levelFilter: levelFilter ?? this.levelFilter,
      query: query ?? this.query,
    );
  }
}

@riverpod
class LogViewerViewModel extends _$LogViewerViewModel {
  @override
  LogViewerState build() => const LogViewerState();

  void setLevelFilter(LogLevelFilter filter) {
    state = state.copyWith(levelFilter: filter);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void refresh() {
    ref.invalidate(logEntriesProvider);
  }

  Future<UiActionOutcome<void>> clearLogs() async {
    try {
      await ref.read(appLogReaderProvider).clearEntries();
      if (ref.mounted) {
        ref.invalidate(logEntriesProvider);
      }
      return const UiActionOutcome.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.severe('Log clear failed unexpectedly.', exception, stackTrace);
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }
}

@riverpod
Future<List<AppLogEntry>> logEntries(Ref ref) {
  return ref.watch(appLogReaderProvider).readEntries();
}

@riverpod
class LogRetentionSettingsViewModel extends _$LogRetentionSettingsViewModel {
  @override
  Future<LogRetentionSettings> build() {
    return ref.watch(logRetentionStoreProvider).read();
  }

  Future<void> setMaxFileAgeDays(int days) {
    return _save((settings) => settings.copyWith(maxFileAgeDays: days));
  }

  Future<void> setMaxFiles(int count) {
    return _save((settings) => settings.copyWith(maxFiles: count));
  }

  Future<void> _save(
    LogRetentionSettings Function(LogRetentionSettings settings) change,
  ) async {
    final store = ref.read(logRetentionStoreProvider);
    final sink = ref.read(appLogFileSinkProvider);
    final next = change(state.value ?? const LogRetentionSettings());
    state = AsyncData(next);
    await store.save(next);
    await sink.applyRetention(
      maxFiles: next.maxFiles,
      maxFileAge: next.maxFileAge,
    );
    if (ref.mounted) {
      ref.invalidate(logEntriesProvider);
    }
  }
}
