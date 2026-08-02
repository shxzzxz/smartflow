import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/form.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import 'app_form_field.dart';
import 'app_switch.dart';

enum AppPlainRowValueAlignment { start, end }

class AppPlainFormSection extends StatelessWidget {
  const AppPlainFormSection({
    required this.children,
    super.key,
    this.spacing = AppSpacing.space4,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(height: spacing),
          children[index],
        ],
      ],
    );
  }
}

class AppPlainFormRow extends StatelessWidget {
  const AppPlainFormRow({
    required this.label,
    required this.child,
    super.key,
    this.onTap,
    this.enabled = true,
    this.requiredIndicator = false,
    this.supportingText,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.errorText,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final bool requiredIndicator;
  final String? supportingText;
  final double labelWidth;
  final double minHeight;
  final CrossAxisAlignment crossAxisAlignment;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final message = errorText ?? supportingText;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              SizedBox(
                width: labelWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: context.appTextStyles.formLabel,
                      ),
                    ),
                    if (requiredIndicator) ...[
                      const SizedBox(width: AppSpacing.space2),
                      Text(
                        '*',
                        style: context.appTextStyles.formLabel.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.space2),
          Padding(
            padding: EdgeInsets.only(left: labelWidth),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    errorText == null ? colors.onSurfaceVariant : colors.error,
              ),
            ),
          ),
        ],
      ],
    );

    final interactive =
        onTap == null
            ? content
            : InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              child: content,
            );
    if (enabled) return interactive;
    return IgnorePointer(
      child: Opacity(
        opacity: AppFormTokens.disabledOpacity,
        child: interactive,
      ),
    );
  }
}

class AppPlainValueRow extends StatelessWidget {
  const AppPlainValueRow({
    required this.label,
    super.key,
    this.value,
    this.child,
    this.onTap,
    this.enabled = true,
    this.valueAlignment = AppPlainRowValueAlignment.end,
    this.valueColor,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
    this.maxLines = 1,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;
  final Widget? child;
  final VoidCallback? onTap;
  final bool enabled;
  final AppPlainRowValueAlignment valueAlignment;
  final Color? valueColor;
  final double labelWidth;
  final double minHeight;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final valueTextAlign =
        valueAlignment == AppPlainRowValueAlignment.end
            ? TextAlign.right
            : TextAlign.left;
    final valueChild =
        child ??
        AppPlainValueText(
          text: value!,
          textAlign: valueTextAlign,
          color: valueColor,
          maxLines: maxLines,
        );

    return AppPlainFormRow(
      label: label,
      labelWidth: labelWidth,
      minHeight: minHeight,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      child: Align(
        alignment:
            valueAlignment == AppPlainRowValueAlignment.end
                ? Alignment.centerRight
                : Alignment.centerLeft,
        child: valueChild,
      ),
    );
  }
}

class AppPlainSwitchRow extends StatelessWidget {
  const AppPlainSwitchRow({
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
    return AppControlledFormField<bool>(
      value: value,
      enabled: enabled,
      onChanged: (nextValue) {
        if (nextValue != null) onChanged(nextValue);
      },
      builder: (context, fieldValue, _, fieldChanged) {
        final description = this.description?.trim();
        final labelStyle = context.appTextStyles.formLabel;
        final descriptionStyle = context.appTextStyles.formSwitchDescription;
        TextStyle styleForState(TextStyle style) {
          if (enabled) return style;
          return style.copyWith(
            color: style.color?.withValues(
              alpha: AppFormTokens.disabledOpacity,
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppFormTokens.rowMinHeight,
          ),
          child: InkWell(
            onTap: enabled ? () => fieldChanged(!(fieldValue ?? value)) : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: styleForState(labelStyle)),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          description,
                          style: styleForState(descriptionStyle),
                        ),
                      ],
                    ],
                  ),
                ),
                AppSwitch(
                  value: fieldValue ?? value,
                  onChanged: enabled ? fieldChanged : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppPlainValueText extends StatelessWidget {
  const AppPlainValueText({
    required this.text,
    super.key,
    this.textAlign = TextAlign.left,
    this.color,
    this.maxLines = 1,
  });

  final String text;
  final TextAlign textAlign;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: context.appTextStyles.formPlainValue.copyWith(color: color),
      ),
    );
  }
}
