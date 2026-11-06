import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_text_styles.dart';
import '../token/form.dart';
import '../token/spacing.dart';
import 'app_form_field.dart';
import 'app_plain_form_row.dart';

/// A multiline form row with an always-visible character counter.
class AppPlainTextAreaFormRow extends FormField<String> {
  AppPlainTextAreaFormRow({
    required this.label,
    required this.controller,
    required this.maxLength,
    super.key,
    this.hintText,
    this.supportingText,
    this.requiredIndicator = false,
    this.minLines = 3,
    this.maxLines = 5,
    this.textInputAction,
    this.onChanged,
    this.focusNode,
    super.validator,
    super.enabled = true,
    super.autovalidateMode = AutovalidateMode.disabled,
    this.labelWidth = AppFormTokens.labelWidth,
    this.minHeight = AppFormTokens.rowMinHeight,
  }) : super(initialValue: controller.text, builder: _buildField);

  final String label;
  final TextEditingController controller;
  final int maxLength;
  final String? hintText;
  final String? supportingText;
  final bool requiredIndicator;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final double labelWidth;
  final double minHeight;

  static Widget _buildField(FormFieldState<String> field) {
    final state = field as _AppPlainTextAreaFormRowState;
    final widget = state.widget;
    final value = field.value ?? widget.controller.text;

    return AppPlainFormRow(
      label: widget.label,
      requiredIndicator: widget.requiredIndicator,
      supportingText: widget.supportingText,
      errorText: field.errorText,
      enabled: widget.enabled,
      labelWidth: widget.labelWidth,
      minHeight: widget.minHeight,
      crossAxisAlignment: CrossAxisAlignment.start,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.space2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              decoration: appPlainInputDecoration(
                field.context,
                hintText: widget.hintText,
              ),
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              textAlignVertical: TextAlignVertical.top,
              textInputAction: widget.textInputAction,
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.maxLength),
              ],
              onChanged: state.handleUserChanged,
              enabled: widget.enabled,
              style: field.context.appTextStyles.formValue,
            ),
            const SizedBox(height: AppSpacing.space4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${value.length}/${widget.maxLength}',
                style: field.context.appTextStyles.formSupporting,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  FormFieldState<String> createState() => _AppPlainTextAreaFormRowState();
}

class _AppPlainTextAreaFormRowState extends FormFieldState<String> {
  @override
  AppPlainTextAreaFormRow get widget => super.widget as AppPlainTextAreaFormRow;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AppPlainTextAreaFormRow oldWidget) {
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
