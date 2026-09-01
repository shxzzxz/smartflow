import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_swipe_action.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../widget/business/finance/bill_item_row.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/bill_item_presentation.dart';
import '../presentation/bill_repayment_presentation.dart';
import '../presentation/bill_status_presentation.dart';
import '../view_model/bill_detail_view_model.dart';

class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(billDetailViewModelProvider(billId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '账单详情',
              actions: switch (detail) {
                AsyncData(value: final bill?) => [
                  if (bill.summary.windowStartDate != null)
                    AppHeaderIconButton(
                      icon: RemixIcons.edit_2_line,
                      tooltip: '编辑区间',
                      onPressed: () => _openEdit(context, ref),
                    ),
                  AppHeaderIconButton(
                    icon: RemixIcons.delete_bin_line,
                    tooltip: '删除账单',
                    onPressed:
                        bill.repayments.isEmpty
                            ? () => _deleteBill(context, ref)
                            : null,
                  ),
                ],
                _ => const [],
              },
            ),
            Expanded(
              child: switch (detail) {
                AsyncData(value: final bill?) => _BillDetailContent(
                  detail: bill,
                  onRepay: () => _openRepayment(context, ref),
                  onInstallment: () => _openInstallment(context, ref),
                  onSync: () => _syncProjection(context, ref),
                  onDeleteRepayment:
                      (repayment) => _deleteRepayment(context, ref, repayment),
                  onEditRepayment:
                      (repayment) => _editRepayment(context, ref, repayment),
                ),
                AsyncData(value: null) => const Center(child: Text('账单不存在')),
                AsyncError() => const Center(child: Text('账单加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncProjection(BuildContext context, WidgetRef ref) async {
    final outcome =
        await ref
            .read(billDetailViewModelProvider(billId).notifier)
            .synchronizeProjection();
    if (!context.mounted) return;
    _showFailure(context, outcome, action: '同步');
  }

  Future<void> _openRepayment(BuildContext context, WidgetRef ref) async {
    final changed = await context.push<bool>('/bills/$billId/repay');
    if (changed == true) {
      ref.read(billDetailViewModelProvider(billId).notifier).reload();
    }
  }

  Future<void> _openInstallment(BuildContext context, WidgetRef ref) async {
    final changed = await context.push<bool>('/bills/$billId/installment');
    if (changed == true) {
      ref.read(billDetailViewModelProvider(billId).notifier).reload();
    }
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final changed = await context.push<bool>('/bills/$billId/edit');
    if (changed == true) {
      ref.read(billDetailViewModelProvider(billId).notifier).reload();
    }
  }

  Future<void> _deleteBill(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除账单'),
            content: const Text('将删除该账单及其全部明细。仅无还款记录的账单可以删除。'),
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
    final outcome =
        await ref
            .read(billDetailViewModelProvider(billId).notifier)
            .deleteBill();
    if (!context.mounted) return;
    if (outcome case UiActionFailure<void>()) {
      _showFailure(context, outcome, action: '删除');
    } else {
      context.pop(true);
    }
  }

  Future<void> _editRepayment(
    BuildContext context,
    WidgetRef ref,
    BillRepaymentReadModel repayment,
  ) async {
    final changed = await context.push<bool>(
      '/repayments/${repayment.id}/edit',
    );
    if (changed == true) {
      ref.read(billDetailViewModelProvider(billId).notifier).reload();
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
    final outcome = await ref
        .read(billDetailViewModelProvider(billId).notifier)
        .deleteRepayment(repayment.id);
    if (!context.mounted) return;
    _showFailure(context, outcome, action: '删除');
  }
}

class _BillDetailContent extends StatelessWidget {
  const _BillDetailContent({
    required this.detail,
    required this.onRepay,
    required this.onInstallment,
    required this.onSync,
    required this.onDeleteRepayment,
    required this.onEditRepayment,
  });

  final BillDetailReadModel detail;
  final VoidCallback onRepay;
  final VoidCallback onInstallment;
  final VoidCallback onSync;
  final ValueChanged<BillRepaymentReadModel> onDeleteRepayment;
  final ValueChanged<BillRepaymentReadModel> onEditRepayment;

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
        const SizedBox(height: AppSpacing.space8),
        _BillActionBar(
          onRepay: onRepay,
          onInstallment: onInstallment,
          onSync: onSync,
        ),
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
                        BillItemRow(
                          presentation: billItemRowPresentation(
                            detail.items[i],
                          ),
                          onTap: _itemTap(context, detail.items[i]),
                        ),
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
                          onEdit: () => onEditRepayment(detail.repayments[i]),
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

  VoidCallback? _itemTap(BuildContext context, BillItemReadModel item) {
    final destination = billItemDestination(item);
    return destination == null ? null : () => context.push(destination);
  }
}

class _SummarySurface extends StatelessWidget {
  const _SummarySurface({required this.summary});

  final BillSummaryReadModel summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppDetailSummaryCard(
      title: _periodLabel(summary.period),
      headerTrailing: AppStatusBadge(
        label: billStatusLabel(summary.status),
        color: _billStatusColor(context, summary.status),
      ),
      mainItems: [
        AppDetailSummaryCardItem(
          label: '账单总额',
          value: summary.totalAmount.format(),
          valueColor: colors.onSurface,
        ),
        AppDetailSummaryCardItem(
          label: '待还金额',
          value: summary.pendingAmount.format(),
          valueColor:
              summary.pendingAmount.minorUnits > 0
                  ? colors.error
                  : colors.onSurface,
        ),
      ],
      supportingItems: [
        if (summary.overdueItemCount > 0)
          AppDetailSummaryCardItem(
            label: '',
            value: '${summary.overdueItemCount} 条逾期',
            valueColor: colors.error,
          ),
        if (summary.windowStartDate != null)
          AppDetailSummaryCardItem(
            label: '起始日',
            value: formatDateLabel(summary.windowStartDate!),
          ),
        if (summary.windowBillingDate != null)
          AppDetailSummaryCardItem(
            label: '结束日',
            value: formatDateLabel(
              summary.windowBillingDate!.subtract(const Duration(days: 1)),
            ),
          ),
      ],
    );
  }
}

class _BillActionBar extends StatelessWidget {
  const _BillActionBar({
    required this.onRepay,
    required this.onInstallment,
    required this.onSync,
  });

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
            Expanded(
              child: _ActionButton(
                icon: RemixIcons.bank_card_line,
                label: '还款',
                onTap: onRepay,
              ),
            ),
            const SizedBox(width: AppSpacing.space6),
            Expanded(
              child: _ActionButton(
                icon: RemixIcons.calendar_schedule_line,
                label: '账单分期',
                onTap: onInstallment,
              ),
            ),
            const SizedBox(width: AppSpacing.space6),
            Expanded(
              child: _ActionButton(
                icon: RemixIcons.refresh_line,
                label: '刷新',
                onTap: onSync,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillRepaymentRow extends StatelessWidget {
  const _BillRepaymentRow({
    required this.repayment,
    required this.onDelete,
    required this.onEdit,
  });

  final BillRepaymentReadModel repayment;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return AppSwipeAction(
      dismissibleKey: ValueKey('bill-repayment-${repayment.id}'),
      label: '编辑',
      icon: RemixIcons.edit_2_line,
      onTriggered: onEdit,
      secondaryAction: AppSwipeActionItem(
        label: '删除',
        icon: RemixIcons.delete_bin_line,
        onTriggered: onDelete,
        tone: AppSwipeActionTone.danger,
      ),
      child: Padding(
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
                  Text(
                    billRepaymentDateText(repayment),
                    style: styles.formLabel,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    billRepaymentBreakdownText(repayment),
                    style: styles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space10),
            Text(repayment.cashPaid.format(), style: styles.amountList),
          ],
        ),
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

Color _billStatusColor(BuildContext context, BillStatus status) {
  final colors = Theme.of(context).colorScheme;
  final appColors = Theme.of(context).extension<AppThemeExtension>()!;
  return switch (status) {
    BillStatus.open => colors.primary,
    BillStatus.billed => colors.error,
    BillStatus.settled => appColors.success,
  };
}

String _periodLabel(BillPeriod period) {
  return '${period.year}年${period.month.toString().padLeft(2, '0')}月账单';
}

void _showFailure(
  BuildContext context,
  UiActionOutcome<void> outcome, {
  required String action,
}) {
  if (outcome case UiActionFailure<void>(:final error)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action失败：${error.message}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
