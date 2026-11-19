import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/token/appearance.dart';
import '../../../design_system/theme/app_appearance_values.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'personalization_view_model.g.dart';

final _logger = Logger('feature.profile.personalization');

class PersonalizationState {
  const PersonalizationState({
    required this.savedSettings,
    required this.appearance,
    required this.showAddTransactionFab,
    this.submitting = false,
  });

  factory PersonalizationState.fromSettings(AppSettings settings) =>
      PersonalizationState(
        savedSettings: settings,
        appearance: AppAppearanceValues.resolve(settings.appearance),
        showAddTransactionFab: settings.showAddTransactionFab,
      );

  final AppSettings savedSettings;
  final AppAppearanceSettings appearance;
  final bool showAddTransactionFab;
  final bool submitting;

  bool get hasChanges =>
      appearance != AppAppearanceValues.resolve(savedSettings.appearance) ||
      showAddTransactionFab != savedSettings.showAddTransactionFab;

  PersonalizationState copyWith({
    AppAppearanceSettings? appearance,
    bool? showAddTransactionFab,
    bool? submitting,
  }) => PersonalizationState(
    savedSettings: savedSettings,
    appearance: appearance ?? this.appearance,
    showAddTransactionFab: showAddTransactionFab ?? this.showAddTransactionFab,
    submitting: submitting ?? this.submitting,
  );
}

@riverpod
class PersonalizationViewModel extends _$PersonalizationViewModel {
  @override
  Future<PersonalizationState> build() async {
    // 全局设置是 keepAlive；只取一次，后续全局更新不覆盖编辑中的草稿。
    final settings = await ref.read(appSettingsViewModelProvider.future);
    return PersonalizationState.fromSettings(settings);
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

  void setIncomeColor(int color) => _update(
    (value) => value.copyWith(
      appearance: value.appearance.copyWith(incomeColor: color),
    ),
  );

  void setExpenseColor(int color) => _update(
    (value) => value.copyWith(
      appearance: value.appearance.copyWith(expenseColor: color),
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

  void setShowAddTransactionFab(bool show) =>
      _update((value) => value.copyWith(showAddTransactionFab: show));

  void restoreDefaults() => _update(
    (value) => value.copyWith(
      appearance: AppAppearanceValues.resolve(const AppAppearanceSettings()),
      showAddTransactionFab: const AppSettings().showAddTransactionFab,
    ),
  );

  void discardChanges() {
    final current = state.value;
    if (current == null || current.submitting) return;
    state = AsyncData(PersonalizationState.fromSettings(current.savedSettings));
  }

  void _update(PersonalizationState Function(PersonalizationState) change) {
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
      final outcome = await guardUiAction(_logger, 'save personalization', () {
        return ref
            .read(appSettingsViewModelProvider.notifier)
            .savePersonalization(
              appearance: submitted.appearance,
              showAddTransactionFab: submitted.showAddTransactionFab,
            );
      });
      if (!ref.mounted) return outcome;
      if (outcome is UiActionSuccess<void>) {
        state = AsyncData(
          PersonalizationState.fromSettings(
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
