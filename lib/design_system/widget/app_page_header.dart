import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../theme/app_chrome_theme.dart';
import '../token/component.dart';
import '../token/header.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_frosted_surface.dart';
import 'app_header_appearance_scope.dart';
import 'app_header_control_surface.dart';
import 'app_page_header_background_scope.dart';

/// 三段页头：左侧控制、中间核心内容、右侧操作。
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
    this.leading,
    this.actions = const [],
  }) : titleContent = null;

  const AppPageHeader.custom({
    required Widget this.titleContent,
    super.key,
    this.showBackButton = true,
    this.onBack,
    this.leading,
    this.actions = const [],
  }) : title = null,
       subtitle = null;

  final String? title;
  final Widget? titleContent;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;

  /// 选择器或切换控件；提供时替代自动返回按钮。
  final Widget? leading;

  /// 只放 [AppHeaderIconButton]、[AppHeaderTextButton] 或
  /// `AppPopupMenuButton`，尺寸由页头统一约束。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final appearance = AppChromeTheme.of(context);
    final showBack =
        showBackButton &&
        (onBack != null || (Navigator.maybeOf(context)?.canPop() ?? false));

    final left =
        leading ??
        (showBack
            ? AppHeaderIconButton(
                icon: RemixIcons.arrow_left_s_line,
                tooltip: '返回',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null);

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppHeaderTokens.minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppHeaderTokens.edgeInset,
          vertical: AppHeaderTokens.verticalInset,
        ),
        child: _HeaderLayout(
          textDirection: Directionality.of(context),
          keepCenterComplete: titleContent != null,
          leading: left == null
              ? const SizedBox.shrink()
              : AppHeaderControlSurface(
                  borderRadius: AppHeaderTokens.controlRadius,
                  child: IconButtonTheme(
                    data: IconButtonThemeData(
                      style: appHeaderIconButtonStyle.copyWith(
                        foregroundColor: WidgetStatePropertyAll(
                          Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    child: left,
                  ),
                ),
          center: titleContent ?? _buildTitle(context),
          trailing: actions.isEmpty
              ? const SizedBox.shrink()
              : _HeaderActions(actions: actions),
        ),
      ),
    );
    return AppHeaderAppearanceScope(
      appearance: appearance,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -AppPageHeaderBackgroundScope.topInsetOf(context),
            bottom: 0,
            left: 0,
            right: 0,
            child: appearance.usesGlassHeader
                ? AppFrostedSurface(
                    variant: AppFrostedSurfaceVariant.background,
                    borderRadius: AppSpacing.space0,
                    glass: appearance.headerBackgroundGlass,
                    child: const SizedBox.expand(),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant
                              .withValues(
                                alpha: AppComponentTokens.mutedOutlineOpacity,
                              ),
                          width: AppComponentTokens.outlineWidth,
                        ),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final subtitle = this.subtitle;
    final textStyles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title!,
          textAlign: TextAlign.center,
          style: textStyles.pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppHeaderTokens.subtitleGap),
          Text(
            subtitle,
            textAlign: TextAlign.center,
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
    this.selected,
  });

  final IconData icon;
  final String tooltip;
  final bool? selected;

  /// 传 null 表示操作当前不可用。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      isSelected: selected,
      style: appHeaderIconButtonStyle.copyWith(
        backgroundColor: selected == true
            ? WidgetStatePropertyAll(
                Theme.of(context).colorScheme.primary.withValues(
                  alpha: AppComponentTokens.selectedContainerOpacity,
                ),
              )
            : null,
      ),
    );
  }
}

/// 页头右上角的文字操作，使用与图标操作一致的触控高度和圆角。
class AppHeaderTextButton extends StatelessWidget {
  const AppHeaderTextButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.loading = false,
  });

  final String label;
  final bool loading;

  /// 传 null 表示操作当前不可用。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: loading ? null : onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(
          AppHeaderTokens.iconButtonSize,
          AppHeaderTokens.iconButtonSize,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
        ),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: AppHeaderTokens.loadingIndicatorSize,
              child: CircularProgressIndicator(
                strokeWidth: AppComponentTokens.focusedOutlineWidth,
              ),
            )
          : Text(label, maxLines: 1),
    );
  }
}

/// 页头图标按钮的共享样式，几何参数由页头 token 提供。
final ButtonStyle appHeaderIconButtonStyle = IconButton.styleFrom(
  iconSize: AppHeaderTokens.iconSize,
  fixedSize: const Size.square(AppHeaderTokens.iconButtonSize),
  minimumSize: const Size.square(AppHeaderTokens.iconButtonSize),
  maximumSize: const Size.square(AppHeaderTokens.iconButtonSize),
  padding: EdgeInsets.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.standard,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppHeaderTokens.controlRadius),
  ),
);

