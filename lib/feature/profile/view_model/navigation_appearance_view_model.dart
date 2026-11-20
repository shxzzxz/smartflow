import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_appearance_values.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'navigation_appearance_view_model.g.dart';

final _logger = Logger('feature.profile.navigation_appearance');

class NavigationAppearanceState {
  const NavigationAppearanceState({
    required this.savedSettings,
    required this.settings,
    this.submitting = false,
  });

  factory NavigationAppearanceState.fromSettings(AppSettings settings) {
    final resolved = settings.copyWith(
      appearance: AppAppearanceValues.resolve(settings.appearance),
    );
    return NavigationAppearanceState(
      savedSettings: resolved,
      settings: resolved,
    );
  }

  final AppSettings savedSettings;
  final AppSettings settings;
  final bool submitting;

  BottomNavigationStyle get style => settings.bottomNavigationStyle;
  bool get showLabels => settings.showBottomNavLabels;
  AppGlassSettings get glass => settings.appearance.navigationGlass;

  bool get hasChanges =>
      style != savedSettings.bottomNavigationStyle ||
      showLabels != savedSettings.showBottomNavLabels ||
      glass != savedSettings.appearance.navigationGlass;

  NavigationAppearanceState copyWith({
    AppSettings? settings,
    bool? submitting,
  }) => NavigationAppearanceState(
    savedSettings: savedSettings,
    settings: settings ?? this.settings,
    submitting: submitting ?? this.submitting,
  );
}

@riverpod
class NavigationAppearanceViewModel extends _$NavigationAppearanceViewModel {
  @override
  Future<NavigationAppearanceState> build() async {
    final settings = await ref.read(appSettingsViewModelProvider.future);
    return NavigationAppearanceState.fromSettings(settings);
  }

  void retry() {
    ref.invalidate(appSettingsViewModelProvider);
    ref.invalidateSelf();
  }

  void setStyle(BottomNavigationStyle style) => _update(
    (current) => current.settings.copyWith(bottomNavigationStyle: style),
  );

  void setShowLabels(bool showLabels) => _update(
    (current) => current.settings.copyWith(showBottomNavLabels: showLabels),
  );

  void setGlass(AppGlassSettings glass) => _update(
    (current) => current.settings.copyWith(
      appearance: AppAppearanceValues.resolve(
        current.settings.appearance.copyWith(navigationGlass: glass),
      ),
    ),
  );

  void restoreDefaults() {
    const defaults = AppSettings();
    final appearance = AppAppearanceValues.resolve(defaults.appearance);
    _update(
      (current) => current.settings.copyWith(
        bottomNavigationStyle: defaults.bottomNavigationStyle,
        showBottomNavLabels: defaults.showBottomNavLabels,
        appearance: current.settings.appearance.copyWith(
          navigationGlass: appearance.navigationGlass,
        ),
      ),
    );
  }

  void discardChanges() {
    final current = state.value;
    if (current == null || current.submitting) return;
    state = AsyncData(current.copyWith(settings: current.savedSettings));
  }

  void _update(AppSettings Function(NavigationAppearanceState) change) {
    final current = state.value;
    if (current == null || current.submitting) return;
    state = AsyncData(current.copyWith(settings: change(current)));
  }

  Future<UiActionOutcome<void>> save() async {
    final submitted = state.value;
    if (submitted == null) {
      return const UiActionOutcome.failure(
        UiError(code: 'not_ready', message: '设置尚未加载，请稍后重试。'),
      );
    }
    if (submitted.submitting || !submitted.hasChanges) {
      return const UiActionOutcome.success(null);
    }
    state = AsyncData(submitted.copyWith(submitting: true));
    try {
      final outcome = await guardUiAction(
        _logger,
        'save navigation appearance',
        () {
          return ref
              .read(appSettingsViewModelProvider.notifier)
              .saveNavigationAppearance(
                style: submitted.style,
                showLabels: submitted.showLabels,
                glass: submitted.glass,
              );
        },
      );
      if (!ref.mounted) return outcome;
      state = AsyncData(
        outcome is UiActionSuccess<void>
            ? NavigationAppearanceState.fromSettings(
                ref.read(appSettingsViewModelProvider).requireValue,
              )
            : submitted.copyWith(submitting: false),
      );
      return outcome;
    } finally {
      if (ref.mounted && state.value?.submitting == true) {
        state = AsyncData(state.requireValue.copyWith(submitting: false));
      }
    }
  }
}
