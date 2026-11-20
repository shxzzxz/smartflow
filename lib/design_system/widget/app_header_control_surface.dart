import 'package:flutter/material.dart';

import '../token/radius.dart';
import 'app_frosted_surface.dart';
import 'app_header_appearance_scope.dart';

/// 顶部控件的共享外壳；经典样式保留交互层，玻璃样式提供悬浮表面。
class AppHeaderControlSurface extends StatelessWidget {
  const AppHeaderControlSurface({
    required this.child,
    super.key,
    this.borderRadius = AppRadius.radiusFull,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final appearance = AppHeaderAppearanceScope.of(context);
    if (appearance.usesGlassHeader) {
      return AppFrostedSurface(
        borderRadius: borderRadius,
        glass: appearance.headerControlGlass,
        child: child,
      );
    }
    return Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }
}
