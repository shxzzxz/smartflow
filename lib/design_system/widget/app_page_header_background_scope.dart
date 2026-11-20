import 'package:flutter/widgets.dart';

/// 页面壳在 SafeArea 消费前保留顶部系统边距，供页头背景覆盖状态栏。
/// 这个值只影响背景绘制，不增加控件或页面内容的避让尺寸。
class AppPageHeaderBackgroundScope extends InheritedWidget {
  const AppPageHeaderBackgroundScope({
    required this.topInset,
    required super.child,
    super.key,
  });

  final double topInset;

  static double topInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppPageHeaderBackgroundScope>()
          ?.topInset ??
      0;

  @override
  bool updateShouldNotify(AppPageHeaderBackgroundScope oldWidget) =>
      topInset != oldWidget.topInset;
}
