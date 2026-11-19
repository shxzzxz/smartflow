import '../../application/shared/app_appearance_settings.dart';
import '../token/appearance.dart';

/// 将用户覆盖值解析为完整视觉参数，默认值只在 token 层定义。
abstract final class AppAppearanceValues {
  static AppAppearanceSettings resolve(AppAppearanceSettings settings) {
    return AppAppearanceSettings(
      primaryColor:
          settings.primaryColor == AppAppearanceSettings.useDefaultColor
          ? AppAppearanceTokens.primaryColor
          : settings.primaryColor,
      backgroundSeedColor:
          settings.backgroundSeedColor == AppAppearanceSettings.useDefaultColor
          ? AppAppearanceTokens.backgroundSeedColor
          : settings.backgroundSeedColor,
      incomeColor: settings.incomeColor == AppAppearanceSettings.useDefaultColor
          ? AppAppearanceTokens.incomeColor
          : settings.incomeColor,
      expenseColor:
          settings.expenseColor == AppAppearanceSettings.useDefaultColor
          ? AppAppearanceTokens.expenseColor
          : settings.expenseColor,
      backgroundStyle: settings.backgroundStyle,
      gradientDepth:
          settings.gradientDepth == AppAppearanceSettings.useDefaultGradient
          ? AppAppearanceTokens.gradientDepth
          : settings.gradientDepth,
      gradientRange:
          settings.gradientRange == AppAppearanceSettings.useDefaultGradient
          ? AppAppearanceTokens.gradientRange
          : settings.gradientRange
                .clamp(AppAppearanceTokens.minGradientRange, 1)
                .toDouble(),
    );
  }
}
