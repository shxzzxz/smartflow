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

  Future<void> setIncomeColor(int value) {
    return _save(
      (settings) => settings.copyWith(
        appearance: settings.appearance.copyWith(incomeColor: value),
      ),
    );
  }

  Future<void> setExpenseColor(int value) {
    return _save(
      (settings) => settings.copyWith(
        appearance: settings.appearance.copyWith(expenseColor: value),
      ),
    );
  }

  /// 只提交主题配色与背景参数，持久化成功后发布到全局主题。
  Future<void> saveThemeAppearance({
    required AppAppearanceSettings appearance,
  }) {
    return _save(
      (settings) => settings.copyWith(
        appearance: settings.appearance.copyWith(
          primaryColor: appearance.primaryColor,
          backgroundSeedColor: appearance.backgroundSeedColor,
          backgroundStyle: appearance.backgroundStyle,
          gradientDepth: appearance.gradientDepth,
          gradientRange: appearance.gradientRange,
        ),
      ),
      optimistic: false,
    );
  }

  /// 导航栏草稿一次提交，保留其他页面更新的设置。
  Future<void> saveNavigationAppearance({
    required BottomNavigationStyle style,
    required bool showLabels,
    required AppGlassSettings glass,
  }) => _save(
    (settings) => settings.copyWith(
      bottomNavigationStyle: style,
      showBottomNavLabels: showLabels,
      appearance: settings.appearance.copyWith(navigationGlass: glass),
    ),
    optimistic: false,
  );

  /// 只提交顶部样式与两层玻璃参数。
  Future<void> saveHeaderAppearance({
    required AppAppearanceSettings appearance,
  }) => _save(
    (settings) => settings.copyWith(
      appearance: settings.appearance.copyWith(
        headerStyle: appearance.headerStyle,
        headerBackgroundGlass: appearance.headerBackgroundGlass,
        headerControlGlass: appearance.headerControlGlass,
      ),
    ),
    optimistic: false,
  );

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
