import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';

import '../finance/finance_dot_label.dart';
import '../finance/finance_labels.dart';

class TransactionPurposeBadge extends StatelessWidget {
  const TransactionPurposeBadge({required this.purpose, super.key});

  final BusinessPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final color = switch (purpose) {
      BusinessPurpose.dailyExpense => financeColors.expense,
      BusinessPurpose.dailyIncome => financeColors.income,
      BusinessPurpose.transfer => financeColors.transfer,
      BusinessPurpose.openingBalance => financeColors.equity,
      _ => financeColors.info,
    };

    return FinanceDotLabel(
      label: transactionPurposeLabel(purpose),
      dotColor: color,
    );
  }
}
