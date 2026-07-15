import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';

class CreditRepaymentFormSection extends StatelessWidget {
  const CreditRepaymentFormSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            0,
            AppSpacing.space4,
            AppSpacing.space6,
          ),
          child: Text(title, style: context.appTextStyles.dateSectionTitle),
        ),
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space10,
              vertical: AppSpacing.space4,
            ),
            child: AppPlainFormSection(children: children),
          ),
        ),
      ],
    );
  }
}

class CreditRepaymentAmountFields extends StatelessWidget {
  const CreditRepaymentAmountFields({
    required this.principalController,
    required this.interestController,
    required this.feeController,
    required this.discountController,
    super.key,
  });

  final TextEditingController principalController;
  final TextEditingController interestController;
  final TextEditingController feeController;
  final TextEditingController discountController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MoneyPlainFormRow(
          label: '本金',
          controller: principalController,
          hintText: '请输入还款本金',
          validator: validatePositiveMoneyText,
        ),
        MoneyPlainFormRow(
          label: '利息',
          controller: interestController,
          hintText: '请输入利息（可选）',
          validator: validateOptionalNonNegativeMoneyText,
        ),
        MoneyPlainFormRow(
          label: '手续费',
          controller: feeController,
          hintText: '请输入手续费（可选）',
          validator: validateOptionalNonNegativeMoneyText,
        ),
        MoneyPlainFormRow(
          label: '优惠',
          controller: discountController,
          hintText: '请输入优惠（可选）',
          validator: validateOptionalNonNegativeMoneyText,
        ),
      ],
    );
  }
}

class CreditRepaymentTransactionFields extends StatelessWidget {
  const CreditRepaymentTransactionFields({
    required this.createTransaction,
    required this.onCreateTransactionChanged,
    required this.occurredAtText,
    required this.onPickDate,
    required this.repaymentAccount,
    required this.selectedRepaymentAccountId,
    required this.repaymentAccounts,
    required this.onPickAccount,
    super.key,
  });

  final bool createTransaction;
  final ValueChanged<bool>? onCreateTransactionChanged;
  final String occurredAtText;
  final VoidCallback onPickDate;
  final Account? repaymentAccount;
  final String? selectedRepaymentAccountId;
  final List<Account> repaymentAccounts;
  final VoidCallback onPickAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onCreateTransactionChanged != null)
          AppPlainSwitchRow(
            label: '生成交易',
            value: createTransaction,
            onChanged: onCreateTransactionChanged!,
          ),
        if (createTransaction) ...[
          DateTimePlainFormRow(
            label: '还款日期',
            value: occurredAtText,
            onTap: onPickDate,
          ),
          AccountPlainFormRow(
            label: '还款账户',
            account: repaymentAccount,
            selectedId: selectedRepaymentAccountId,
            placeholder: '请选择还款账户',
            onTap: repaymentAccounts.isEmpty ? null : onPickAccount,
            validator: (value) => value == null ? '请选择还款账户' : null,
          ),
        ],
      ],
    );
  }
}

class CreditRepaymentSubmitHint extends StatelessWidget {
  const CreditRepaymentSubmitHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
