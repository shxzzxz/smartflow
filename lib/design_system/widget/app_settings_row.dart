import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/spacing.dart';
import 'app_select.dart';
import 'app_switch.dart';

class AppSettingsSwitchRow extends StatelessWidget {
  const AppSettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
    this.description,
    this.enabled = true,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppSettingsRow(
      label: label,
      description: description,
      enabled: enabled,
      onTap: () => onChanged(!value),
      child: AppSwitch(value: value, onChanged: enabled ? onChanged : null),
    );
  }
}

class AppSettingsSelectRow<T> extends StatelessWidget {
  const AppSettingsSelectRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
    this.description,
    this.tooltip,
  });

  final String label;
  final String? description;
  final T value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return AppSelectMenu<T>(
      value: value,
      options: options,
      onChanged: onChanged,
      tooltip: tooltip ?? '选择$label',
      alignment: AppSelectMenuAlignment.end,
      triggerBuilder: (context, selected) => AppSettingsRow(
        label: label,
        description: description,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selected.label, style: context.appTextStyles.listSupporting),
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              size: AppSpacing.space20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置项的公共行布局。
///
/// 统一标题、说明、最小高度、水平留白与整行点击区域，[child] 只负责
/// 开关、选择值等尾部内容和对应交互。
class AppSettingsRow extends StatelessWidget {
  const AppSettingsRow({
    required this.label,
    required this.child,
    this.description,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String? description;
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppComponentTokens.controlMinHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space12,
          0,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: context.appTextStyles.settingsTitle),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      description!,
                      style: context.appTextStyles.listSupporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            child,
          ],
        ),
      ),
    );
    final interactive = onTap == null
        ? content
        : InkWell(onTap: enabled ? onTap : null, child: content);
    if (enabled) return interactive;
    return IgnorePointer(
      child: Opacity(
        opacity: AppComponentTokens.disabledContentOpacity,
        child: interactive,
      ),
    );
  }
}
