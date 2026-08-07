import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';

import '../theme/app_text_styles.dart';
import '../token/form.dart';
import '../token/spacing.dart';
import 'app_form_field.dart';
import 'app_plain_form_row.dart';
import 'app_segmented_control.dart';
import 'app_select.dart';

class AppPlainTextFormRow extends FormField<String> {
  AppPlainTextFormRow({
    required this.label,
    required this.controller,
    super.key,
    this.hintText,
    this.supportingText,
    this.requiredIndicator = false,
    this.keyboardType,
    this.inputFormatters,
    super.validator,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.textAlign = TextAlign.left,
    this.readOnly = false,
    this.onTap,
    super.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
    super.autovalidateMode = AutovalidateMode.disabled,
  }) : super(initialValue: controller.text, builder: _buildField);

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? supportingText;
  final bool requiredIndicator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final double labelWidth;
  final double minHeight;

  static Widget _buildField(FormFieldState<String> field) {
    final state = field as _AppPlainTextFormRowState;
    final widget = state.widget;

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
          field.context,
          hintText: widget.hintText,
        ),
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textInputAction: widget.textInputAction,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        onChanged: state.handleUserChanged,
        textAlign: widget.textAlign,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        style: field.context.appTextStyles.formPlainValue,
      ),
    );
  }

  @override
  FormFieldState<String> createState() => _AppPlainTextFormRowState();
}

class _AppPlainTextFormRowState extends FormFieldState<String> {
  @override
  AppPlainTextFormRow get widget => super.widget as AppPlainTextFormRow;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppPlainTextFormRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    setValue(widget.controller.text);
  }

  void _handleControllerChanged() {
    final text = widget.controller.text;
    if (value != text) setValue(text);
  }

  void handleUserChanged(String value) {
    didChange(value);
    widget.onChanged?.call(value);
  }

  @override
  void reset() {
    super.reset();
    final initialText = widget.initialValue ?? '';
    if (widget.controller.text == initialText) return;

    widget.controller.value = TextEditingValue(
      text: initialText,
      selection: TextSelection.collapsed(offset: initialText.length),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
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

typedef AppPlainSelectTap<T> = void Function(ValueChanged<T?> onSelected);

class AppPlainSelectFormRow<T> extends StatelessWidget {
  const AppPlainSelectFormRow({
    required this.label,
    required this.value,
    required this.placeholder,
    super.key,
    this.valueText,
    this.onTap,
    this.onChanged,
    this.validator,
    this.supportingText,
    this.requiredIndicator = false,
    this.enabled = true,
    this.showChevron = true,
    this.valueAlignment = AppPlainRowValueAlignment.start,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  final String label;
  final T? value;
  final String placeholder;
  final String? valueText;
  final AppPlainSelectTap<T>? onTap;
  final ValueChanged<T?>? onChanged;
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
    return AppControlledFormField<T>(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (context, fieldValue, errorText, fieldChanged) {
        final hasValue = fieldValue != null;
        final handleTap = onTap;
        return AppPlainFormRow(
          label: label,
          requiredIndicator: requiredIndicator,
          supportingText: supportingText,
          errorText: errorText,
          onTap: handleTap == null ? null : () => handleTap(fieldChanged),
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
                  text: hasValue ? (valueText ?? '$fieldValue') : placeholder,
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

class AppPlainSelectMenuFormRow<T> extends StatelessWidget {
  const AppPlainSelectMenuFormRow({
    required this.label,
    required this.value,
    required this.options,
    super.key,
    this.onChanged,
    this.tooltip,
    this.supportingText,
    this.validator,
    this.requiredIndicator = false,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final T value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String? tooltip;
  final String? supportingText;
  final FormFieldValidator<T>? validator;
  final bool requiredIndicator;
  final bool enabled;
  final AutovalidateMode autovalidateMode;
  final double labelWidth;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final interactive = enabled && onChanged != null;
    return AppControlledFormField<T>(
      value: value,
      enabled: interactive,
      onChanged: (nextValue) {
        if (nextValue != null) onChanged?.call(nextValue);
      },
      validator: validator,
      autovalidateMode: autovalidateMode,
      builder: (context, fieldValue, errorText, fieldChanged) {
        final selected = options.firstWhere(
          (option) => option.value == (fieldValue ?? value),
          orElse: () => options.first,
        );
        final trigger = AppPlainFormRow(
          label: label,
          requiredIndicator: requiredIndicator,
          supportingText: supportingText,
          errorText: errorText,
          enabled: interactive,
          labelWidth: labelWidth,
          minHeight: minHeight,
          child: Row(
            children: [
              Expanded(
                child: AppPlainValueText(
                  text: selected.label,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: AppSpacing.space6),
              Icon(
                RemixIcons.arrow_down_s_line,
                size: AppSpacing.space20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        );
        if (!interactive) return trigger;
        return AppSelectMenu<T>(
          options: options,
          value: selected.value,
          onChanged: (nextValue) => fieldChanged(nextValue),
          tooltip: tooltip ?? '选择$label',
          alignment: AppSelectMenuAlignment.end,
          triggerBuilder: (context, _) => trigger,
        );
      },
    );
  }
}

class AppPlainSegmentedFormRow<T> extends StatelessWidget {
  const AppPlainSegmentedFormRow({
    required this.label,
    required this.value,
    required this.segments,
    super.key,
    this.onChanged,
    this.supportingText,
    this.validator,
    this.requiredIndicator = false,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final T value;
  final List<AppSegment<T>> segments;
  final ValueChanged<T>? onChanged;
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
          minHeight: minHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppSegmentedControl<T>(
              segments: segments,
              selected: fieldValue ?? value,
              onChanged:
                  interactive ? (nextValue) => fieldChanged(nextValue) : (_) {},
              size: AppSegmentedControlSize.small,
              tone: AppSegmentedControlTone.neutral,
              textStyle: context.appTextStyles.formPlainValue,
            ),
          ),
        );
      },
    );
  }
}
