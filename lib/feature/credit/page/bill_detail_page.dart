import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart' as credit_command;
import '../../../application/credit/credit_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../provider/bill_query_providers.dart';
import '../provider/credit_account_query_providers.dart';
import '../provider/installment_query_providers.dart';
import '../../shared/provider/ledger_query_providers.dart';

class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(billDetailProvider(billId));
    return Scaffold(
      appBar: AppBar(title: const Text('账单详情')),
      body: switch (detail) {
        AsyncData(value: final bill?) => _BillDetailContent(
          detail: bill,
          onRepay: () => _openRepayment(context, ref),
          onInstallment: () => _openInstallment(context, ref),
          onSync: () => _syncProjection(context, ref),
          onDeleteRepayment:
              (repayment) => _deleteRepayment(context, ref, repayment),
        ),
        AsyncData(value: null) => const Center(child: Text('账单不存在')),
        AsyncError(:final error) => Center(child: Text('账单加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _syncProjection(BuildContext context, WidgetRef ref) async {
    final accountId =
        ref.read(billDetailProvider(billId)).asData?.value?.summary.accountId;
    try {
      await ref
          .read(creditBillGenerationAppServiceProvider)
          .refreshBill(billId);
      ref.invalidate(billDetailProvider(billId));
      if (accountId != null) {
        ref.invalidate(billSummariesByAccountProvider(accountId));
        ref.invalidate(creditAccountOverviewProvider(accountId));
        ref.invalidate(installmentContractsByAccountProvider(accountId));
      }
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openRepayment(BuildContext context, WidgetRef ref) async {
    final changed = await context.push<bool>('/bills/$billId/repay');
    if (changed == true) {
      ref.invalidate(billDetailProvider(billId));
    }
  }

  Future<void> _openInstallment(BuildContext context, WidgetRef ref) async {
    final changed = await context.push<bool>('/bills/$billId/installment');
    if (changed == true) {
      ref.invalidate(billDetailProvider(billId));
    }
  }

  Future<void> _deleteRepayment(
    BuildContext context,
    WidgetRef ref,
    BillRepaymentReadModel repayment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除还款记录'),
            content: const Text('将删除该还款记录，并回退账单明细与关联计划状态。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(repaymentAppServiceProvider)
          .deleteRepayment(
            credit_command.DeleteCreditRepaymentCommand(
              repaymentId: repayment.id,
            ),
          );
      final detail = ref.read(billDetailProvider(billId)).asData?.value;
      final accountId = detail?.summary.accountId;
      ref.invalidate(billDetailProvider(billId));
      if (accountId != null) {
        ref.invalidate(billSummariesByAccountProvider(accountId));
        ref.invalidate(creditAccountOverviewProvider(accountId));
        ref.invalidate(installmentContractsByAccountProvider(accountId));
        ref.invalidate(transactionListProvider(accountId: accountId));
      }
      ref.invalidate(accountsByIdProvider);
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：$error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _BillDetailContent extends StatelessWidget {
  const _BillDetailContent({
    required this.detail,
    required this.onRepay,
    required this.onInstallment,
    required this.onSync,
    required this.onDeleteRepayment,
  });

  final BillDetailReadModel detail;
  final VoidCallback onRepay;
  final VoidCallback onInstallment;
  final VoidCallback onSync;
  final ValueChanged<BillRepaymentReadModel> onDeleteRepayment;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space10,
        AppSpacing.space8,
        AppSpacing.space10,
        AppSpacing.space16,
      ),
      children: [
        _SummarySurface(summary: summary),
        if (_hasBillActions(detail)) ...[
          const SizedBox(height: AppSpacing.space8),
          _BillActionBar(
            detail: detail,
            onRepay: onRepay,
            onInstallment: onInstallment,
            onSync: onSync,
          ),
        ],
        const SizedBox(height: AppSpacing.space8),
        Text('明细', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space4),
        AppSurface(
          child:
              detail.items.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.space20),
                    child: Text('暂无账单明细'),
                  )
                  : Column(
                    children: [
                      for (var i = 0; i < detail.items.length; i++) ...[
                        _BillItemRow(item: detail.items[i]),
                        if (i < detail.items.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.space16,
                            ),
                            child: Divider(height: 1),
                          ),
                      ],
                    ],
                  ),
        ),
        const SizedBox(height: AppSpacing.space12),
        Text('还款记录', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space4),
        AppSurface(
          child:
              detail.repayments.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.space20),
                    child: Text('暂无还款记录'),
                  )
                  : Column(
                    children: [
                      for (var i = 0; i < detail.repayments.length; i++) ...[
                        _BillRepaymentRow(
                          repayment: detail.repayments[i],
                          onDelete:
                              () => onDeleteRepayment(detail.repayments[i]),
                        ),
                        if (i < detail.repayments.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.space16,
                            ),
                            child: Divider(height: 1),
                          ),
                      ],
                    ],
                  ),
        ),
      ],
    );
  }
}

class _SummarySurface extends StatelessWidget {
  const _SummarySurface({required this.summary});

