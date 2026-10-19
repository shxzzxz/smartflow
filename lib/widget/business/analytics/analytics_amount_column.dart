import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/spacing.dart';
import '../finance/adaptive_money_text.dart';
import '../finance/money_text.dart';

class AnalyticsAmountColumn extends StatelessWidget {
  const AnalyticsAmountColumn({
    required this.money,
    required this.semantic,
    required this.maxWidth,
    super.key,
    this.secondaryText,
  });

  final Money money;
  final MoneySemantic semantic;
  final double maxWidth;
  final String? secondaryText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final amountStyle = context.appTextStyles.amountList.copyWith(
      color: switch (semantic) {
        MoneySemantic.income => financeColors.income,
        MoneySemantic.expense => financeColors.expense,
        MoneySemantic.neutral => colors.onSurface,
        MoneySemantic.asset => financeColors.asset,
        MoneySemantic.liability => financeColors.liability,
        MoneySemantic.equity => financeColors.equity,
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          label: money.format(),
          child: ExcludeSemantics(
            child: AdaptiveMoneyText(
              preciseText: formatMoney(money, style: MoneyFormatStyle.plain),
              compactText: formatMoney(money, style: MoneyFormatStyle.compact),
              style: amountStyle,
              fallbackStyle: amountStyle,
              maxWidth: maxWidth,
            ),
          ),
        ),
        if (secondaryText case final text?) ...[
          const SizedBox(height: AppSpacing.space2),
          Text(text, style: context.appTextStyles.listSupporting),
        ],
      ],
    );
  }
}
