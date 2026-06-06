import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/theme/app_text_styles.dart';
import '../../design_system/theme/app_theme_extension.dart';
import '../../design_system/token/spacing.dart';
import '../../design_system/widget/app_surface.dart';
import 'empty_transaction_card.dart';
import 'transaction_list_presentation.dart';
import 'transaction_row.dart';

class TransactionDayCard extends StatelessWidget {
  const TransactionDayCard({
    required this.group,
    super.key,
    this.emptyMessage,
    this.onRowTap,
    this.onRowQuickEdit,
  });

  final TransactionDayGroup group;
  final String? emptyMessage;
  final ValueChanged<String>? onRowTap;
  final ValueChanged<String>? onRowQuickEdit;

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
        if (group.rows.isEmpty)
          EmptyTransactionCard(message: emptyMessage ?? '本月暂无交易记录')
        else
          AppSurface(
            child: Column(
              children: [
                for (var i = 0; i < group.rows.length; i++) ...[
                  TransactionRow(
                    presentation: group.rows[i],
                    onTap: () => _openTransaction(context, group.rows[i]),
                    onQuickEdit:
                        () => _openTransactionEditor(context, group.rows[i]),
                  ),
                  if (i < group.rows.length - 1)
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

  void _openTransaction(
    BuildContext context,
    TransactionRowPresentation presentation,
  ) {
    final callback = onRowTap;
    if (callback != null) {
      callback(presentation.transactionId);
      return;
    }
    context.push('/transaction/${presentation.transactionId}');
  }

  void _openTransactionEditor(
    BuildContext context,
    TransactionRowPresentation presentation,
  ) {
    final callback = onRowQuickEdit;
    if (callback != null) {
      callback(presentation.transactionId);
      return;
    }
    context.push('/transaction/${presentation.transactionId}/edit');
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final TransactionDayGroup group;

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
