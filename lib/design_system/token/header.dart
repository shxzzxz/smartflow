abstract final class AppHeaderTokens {
  /// 页头最小高度，容纳 48dp 触控目标并保留上下留白。
  static const double minHeight = 56;

  /// 文字与图标字形距屏幕边缘的光学间距，与页面内容水平边距保持一致。
  static const double edgeInset = 16;

  static const double iconSize = 24;
  static const double iconButtonSize = 48;

  /// 图标按钮触控盒内的字形留白。按钮贴边时用它抵消触控盒宽度，
  /// 使字形而非触控盒落在 [edgeInset] 上。
  static const double glyphInset = (iconButtonSize - iconSize) / 2;

  /// 标题与操作区的最小间距，避免长标题贴住操作按钮。
  static const double titleActionGap = 8;

  /// 标题与副标题的行间距。
  static const double subtitleGap = 2;
}
