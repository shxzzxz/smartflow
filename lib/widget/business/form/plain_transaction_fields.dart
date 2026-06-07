import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';
import 'package:smartflow/design_system/widget/app_plain_form_row.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';

import '../icon/business_icon.dart';

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

bool containsAccount(List<Account> accounts, String? accountId) {
  if (accountId == null) return false;
  return accounts.any((account) => account.id == accountId);
}

Account? findAccountById(String? accountId, List<Account> accounts) {
  if (accountId == null) return null;
  for (final account in accounts) {
    if (account.id == accountId) return account;
  }
  return null;
}

String? effectiveAccountId(String? selectedId, List<Account> accounts) {
  if (containsAccount(accounts, selectedId)) return selectedId;
  return accounts.isEmpty ? null : accounts.first.id;
}

Account? effectiveAccount(String? selectedId, List<Account> accounts) {
  return findAccountById(effectiveAccountId(selectedId, accounts), accounts);
}

class MoneyPlainFormRow extends StatelessWidget {
  const MoneyPlainFormRow({
    required this.label,
    required this.controller,
    super.key,
    this.hintText,
    this.validator,
    this.onChanged,
    this.textAlign = TextAlign.left,
    this.minHeight = 56,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormRow(
      label: label,
      minHeight: minHeight,
      child: AppPlainTextFormField(
        controller: controller,
        hintText: hintText,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [moneyInputFormatter],
        validator: validator,
        onChanged: onChanged,
        textAlign: textAlign,
      ),
    );
  }
}

class NotePlainFormRow extends StatelessWidget {
  const NotePlainFormRow({
    required this.controller,
    super.key,
    this.label = '备注',
    this.hintText = '请输入备注（可选）',
    this.textAlign = TextAlign.left,
    this.minHeight = 56,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextAlign textAlign;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormRow(
      label: label,
      minHeight: minHeight,
      child: AppPlainTextFormField(
        controller: controller,
        hintText: hintText,
        maxLines: 1,
        textAlign: textAlign,
      ),
    );
  }
}

class DateTimePlainFormRow extends StatelessWidget {
  const DateTimePlainFormRow({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
    this.valueAlignment = AppPlainRowValueAlignment.start,
    this.minHeight = 56,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final AppPlainRowValueAlignment valueAlignment;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainValueRow(
      label: label,
      value: value,
      onTap: onTap,
      valueAlignment: valueAlignment,
      minHeight: minHeight,
    );
  }
}

class DropdownPlainFormRow<T> extends StatelessWidget {
  const DropdownPlainFormRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
    this.isExpanded = true,
    this.minHeight = 56,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;

  /// 传 null 表示禁用（Dropdown 灰显不可点）。
  final ValueChanged<T>? onChanged;
  final bool isExpanded;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cb = onChanged;
    return AppPlainFormRow(
      label: label,
      minHeight: minHeight,
      child: DropdownButton<T>(
        value: value,
        isExpanded: isExpanded,
        isDense: true,
        style: context.appTextStyles.formPlainValue.copyWith(
          color: colors.onSurface,
        ),
        underline: const SizedBox.shrink(),
        items: items,
        onChanged:
            cb == null
                ? null
                : (v) {
                  if (v != null) cb(v);
                },
      ),
    );
  }
}

class ValueWithUnitPlainFormRow<T> extends StatelessWidget {
  const ValueWithUnitPlainFormRow({
    required this.label,
    required this.controller,
    required this.unit,
    required this.unitItems,
    required this.onUnitChanged,
    super.key,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.minHeight = 56,
  });

