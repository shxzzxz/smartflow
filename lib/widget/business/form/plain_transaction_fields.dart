import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/form.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/design_system/widget/app_plain_form_row.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';

import '../icon/business_icon.dart';

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

class NotePlainFormRow extends StatelessWidget {
  const NotePlainFormRow({
    required this.controller,
    super.key,
    this.label = '备注',
    this.hintText = '请输入备注（可选）',
    this.textAlign = TextAlign.left,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final TextAlign textAlign;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainTextFormRow(
      label: label,
      controller: controller,
      hintText: hintText,
      maxLines: 1,
      textAlign: textAlign,
      minHeight: minHeight,
    );
  }
}

class DateTimePlainFormRow extends StatelessWidget {
  const DateTimePlainFormRow({
    required this.label,
    required this.dateTime,
    required this.value,
    required this.onTap,
    required this.onChanged,
    super.key,
    this.showChevron = false,
    this.valueAlignment = AppPlainRowValueAlignment.start,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final DateTime? dateTime;
  final String value;
  final AppPlainSelectTap<DateTime>? onTap;
  final ValueChanged<DateTime?> onChanged;
  final bool showChevron;
  final AppPlainRowValueAlignment valueAlignment;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainSelectFormRow<DateTime>(
      label: label,
      value: dateTime,
      valueText: value,
      placeholder: value,
      onTap: onTap,
      onChanged: onChanged,
      showChevron: showChevron,
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
    this.minHeight = AppFormTokens.rowMinHeight,
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
    return AppControlledFormField<T>(
      value: value,
      enabled: cb != null,
      onChanged:
          cb == null
              ? null
              : (nextValue) {
                if (nextValue != null) cb(nextValue);
              },
      builder: (context, fieldValue, _, fieldChanged) {
        return AppPlainFormRow(
          label: label,
          minHeight: minHeight,
          child: DropdownButton<T>(
            value: fieldValue,
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
                    : (nextValue) {
                      if (nextValue != null) fieldChanged(nextValue);
                    },
          ),
        );
      },
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
    this.minHeight = AppFormTokens.rowMinHeight,
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
    return AppControlledFormField<T>(
      value: unit,
      onChanged: (nextUnit) {
        if (nextUnit != null) onUnitChanged(nextUnit);
      },
      builder: (context, fieldUnit, _, fieldChanged) {
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
                value: fieldUnit,
                isDense: true,
                style: valueStyle,
                underline: const SizedBox.shrink(),
                items: unitItems,
                onChanged: (nextUnit) {
                  if (nextUnit != null) fieldChanged(nextUnit);
                },
              ),
            ],
          ),
        );
      },
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
    this.onChanged,
    this.validator,
    this.valueAlignment = AppPlainRowValueAlignment.start,
  });

  final String label;
  final Account? account;
  final String placeholder;
  final String? selectedId;
  final AppPlainSelectTap<String>? onTap;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;
  final AppPlainRowValueAlignment valueAlignment;

  @override
  Widget build(BuildContext context) {
    return AppControlledFormField<String>(
      value: selectedId,
      onChanged: onChanged,
      validator: validator,
      builder: (context, _, errorText, fieldChanged) {
        final handleTap = onTap;
        return AppPlainFormRow(
          label: label,
          onTap: handleTap == null ? null : () => handleTap(fieldChanged),
          errorText: errorText,
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
