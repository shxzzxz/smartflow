import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';

import '../finance/finance_dot_label.dart';
import '../finance/finance_labels.dart';

class AccountTypeTag extends StatelessWidget {
  const AccountTypeTag({required this.type, this.subtype, super.key});

  final AccountType type;
  final AccountSubtype? subtype;

  @override
  Widget build(BuildContext context) {
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final color = switch (type) {
      AccountType.asset => financeColors.asset,
      AccountType.liability => financeColors.liability,
      AccountType.equity => financeColors.equity,
      AccountType.income => financeColors.income,
      AccountType.expense => financeColors.expense,
    };

    return FinanceDotLabel(
      label: _accountTagLabel(type, subtype),
      dotColor: color,
    );
  }
}

String _accountTagLabel(AccountType type, AccountSubtype? subtype) {
  if (type == AccountType.asset) {
    return switch (subtype) {
      AccountSubtype.fund => '资金账户',
      AccountSubtype.receivable => '应收账户',
      AccountSubtype.payable => '应付账户',
      AccountSubtype.loan => '贷款账户',
      null => '账户',
    };
  }
  return accountTypeLabel(type);
}