  final String label;
  final TextEditingController controller;
  final T unit;
  final List<DropdownMenuItem<T>> unitItems;
  final ValueChanged<T> onUnitChanged;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valueStyle = context.appTextStyles.formPlainValue.copyWith(
      color: colors.onSurface,
    );
    return AppPlainFormRow(
      label: label,
      minHeight: minHeight,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: valueStyle,
              validator: validator,
              decoration: InputDecoration(
                hintText: hintText,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          DropdownButton<T>(
            value: unit,
            isDense: true,
            style: valueStyle,
            underline: const SizedBox.shrink(),
            items: unitItems,
            onChanged: (v) {
              if (v != null) onUnitChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class AccountPlainFormRow extends StatelessWidget {
  const AccountPlainFormRow({
    required this.label,
    required this.account,
    required this.placeholder,
    super.key,
    this.selectedId,
    this.onTap,
    this.validator,
    this.valueAlignment = AppPlainRowValueAlignment.start,
  });

  final String label;
  final Account? account;
  final String placeholder;
  final String? selectedId;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final AppPlainRowValueAlignment valueAlignment;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey(selectedId),
      initialValue: selectedId,
      validator: validator,
      builder: (field) {
        return AppPlainFormRow(
          label: label,
          onTap: onTap,
          errorText: field.errorText,
          child: Align(
            alignment:
                valueAlignment == AppPlainRowValueAlignment.end
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
            child: AccountPlainValue(
              account: account,
              placeholder: placeholder,
              valueAlignment: valueAlignment,
            ),
          ),
        );
      },
    );
  }
}

class AccountPlainValue extends StatelessWidget {
  const AccountPlainValue({
    required this.account,
    required this.placeholder,
    super.key,
    this.valueAlignment = AppPlainRowValueAlignment.start,
  });

  final Account? account;
  final String placeholder;
  final AppPlainRowValueAlignment valueAlignment;

  @override
  Widget build(BuildContext context) {
    final account = this.account;
    final colors = Theme.of(context).colorScheme;
    final textAlign =
        valueAlignment == AppPlainRowValueAlignment.end
            ? TextAlign.right
            : TextAlign.left;
    if (account == null) {
      return AppPlainValueText(
        text: placeholder,
        textAlign: textAlign,
        color: colors.onSurfaceVariant,
      );
    }

    return Row(
      mainAxisSize:
          valueAlignment == AppPlainRowValueAlignment.end
              ? MainAxisSize.min
              : MainAxisSize.max,
      mainAxisAlignment:
          valueAlignment == AppPlainRowValueAlignment.end
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: AppSpacing.space20,
          child: Center(
            child: BusinessIcon(
              iconKey: account.iconKey,
              size: AppSpacing.space20,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space8),
        Flexible(
          child: Text(
            account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: context.appTextStyles.formPlainValue,
          ),
        ),
      ],
    );
  }
}

Future<String?> showAccountPickerSheet({
  required BuildContext context,
  required String title,
  required List<Account> accounts,
  required String? selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return _AccountPickerSheet(
        title: title,
        accounts: accounts,
        selectedId: selectedId,
        onAccountTap: (account) => Navigator.of(context).pop(account.id),
      );
    },
  );
}

class AccountPickerSheetSelection {
  const AccountPickerSheetSelection(this.accountId);

  final String? accountId;
}

Future<AccountPickerSheetSelection?> showOptionalAccountPickerSheet({
  required BuildContext context,
  required String title,
  required List<Account> accounts,
  required String? selectedId,
  required String noneLabel,
}) {
  return showModalBottomSheet<AccountPickerSheetSelection>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return _AccountPickerSheet(
        title: title,
        accounts: accounts,
        selectedId: selectedId,
        noneLabel: noneLabel,
        onNoneTap:
            () => Navigator.of(
              context,
            ).pop(const AccountPickerSheetSelection(null)),
        onAccountTap:
            (account) => Navigator.of(
              context,
            ).pop(AccountPickerSheetSelection(account.id)),
      );
    },
  );
}

class _AccountPickerSheet extends StatelessWidget {
  const _AccountPickerSheet({
    required this.title,
    required this.accounts,
    required this.selectedId,
    required this.onAccountTap,
    this.noneLabel,
    this.onNoneTap,
  });

  final String title;
  final List<Account> accounts;
  final String? selectedId;
  final String? noneLabel;
  final VoidCallback? onNoneTap;
  final ValueChanged<Account> onAccountTap;

  @override
  Widget build(BuildContext context) {
    final noneLabel = this.noneLabel;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              0,
              AppSpacing.space16,
              AppSpacing.space8,
            ),
            child: Text(title, style: context.appTextStyles.subsectionTitle),
          ),
          if (noneLabel != null)
            _AccountPickerRow(
              label: noneLabel,
              selected: selectedId == null,
              onTap: onNoneTap,
            ),
          for (final account in accounts)
            _AccountPickerRow(
              label: account.name,
              iconKey: account.iconKey,
              selected: account.id == selectedId,
              onTap: () => onAccountTap(account),
            ),
          if (accounts.isEmpty && noneLabel == null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space20),
              child: Text('暂无可选账户', style: context.appTextStyles.inputText),
            ),
        ],
      ),
    );
  }
}

class _AccountPickerRow extends StatelessWidget {
  const _AccountPickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconKey,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: AppSpacing.space24,
              child: Center(
                child:
                    iconKey == null
                        ? null
                        : BusinessIcon(
                          iconKey: iconKey,
                          size: AppSpacing.space20,
                        ),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles.formPlainValue,
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
