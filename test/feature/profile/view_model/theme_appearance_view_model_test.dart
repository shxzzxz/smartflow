import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/feature/profile/view_model/theme_appearance_view_model.dart';
import 'package:smartflow/feature/shared/view_model/app_settings_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  Future<ProviderContainer> open(_SettingsStore store) async {
    final container = ProviderContainer(
      overrides: [appSettingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      themeAppearanceViewModelProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await container.read(themeAppearanceViewModelProvider.future);
    return container;
  }

  test('edits stay local when unrelated global settings change', () async {
    final store = _SettingsStore();
    final container = await open(store);
    final notifier = container.read(themeAppearanceViewModelProvider.notifier);

    notifier.setPrimaryColor(0xFFE7AE47);
    notifier.setBackgroundSeedColor(0xFF1677FF);
    notifier.setBackgroundStyle(AppBackgroundStyle.singleGlow);
    notifier.setGradientDepth(0.7);
    notifier.setGradientRange(0.9);
    expect(store.writes, 0);
    expect(store.settings.appearance, const AppAppearanceSettings());

    await container
        .read(appSettingsViewModelProvider.notifier)
        .setShowBottomNavLabels(false);
    final draft = container.read(themeAppearanceViewModelProvider).requireValue;
    expect(draft.appearance.primaryColor, 0xFFE7AE47);
    expect(draft.appearance.backgroundSeedColor, 0xFF1677FF);
    expect(draft.appearance.backgroundStyle, AppBackgroundStyle.singleGlow);
    expect(draft.appearance.gradientDepth, 0.7);
    expect(draft.appearance.gradientRange, 0.9);
    expect(draft.hasChanges, isTrue);
    expect(store.settings.appearance, const AppAppearanceSettings());
  });

  test(
    'saving a theme preserves newer transaction and operation settings',
    () async {
      final store = _SettingsStore();
      final container = await open(store);
      final theme = container.read(themeAppearanceViewModelProvider.notifier);
      theme.setPrimaryColor(0xFFE7AE47);
      theme.setBackgroundSeedColor(0xFFB73831);
      final settings = container.read(appSettingsViewModelProvider.notifier);
      await settings.setIncomeColor(0xFF9254DE);
      await settings.setExpenseColor(0xFF1976D2);
      await settings.setShowAddTransactionFab(false);
      await settings.setShowBottomNavLabels(false);

      expect(await theme.save(), isA<UiActionSuccess<void>>());
      expect(store.settings.appearance.primaryColor, 0xFFE7AE47);
      expect(store.settings.appearance.backgroundSeedColor, 0xFFB73831);
      expect(store.settings.appearance.incomeColor, 0xFF9254DE);
      expect(store.settings.appearance.expenseColor, 0xFF1976D2);
      expect(store.settings.showAddTransactionFab, isFalse);
      expect(store.settings.showBottomNavLabels, isFalse);
      expect(
        container
            .read(themeAppearanceViewModelProvider)
            .requireValue
            .hasChanges,
        isFalse,
      );
    },
  );

  test(
    'publishes after persistence and serializes other settings writes',
    () async {
      final store = _SettingsStore();
      final container = await open(store);
      final notifier = container.read(
        themeAppearanceViewModelProvider.notifier,
      );
      notifier.setPrimaryColor(0xFFE7AE47);
      notifier.setBackgroundSeedColor(0xFF9254DE);
      notifier.setBackgroundStyle(AppBackgroundStyle.solid);
      store.gate = Completer<void>();

      final save = notifier.save();
      final changeNavigation = container
          .read(appSettingsViewModelProvider.notifier)
          .setShowBottomNavLabels(false);
      final changeIncome = container
          .read(appSettingsViewModelProvider.notifier)
          .setIncomeColor(0xFF9254DE);
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, 1);
      expect(
        container.read(appSettingsViewModelProvider).requireValue.appearance,
        const AppAppearanceSettings(),
      );
      expect(
        container
            .read(appSettingsViewModelProvider)
            .requireValue
            .showAddTransactionFab,
        isTrue,
      );
      expect(
        container
            .read(themeAppearanceViewModelProvider)
            .requireValue
            .submitting,
        isTrue,
      );
      notifier.restoreDefaults();
      expect(
        container
            .read(themeAppearanceViewModelProvider)
            .requireValue
            .appearance
            .primaryColor,
        0xFFE7AE47,
      );

      store.gate!.complete();
      expect(await save, isA<UiActionSuccess<void>>());
      await changeNavigation;
      await changeIncome;
      expect(store.settings.appearance.primaryColor, 0xFFE7AE47);
      expect(store.settings.appearance.backgroundSeedColor, 0xFF9254DE);
      expect(
        store.settings.appearance.backgroundStyle,
        AppBackgroundStyle.solid,
      );
      expect(store.settings.appearance.incomeColor, 0xFF9254DE);
      expect(store.settings.showAddTransactionFab, isTrue);
      expect(store.settings.showBottomNavLabels, isFalse);
      expect(store.writes, 3);
      final current = container
          .read(themeAppearanceViewModelProvider)
          .requireValue;
      expect(current.hasChanges, isFalse);
      expect(current.submitting, isFalse);
    },
  );

  test('failed save retains the draft and global settings for retry', () async {
    final store = _SettingsStore()..fail = true;
    final container = await open(store);
    final notifier = container.read(themeAppearanceViewModelProvider.notifier);
    notifier.setPrimaryColor(0xFFE7AE47);
    notifier.setBackgroundSeedColor(0xFF9254DE);
    notifier.setBackgroundStyle(AppBackgroundStyle.singleGlow);

    expect(await notifier.save(), isA<UiActionFailure<void>>());
    expect(store.settings.appearance, const AppAppearanceSettings());
    expect(
      container.read(appSettingsViewModelProvider).requireValue.appearance,
      const AppAppearanceSettings(),
    );
    final failed = container
        .read(themeAppearanceViewModelProvider)
        .requireValue;
    expect(failed.appearance.primaryColor, 0xFFE7AE47);
    expect(failed.appearance.backgroundSeedColor, 0xFF9254DE);
    expect(failed.appearance.backgroundStyle, AppBackgroundStyle.singleGlow);
    expect(failed.hasChanges, isTrue);
    expect(failed.submitting, isFalse);

    store.fail = false;
    expect(await notifier.save(), isA<UiActionSuccess<void>>());
    expect(store.settings.appearance.primaryColor, 0xFFE7AE47);
    expect(store.settings.appearance.backgroundSeedColor, 0xFF9254DE);
    expect(
      store.settings.appearance.backgroundStyle,
      AppBackgroundStyle.singleGlow,
    );
    expect(
      container.read(themeAppearanceViewModelProvider).requireValue.hasChanges,
      isFalse,
    );
  });

  test('restore and discard affect the theme draft only', () async {
    const saved = AppSettings(
      appearance: AppAppearanceSettings(
        primaryColor: 0xFFE7AE47,
        backgroundSeedColor: 0xFF9254DE,
        incomeColor: 0xFF9254DE,
        expenseColor: 0xFF1976D2,
        backgroundStyle: AppBackgroundStyle.solid,
        gradientDepth: 0.8,
        gradientRange: 0.9,
      ),
      showAddTransactionFab: false,
    );
    final store = _SettingsStore(saved);
    final container = await open(store);
    final notifier = container.read(themeAppearanceViewModelProvider.notifier);

    notifier.restoreDefaults();
    final reset = container.read(themeAppearanceViewModelProvider).requireValue;
    expect(reset.appearance.primaryColor, 0xFF1677FF);
    expect(reset.appearance.backgroundSeedColor, 0xFF1677FF);
    expect(reset.appearance.backgroundStyle, AppBackgroundStyle.multiGlow);
    expect(reset.appearance.incomeColor, saved.appearance.incomeColor);
    expect(reset.appearance.expenseColor, saved.appearance.expenseColor);
    expect(reset.appearance.gradientDepth, 0.35);
    expect(reset.appearance.gradientRange, 0.65);
    expect(reset.hasChanges, isTrue);
    expect(store.settings, saved);
    expect(store.writes, 0);

    notifier.discardChanges();
    final discarded = container
        .read(themeAppearanceViewModelProvider)
        .requireValue;
    expect(discarded.appearance.primaryColor, saved.appearance.primaryColor);
    expect(
      discarded.appearance.backgroundSeedColor,
      saved.appearance.backgroundSeedColor,
    );
    expect(discarded.appearance.backgroundStyle, AppBackgroundStyle.solid);
    expect(discarded.appearance.gradientDepth, saved.appearance.gradientDepth);
    expect(discarded.hasChanges, isFalse);
    expect(store.writes, 0);

    notifier.restoreDefaults();
    expect(await notifier.save(), isA<UiActionSuccess<void>>());
    expect(store.settings.appearance.primaryColor, 0xFF1677FF);
    expect(store.settings.appearance.backgroundSeedColor, 0xFF1677FF);
    expect(
      store.settings.appearance.backgroundStyle,
      AppBackgroundStyle.multiGlow,
    );
    expect(store.settings.appearance.incomeColor, saved.appearance.incomeColor);
    expect(
      store.settings.appearance.expenseColor,
      saved.appearance.expenseColor,
    );
    expect(store.settings.showAddTransactionFab, isFalse);
    expect(store.writes, 1);
    notifier.restoreDefaults();
    expect(
      container.read(themeAppearanceViewModelProvider).requireValue.hasChanges,
      isFalse,
    );
    expect(await notifier.save(), isA<UiActionSuccess<void>>());
    expect(store.writes, 1);
  });
}

class _SettingsStore implements AppSettingsStore {
  _SettingsStore([this.settings = const AppSettings()]);

  AppSettings settings;
  int writes = 0;
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings value) async {
    writes++;
    await gate?.future;
    if (fail) throw Exception('settings write failed');
    settings = value;
  }
}
