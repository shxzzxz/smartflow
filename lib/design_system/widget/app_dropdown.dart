import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

class AppDropdownOption<T> {
  const AppDropdownOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// 下拉选择控件：胶囊显示当前值，点击弹出锚定菜单，选中项带对勾。
/// 浮层观感由全局 popupMenuTheme 统一，与 [AppPopupMenuButton] 一致。
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.options,
    required this.value,
    required this.onChanged,
    this.tooltip = '选择',
    super.key,
  }) : assert(options.length > 0, '下拉控件至少需要一个选项');

  final List<AppDropdownOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = options.firstWhere(
      (option) => option.value == value,
      orElse: () => options.first,
    );
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onChanged,
      constraints: const BoxConstraints(
        minWidth: AppComponentTokens.menuMinWidth,
      ),
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
                    if (option.value == value)
                      Icon(
                        RemixIcons.check_line,
                        size: AppSpacing.space20,
                        color: colors.primary,
                      ),
                  ],
                ),
              ),
          ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(current.label, style: context.appTextStyles.formValue),
              const SizedBox(width: AppSpacing.space6),
              Icon(
                RemixIcons.arrow_down_s_line,
                size: AppSpacing.space16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
