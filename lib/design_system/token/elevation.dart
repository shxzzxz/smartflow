import 'package:flutter/material.dart';

abstract final class AppElevation {
  static const double surfaceShadowOpacity = 0.05;
  static const double surfaceShadowBlur = 20;
  static const Offset surfaceShadowOffset = Offset(0, 4);
  static const double frostedShadowOpacity = 0.10;
  static const double frostedShadowBlur = 24;

  /// 外阴影与半透明表面同位，避免错位轮廓形成第二层玻璃底座。
  static const Offset frostedShadowOffset = Offset.zero;
}