  final BillSummaryReadModel summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_periodLabel(summary.period), style: styles.groupTitle),
                const Spacer(),
                _StatusPill(status: summary.status),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            Text('待还本金', style: styles.detailLabel),
            const SizedBox(height: AppSpacing.space4),
            Text(
              summary.pendingPrincipal.format(),
              style: styles.amountPrimary.copyWith(
                color:
                    summary.pendingPrincipal.minorUnits > 0
                        ? colors.error
                        : colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.space10),
            Text(
              _dueText(summary),
              style: styles.listSupporting.copyWith(
                color:
                    summary.overdueItemCount > 0
                        ? colors.error
                        : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillActionBar extends StatelessWidget {
  const _BillActionBar({
    required this.detail,
    required this.onRepay,
    required this.onInstallment,
    required this.onSync,
  });

  final BillDetailReadModel detail;
  final VoidCallback onRepay;
  final VoidCallback onInstallment;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space8,
          vertical: AppSpacing.space6,
        ),
        child: Row(
          children: [
            if (detail.summary.pendingPrincipal.minorUnits > 0) ...[
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.bank_card_line,
                  label: '还款',
                  onTap: onRepay,
                ),
              ),
            ],
            if (_canConvertToInstallment(detail)) ...[
              if (detail.summary.pendingPrincipal.minorUnits > 0)
                const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.calendar_schedule_line,
                  label: '账单分期',
                  onTap: onInstallment,
                ),
              ),
            ],
            if (_canRefreshBill(detail)) ...[
              if (detail.summary.pendingPrincipal.minorUnits > 0 ||
                  _canConvertToInstallment(detail))
                const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.refresh_line,
                  label: '刷新',
                  onTap: onSync,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillRepaymentRow extends StatelessWidget {
  const _BillRepaymentRow({required this.repayment, required this.onDelete});

  final BillRepaymentReadModel repayment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space12,
      ),
      child: Row(
        children: [
          Icon(RemixIcons.refund_2_line, size: 22, color: colors.primary),
          const SizedBox(width: AppSpacing.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repayment.repaymentType.label, style: styles.formLabel),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  _repaymentSupportingText(repayment),
                  style: styles.listSupporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space10),
          Text(repayment.cashPaid.format(), style: styles.amountList),
          IconButton(
            tooltip: '删除',
            icon: Icon(
              RemixIcons.delete_bin_line,
              color: colors.onSurfaceVariant,
              size: AppSpacing.space20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space6,
          vertical: AppSpacing.space6,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.primary, size: AppSpacing.space20),
            const SizedBox(width: AppSpacing.space6),
            Flexible(
              child: Text(
                label,
                style: textStyles.formLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillItemRow extends StatelessWidget {
  const _BillItemRow({required this.item});

  final BillItemReadModel item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    final icon =
        item.itemType == BillItemType.consumption
            ? RemixIcons.shopping_bag_3_line
            : RemixIcons.calendar_schedule_line;
    return InkWell(
      onTap:
          item.contractId == null
              ? null
              : () => context.push('/installments/${item.contractId}/edit'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.primary),
            const SizedBox(width: AppSpacing.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: styles.formLabel),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    '${_dateLabel(item.repaymentDate)} · ${_itemStatusLabel(item)}',
                    style: styles.listSupporting.copyWith(
                      color:
                          item.isOverdue
                              ? colors.error
                              : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space10),
            Text(item.expectedPrincipal.format(), style: styles.amountList),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final BillStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      BillStatus.open => ('累积中', colors.primary),
      BillStatus.billed => ('已出账', colors.error),
      BillStatus.settled => ('已了结', colors.tertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.appTextStyles.listSupporting.copyWith(color: color),
      ),
    );
  }
}

String _periodLabel(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月账单';
}

String _dueText(BillSummaryReadModel summary) {
  final date = summary.dueDate;
  final due = date == null ? '无到期日' : '到期日 ${_dateLabel(date)}';
  if (summary.overdueItemCount == 0) return due;
  return '$due · ${summary.overdueItemCount} 条逾期';
}

String _dateLabel(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _itemStatusLabel(BillItemReadModel item) {
  if (item.isOverdue) return '已逾期';
  return switch (item.status) {
    BillItemStatus.pending => '待还',
    BillItemStatus.partiallyPaid => '部分已还',
    BillItemStatus.paid => '已核销',
    BillItemStatus.skipped => '已跳过',
  };
}

bool _canConvertToInstallment(BillDetailReadModel detail) {
  return detail.summary.status == BillStatus.billed &&
      detail.items.any(
        (item) =>
            item.itemType == BillItemType.consumption &&
            (item.status == BillItemStatus.pending ||
                item.status == BillItemStatus.partiallyPaid),
      );
}

bool _canRefreshBill(BillDetailReadModel detail) {
  return true;
}

bool _hasBillActions(BillDetailReadModel detail) {
  return detail.summary.pendingPrincipal.minorUnits > 0 ||
      _canConvertToInstallment(detail) ||
      _canRefreshBill(detail);
}

String _repaymentSupportingText(BillRepaymentReadModel repayment) {
  final prefix =
      repayment.timeSource == BillRepaymentTimeSource.transaction
          ? '还款日'
          : '记录于';
  final account = repayment.paidFromAccountId;
  final dateText = '$prefix ${_dateLabel(repayment.displayTime)}';
  if (account == null) return dateText;
  return '$dateText · $account';
}
