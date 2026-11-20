import 'package:flutter/material.dart';

import '../../application/shared/app_appearance_settings.dart';
import 'app_appearance_values.dart';

/// 导航栏与页头的完整视觉参数，由应用设置映射到主题。
@immutable
class AppChromeTheme extends ThemeExtension<AppChromeTheme> {
  const AppChromeTheme({
    required this.headerStyle,
    required this.navigationGlass,
    required this.headerBackgroundGlass,
    required this.headerControlGlass,
  });

  factory AppChromeTheme.fromAppearance(AppAppearanceSettings appearance) {
    final resolved = AppAppearanceValues.resolve(appearance);
    return AppChromeTheme(
      headerStyle: resolved.headerStyle,
      navigationGlass: resolved.navigationGlass,
      headerBackgroundGlass: resolved.headerBackgroundGlass,
      headerControlGlass: resolved.headerControlGlass,
    );
  }

  static final defaults = AppChromeTheme.fromAppearance(
    const AppAppearanceSettings(),
  );

  static AppChromeTheme of(BuildContext context) =>
      Theme.of(context).extension<AppChromeTheme>() ?? defaults;

  final AppHeaderStyle headerStyle;
  final AppGlassSettings navigationGlass;
  final AppGlassSettings headerBackgroundGlass;
  final AppGlassSettings headerControlGlass;

  bool get usesGlassHeader => headerStyle == AppHeaderStyle.frostedGlass;

  @override
  AppChromeTheme copyWith({
    AppHeaderStyle? headerStyle,
    AppGlassSettings? navigationGlass,
    AppGlassSettings? headerBackgroundGlass,
    AppGlassSettings? headerControlGlass,
  }) => AppChromeTheme(
    headerStyle: headerStyle ?? this.headerStyle,
    navigationGlass: navigationGlass ?? this.navigationGlass,
    headerBackgroundGlass: headerBackgroundGlass ?? this.headerBackgroundGlass,
    headerControlGlass: headerControlGlass ?? this.headerControlGlass,
  );

  @override
  AppChromeTheme lerp(covariant AppChromeTheme? other, double t) {
    if (other == null) return this;
    AppGlassSettings glass(
      AppGlassSettings a,
      AppGlassSettings b,
    ) => AppGlassSettings(
      blurSigma: a.blurSigma + (b.blurSigma - a.blurSigma) * t,
      backgroundOpacity:
          a.backgroundOpacity + (b.backgroundOpacity - a.backgroundOpacity) * t,
      saturation: a.saturation + (b.saturation - a.saturation) * t,
      shadowOpacity: a.shadowOpacity + (b.shadowOpacity - a.shadowOpacity) * t,
    );
    return AppChromeTheme(
      headerStyle: t < 0.5 ? headerStyle : other.headerStyle,
      navigationGlass: glass(navigationGlass, other.navigationGlass),
      headerBackgroundGlass: glass(
        headerBackgroundGlass,
        other.headerBackgroundGlass,
      ),
      headerControlGlass: glass(headerControlGlass, other.headerControlGlass),
    );
  }
}
