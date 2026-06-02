import 'package:flutter/material.dart';

import '../token/colors.dart';

abstract final class AppColorSchemes {
  static ColorScheme light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
    );
    return base.copyWith(
      primary: AppColors.brand,
      onPrimary: AppColors.neutral99,
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

  static ColorScheme dark() {
    return ColorScheme.fromSeed(
      seedColor: AppColors.brandDark,
      brightness: Brightness.dark,
    );
  }
}
