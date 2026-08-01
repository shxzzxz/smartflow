import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../token/component.dart';
import '../token/spacing.dart';

/// 弹出菜单选项；[icon] 为条目前置图标，可省略。
class AppPopupMenuOption<T> {
  const AppPopupMenuOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// 紧凑图标触发的弹出菜单，容器观感由全局 popupMenuTheme 统一。
/// 传入 [selected] 时按单选菜单渲染，选中项右侧带对勾；省略则为纯动作菜单。
class AppPopupMenuButton<T> extends StatelessWidget {
  const AppPopupMenuButton({
    required this.options,
    required this.onSelected,
    required this.tooltip,
    required this.icon,
    this.selected,
    super.key,
  });

  final List<AppPopupMenuOption<T>> options;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final IconData icon;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: AppSpacing.space20,
        color: colors.onSurfaceVariant,
      ),
      style: const ButtonStyle(
        fixedSize: WidgetStatePropertyAll(Size.square(AppSpacing.space32)),
        minimumSize: WidgetStatePropertyAll(Size.square(AppSpacing.space32)),
        padding: WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.space6)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      constraints: const BoxConstraints(
        minWidth: AppComponentTokens.menuMinWidth,
      ),
      onSelected: onSelected,
      itemBuilder:
          (context) => [
            for (final option in options)
              PopupMenuItem(
                value: option.value,
                child: Row(
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: AppSpacing.space20,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.space12),
                    ],
                    Expanded(child: Text(option.label)),
                    if (selected != null && option.value == selected)
                      Icon(
                        RemixIcons.check_line,
                        size: AppSpacing.space20,
                        color: colors.primary,
                      ),
                  ],
                ),
              ),
          ],
    );
  }
}
