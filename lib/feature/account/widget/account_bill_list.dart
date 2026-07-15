import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/design_system/theme/app_text_styles.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';

class AccountBillList extends StatelessWidget {
  const AccountBillList({required this.bills, super.key});

  final List<BillSummaryReadModel> bills;

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space20),
          child: Text(
            '暂无账单',
            style: context.appTextStyles.formLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return AppSurface(
      child: Column(
        children: [
          for (var i = 0; i < bills.length; i++) ...[
            _BillRow(bill: bills[i]),
            if (i < bills.length - 1) const _BillDivider(),
          ],
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill});

  final BillSummaryReadModel bill;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final pendingColor =
        bill.pendingPrincipal.minorUnits > 0 ? colors.error : colors.onSurface;
    return InkWell(
      onTap: () => context.push('/bills/${bill.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_billTitle(bill.period), style: styles.listTitle),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    _billSubtitle(bill),
                    style: styles.listSupporting.copyWith(
                      color:
                          bill.overdueItemCount > 0
                              ? colors.error
                              : colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bill.pendingPrincipal.format(),
                  style: styles.amountList.copyWith(color: pendingColor),
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  _billStatusLabel(bill.status),
                  style: styles.listSupporting.copyWith(
                    color: _billColor(context, bill.status),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.space4),
            Icon(
              RemixIcons.arrow_right_s_line,
              color: colors.onSurfaceVariant,
              size: AppSpacing.space18,
            ),
          ],
        ),
      ),
    );
  }
}

class _BillDivider extends StatelessWidget {
  const _BillDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.space16),
      height: 1,
      color: colors.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

Color _billColor(BuildContext context, BillStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    BillStatus.open => colors.primary,
    BillStatus.billed => colors.error,
    BillStatus.settled => colors.tertiary,
  };
}

String _billTitle(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月';
}

String _billSubtitle(BillSummaryReadModel bill) {
  final due =
      bill.dueDate == null ? '无到期日' : '到期 ${_formatBillDate(bill.dueDate!)}';
  if (bill.overdueItemCount > 0) {
    return '$due · ${bill.overdueItemCount} 条逾期';
  }
  return '$due · ${bill.itemCount} 条明细';
}

String _billStatusLabel(BillStatus status) {
  return switch (status) {
    BillStatus.open => '累积中',
    BillStatus.billed => '已出账',
    BillStatus.settled => '已了结',
  };
}

String _formatBillDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
