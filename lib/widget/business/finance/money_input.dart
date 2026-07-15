import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/token/form.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';

final moneyInputFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,2}'),
);

String appendMoneyInputText(String current, String input) {
  if (input == '.') {
    if (current.contains('.')) return current;
    return current.isEmpty ? '0.' : '$current.';
  }

  if (input.length != 1 || !RegExp(r'^\d$').hasMatch(input)) {
    return current;
  }

  final next = current == '0' ? input : '$current$input';
  final decimalIndex = next.indexOf('.');
  if (decimalIndex >= 0 && next.length - decimalIndex > 3) {
    return current;
  }
  return next;
}

String deleteLastMoneyInputText(String current) {
  if (current.isEmpty) return current;
  return current.substring(0, current.length - 1);
}

String? validatePositiveMoneyText(
  String? value, {
  String invalidMessage = '请输入有效金额',
  String nonPositiveMessage = '金额必须大于 0',
}) {
  final money = Money.tryParse(value);
  if (money == null) return invalidMessage;
  return money.minorUnits > 0 ? null : nonPositiveMessage;
}

String? validateNonNegativeMoneyText(
  String? value, {
  String invalidMessage = '请输入有效金额',
  String negativeMessage = '金额不能小于 0',
}) {
  final money = Money.tryParse(value);
  if (money == null) return invalidMessage;
  return money.minorUnits >= 0 ? null : negativeMessage;
}

String? validateOptionalNonNegativeMoneyText(
  String? value, {
  String invalidMessage = '请输入有效金额',
  String negativeMessage = '金额不能小于 0',
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return validateNonNegativeMoneyText(
    trimmed,
    invalidMessage: invalidMessage,
    negativeMessage: negativeMessage,
  );
}

int? parseMoneyMinorUnitsOrNull(String? value) {
  return Money.tryParse(value)?.minorUnits;
}

class MoneyPlainFormRow extends StatelessWidget {
  const MoneyPlainFormRow({
    required this.label,
    required this.controller,
    super.key,
    this.hintText,
    this.supportingText,
    this.requiredIndicator = false,
    this.validator,
    this.onChanged,
    this.textAlign = TextAlign.left,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? supportingText;
  final bool requiredIndicator;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainTextFormRow(
      label: label,
      controller: controller,
      hintText: hintText,
      supportingText: supportingText,
      requiredIndicator: requiredIndicator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [moneyInputFormatter],
      validator: validator,
      onChanged: onChanged,
      textAlign: textAlign,
      minHeight: minHeight,
    );
  }
}
