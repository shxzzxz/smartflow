import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../token/component.dart';
import '../token/spacing.dart';

class AppSelectOption<T> {
  const AppSelectOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

typedef AppSelectTriggerBuilder<T> =
    Widget Function(BuildContext context, AppSelectOption<T> selectedOption);

enum AppSelectMenuAlignment { start, end }

enum AppSelectMenuBehavior { adaptive, nested }

/// Owns option selection while callers provide the context-specific trigger.
///
/// Standalone selects use an adaptive anchored menu. Nested selects keep the
/// [PopupMenuButton] route so selecting an option does not dismiss the parent
/// menu.
class AppSelectMenu<T> extends StatefulWidget {
  const AppSelectMenu({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.triggerBuilder,
    this.tooltip = '选择',
    this.alignment = AppSelectMenuAlignment.start,
    this.behavior = AppSelectMenuBehavior.adaptive,
    super.key,
  }) : assert(options.length > 0, '选择菜单至少需要一个选项');

  final List<AppSelectOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final AppSelectTriggerBuilder<T> triggerBuilder;
  final String tooltip;
  final AppSelectMenuAlignment alignment;
  final AppSelectMenuBehavior behavior;

  @override
  State<AppSelectMenu<T>> createState() => _AppSelectMenuState<T>();
}

class _AppSelectMenuState<T> extends State<AppSelectMenu<T>> {
  final _triggerKey = GlobalKey();
  bool _menuOpen = false;

  AppSelectOption<T> get _current => widget.options.firstWhere(
    (option) => option.value == widget.value,
    orElse: () => widget.options.first,
  );

  List<PopupMenuEntry<T>> _items(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return [
      for (final option in widget.options)
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
              if (option.value == widget.value)
                Icon(
                  RemixIcons.check_line,
                  size: AppSpacing.space20,
                  color: colors.primary,
                ),
            ],
          ),
        ),
    ];
  }

  Future<void> _openAdaptiveMenu(BuildContext context) async {
    if (_menuOpen) return;
    setState(() => _menuOpen = true);
    try {
      final selected = await showMenu<T>(
        context: context,
        positionBuilder: (menuContext, constraints) {
          final trigger =
              _triggerKey.currentContext?.findRenderObject() as RenderBox?;
          final overlay =
              Navigator.of(menuContext).overlay?.context.findRenderObject()
                  as RenderBox?;
          if (trigger == null || overlay == null) {
            return RelativeRect.fromLTRB(
              AppSpacing.space8,
              AppSpacing.space8,
              AppSpacing.space8,
              AppSpacing.space8,
            );
          }

          final topLeft = trigger.localToGlobal(Offset.zero, ancestor: overlay);
          final triggerRect = topLeft & trigger.size;
          final screenSize = constraints.biggest;
          final menuHeight =
              widget.options.length * AppComponentTokens.controlMinHeight +
              AppSpacing.space16;
          final below =
              screenSize.height - triggerRect.bottom - AppSpacing.space8;
          final above = triggerRect.top - AppSpacing.space8;
          final openBelow = below >= menuHeight || below >= above;
          final desiredTop =
              openBelow ? triggerRect.bottom : triggerRect.top - menuHeight;
          final top =
              desiredTop
                  .clamp(
                    AppSpacing.space8,
                    math.max(
                      AppSpacing.space8,
                      screenSize.height - menuHeight - AppSpacing.space8,
                    ),
                  )
                  .toDouble();

          final menuWidth = AppComponentTokens.menuMinWidth;
          final desiredLeft =
              widget.alignment == AppSelectMenuAlignment.end
                  ? triggerRect.right - menuWidth
                  : triggerRect.left;
          final left =
              desiredLeft
                  .clamp(
                    AppSpacing.space8,
                    math.max(
                      AppSpacing.space8,
                      screenSize.width - menuWidth - AppSpacing.space8,
                    ),
                  )
                  .toDouble();

          return RelativeRect.fromLTRB(
            left,
            top,
            screenSize.width - left - menuWidth,
            screenSize.height - top - menuHeight,
          );
        },
        initialValue: widget.value,
        constraints: const BoxConstraints(
          minWidth: AppComponentTokens.menuMinWidth,
        ),
        items: _items(context),
      );
      if (selected != null && mounted) widget.onChanged(selected);
    } finally {
      if (mounted) setState(() => _menuOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trigger = KeyedSubtree(
      key: _triggerKey,
      child: widget.triggerBuilder(context, _current),
    );
    if (widget.behavior == AppSelectMenuBehavior.nested) {
      return PopupMenuButton<T>(
        tooltip: widget.tooltip,
        onSelected: widget.onChanged,
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(
          minWidth: AppComponentTokens.menuMinWidth,
        ),
        itemBuilder: (context) => _items(context),
        child: trigger,
      );
    }

    void openMenu() => _openAdaptiveMenu(context);
    return Semantics(
      button: true,
      expanded: _menuOpen,
      onTap: openMenu,
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(onTap: openMenu, child: trigger),
      ),
    );
  }
}
