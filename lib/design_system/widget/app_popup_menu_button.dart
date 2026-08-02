import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../token/component.dart';
import '../token/spacing.dart';
import 'app_switch.dart';

/// 弹出菜单选项；[icon] 为条目前置图标，可省略。
/// [switchValue] 非空时条目按开关项渲染，右侧展示开关状态，点击条目即切换。
/// [child] 可提供不触发菜单选择的自定义内容，例如内嵌选择控件。
class AppPopupMenuOption<T> {
  const AppPopupMenuOption({
    required this.value,
    required this.label,
    this.icon,
    this.switchValue,
    this.child,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool? switchValue;
  final Widget? child;
  final bool enabled;
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
                enabled: option.enabled,
                child:
                    option.child ??
                    Row(
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
                        if (option.switchValue != null) ...[
                          const SizedBox(width: AppSpacing.space12),
                          IgnorePointer(
                            child: AppSwitch(
                              value: option.switchValue!,
                              onChanged: (_) {},
                            ),
                          ),
                        ] else if (selected != null && option.value == selected)
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
