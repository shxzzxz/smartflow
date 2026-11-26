import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/header.dart';
import '../token/spacing.dart';
import 'app_popup_menu_button.dart';
import 'app_select.dart';

/// 页头单选入口：名称触发锚定菜单，选择与附加动作在执行前关闭菜单。
class AppHeaderSelectButton<T> extends StatefulWidget {
  const AppHeaderSelectButton({
    required this.label,
    required this.tooltip,
    required this.options,
    required this.value,
    required this.onChanged,
    this.actions = const [],
    this.showDropdownIcon = false,
    this.maxWidth = AppHeaderTokens.selectorMaxWidth,
    this.textStyle,
    super.key,
  });

  final String label;
  final String tooltip;
  final List<AppSelectOption<T>> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final List<AppPopupMenuAction> actions;
  final bool showDropdownIcon;
  final double maxWidth;
  final TextStyle? textStyle;

  @override
  State<AppHeaderSelectButton<T>> createState() =>
      _AppHeaderSelectButtonState<T>();
}

class _AppHeaderSelectButtonState<T> extends State<AppHeaderSelectButton<T>> {
  final _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _menuController,
      useRootOverlay: true,
      crossAxisUnconstrained: false,
      consumeOutsideTap: true,
      alignmentOffset: const Offset(0, AppSpacing.space4),
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomStart,
        minimumSize: WidgetStatePropertyAll(
          Size(AppComponentTokens.menuMinWidth, 0),
        ),
        maximumSize: WidgetStatePropertyAll(
          Size(AppComponentTokens.selectionMenuMaxWidth, double.infinity),
        ),
      ),
      menuChildren: [
        for (final option in widget.options)
          MenuItemButton(
            leadingIcon: option.icon == null ? null : Icon(option.icon),
            trailingIcon: option.value == widget.value
                ? Icon(RemixIcons.check_line, color: colors.primary)
                : null,
            style: option.value == widget.value
                ? ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      colors.primary.withValues(
                        alpha: AppComponentTokens.selectedContainerOpacity,
                      ),
                    ),
                  )
                : null,
            onPressed: widget.onChanged == null
                ? null
                : () {
                    _menuController.close();
                    widget.onChanged!(option.value);
                  },
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.listTitle,
            ),
          ),
        if (widget.actions.isNotEmpty) ...[
          const Divider(height: AppSpacing.space16),
          ...widget.actions,
        ],
      ],
      builder: (context, controller, child) => Tooltip(
        message: widget.tooltip,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              minimumSize: const Size(0, AppHeaderTokens.iconButtonSize),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppHeaderTokens.controlRadius,
                ),
              ),
            ),
            onPressed: widget.onChanged == null
                ? null
                : (controller.isOpen ? controller.close : controller.open),
            child: widget.showDropdownIcon
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: _label()),
                      const SizedBox(width: AppSpacing.space4),
                      const Icon(
                        RemixIcons.arrow_down_s_line,
                        size: AppSpacing.space16,
                      ),
                    ],
                  )
                : _label(),
          ),
        ),
      ),
    );
  }

  Widget _label() => Text(
    widget.label,
    style: widget.textStyle,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}
