import 'package:flutter/material.dart';

import '../../design_system/theme/app_theme_extension.dart';
import '../../application/accounting/accounting_api.dart';
import 'finance_labels.dart';

class AccountTypeTag extends StatelessWidget {
  const AccountTypeTag({required this.type, this.subtype, super.key});

  final AccountType type;
  final AccountSubtype? subtype;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final color = switch (type) {
      AccountType.asset => financeColors.asset,
      AccountType.liability => financeColors.liability,
      AccountType.equity => financeColors.equity,
      AccountType.income => financeColors.income,
      AccountType.expense => financeColors.expense,
    };

    return Chip(
      label: Text(_accountTagLabel(type, subtype)),
      avatar: Icon(Icons.circle, size: 10, color: color),
      visualDensity: VisualDensity.compact,
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide(color: colors.outlineVariant),
    );
  }
}

String _accountTagLabel(AccountType type, AccountSubtype? subtype) {
  if (type == AccountType.asset) {
    return subtype == AccountSubtype.reimbursement ? '报销账户' : '资金账户';
  }
  return accountTypeLabel(type);
}
