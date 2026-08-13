import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../token/header.dart';
import '../token/radius.dart';

/// 页面头部。承载返回、标题和右上角操作，统一各页面的头部几何与控件规格。
///
/// 标题位需要放置月份选择器、周期选择器或页签等控件时使用 [AppPageHeader.custom]。
///
/// 返回键默认按当前路由能否 pop 自动出现：一级 tab 页不显示，二级页显示。
/// 页面只在需要抑制返回键（[showBackButton] 传 false）或需要接管返回动作
/// （[onBack]，例如离开前确认）时才显式配置。
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required String this.title,
    super.key,
    this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.actions = const [],
  }) : titleContent = null;

  const AppPageHeader.custom({
    required Widget this.titleContent,
    super.key,
    this.showBackButton = true,
    this.onBack,
    this.actions = const [],
  }) : title = null,
       subtitle = null;

  final String? title;
  final Widget? titleContent;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;

  /// 只放 [AppHeaderIconButton] 或 `AppPopupMenuButton`，尺寸由页头统一约束。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final showBack =
        showBackButton &&
        (onBack != null || (Navigator.maybeOf(context)?.canPop() ?? false));

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppHeaderTokens.minHeight),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: _edgeInset(hasIconButton: showBack),
          end: _edgeInset(hasIconButton: actions.isNotEmpty),
        ),
        child: Row(
          children: [
            if (showBack)
              _HeaderBackButton(
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
            Expanded(child: titleContent ?? _buildTitle(context)),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: AppHeaderTokens.titleActionGap),
              _HeaderActions(actions: actions),
            ],
          ],
        ),
      ),
    );
  }

  static double _edgeInset({required bool hasIconButton}) {
    return hasIconButton
        ? AppHeaderTokens.edgeInset - AppHeaderTokens.glyphInset
        : AppHeaderTokens.edgeInset;
  }

  Widget _buildTitle(BuildContext context) {
    final subtitle = this.subtitle;
    final textStyles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title!,
          style: textStyles.pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppHeaderTokens.subtitleGap),
          Text(
            subtitle,
            style: textStyles.pageSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// 页头右上角的图标操作。
class AppHeaderIconButton extends StatelessWidget {
  const AppHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;

  /// 传 null 表示操作当前不可用。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      style: appHeaderIconButtonStyle,
    );
  }
}

/// 页头图标按钮的统一几何：24 字形、48 触控盒。
final ButtonStyle appHeaderIconButtonStyle = IconButton.styleFrom(
  iconSize: AppHeaderTokens.iconSize,
  fixedSize: const Size.square(AppHeaderTokens.iconButtonSize),
  minimumSize: const Size.square(AppHeaderTokens.iconButtonSize),
  padding: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
  ),
);

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(RemixIcons.arrow_left_s_line),
      tooltip: '返回',
      style: appHeaderIconButtonStyle,
    );
  }
}

/// 兜底约束操作区尺寸，避免页面塞入未按页头规格声明的图标按钮。
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return IconButtonTheme(
      data: IconButtonThemeData(style: appHeaderIconButtonStyle),
      child: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}
