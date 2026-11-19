import 'package:flutter/material.dart';

import '../token/colors.dart';
import '../token/appearance.dart';

abstract final class AppColorSchemes {
  static Color foregroundFor(Color color) {
    final luminance = color.computeLuminance();
    final lightContrast =
        (AppColors.neutral99.computeLuminance() + 0.05) / (luminance + 0.05);
    final darkContrast =
        (luminance + 0.05) / (AppColors.neutral10.computeLuminance() + 0.05);
    return lightContrast >= darkContrast
        ? AppColors.neutral99
        : AppColors.neutral10;
  }

  static Color readableOnSurface(Color color, {Color? fallback}) {
    final luminance = color.computeLuminance();
    final surfaceLuminance = AppColors.neutral99.computeLuminance();
    final contrast = (surfaceLuminance + 0.05) / (luminance + 0.05);
    if (contrast >= AppAppearanceTokens.minContentContrast) return color;
    return fallback ??
        ColorScheme.fromSeed(
          seedColor: color,
          brightness: Brightness.light,
        ).primary;
  }

  static ColorScheme light({Color primaryColor = AppColors.brand}) {
    final base = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    );
    return base.copyWith(
      primary: primaryColor,
      onPrimary: primaryColor == AppColors.brand
          ? AppColors.neutral99
          : foregroundFor(primaryColor),
      surface: AppColors.neutral95,
      onSurface: AppColors.neutral10,
      surfaceContainerLowest: AppColors.neutral99,
      surfaceContainerLow: AppColors.neutral99,
      surfaceContainer: AppColors.neutral95,
      surfaceContainerHigh: AppColors.neutral95,
      surfaceContainerHighest: AppColors.neutral90,
      onSurfaceVariant: AppColors.neutral20,
      outlineVariant: AppColors.neutral90,
    );
  }

  static ColorScheme dark({Color seedColor = AppColors.brandDark}) {
    final surfaces = ColorScheme.fromSeed(
      seedColor: AppColors.brandDark,
      brightness: Brightness.dark,
    );
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: seedColor,
      onPrimary: foregroundFor(seedColor),
      surface: surfaces.surface,
      surfaceDim: surfaces.surfaceDim,
      surfaceBright: surfaces.surfaceBright,
      surfaceContainerLowest: surfaces.surfaceContainerLowest,
      surfaceContainerLow: surfaces.surfaceContainerLow,
      surfaceContainer: surfaces.surfaceContainer,
      surfaceContainerHigh: surfaces.surfaceContainerHigh,
      surfaceContainerHighest: surfaces.surfaceContainerHighest,
    );
  }
}
