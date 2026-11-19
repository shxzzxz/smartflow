import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/token/appearance.dart';
import '../../../design_system/theme/app_appearance_values.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'theme_appearance_view_model.g.dart';

final _logger = Logger('feature.profile.theme_appearance');

class ThemeAppearanceState {
  const ThemeAppearanceState({
    required this.savedAppearance,
    required this.appearance,
    this.submitting = false,
  });

  factory ThemeAppearanceState.fromSettings(AppSettings settings) {
    final appearance = AppAppearanceValues.resolve(settings.appearance);
    return ThemeAppearanceState(
      savedAppearance: appearance,
      appearance: appearance,
    );
  }

  final AppAppearanceSettings savedAppearance;
  final AppAppearanceSettings appearance;
  final bool submitting;

  bool get hasChanges => appearance != savedAppearance;

  ThemeAppearanceState copyWith({
    AppAppearanceSettings? appearance,
    bool? submitting,
  }) => ThemeAppearanceState(
    savedAppearance: savedAppearance,
    appearance: appearance ?? this.appearance,
    submitting: submitting ?? this.submitting,
  );
}

@riverpod
class ThemeAppearanceViewModel extends _$ThemeAppearanceViewModel {
  @override
  Future<ThemeAppearanceState> build() async {
    // 全局设置是 keepAlive；只取一次，后续全局更新不覆盖编辑中的草稿。
    final settings = await ref.read(appSettingsViewModelProvider.future);
    return ThemeAppearanceState.fromSettings(settings);
  }

  void retry() {
    ref.invalidate(appSettingsViewModelProvider);
    ref.invalidateSelf();
  }

  void setPrimaryColor(int color) => _update(
    (value) => value.copyWith(
      appearance: value.appearance.copyWith(primaryColor: color),
    ),
  );

  void setBackgroundSeedColor(int color) => _update(
    (value) => value.copyWith(
      appearance: value.appearance.copyWith(backgroundSeedColor: color),
    ),
  );

  void setBackgroundStyle(AppBackgroundStyle style) => _update(
    (value) => value.copyWith(
      appearance: value.appearance.copyWith(backgroundStyle: style),
    ),
  );

  void setGradientDepth(double depth) {
    if (!depth.isFinite) return;
    _update(
      (value) => value.copyWith(
        appearance: value.appearance.copyWith(
          gradientDepth: depth.clamp(0, 1).toDouble(),
        ),
      ),
    );
  }

  void setGradientRange(double range) {
    if (!range.isFinite) return;
    _update(
      (value) => value.copyWith(
        appearance: value.appearance.copyWith(
          gradientRange: range
              .clamp(AppAppearanceTokens.minGradientRange, 1)
              .toDouble(),
        ),
      ),
    );
  }

  void restoreDefaults() {
    final defaults = AppAppearanceValues.resolve(const AppAppearanceSettings());
    _update(
      (value) => value.copyWith(
        appearance: value.appearance.copyWith(
          primaryColor: defaults.primaryColor,
          backgroundSeedColor: defaults.backgroundSeedColor,
          backgroundStyle: defaults.backgroundStyle,
          gradientDepth: defaults.gradientDepth,
          gradientRange: defaults.gradientRange,
        ),
      ),
    );
  }

  void discardChanges() {
    final current = state.value;
    if (current == null || current.submitting) return;
    state = AsyncData(current.copyWith(appearance: current.savedAppearance));
  }

  void _update(ThemeAppearanceState Function(ThemeAppearanceState) change) {
    final current = state.value;
    if (current == null || current.submitting) return;
    state = AsyncData(change(current));
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
      final outcome = await guardUiAction(_logger, 'save theme appearance', () {
        return ref
            .read(appSettingsViewModelProvider.notifier)
            .saveThemeAppearance(appearance: submitted.appearance);
      });
      if (!ref.mounted) return outcome;
      if (outcome is UiActionSuccess<void>) {
        state = AsyncData(
          ThemeAppearanceState.fromSettings(
            ref.read(appSettingsViewModelProvider).requireValue,
          ),
        );
      } else {
        state = AsyncData(submitted.copyWith(submitting: false));
      }
      return outcome;
    } finally {
      if (ref.mounted && state.value?.submitting == true) {
        state = AsyncData(state.requireValue.copyWith(submitting: false));
      }
    }
  }
}
