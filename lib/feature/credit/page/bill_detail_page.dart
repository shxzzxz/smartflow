import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../provider/bill_query_providers.dart';

class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(billDetailProvider(billId));
    return Scaffold(
      appBar: AppBar(title: const Text('账单详情')),
      body: switch (detail) {
        AsyncData(value: final bill?) => _BillDetailContent(detail: bill),
        AsyncData(value: null) => const Center(child: Text('账单不存在')),
        AsyncError(:final error) => Center(child: Text('账单加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _BillDetailContent extends StatelessWidget {
  const _BillDetailContent({required this.detail});

  final BillDetailReadModel detail;

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
    return Padding(
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
                        item.isOverdue ? colors.error : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space10),
          Text(item.expectedPrincipal.format(), style: styles.amountList),
        ],
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
    BillItemStatus.paid => '已核销',
    BillItemStatus.skipped => '已跳过',
  };
}
