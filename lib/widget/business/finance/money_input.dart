import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/token/form.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';

const moneyInputMaxDigits = 12;

final moneyInputFormatter = TextInputFormatter.withFunction(
  (oldValue, newValue) =>
      _isAcceptedMoneyInputText(newValue.text) ? newValue : oldValue,
);

String appendMoneyInputText(String current, String input) {
  if (input == '.') {
    if (current.contains('.')) return current;
    final next = current.isEmpty ? '0.' : '$current.';
    return _isAcceptedMoneyInputText(next) ? next : current;
  }

  if (input.length != 1 || !RegExp(r'^\d$').hasMatch(input)) {
    return current;
  }

  final next = current == '0' ? input : '$current$input';
  return _isAcceptedMoneyInputText(next) ? next : current;
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
  if (!_isValidMoneyValueText(value?.trim() ?? '')) return invalidMessage;
  final money = Money.tryParse(value);
  if (money == null) return invalidMessage;
  return money.minorUnits > 0 ? null : nonPositiveMessage;
}

String? validateNonNegativeMoneyText(
  String? value, {
  String invalidMessage = '请输入有效金额',
  String negativeMessage = '金额不能小于 0',
}) {
  if (!_isValidMoneyValueText(value?.trim() ?? '')) return invalidMessage;
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

bool _isAcceptedMoneyInputText(String text) {
  if (!RegExp(r'^-?\d*\.?\d{0,2}$').hasMatch(text)) return false;
  final digitCount = text.replaceAll(RegExp(r'[-.]'), '').length;
  if (digitCount > moneyInputMaxDigits) return false;
  return !(text.endsWith('.') && digitCount >= moneyInputMaxDigits);
}

bool _isValidMoneyValueText(String text) {
  if (!RegExp(r'^-?\d*\.?\d{0,2}$').hasMatch(text)) return false;
  return text.replaceAll(RegExp(r'[-.]'), '').length <= moneyInputMaxDigits;
}

class MoneyPlainFormRow extends StatefulWidget {
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
  State<MoneyPlainFormRow> createState() => _MoneyPlainFormRowState();
}

class _MoneyPlainFormRowState extends State<MoneyPlainFormRow> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPlainTextFormRow(
      label: widget.label,
      controller: widget.controller,
      focusNode: _focusNode,
      hintText: widget.hintText,
      supportingText: widget.supportingText,
      suffixIcon: _MoneyInputClearButton(
        label: widget.label,
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
      ),
      requiredIndicator: widget.requiredIndicator,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [moneyInputFormatter],
      validator: widget.validator,
      onChanged: widget.onChanged,
      textAlign: widget.textAlign,
      minHeight: widget.minHeight,
    );
  }
}

class _MoneyInputClearButton extends StatelessWidget {
  const _MoneyInputClearButton({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return ListenableBuilder(
          listenable: focusNode,
          builder: (context, _) {
            return SizedBox(
              width: AppSpacing.space48,
              height: AppSpacing.space48,
              child: !focusNode.hasFocus || value.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged?.call('');
                      },
                      tooltip: '清空$label',
                      icon: const Icon(
                        RemixIcons.close_circle_line,
                        size: AppSpacing.space18,
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}
