import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/form.dart';
import 'package:smartflow/design_system/token/radius.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_form_field.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/design_system/widget/app_plain_form_row.dart';
import 'package:smartflow/design_system/widget/app_segmented_control.dart';
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
    this.supportingText,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final DateTime? dateTime;
  final String value;
  final AppPlainSelectTap<DateTime>? onTap;
  final ValueChanged<DateTime?> onChanged;
  final bool showChevron;
  final AppPlainRowValueAlignment valueAlignment;
  final String? supportingText;
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
      supportingText: supportingText,
      minHeight: minHeight,
    );
  }
}

class BillingRepaymentDayPlainFields extends StatelessWidget {
  const BillingRepaymentDayPlainFields({
    required this.billingDay,
    required this.repaymentDay,
    required this.onSelectBillingDay,
    required this.onSelectRepaymentDay,
    super.key,
  });

  final int? billingDay;
  final int? repaymentDay;
  final VoidCallback onSelectBillingDay;
  final VoidCallback onSelectRepaymentDay;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _MonthlyDayPlainField(
        day: billingDay,
        label: '出账日',
        onTap: onSelectBillingDay,
      ),
      _MonthlyDayPlainField(
        day: repaymentDay,
        label: '还款日',
        onTap: onSelectRepaymentDay,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText =
            MediaQuery.textScalerOf(context).scale(14) >= AppSpacing.space18;
        final stackFields = constraints.maxWidth < 340 || largeText;
        if (stackFields) {
          return Column(
            children: [
              fields.first,
              const SizedBox(height: AppSpacing.space4),
              fields.last,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: fields.first),
            const SizedBox(width: AppSpacing.space12),
            Expanded(child: fields.last),
          ],
        );
      },
    );
  }
}

class _MonthlyDayPlainField extends StatelessWidget {
  const _MonthlyDayPlainField({
    required this.day,
    required this.label,
    required this.onTap,
  });

  final int? day;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppFormTokens.rowMinHeight + AppSpacing.space16,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: context.appTextStyles.formLabel),
              const SizedBox(height: AppSpacing.space4),
              AppPlainValueText(text: day == null ? '请选择' : '每月 $day 日'),
            ],
          ),
        ),
      ),
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
    required this.unitSegments,
    required this.onUnitChanged,
    super.key,
    this.hintText,
    this.suffixText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.minHeight = AppFormTokens.rowMinHeight,
  });

  final String label;
  final TextEditingController controller;
  final T unit;
  final List<AppSegment<T>> unitSegments;
  final ValueChanged<T> onUnitChanged;
  final String? hintText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final valueStyle = context.appTextStyles.formPlainValue;
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
                child: AppPlainTextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: valueStyle,
                  validator: validator,
                  hintText: hintText,
                ),
              ),
              if (suffixText != null) ...[
                const SizedBox(width: AppSpacing.space4),
                Text(suffixText!, style: valueStyle),
              ],
              const SizedBox(width: AppSpacing.space8),
              AppSegmentedControl<T>(
                segments: unitSegments,
                selected: fieldUnit ?? unit,
                onChanged: fieldChanged,
                size: AppSegmentedControlSize.small,
                tone: AppSegmentedControlTone.neutral,
                textStyle: valueStyle,
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
              usage: BusinessIconUsage.account,
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
                          usage: BusinessIconUsage.account,
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
