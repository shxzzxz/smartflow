import 'package:flutter/material.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../view_model/home_transaction_group.dart';
import '../view_model/transaction_row_presentation.dart';
import 'empty_transaction_card.dart';
import 'transaction_row.dart';

class TransactionDayCard extends StatelessWidget {
  const TransactionDayCard({required this.group, super.key, this.emptyMessage});

  final HomeTransactionDayGroup group;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dividerColor = colors.outlineVariant.withValues(alpha: 0.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            0,
            AppSpacing.space4,
            AppSpacing.space8,
          ),
          child: _DayHeader(group: group),
        ),
        if (group.items.isEmpty)
          EmptyTransactionCard(message: emptyMessage ?? '本月暂无交易记录')
        else
          AppSurface(
            child: Column(
              children: [
                for (var i = 0; i < group.items.length; i++) ...[
                  TransactionRow(item: group.items[i]),
                  if (i < group.items.length - 1)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space16,
                      ),
                      height: 1,
                      color: dividerColor,
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final HomeTransactionDayGroup group;

  @override
  Widget build(BuildContext context) {
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final textStyles = context.appTextStyles;

    return Row(
      children: [
        Text(
          '${group.date.month}月${group.date.day}日',
          style: textStyles.dateSectionTitle,
        ),
        const SizedBox(width: AppSpacing.space8),
        Text(weekdayLabel(group.date), style: textStyles.listSupporting),
        const Spacer(),
        _DayTotal(
          label: '收入',
          amountMinor: group.incomeMinor,
          color: financeColors.income,
        ),
        const SizedBox(width: AppSpacing.space12),
        _DayTotal(
          label: '支出',
          amountMinor: group.expenseMinor,
          color: financeColors.expense,
        ),
      ],
    );
  }
}

class _DayTotal extends StatelessWidget {
  const _DayTotal({
    required this.label,
    required this.amountMinor,
    required this.color,
  });

  final String label;
  final int amountMinor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;

    return Text.rich(
      TextSpan(
        text: '$label ',
        style: textStyles.listSupporting,
        children: [
          TextSpan(
            text: formatMinorAmount(amountMinor),
            style: textStyles.amountCompact.copyWith(color: color),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}
