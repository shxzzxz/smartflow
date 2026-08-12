import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/shared/app_settings_store.dart';
import 'action_guard.dart';
import 'ui_action_outcome.dart';

part 'app_settings_view_model.g.dart';

final _logger = Logger('feature.shared.app_settings');

@Riverpod(keepAlive: true)
class AppSettingsViewModel extends _$AppSettingsViewModel {
  @override
  Future<AppSettings> build() {
    return ref.watch(appSettingsStoreProvider).read();
  }

  Future<void> setShowAddTransactionFab(bool value) {
    return _save((settings) => settings.copyWith(showAddTransactionFab: value));
  }

  Future<void> setShowBottomNavLabels(bool value) {
    return _save((settings) => settings.copyWith(showBottomNavLabels: value));
  }

  Future<void> setPullToCreateSensitivity(PullToCreateSensitivity value) {
    return _save(
      (settings) => settings.copyWith(pullToCreateSensitivity: value),
    );
  }

  Future<UiActionOutcome<void>> setCopyPreviousMonthBudgetsOnOpen(bool value) {
    return guardUiAction(_logger, 'set copy previous month budgets', () {
      return _save(
        (settings) => settings.copyWith(copyPreviousMonthBudgetsOnOpen: value),
      );
    });
  }

  Future<void> setCalendarHeatmapEnabled(bool value) {
    return _save(
      (settings) => settings.copyWith(calendarHeatmapEnabled: value),
    );
  }

  Future<void> setCalendarHeatMetric(CalendarHeatMetric value) {
    return _save(
      (settings) => settings.copyWith(
        calendarHeatmapEnabled: true,
        calendarHeatMetric: value,
      ),
    );
  }

  Future<void> _save(AppSettings Function(AppSettings settings) change) async {
    final previous = state.value ?? const AppSettings();
    final next = change(previous);
    state = AsyncData(next);
    try {
      await ref.read(appSettingsStoreProvider).save(next);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}
