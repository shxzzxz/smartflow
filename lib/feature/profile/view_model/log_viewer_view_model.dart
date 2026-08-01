import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../core/logging/app_log_reader.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'log_viewer_view_model.g.dart';

/// 日志级别过滤，阈值语义：显示选中级别及以上的条目。
enum LogLevelFilter { all, warning, severe }

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
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    }
  }
}

@riverpod
Future<List<AppLogEntry>> logEntries(Ref ref) {
  return ref.watch(appLogReaderProvider).readEntries();
}
