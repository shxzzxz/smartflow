import 'package:flutter/widgets.dart';

import '../theme/app_chrome_theme.dart';

/// 页头内部的样式环境，外部传入的控件在自己的 build 中读取。
class AppHeaderAppearanceScope extends InheritedWidget {
  const AppHeaderAppearanceScope({
    required this.appearance,
    required super.child,
    super.key,
  });

  final AppChromeTheme appearance;

  static AppChromeTheme of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderAppearanceScope>()
          ?.appearance ??
      AppChromeTheme.of(context);

  @override
  bool updateShouldNotify(AppHeaderAppearanceScope oldWidget) =>
      appearance.headerStyle != oldWidget.appearance.headerStyle ||
      appearance.headerControlGlass != oldWidget.appearance.headerControlGlass;
}
