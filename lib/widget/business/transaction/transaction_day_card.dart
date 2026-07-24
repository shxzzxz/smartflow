import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/widget/business/finance/adaptive_money_text.dart';

import 'empty_transaction_card.dart';
import 'transaction_row.dart';

class TransactionDayCard extends StatelessWidget {
  const TransactionDayCard({
    required this.group,
    super.key,
    this.emptyMessage,
    this.onRowTap,
    this.onRowQuickEdit,
    this.enableRowTap = true,
    this.showDailyTotals = true,
  });

  final TransactionDayGroup group;
  final String? emptyMessage;
  final ValueChanged<String>? onRowTap;
  final ValueChanged<String>? onRowQuickEdit;
  final bool enableRowTap;
  final bool showDailyTotals;

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
          child: _DayHeader(group: group, showDailyTotals: showDailyTotals),
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
                    onTap:
                        enableRowTap
                            ? () => _openTransaction(context, group.rows[i])
                            : null,
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
  const _DayHeader({required this.group, required this.showDailyTotals});

  final TransactionDayGroup group;
  final bool showDailyTotals;

  @override
  Widget build(BuildContext context) {
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    final textStyles = context.appTextStyles;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.space8,
      runSpacing: AppSpacing.space4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${group.date.month}月${group.date.day}日',
              style: textStyles.dateSectionTitle,
            ),
            const SizedBox(width: AppSpacing.space8),
            Text(weekdayLabel(group.date), style: textStyles.listSupporting),
          ],
        ),
        if (showDailyTotals)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: textStyles.listSupporting),
        SectionMoneyText(
          money: Money(minorUnits: amountMinor),
          style: textStyles.amountCompact.copyWith(color: color),
        ),
      ],
    );
  }
}
