import 'package:flutter/material.dart';

import '../../application/shared/app_appearance_settings.dart';
import '../token/appearance.dart';
import '../token/colors.dart';

@immutable
class AppAppearanceTheme extends ThemeExtension<AppAppearanceTheme> {
  const AppAppearanceTheme({
    required this.gradientColor,
    required this.gradientDepth,
    required this.gradientRange,
    required this.backgroundStyle,
  });

  final Color gradientColor;
  final double gradientDepth;
  final double gradientRange;
  final AppBackgroundStyle backgroundStyle;

  /// 辅助光晕只随背景基色派生，不消费主题色或财务语义色。
  Color get secondaryGradientColor =>
      _shiftGradientHue(AppAppearanceTokens.secondaryGradientHueShift);

  Color get tertiaryGradientColor =>
      _shiftGradientHue(AppAppearanceTokens.tertiaryGradientHueShift);

  Color _shiftGradientHue(double degrees) {
    final hsl = HSLColor.fromColor(gradientColor);
    return hsl.withHue((hsl.hue + degrees) % 360).toColor();
  }

  static const colorChoices = [
    AppColors.brand,
    AppColors.income,
    AppColors.expense,
    AppColors.categorySalary,
    AppColors.categoryDining,
    AppColors.chart5,
    AppColors.chart6,
    AppColors.neutral10,
    AppColors.neutral99,
  ];

  @override
  AppAppearanceTheme copyWith({
    Color? gradientColor,
    double? gradientDepth,
    double? gradientRange,
    AppBackgroundStyle? backgroundStyle,
  }) => AppAppearanceTheme(
    gradientColor: gradientColor ?? this.gradientColor,
    gradientDepth: gradientDepth ?? this.gradientDepth,
    gradientRange: gradientRange ?? this.gradientRange,
    backgroundStyle: backgroundStyle ?? this.backgroundStyle,
  );

  @override
  AppAppearanceTheme lerp(covariant AppAppearanceTheme? other, double t) {
    if (other == null) return this;
    return AppAppearanceTheme(
      gradientColor: Color.lerp(gradientColor, other.gradientColor, t)!,
      gradientDepth: gradientDepth + (other.gradientDepth - gradientDepth) * t,
      gradientRange: gradientRange + (other.gradientRange - gradientRange) * t,
      backgroundStyle: t < 0.5 ? backgroundStyle : other.backgroundStyle,
    );
  }
}
