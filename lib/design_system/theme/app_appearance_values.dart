import '../../application/shared/app_appearance_settings.dart';
import '../token/appearance.dart';
import '../token/component.dart';
import '../token/elevation.dart';

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
      headerStyle: settings.headerStyle,
      navigationGlass: resolveGlass(
        settings.navigationGlass,
        defaults: const AppGlassSettings(
          blurSigma: AppComponentTokens.frostedNavigationBarBlurSigma,
          backgroundOpacity:
              AppComponentTokens.frostedNavigationBarBackgroundOpacity,
          saturation: AppComponentTokens.frostedNavigationBarSaturation,
          shadowOpacity: AppComponentTokens.frostedNavigationBarShadowOpacity,
        ),
      ),
      headerBackgroundGlass: resolveGlass(
        settings.headerBackgroundGlass,
        defaults: const AppGlassSettings(
          blurSigma: AppComponentTokens.frostedBackgroundBlurSigma,
          backgroundOpacity: AppComponentTokens.frostedBackgroundTopOpacity,
          saturation: AppComponentTokens.frostedBackgroundSaturation,
          shadowOpacity: AppComponentTokens.frostedBackgroundShadowOpacity,
        ),
      ),
      headerControlGlass: resolveGlass(
        settings.headerControlGlass,
        defaults: const AppGlassSettings(
          blurSigma: AppComponentTokens.frostedSurfaceBlurSigma,
          backgroundOpacity: AppComponentTokens.frostedSurfaceTopOpacity,
          saturation: AppComponentTokens.frostedSurfaceSaturation,
          shadowOpacity: AppElevation.frostedShadowOpacity,
        ),
      ),
    );
  }

  static AppGlassSettings resolveGlass(
    AppGlassSettings settings, {
    required AppGlassSettings defaults,
  }) {
    double value(double override, double fallback, double maximum) =>
        override == AppGlassSettings.useDefault || !override.isFinite
        ? fallback
        : override.clamp(0, maximum).toDouble();
    return AppGlassSettings(
      blurSigma: value(
        settings.blurSigma,
        defaults.blurSigma,
        AppAppearanceTokens.maxGlassBlur,
      ),
      backgroundOpacity: value(
        settings.backgroundOpacity,
        defaults.backgroundOpacity,
        1,
      ),
      saturation: value(
        settings.saturation,
        defaults.saturation,
        AppAppearanceTokens.maxGlassSaturation,
      ),
      shadowOpacity: value(
        settings.shadowOpacity,
        defaults.shadowOpacity,
        AppAppearanceTokens.maxGlassShadowOpacity,
      ),
    );
  }
}
