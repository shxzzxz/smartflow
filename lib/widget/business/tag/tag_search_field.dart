import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';

/// 标签相关页面共用的搜索输入框。
class TagSearchField extends StatelessWidget {
  const TagSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
    this.hintText = '搜索标签',
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          autofocus: autofocus,
          enabled: enabled,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: context.appTextStyles.inputText,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: context.appTextStyles.inputText.copyWith(
              color: colors.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              RemixIcons.search_line,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            suffixIcon:
                value.text.isEmpty
                    ? null
                    : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(RemixIcons.close_circle_line),
                      tooltip: '清除搜索',
                    ),
            isDense: true,
            filled: true,
            fillColor: colors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space16,
              vertical: AppSpacing.space10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              borderSide: BorderSide(
                color: colors.outlineVariant.withValues(
                  alpha: AppComponentTokens.mutedOutlineOpacity,
                ),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        );
      },
    );
  }
}
