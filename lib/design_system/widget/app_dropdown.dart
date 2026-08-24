import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_select.dart';

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

  final List<AppSelectOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSelectMenu<T>(
      options: options,
      value: value,
      onChanged: onChanged,
      tooltip: tooltip,
      triggerBuilder: (context, current) => DecoratedBox(
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
              Text(
                current.label,
                style: context.appTextStyles.formValueEmphasis,
              ),
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