/// 兜底约束操作区尺寸，避免页面塞入未按页头规格声明的图标按钮。
class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppHeaderControlSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppHeaderTokens.actionGroupInset,
        ),
        child: IconButtonTheme(
          data: IconButtonThemeData(
            style: appHeaderIconButtonStyle.copyWith(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.disabled)
                    ? colors.onSurface.withValues(
                        alpha: AppComponentTokens.disabledContentOpacity,
                      )
                    : colors.primary;
              }),
            ),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  SizedBox(
                    width: AppComponentTokens.outlineWidth,
                    height: AppHeaderTokens.actionDividerHeight,
                    child: ColoredBox(
                      color: colors.outlineVariant.withValues(
                        alpha: AppComponentTokens.mutedOutlineOpacity,
                      ),
                    ),
                  ),
                actions[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 先测量两侧，再给中心对称留空；完整控件放不下时使用第二行。
class _HeaderLayout extends MultiChildRenderObjectWidget {
  _HeaderLayout({
    required this.textDirection,
    required this.keepCenterComplete,
    required Widget leading,
    required Widget center,
    required Widget trailing,
  }) : super(children: [leading, center, trailing]);

  final TextDirection textDirection;
  final bool keepCenterComplete;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeaderLayout(
    textDirection: textDirection,
    keepCenterComplete: keepCenterComplete,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderHeaderLayout renderObject,
  ) {
    renderObject.update(textDirection, keepCenterComplete);
  }
}

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderHeaderLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  _RenderHeaderLayout({
    required TextDirection textDirection,
    required bool keepCenterComplete,
  }) : _textDirection = textDirection,
       _keepCenterComplete = keepCenterComplete;

  TextDirection _textDirection;
  bool _keepCenterComplete;

  void update(TextDirection direction, bool keepCenterComplete) {
    if (_textDirection == direction &&
        _keepCenterComplete == keepCenterComplete) {
      return;
    }
    _textDirection = direction;
    _keepCenterComplete = keepCenterComplete;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData) {
      child.parentData = _HeaderParentData();
    }
  }

  ({Size size, List<Offset> offsets}) _computeLayout(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) layout,
  ) {
    assert(constraints.hasBoundedWidth, '页头需要有界的页面宽度');
    final width = constraints.maxWidth;
    final leading = firstChild!;
    final center = childAfter(leading)!;
    final trailing = childAfter(center)!;
    final sideConstraints = BoxConstraints(maxWidth: width / 2);
    final left = layout(leading, sideConstraints);
    final right = layout(trailing, sideConstraints);
    final sideWidth = math.max(left.width, right.width);
    final gap = sideWidth == 0 ? 0.0 : AppHeaderTokens.titleActionGap;
    final centerWidth = math.max(0.0, width - (sideWidth + gap) * 2);
    var middle = layout(center, BoxConstraints(maxWidth: width));
    final secondRow =
        middle.width > centerWidth &&
        (_keepCenterComplete ||
            centerWidth < AppHeaderTokens.minimumCenterWidth);
    if (!secondRow && middle.width > centerWidth) {
      middle = layout(center, BoxConstraints(maxWidth: centerWidth));
    }
    final sideHeight = math.max(left.height, right.height);
    final contentHeight = secondRow
        ? sideHeight + AppHeaderTokens.titleActionGap + middle.height
        : math.max(sideHeight, middle.height);
    final size = constraints.constrain(Size(width, contentHeight));
    final rowHeight = secondRow ? sideHeight : size.height;
    final rtl = _textDirection == TextDirection.rtl;
    return (
      size: size,
      offsets: [
        Offset(rtl ? width - left.width : 0, (rowHeight - left.height) / 2),
        Offset(
          (width - middle.width) / 2,
          secondRow
              ? sideHeight + AppHeaderTokens.titleActionGap
              : (rowHeight - middle.height) / 2,
        ),
        Offset(rtl ? 0 : width - right.width, (rowHeight - right.height) / 2),
      ],
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _computeLayout(
    constraints,
    (child, childConstraints) => child.getDryLayout(childConstraints),
  ).size;

  @override
  void performLayout() {
    final result = _computeLayout(constraints, (child, childConstraints) {
      child.layout(childConstraints, parentUsesSize: true);
      return child.size;
    });
    size = result.size;
    var child = firstChild;
    for (final offset in result.offsets) {
      (child!.parentData! as _HeaderParentData).offset = offset;
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
