import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_chrome_theme.dart';
import 'package:smartflow/feature/profile/view_model/header_appearance_view_model.dart';
import 'package:smartflow/feature/profile/view_model/navigation_appearance_view_model.dart';
import 'package:smartflow/feature/shared/view_model/app_settings_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  Future<ProviderContainer> open(_SettingsStore store) async {
    final container = ProviderContainer(
      overrides: [appSettingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container.listen(headerAppearanceViewModelProvider, (_, _) {});
    container.listen(navigationAppearanceViewModelProvider, (_, _) {});
    await Future.wait([
      container.read(headerAppearanceViewModelProvider.future),
      container.read(navigationAppearanceViewModelProvider.future),
    ]);
    return container;
  }

  test(
    'independent drafts merge with newer global settings when saved',
    () async {
      final store = _SettingsStore();
      final container = await open(store);
      final header = container.read(headerAppearanceViewModelProvider.notifier);
      final navigation = container.read(
        navigationAppearanceViewModelProvider.notifier,
      );
      const navigationGlass = AppGlassSettings(
        blurSigma: 14,
        backgroundOpacity: 0.4,
        saturation: 1.6,
        shadowOpacity: 0.2,
      );
      header.setStyle(AppHeaderStyle.classic);
      header.setBackgroundGlass(
        AppChromeTheme.defaults.headerBackgroundGlass.copyWith(blurSigma: 24),
      );
      header.setControlGlass(
        AppChromeTheme.defaults.headerControlGlass.copyWith(blurSigma: 4),
      );
      navigation.setStyle(BottomNavigationStyle.frostedGlass);
      navigation.setShowLabels(false);
      navigation.setGlass(navigationGlass);
      expect(store.writes, 0);
      expect(store.settings.appearance, const AppAppearanceSettings());

      final global = container.read(appSettingsViewModelProvider.notifier);
      await global.setIncomeColor(0xFF9254DE);
      await global.setShowAddTransactionFab(false);
      await global.saveThemeAppearance(
        appearance: const AppAppearanceSettings(primaryColor: 0xFFE7AE47),
      );
      expect(
        container
            .read(headerAppearanceViewModelProvider)
            .requireValue
            .appearance
            .headerStyle,
        AppHeaderStyle.classic,
      );
      expect(
        container
            .read(navigationAppearanceViewModelProvider)
            .requireValue
            .glass,
        navigationGlass,
      );

      final outcomes = await Future.wait([header.save(), navigation.save()]);
      expect(outcomes, everyElement(isA<UiActionSuccess<void>>()));
      final saved = store.settings;
      expect(saved.appearance.headerStyle, AppHeaderStyle.classic);
      expect(saved.appearance.headerBackgroundGlass.blurSigma, 24);
      expect(saved.appearance.headerControlGlass.blurSigma, 4);
      expect(saved.appearance.navigationGlass, navigationGlass);
      expect(saved.bottomNavigationStyle, BottomNavigationStyle.frostedGlass);
      expect(saved.showBottomNavLabels, isFalse);
      expect(saved.appearance.primaryColor, 0xFFE7AE47);
      expect(saved.appearance.incomeColor, 0xFF9254DE);
      expect(saved.showAddTransactionFab, isFalse);
      expect(
        container
            .read(headerAppearanceViewModelProvider)
            .requireValue
            .hasChanges,
        isFalse,
      );
      expect(
        container
            .read(navigationAppearanceViewModelProvider)
            .requireValue
            .hasChanges,
        isFalse,
      );
    },
  );

  for (final editingHeader in [true, false]) {
    test(
      '${editingHeader ? 'header' : 'navigation'} save failure retains draft and prevents edits during submission',
      () async {
        final store = _SettingsStore();
        final container = await open(store);
        final header = container.read(
          headerAppearanceViewModelProvider.notifier,
        );
        final navigation = container.read(
          navigationAppearanceViewModelProvider.notifier,
        );
        if (editingHeader) {
          header.setStyle(AppHeaderStyle.classic);
        } else {
          navigation.setStyle(BottomNavigationStyle.frostedGlass);
        }
        store.fail = true;
        store.gate = Completer<void>();
        final pending = editingHeader ? header.save() : navigation.save();
        await Future<void>.delayed(Duration.zero);
        expect(
          store.settings.appearance.headerStyle,
          AppHeaderStyle.frostedGlass,
        );
        expect(
          store.settings.bottomNavigationStyle,
          BottomNavigationStyle.classic,
        );
        header.restoreDefaults();
        navigation.restoreDefaults();
        header.discardChanges();
        navigation.discardChanges();
        if (editingHeader) {
          header.setStyle(AppHeaderStyle.frostedGlass);
          expect(
            container
                .read(headerAppearanceViewModelProvider)
                .requireValue
                .submitting,
            isTrue,
          );
          expect(
            container
                .read(headerAppearanceViewModelProvider)
                .requireValue
                .appearance
                .headerStyle,
            AppHeaderStyle.classic,
          );
        } else {
          navigation.setStyle(BottomNavigationStyle.classic);
          expect(
            container
                .read(navigationAppearanceViewModelProvider)
                .requireValue
                .submitting,
            isTrue,
          );
          expect(
            container
                .read(navigationAppearanceViewModelProvider)
                .requireValue
                .style,
            BottomNavigationStyle.frostedGlass,
          );
        }
        store.gate!.complete();
        expect(await pending, isA<UiActionFailure<void>>());
        expect(
          container
              .read(headerAppearanceViewModelProvider)
              .requireValue
              .submitting,
          isFalse,
        );
        expect(
          container
              .read(navigationAppearanceViewModelProvider)
              .requireValue
              .submitting,
          isFalse,
        );
        expect(
          editingHeader
              ? container
                    .read(headerAppearanceViewModelProvider)
                    .requireValue
                    .hasChanges
              : container
                    .read(navigationAppearanceViewModelProvider)
                    .requireValue
                    .hasChanges,
          isTrue,
        );
        store.fail = false;
        store.gate = null;
        expect(
          await (editingHeader ? header.save() : navigation.save()),
          isA<UiActionSuccess<void>>(),
        );
        expect(store.writes, 2);
      },
    );
  }

  test(
    'classic style preserves glass drafts and discard restores saved values',
    () async {
      final store = _SettingsStore();
      final container = await open(store);
      final header = container.read(headerAppearanceViewModelProvider.notifier);
      final navigation = container.read(
        navigationAppearanceViewModelProvider.notifier,
      );
      final background = AppChromeTheme.defaults.headerBackgroundGlass.copyWith(
        blurSigma: 30,
      );
      final control = AppChromeTheme.defaults.headerControlGlass.copyWith(
        backgroundOpacity: 0.6,
      );
      final glass = AppChromeTheme.defaults.navigationGlass.copyWith(
        saturation: 1.9,
      );
      header.setBackgroundGlass(background);
      header.setControlGlass(control);
      navigation.setGlass(glass);
      header.setStyle(AppHeaderStyle.classic);
      navigation.setStyle(BottomNavigationStyle.classic);
      header.setStyle(AppHeaderStyle.frostedGlass);
      navigation.setStyle(BottomNavigationStyle.frostedGlass);
      expect(
        container
            .read(headerAppearanceViewModelProvider)
            .requireValue
            .appearance
            .headerBackgroundGlass,
        background,
      );
      expect(
        container
            .read(headerAppearanceViewModelProvider)
            .requireValue
            .appearance
            .headerControlGlass,
        control,
      );
      expect(
        container
            .read(navigationAppearanceViewModelProvider)
            .requireValue
            .glass,
        glass,
      );
      header.discardChanges();
      navigation.discardChanges();
      expect(
        container
            .read(headerAppearanceViewModelProvider)
            .requireValue
            .hasChanges,
        isFalse,
      );
      expect(
        container
            .read(navigationAppearanceViewModelProvider)
            .requireValue
            .hasChanges,
        isFalse,
      );
      expect(store.writes, 0);
    },
  );

  test('restoring either section keeps other appearance choices', () async {
    const appearance = AppAppearanceSettings(
      primaryColor: 0xFFE7AE47,
      headerStyle: AppHeaderStyle.classic,
      navigationGlass: AppGlassSettings(blurSigma: 30),
      headerBackgroundGlass: AppGlassSettings(blurSigma: 35),
      headerControlGlass: AppGlassSettings(blurSigma: 16),
    );
    final store = _SettingsStore(
      const AppSettings(
        appearance: appearance,
        bottomNavigationStyle: BottomNavigationStyle.frostedGlass,
        showBottomNavLabels: false,
        showAddTransactionFab: false,
      ),
    );
    final container = await open(store);
    final navigation = container.read(
      navigationAppearanceViewModelProvider.notifier,
    );
    navigation.restoreDefaults();
    expect(await navigation.save(), isA<UiActionSuccess<void>>());
    expect(store.settings.appearance.headerStyle, AppHeaderStyle.classic);
    expect(
      store.settings.appearance.headerBackgroundGlass,
      appearance.headerBackgroundGlass,
    );
    expect(
      store.settings.appearance.headerControlGlass,
      appearance.headerControlGlass,
    );
    expect(store.settings.bottomNavigationStyle, BottomNavigationStyle.classic);
    expect(store.settings.showBottomNavLabels, isTrue);
    expect(
      store.settings.appearance.navigationGlass,
      AppChromeTheme.defaults.navigationGlass,
    );
    final header = container.read(headerAppearanceViewModelProvider.notifier);
    header.restoreDefaults();
    expect(await header.save(), isA<UiActionSuccess<void>>());
    expect(store.settings.appearance.headerStyle, AppHeaderStyle.frostedGlass);
    expect(
      store.settings.appearance.headerBackgroundGlass,
      AppChromeTheme.defaults.headerBackgroundGlass,
    );
    expect(
      store.settings.appearance.headerControlGlass,
      AppChromeTheme.defaults.headerControlGlass,
    );
    expect(
      store.settings.appearance.navigationGlass,
      AppChromeTheme.defaults.navigationGlass,
    );
    expect(store.settings.appearance.primaryColor, appearance.primaryColor);
    expect(store.settings.showAddTransactionFab, isFalse);
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
