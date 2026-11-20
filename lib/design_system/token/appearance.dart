/// 可持久化的外观默认值；保持纯 Dart，供设置模型和 Flutter 主题共用。
abstract final class AppAppearanceTokens {
  static const int primaryColor = 0xFF1677FF;
  static const int backgroundSeedColor = 0xFF1677FF;
  static const int incomeColor = 0xFF00B85C;
  static const int expenseColor = 0xFFFF2B2B;
  static const double gradientDepth = 0.35;
  static const double gradientRange = 0.65;
  static const double minGradientRange = 0.25;
  static const double minContentContrast = 4.5;
  static const double maxGlassBlur = 40;
  static const double maxGlassSaturation = 2;
  static const double maxGlassShadowOpacity = 0.4;

  static const double lightGradientOpacity = 0.60;
  static const double darkGradientOpacity = 0.13;
  static const double secondaryGradientOpacity = 0.60;
  static const double tertiaryGradientOpacity = 0.35;
  static const double secondaryGradientHueShift = 30;
  static const double tertiaryGradientHueShift = -30;

  static const double primaryGradientWidth = 1.35;
  static const double primaryGradientHeight = 1.25;
  static const double secondaryGradientWidth = 1.05;
  static const double secondaryGradientHeight = 0.95;
  static const double secondaryGradientTop = 0.48;
  static const double tertiaryGradientWidth = 1.15;
  static const double tertiaryGradientHeight = 0.85;

  /// 保留光晕内侧的颜色，再平缓收尾，避免线性淡出过早露出基底。
  static const gradientStops = <double>[0, 0.2, 0.4, 0.6, 0.8, 0.9, 1];
  static const gradientOpacityFactors = <double>[
    1,
    0.97,
    0.86,
    0.62,
    0.25,
    0.07,
    0,
  ];
}
