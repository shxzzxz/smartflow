import 'package:flutter/widgets.dart';

@immutable
class AppBottomNavigationLayout {
  const AppBottomNavigationLayout({
    required this.contentInset,
    required this.floatingActionInset,
  });

  static const none = AppBottomNavigationLayout(
    contentInset: 0,
    floatingActionInset: 0,
  );

  /// 一级页面滚动内容需要额外避让的底部距离。
  final double contentInset;

  /// 页面悬浮按钮需要额外抬升的距离。
  final double floatingActionInset;

  @override
  bool operator ==(Object other) {
    return other is AppBottomNavigationLayout &&
        other.contentInset == contentInset &&
        other.floatingActionInset == floatingActionInset;
  }

  @override
  int get hashCode => Object.hash(contentInset, floatingActionInset);
}

/// 由 App Shell 下发的底部导航覆盖层布局。
///
/// 页面只消费避让尺寸，不感知经典或毛玻璃等具体导航样式。页面脱离 Shell
/// 单独使用时退化为不需要额外避让的普通布局。
class AppBottomNavigationLayoutScope extends InheritedWidget {
  const AppBottomNavigationLayoutScope({
    required this.layout,
    required super.child,
    super.key,
  });

  final AppBottomNavigationLayout layout;

  static AppBottomNavigationLayout of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              AppBottomNavigationLayoutScope
            >()
            ?.layout ??
        AppBottomNavigationLayout.none;
  }

  @override
  bool updateShouldNotify(AppBottomNavigationLayoutScope oldWidget) {
    return layout != oldWidget.layout;
  }
}
