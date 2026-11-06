import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/component.dart';
import '../token/form.dart';
import '../token/spacing.dart';
import '../token/typography.dart';
import 'app_form_field.dart';
import 'app_plain_form_row.dart';

class AppChoiceChipOption<T> {
  const AppChoiceChipOption({required this.value, required this.label});

  final T value;
  final String label;
}

enum AppChoiceChipLayout { wrap, equalWidth }

enum AppChoiceChipSize { regular, compact }

/// A compact single-choice control for short, mutually exclusive options.
class AppChoiceChipGroup<T> extends StatelessWidget {
  const AppChoiceChipGroup({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
    this.layout = AppChoiceChipLayout.wrap,
    this.size = AppChoiceChipSize.regular,
    this.enabled = true,
  }) : assert(options.length > 0, '选项至少需要一个');

  final List<AppChoiceChipOption<T>> options;
  final T selected;
  final ValueChanged<T>? onChanged;
  final AppChoiceChipLayout layout;
  final AppChoiceChipSize size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    final spacing = _choiceChipSpacing(size);
    final chips = [
      for (final option in options)
        _ChoiceChip(
          label: option.label,
          selected: option.value == selected,
          enabled: interactive,
          size: size,
          onTap: () => onChanged?.call(option.value),
        ),
    ];

    final content = switch (layout) {
      AppChoiceChipLayout.wrap => Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: chips,
      ),
      AppChoiceChipLayout.equalWidth => Row(
        children: [
          for (var index = 0; index < chips.length; index++) ...[
            if (index > 0) SizedBox(width: spacing),
            Expanded(child: chips[index]),
          ],
        ],
      ),
    };
    if (enabled) return content;
    return IgnorePointer(
      child: Opacity(opacity: AppFormTokens.disabledOpacity, child: content),
    );
  }
}

/// Form-row adapter for [AppChoiceChipGroup], including label and validation.
///
/// [reservedRows] keeps wrapped and single-row groups at the same height while
/// the content is within the reserved row count.
class AppPlainChoiceChipFormRow<T> extends StatelessWidget {
  const AppPlainChoiceChipFormRow({
    required this.label,
    required this.value,
    required this.options,
    super.key,
    this.onChanged,
    this.layout = AppChoiceChipLayout.wrap,
    this.size = AppChoiceChipSize.compact,
    this.reservedRows = 2,
    this.supportingText,
    this.validator,
    this.requiredIndicator = false,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
  }) : assert(reservedRows > 0, '至少保留一行选项');

  final String label;
  final T value;
  final List<AppChoiceChipOption<T>> options;
  final ValueChanged<T>? onChanged;
  final AppChoiceChipLayout layout;
  final AppChoiceChipSize size;
  final int reservedRows;
  final String? supportingText;
  final FormFieldValidator<T>? validator;
  final bool requiredIndicator;
  final bool enabled;
  final AutovalidateMode autovalidateMode;
  final double labelWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    final reservedHeight =
        _choiceChipMinHeight(context, size) * reservedRows +
        _choiceChipSpacing(size) * (reservedRows - 1);
    final effectiveMinHeight = reservedHeight > minHeight
        ? reservedHeight
        : minHeight;
    return AppControlledFormField<T>(
      value: value,
      enabled: interactive,
      onChanged: (nextValue) {
        if (nextValue != null) onChanged?.call(nextValue);
      },
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (context, fieldValue, errorText, fieldChanged) {
        return AppPlainFormRow(
          label: label,
          enabled: interactive,
          requiredIndicator: requiredIndicator,
          supportingText: supportingText,
          errorText: errorText,
          labelWidth: labelWidth,
          minHeight: effectiveMinHeight,
          child: AppChoiceChipGroup<T>(
            options: options,
            selected: fieldValue ?? value,
            layout: layout,
            size: size,
            enabled: interactive,
            onChanged: fieldChanged,
          ),
        );
      },
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.size,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final AppChoiceChipSize size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurfaceVariant;
    final compact = size == AppChoiceChipSize.compact;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? colors.primary.withValues(
                alpha: AppComponentTokens.selectedContainerOpacity,
              )
            : colors.surfaceContainerLowest,
        shape: StadiumBorder(
          side: BorderSide(
            width: selected
                ? AppComponentTokens.focusedOutlineWidth
                : AppComponentTokens.outlineWidth,
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: _choiceChipMinHeight(context, size),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppSpacing.space6 : AppSpacing.space14,
                vertical: AppSpacing.space6,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.formValue
                      .copyWith(
                        color: foreground,
                        fontSize: compact
                            ? AppTypography.fontSizeXs
                            : AppTypography.fontSizeMd,
                        height: compact ? 1.2 : null,
                      )
                      .copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _choiceChipMinHeight(BuildContext context, AppChoiceChipSize size) {
  if (size == AppChoiceChipSize.regular) return AppSpacing.space32;
  final scaledLineHeight = MediaQuery.textScalerOf(
    context,
  ).scale(AppTypography.fontSizeSm * 1.2);
  final paddedHeight = scaledLineHeight + AppSpacing.space12;
  return paddedHeight > AppSpacing.space32 ? paddedHeight : AppSpacing.space32;
}

double _choiceChipSpacing(AppChoiceChipSize size) {
  return size == AppChoiceChipSize.compact
      ? AppSpacing.space6
      : AppSpacing.space8;
}
