import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/feature/profile/view_model/personalization_view_model.dart';
import 'package:smartflow/feature/shared/view_model/app_settings_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  Future<ProviderContainer> open(_SettingsStore store) async {
    final container = ProviderContainer(
      overrides: [appSettingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      personalizationViewModelProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await container.read(personalizationViewModelProvider.future);
    return container;
  }

  test('edits stay local when unrelated global settings change', () async {
    final store = _SettingsStore();
    final container = await open(store);
    final notifier = container.read(personalizationViewModelProvider.notifier);

    notifier.setPrimaryColor(0xFFE7AE47);
    notifier.setBackgroundSeedColor(0xFF1677FF);
    notifier.setBackgroundStyle(AppBackgroundStyle.singleGlow);
    notifier.setIncomeColor(0xFF9254DE);
    notifier.setExpenseColor(0xFF1976D2);
    notifier.setGradientDepth(0.7);
    notifier.setGradientRange(0.9);
    notifier.setShowAddTransactionFab(false);
    expect(store.writes, 0);
    expect(store.settings.appearance, const AppAppearanceSettings());

    await container
        .read(appSettingsViewModelProvider.notifier)
        .setShowBottomNavLabels(false);
    final draft = container.read(personalizationViewModelProvider).requireValue;
    expect(draft.appearance.primaryColor, 0xFFE7AE47);
    expect(draft.appearance.backgroundSeedColor, 0xFF1677FF);
    expect(draft.appearance.backgroundStyle, AppBackgroundStyle.singleGlow);
    expect(draft.appearance.incomeColor, 0xFF9254DE);
    expect(draft.appearance.expenseColor, 0xFF1976D2);
    expect(draft.appearance.gradientDepth, 0.7);
    expect(draft.appearance.gradientRange, 0.9);
    expect(draft.showAddTransactionFab, isFalse);
    expect(draft.hasChanges, isTrue);
    expect(store.settings.appearance, const AppAppearanceSettings());
  });

  test(
    'publishes after persistence and serializes other settings writes',
    () async {
      final store = _SettingsStore();
      final container = await open(store);
      final notifier = container.read(
        personalizationViewModelProvider.notifier,
      );
      notifier.setPrimaryColor(0xFFE7AE47);
      notifier.setBackgroundSeedColor(0xFF9254DE);
      notifier.setBackgroundStyle(AppBackgroundStyle.solid);
      notifier.setShowAddTransactionFab(false);
      store.gate = Completer<void>();

      final save = notifier.save();
      final changeNavigation = container
          .read(appSettingsViewModelProvider.notifier)
          .setShowBottomNavLabels(false);
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
            .read(personalizationViewModelProvider)
            .requireValue
            .submitting,
        isTrue,
      );
      notifier.restoreDefaults();
      expect(
        container
            .read(personalizationViewModelProvider)
            .requireValue
            .appearance
            .primaryColor,
        0xFFE7AE47,
      );

      store.gate!.complete();
      expect(await save, isA<UiActionSuccess<void>>());
      await changeNavigation;
      expect(store.settings.appearance.primaryColor, 0xFFE7AE47);
      expect(store.settings.appearance.backgroundSeedColor, 0xFF9254DE);
      expect(
        store.settings.appearance.backgroundStyle,
        AppBackgroundStyle.solid,
      );
      expect(store.settings.showAddTransactionFab, isFalse);
      expect(store.settings.showBottomNavLabels, isFalse);
      expect(store.writes, 2);
      final current = container
          .read(personalizationViewModelProvider)
          .requireValue;
      expect(current.hasChanges, isFalse);
      expect(current.submitting, isFalse);
    },
  );

  test('failed save retains the draft and global settings for retry', () async {
    final store = _SettingsStore()..fail = true;
    final container = await open(store);
    final notifier = container.read(personalizationViewModelProvider.notifier);
    notifier.setPrimaryColor(0xFFE7AE47);
    notifier.setBackgroundSeedColor(0xFF9254DE);
    notifier.setBackgroundStyle(AppBackgroundStyle.singleGlow);
    notifier.setShowAddTransactionFab(false);

    expect(await notifier.save(), isA<UiActionFailure<void>>());
    expect(store.settings.appearance, const AppAppearanceSettings());
    expect(
      container.read(appSettingsViewModelProvider).requireValue.appearance,
      const AppAppearanceSettings(),
    );
    final failed = container
        .read(personalizationViewModelProvider)
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
    expect(store.settings.showAddTransactionFab, isFalse);
    expect(
      container.read(personalizationViewModelProvider).requireValue.hasChanges,
      isFalse,
    );
  });

  test('restore and discard change only the draft', () async {
    const saved = AppSettings(
      appearance: AppAppearanceSettings(
        primaryColor: 0xFFE7AE47,
        backgroundSeedColor: 0xFF9254DE,
        backgroundStyle: AppBackgroundStyle.solid,
        gradientDepth: 0.8,
        gradientRange: 0.9,
      ),
      showAddTransactionFab: false,
    );
    final store = _SettingsStore(saved);
    final container = await open(store);
    final notifier = container.read(personalizationViewModelProvider.notifier);

    notifier.restoreDefaults();
    final reset = container.read(personalizationViewModelProvider).requireValue;
    expect(reset.appearance.primaryColor, 0xFF1677FF);
    expect(reset.appearance.backgroundSeedColor, 0xFF1677FF);
    expect(reset.appearance.backgroundStyle, AppBackgroundStyle.multiGlow);
    expect(reset.appearance.incomeColor, 0xFF00B85C);
    expect(reset.appearance.expenseColor, 0xFFFF2B2B);
    expect(reset.appearance.gradientDepth, 0.35);
    expect(reset.appearance.gradientRange, 0.65);
    expect(reset.showAddTransactionFab, isTrue);
    expect(reset.hasChanges, isTrue);
    expect(store.settings, saved);
    expect(store.writes, 0);

    notifier.discardChanges();
    final discarded = container
        .read(personalizationViewModelProvider)
        .requireValue;
    expect(discarded.appearance.primaryColor, saved.appearance.primaryColor);
    expect(
      discarded.appearance.backgroundSeedColor,
      saved.appearance.backgroundSeedColor,
    );
    expect(discarded.appearance.backgroundStyle, AppBackgroundStyle.solid);
    expect(discarded.appearance.gradientDepth, saved.appearance.gradientDepth);
    expect(discarded.showAddTransactionFab, isFalse);
    expect(discarded.hasChanges, isFalse);
    expect(store.writes, 0);
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
