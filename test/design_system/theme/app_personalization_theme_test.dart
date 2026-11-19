import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_appearance_theme.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';

void main() {
  test('unconfigured settings retain the current brand and page color', () {
    final theme = AppTheme.light();
    final background = theme.extension<AppAppearanceTheme>()!;
    expect(theme.colorScheme.primary, const Color(0xFF1677FF));
    expect(theme.colorScheme.surface, const Color(0xFFF6F6F6));
    expect(background.gradientDepth, 0.35);
    expect(background.gradientRange, 0.65);
    expect(background.gradientColor, const Color(0xFF1677FF));
    expect(background.backgroundStyle, AppBackgroundStyle.multiGlow);
  });

  test('financial choices do not alter other financial or state colors', () {
    const appearance = AppAppearanceSettings(
      primaryColor: 0xFFE7AE47,
      backgroundSeedColor: 0xFFE7AE47,
      incomeColor: 0xFF9254DE,
      expenseColor: 0xFF1976D2,
      gradientDepth: 0.8,
      gradientRange: 0.9,
    );
    for (final brightness in Brightness.values) {
      final baseline = brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark();
      final selected = brightness == Brightness.light
          ? AppTheme.light(appearance: appearance)
          : AppTheme.dark(appearance: appearance);
      final original = baseline.extension<AppThemeExtension>()!;
      final finance = selected.extension<AppThemeExtension>()!;
      expect(finance.income, isNot(original.income));
      expect(finance.expense, isNot(original.expense));
      expect(finance.asset, original.asset);
      expect(finance.liability, original.liability);
      expect(finance.success, original.success);
      expect(finance.danger, original.danger);
      expect(finance.transfer, original.transfer);
      final background = selected.extension<AppAppearanceTheme>()!;
      expect(background.gradientColor, const Color(0xFFE7AE47));
      expect(background.gradientDepth, 0.8);
      expect(background.gradientRange, 0.9);
    }
  });

  test(
    'pale finance colors stay readable without replacing the theme seed',
    () {
      const appearance = AppAppearanceSettings(
        primaryColor: 0xFFFFFFFF,
        backgroundSeedColor: 0xFFFFFFFF,
        incomeColor: 0xFFFFFFFF,
        expenseColor: 0xFFFFF0F0,
      );
      final theme = AppTheme.light(appearance: appearance);
      final finance = theme.extension<AppThemeExtension>()!;
      for (final color in [finance.income, finance.expense]) {
        final contrast = (1 + 0.05) / (color.computeLuminance() + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
      expect(theme.colorScheme.primary, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onPrimary, const Color(0xFF101827));
      expect(
        theme.extension<AppAppearanceTheme>()!.gradientColor,
        const Color(0xFFFFFFFF),
      );
    },
  );

  test('theme and background colors remain independent in both themes', () {
    const appearance = AppAppearanceSettings(
      primaryColor: 0xFFFFA940,
      backgroundSeedColor: 0xFF1677FF,
      backgroundStyle: AppBackgroundStyle.singleGlow,
    );
    for (final brightness in Brightness.values) {
      ThemeData themeFor(AppAppearanceSettings value) =>
          brightness == Brightness.light
          ? AppTheme.light(appearance: value)
          : AppTheme.dark(appearance: value);
      final original = themeFor(appearance);
      final changedTheme = themeFor(
        appearance.copyWith(primaryColor: 0xFF9254DE),
      );
      final changedBackground = themeFor(
        appearance.copyWith(backgroundSeedColor: 0xFFB73831),
      );
      expect(original.colorScheme.primary, const Color(0xFFFFA940));
      expect(original.colorScheme.onPrimary, const Color(0xFF101827));
      expect(changedTheme.colorScheme.primary, const Color(0xFF9254DE));
      expect(changedTheme.colorScheme.surface, original.colorScheme.surface);
      expect(
        changedTheme.extension<AppAppearanceTheme>()!.gradientColor,
        const Color(0xFF1677FF),
      );
      expect(changedBackground.colorScheme, original.colorScheme);
      expect(
        changedBackground.extension<AppAppearanceTheme>()!.gradientColor,
        const Color(0xFFB73831),
      );
      expect(
        changedBackground.extension<AppAppearanceTheme>()!.backgroundStyle,
        AppBackgroundStyle.singleGlow,
      );
    }
  });
}
