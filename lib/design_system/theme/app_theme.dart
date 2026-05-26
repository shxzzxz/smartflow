import 'package:flutter/material.dart';

import '../token/radius.dart';
import '../token/typography.dart';
import 'app_color_scheme.dart';
import 'app_text_theme.dart';
import 'app_theme_extension.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final colors = AppColorSchemes.light();
    return _theme(colors, AppThemeExtension.light());
  }

  static ThemeData dark() {
    final colors = AppColorSchemes.dark();
    return _theme(colors, AppThemeExtension.dark());
  }

  static ThemeData _theme(ColorScheme colors, AppThemeExtension extension) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      textTheme: AppTextThemes.textTheme(colors),
      extensions: [extension],
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
      ),
    );
  }
}
