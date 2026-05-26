import 'package:flutter/material.dart';

import '../token/typography.dart';

abstract final class AppTextThemes {
  static TextTheme textTheme(ColorScheme colors) {
    final base = Typography.material2021().black.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
    );

    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: AppTypography.fontSizeXl,
        fontWeight: AppTypography.strongWeight,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: AppTypography.fontSizeLg,
        fontWeight: AppTypography.titleWeight,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: AppTypography.fontSizeMd,
        fontWeight: AppTypography.titleWeight,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: AppTypography.fontSizeMd,
        fontWeight: AppTypography.emphasisWeight,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: AppTypography.fontSizeMd,
        fontWeight: AppTypography.bodyWeight,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: AppTypography.fontSizeSm,
        fontWeight: AppTypography.bodyWeight,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.bodyWeight,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.emphasisWeight,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: AppTypography.fontSizeTiny,
        fontWeight: AppTypography.emphasisWeight,
      ),
    );
  }
}
