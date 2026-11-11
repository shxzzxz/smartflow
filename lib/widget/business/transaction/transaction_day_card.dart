import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
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
    this.onRowLongPress,
    this.onRowQuickEdit,
    this.onRowSelectionChanged,
    this.enableRowTap = true,
    this.enableRowQuickEdit = true,
    this.showDailyTotals = true,
    this.showClosingBalance = true,
  });

  final TransactionDayGroup group;
  final String? emptyMessage;
  final ValueChanged<String>? onRowTap;
  final ValueChanged<String>? onRowLongPress;
  final ValueChanged<String>? onRowQuickEdit;
  final void Function(String transactionId, bool selected)?
  onRowSelectionChanged;
  final bool enableRowTap;
  final bool enableRowQuickEdit;
  final bool showDailyTotals;
  final bool showClosingBalance;

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
          child: _DayHeader(
            group: group,
            showDailyTotals: showDailyTotals,
            showClosingBalance: showClosingBalance,
          ),
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
                    onTap: enableRowTap && group.rows[i].canOpenTransaction
                        ? () => _openTransaction(context, group.rows[i])
                        : null,
                    onLongPress:
                        onRowLongPress == null ||
                            !group.rows[i].canOpenTransaction
                        ? null
                        : () => onRowLongPress!(group.rows[i].transactionId),
                    onQuickEdit: () =>
                        _openTransactionEditor(context, group.rows[i]),
                    enableQuickEdit: enableRowQuickEdit,
                    onSelectionChanged:
                        onRowSelectionChanged == null ||
                            !group.rows[i].canOpenTransaction
                        ? null
                        : (selected) => onRowSelectionChanged!(
                            group.rows[i].transactionId,
                            selected,
                          ),
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
  const _DayHeader({
    required this.group,
    required this.showDailyTotals,
    required this.showClosingBalance,
  });

  final TransactionDayGroup group;
  final bool showDailyTotals;
  final bool showClosingBalance;

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
        if (group.warning case final warning?)
          AppStatusBadge(
            presentation: AppStatusBadgePresentation(
              label: warning,
              tone: AppStatusTone.warning,
            ),
            size: AppStatusBadgeSize.compact,
          ),
        if (showDailyTotals ||
            (showClosingBalance && group.closingBalance != null))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDailyTotals) ...[
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
              if (showDailyTotals &&
                  showClosingBalance &&
                  group.closingBalance != null)
                const SizedBox(width: AppSpacing.space12),
              if (showClosingBalance && group.closingBalance != null)
                _DayClosingBalance(
                  label: group.closingBalanceLabel,
                  balance: group.closingBalance!,
                ),
            ],
          ),
      ],
    );
  }
}

class _DayClosingBalance extends StatelessWidget {
  const _DayClosingBalance({required this.label, required this.balance});

  final String label;
  final Money balance;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: textStyles.listSupporting),
        SectionMoneyText(
          money: balance,
          style: textStyles.amountCompact.copyWith(
            color: balance.minorUnits < 0 ? colors.error : colors.onSurface,
          ),
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
