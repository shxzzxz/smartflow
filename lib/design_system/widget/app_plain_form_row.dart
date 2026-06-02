import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

enum AppPlainRowValueAlignment { start, end }

class AppPlainFormSection extends StatelessWidget {
  const AppPlainFormSection({
    required this.children,
    super.key,
    this.spacing = 0,
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
    this.labelWidth = 92,
    this.minHeight = 56,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.errorText,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final double labelWidth;
  final double minHeight;
  final CrossAxisAlignment crossAxisAlignment;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                child: Text(label, style: context.appTextStyles.formValue),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.space2),
          Padding(
            padding: EdgeInsets.only(left: labelWidth),
            child: Text(
              errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: content,
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
    this.labelWidth = 92,
    this.minHeight = 56,
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
    this.labelWidth = 92,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormRow(
      label: label,
      labelWidth: labelWidth,
      minHeight: 56,
      child: Align(
        alignment: Alignment.centerRight,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
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
