import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_text_styles.dart';
import '../token/radius.dart';
import '../token/spacing.dart';

void syncTextControllerText(TextEditingController controller, String text) {
  if (controller.text == text) return;
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}

class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    required this.controller,
    super.key,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.enabled,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final bool? enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: appFormInputDecoration(
        context,
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      textAlign: textAlign,
      autofocus: autofocus,
      style: context.appTextStyles.inputText,
    );
  }
}

class AppDropdownFormField<T> extends StatelessWidget {
  const AppDropdownFormField({
    required this.items,
    required this.onChanged,
    super.key,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
  });

  final T? initialValue;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      decoration: appFormInputDecoration(
        context,
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      style: context.appTextStyles.inputText,
    );
  }
}

InputDecoration appFormInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  Widget? prefixIcon,
}) {
  final colors = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(AppRadius.radiusMd);
  final border = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: colors.outlineVariant),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: colors.surfaceContainerLowest,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.space14,
      vertical: AppSpacing.space12,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: colors.primary, width: 1.4),
    ),
    errorBorder: border.copyWith(borderSide: BorderSide(color: colors.error)),
    focusedErrorBorder: border.copyWith(
      borderSide: BorderSide(color: colors.error, width: 1.4),
    ),
  );
}

class AppPlainTextFormField extends StatelessWidget {
  const AppPlainTextFormField({
    required this.controller,
    super.key,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onFieldSubmitted,
    this.textAlign = TextAlign.left,
    this.readOnly = false,
    this.onTap,
    this.enabled,
    this.autofocus = false,
    this.focusNode,
    this.showCursor,
    this.style,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextAlign textAlign;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool? enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool? showCursor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: appPlainInputDecoration(context, hintText: hintText),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textAlign: textAlign,
      readOnly: readOnly,
      onTap: onTap,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      showCursor: showCursor,
      style: style ?? context.appTextStyles.formPlainValue,
    );
  }
}

InputDecoration appPlainInputDecoration(
  BuildContext context, {
  String? hintText,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    hintStyle: context.appTextStyles.formPlainValue.copyWith(
      color: colors.onSurfaceVariant,
    ),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    isDense: true,
    contentPadding: EdgeInsets.zero,
  );
}
