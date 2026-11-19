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
  Future<void> _pendingSave = Future<void>.value();

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

  Future<void> setBottomNavigationStyle(BottomNavigationStyle value) {
    return _save((settings) => settings.copyWith(bottomNavigationStyle: value));
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

  Future<void> setCashflowPeriodMetric(CashflowPeriodMetric value) {
    return _save((settings) => settings.copyWith(cashflowPeriodMetric: value));
  }

  Future<void> setTransactionListDisplayMode(TransactionListDisplayMode value) {
    return _save(
      (settings) => settings.copyWith(transactionListDisplayMode: value),
    );
  }

  /// 外观与记账按钮一次提交，持久化成功前不发布到全局主题。
  Future<void> savePersonalization({
    required AppAppearanceSettings appearance,
    required bool showAddTransactionFab,
  }) {
    return _save(
      (settings) => settings.copyWith(
        appearance: appearance,
        showAddTransactionFab: showAddTransactionFab,
      ),
      optimistic: false,
    );
  }

  Future<void> _save(
    AppSettings Function(AppSettings settings) change, {
    bool optimistic = true,
  }) {
    final operation = _pendingSave.then((_) async {
      final previous = state.value ?? const AppSettings();
      final next = change(previous);
      if (optimistic) state = AsyncData(next);
      try {
        await ref.read(appSettingsStoreProvider).save(next);
        if (!optimistic && ref.mounted) state = AsyncData(next);
      } catch (_) {
        if (optimistic && ref.mounted) state = AsyncData(previous);
        rethrow;
      }
    });
    _pendingSave = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }
}
