import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_text_styles.dart';
import '../token/form.dart';
import '../token/spacing.dart';
import 'app_form_field.dart';
import 'app_plain_form_row.dart';

class AppPlainTextFormRow extends StatefulWidget {
  const AppPlainTextFormRow({
    required this.label,
    required this.controller,
    super.key,
    this.hintText,
    this.supportingText,
    this.requiredIndicator = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.textAlign = TextAlign.left,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? supportingText;
  final bool requiredIndicator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final double labelWidth;
  final double minHeight;
  final AutovalidateMode autovalidateMode;

  @override
  State<AppPlainTextFormRow> createState() => _AppPlainTextFormRowState();
}

class _AppPlainTextFormRowState extends State<AppPlainTextFormRow> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  void didUpdateWidget(covariant AppPlainTextFormRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final field = _fieldKey.currentState;
    if (field != null && field.value != widget.controller.text) {
      field.didChange(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      enabled: widget.enabled,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      builder: (field) {
        return AppPlainFormRow(
          label: widget.label,
          requiredIndicator: widget.requiredIndicator,
          supportingText: widget.supportingText,
          errorText: field.errorText,
          enabled: widget.enabled,
          labelWidth: widget.labelWidth,
          minHeight: widget.minHeight,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            decoration: appPlainInputDecoration(
              context,
              hintText: widget.hintText,
            ),
            keyboardType: widget.keyboardType,
            inputFormatters: widget.inputFormatters,
            textInputAction: widget.textInputAction,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            onChanged: (value) {
              field.didChange(value);
              widget.onChanged?.call(value);
            },
            textAlign: widget.textAlign,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            style: context.appTextStyles.formPlainValue,
          ),
        );
      },
    );
  }
}

class AppPlainIntegerFormRow extends StatelessWidget {
  const AppPlainIntegerFormRow({
    required this.label,
    required this.controller,
    required this.hintText,
    super.key,
    this.validator,
    this.requiredIndicator = false,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final bool requiredIndicator;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainTextFormRow(
      label: label,
      controller: controller,
      hintText: hintText,
      requiredIndicator: requiredIndicator,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
      minHeight: minHeight,
    );
  }
}

class AppPlainSelectFormRow<T> extends StatelessWidget {
  const AppPlainSelectFormRow({
    required this.label,
    required this.value,
    required this.placeholder,
    super.key,
    this.valueText,
    this.onTap,
    this.validator,
    this.supportingText,
    this.requiredIndicator = false,
    this.enabled = true,
    this.showChevron = true,
    this.valueAlignment = AppPlainRowValueAlignment.end,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  final String label;
  final T? value;
  final String placeholder;
  final String? valueText;
  final VoidCallback? onTap;
  final FormFieldValidator<T>? validator;
  final String? supportingText;
  final bool requiredIndicator;
  final bool enabled;
  final bool showChevron;
  final AppPlainRowValueAlignment valueAlignment;
  final double labelWidth;
  final double minHeight;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FormField<T>(
      key: ValueKey(value),
      initialValue: value,
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (field) {
        final hasValue = value != null;
        return AppPlainFormRow(
          label: label,
          requiredIndicator: requiredIndicator,
          supportingText: supportingText,
          errorText: field.errorText,
          onTap: onTap,
          enabled: enabled,
          labelWidth: labelWidth,
          minHeight: minHeight,
          child: Row(
            mainAxisAlignment:
                valueAlignment == AppPlainRowValueAlignment.end
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
            children: [
              Expanded(
                child: AppPlainValueText(
                  text: hasValue ? (valueText ?? '$value') : placeholder,
                  textAlign:
                      valueAlignment == AppPlainRowValueAlignment.end
                          ? TextAlign.right
                          : TextAlign.left,
                  color: hasValue ? null : colors.onSurfaceVariant,
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: AppSpacing.space6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppSpacing.space20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
