import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../token/component.dart';
import '../token/spacing.dart';
import 'app_switch.dart';

sealed class AppPopupMenuEntry {}

/// 执行一次命令的菜单项。激活后关闭菜单。
class AppPopupMenuAction extends StatelessWidget implements AppPopupMenuEntry {
  const AppPopupMenuAction({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: icon == null ? null : Icon(icon),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// 受控单选配置项。激活后保持菜单打开。
class AppPopupMenuChoice extends StatelessWidget implements AppPopupMenuEntry {
  const AppPopupMenuChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuItemButton(
      closeOnActivate: false,
      leadingIcon: icon == null ? null : Icon(icon),
      trailingIcon:
          selected
              ? Icon(
                RemixIcons.check_line,
                size: AppSpacing.space20,
                color: colors.primary,
              )
              : null,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// 菜单中的复合配置控件。内部交互不会关闭菜单。
class AppPopupMenuControl extends StatelessWidget implements AppPopupMenuEntry {
  const AppPopupMenuControl({
    required this.label,
    required this.child,
    super.key,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.space8),
            child,
          ],
        ),
      ),
    );
  }
}

/// 布尔配置项。点击整行切换值，菜单保持打开。
class AppPopupMenuToggle extends StatefulWidget implements AppPopupMenuEntry {
  const AppPopupMenuToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  State<AppPopupMenuToggle> createState() => _AppPopupMenuToggleState();
}

class _AppPopupMenuToggleState extends State<AppPopupMenuToggle> {
  late bool _value = widget.value;

  @override
  void didUpdateWidget(covariant AppPopupMenuToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      closeOnActivate: false,
      leadingIcon: widget.icon == null ? null : Icon(widget.icon),
      trailingIcon: IgnorePointer(
        child: AppSwitch(value: _value, onChanged: (_) {}),
      ),
      onPressed: () {
        setState(() => _value = !_value);
        widget.onChanged(_value);
      },
      child: Text(widget.label),
    );
  }
}

/// 紧凑图标触发的弹出菜单。
/// 动作项激活后关闭菜单，配置项在原位更新并保持菜单打开。
class AppPopupMenuButton extends StatelessWidget {
  const AppPopupMenuButton({
    required this.tooltip,
    required this.icon,
    required this.items,
    super.key,
  });

  final List<AppPopupMenuEntry> items;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(AppComponentTokens.menuMinWidth, 0),
        ),
      ),
      menuChildren: items.cast<Widget>(),
      builder: (context, controller, child) {
        return IconButton(
          tooltip: tooltip,
          onPressed: controller.isOpen ? controller.close : controller.open,
          icon: Icon(
            icon,
            size: AppSpacing.space20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          style: const ButtonStyle(
            fixedSize: WidgetStatePropertyAll(Size.square(AppSpacing.space48)),
            minimumSize: WidgetStatePropertyAll(
              Size.square(AppSpacing.space48),
            ),
            padding: WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.space6)),
          ),
        );
      },
    );
  }
}
