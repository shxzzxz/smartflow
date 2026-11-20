import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_appearance_values.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'header_appearance_view_model.g.dart';

final _logger = Logger('feature.profile.header_appearance');

class HeaderAppearanceState {
  const HeaderAppearanceState({
    required this.savedAppearance,
    required this.appearance,
    this.submitting = false,
  });

  factory HeaderAppearanceState.fromSettings(AppSettings settings) {
    final appearance = AppAppearanceValues.resolve(settings.appearance);
    return HeaderAppearanceState(
      savedAppearance: appearance,
      appearance: appearance,
    );
  }

  final AppAppearanceSettings savedAppearance;
  final AppAppearanceSettings appearance;
  final bool submitting;

  bool get hasChanges =>
      appearance.headerStyle != savedAppearance.headerStyle ||
      appearance.headerBackgroundGlass !=
          savedAppearance.headerBackgroundGlass ||
      appearance.headerControlGlass != savedAppearance.headerControlGlass;

  HeaderAppearanceState copyWith({
    AppAppearanceSettings? appearance,
    bool? submitting,
  }) => HeaderAppearanceState(
    savedAppearance: savedAppearance,
    appearance: appearance ?? this.appearance,
    submitting: submitting ?? this.submitting,
  );
}

@riverpod
class HeaderAppearanceViewModel extends _$HeaderAppearanceViewModel {
  @override
  Future<HeaderAppearanceState> build() async {
    final settings = await ref.read(appSettingsViewModelProvider.future);
    return HeaderAppearanceState.fromSettings(settings);
  }

  void retry() {
    ref.invalidate(appSettingsViewModelProvider);
    ref.invalidateSelf();
  }

  void setStyle(AppHeaderStyle style) =>
      _update((current) => current.appearance.copyWith(headerStyle: style));

  void setBackgroundGlass(AppGlassSettings glass) => _update(
    (current) => AppAppearanceValues.resolve(
      current.appearance.copyWith(headerBackgroundGlass: glass),
    ),
  );

  void setControlGlass(AppGlassSettings glass) => _update(
    (current) => AppAppearanceValues.resolve(
      current.appearance.copyWith(headerControlGlass: glass),
    ),
  );

  void restoreDefaults() {
    final defaults = AppAppearanceValues.resolve(const AppAppearanceSettings());
    _update(
      (current) => current.appearance.copyWith(
        headerStyle: defaults.headerStyle,
        headerBackgroundGlass: defaults.headerBackgroundGlass,
        headerControlGlass: defaults.headerControlGlass,
      ),
    );
  }

  void discardChanges() {
    final current = state.value;
    if (current == null || current.submitting) return;
    state = AsyncData(current.copyWith(appearance: current.savedAppearance));
  }

  void _update(AppAppearanceSettings Function(HeaderAppearanceState) change) {
    final current = state.value;
    if (current == null || current.submitting) return;
    state = AsyncData(current.copyWith(appearance: change(current)));
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
        'save header appearance',
        () {
          return ref
              .read(appSettingsViewModelProvider.notifier)
              .saveHeaderAppearance(appearance: submitted.appearance);
        },
      );
      if (!ref.mounted) return outcome;
      state = AsyncData(
        outcome is UiActionSuccess<void>
            ? HeaderAppearanceState.fromSettings(
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
