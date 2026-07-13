import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_detail_view_model.dart';

class InstallmentDetailPage extends ConsumerWidget {
  const InstallmentDetailPage({required this.contractId, super.key});

  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(
      installmentDetailViewModelProvider(contractId),
    );

    final loaded = switch (detailAsync) {
      AsyncData(value: final InstallmentDetailLoaded value) => value,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('分期合同'),
        actions: [
          if (loaded != null)
            IconButton(
              onPressed: () => _confirmDelete(context, ref),
              icon: const Icon(RemixIcons.delete_bin_line),
              tooltip: '删除合同',
            ),
        ],
      ),
      body: switch (detailAsync) {
        AsyncData(value: final InstallmentDetailLoaded loaded) => _Body(
          loaded: loaded,
        ),
        AsyncData(value: InstallmentDetailNotFound()) => const Center(
          child: Text('合同不存在'),
        ),
        AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除分期合同'),
            content: const Text('将撤回所有还款交易与放款交易，并清除合同与还款计划。此操作不可撤销。'),
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
            .read(installmentDetailViewModelProvider(contractId).notifier)
            .deleteContract();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<void>():
        context.pop();
      case UiActionFailure<void>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：${error.message}')));
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.loaded});

  final InstallmentDetailLoaded loaded;

  @override
  Widget build(BuildContext context) {
    final contract = loaded.contract;
    final schedules = loaded.schedules;
    final cashflows = loaded.repayments;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space10,
        AppSpacing.space6,
        AppSpacing.space10,
        AppSpacing.space16,
      ),
      children: [
        _Header(
          contract: contract,
          remainingPrincipalMinor: loaded.remainingPrincipalMinor,
          paidInterestMinor: loaded.paidInterestMinor,
          paidFeeMinor: loaded.paidFeeMinor,
        ),
        const SizedBox(height: AppSpacing.space8),
        _ActionBar(contract: contract),
        const SizedBox(height: AppSpacing.space12),
        Text('还款计划', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < schedules.length; i++) ...[
                _ScheduleRow(contract: contract, schedule: schedules[i]),
                if (i < schedules.length - 1)
                  const Divider(height: 1, indent: AppSpacing.space12),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        Text('实际还款记录', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        if (cashflows.isEmpty)
          AppSurface(
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.space20),
              child: Text('暂无还款记录'),
            ),
          )
        else
          AppSurface(
            child: Column(
              children: [
                for (var i = 0; i < cashflows.length; i++) ...[
                  _RepaymentRow(cashflow: cashflows[i], contract: contract),
                  if (i < cashflows.length - 1)
                    const Divider(height: 1, indent: AppSpacing.space12),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.contract,
    required this.remainingPrincipalMinor,
    required this.paidInterestMinor,
    required this.paidFeeMinor,
  });

  final InstallmentContractReadModel contract;
  final int remainingPrincipalMinor;
  final int paidInterestMinor;
  final int paidFeeMinor;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(status: contract.status),
                const SizedBox(width: AppSpacing.space8),
                Text(
                  _methodLabel(contract.repaymentMethod),
                  style: styles.formLabel.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space10),
            Text('本金', style: styles.detailLabel),
            Text(contract.principal.format(), style: styles.amountPrimary),
            const SizedBox(height: AppSpacing.space8),
            Row(
              children: [
                Expanded(
                  child: _LabelValue(
                    label: '剩余本金',
                    value: Money(minorUnits: remainingPrincipalMinor).format(),
                  ),
                ),
                Expanded(
                  child: _LabelValue(
                    label: '期数',
                    value: '${contract.totalPeriods} 期',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space6),
            Row(
              children: [
                Expanded(
                  child: _LabelValue(
                    label: '借款日期',
                    value: _formatDate(contract.borrowingDate),
                  ),
                ),
                Expanded(
                  child: _LabelValue(
                    label: '利率',
                    value: _formatRate(
                      contract.interestRatePeriod,
                      contract.interestRatePpm,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space6),
            Row(
              children: [
                Expanded(
                  child: _LabelValue(
                    label: '已还利息',
                    value: Money(minorUnits: paidInterestMinor).format(),
                  ),
                ),
                Expanded(
                  child: _LabelValue(
                    label: '已还手续费',
                    value: Money(minorUnits: paidFeeMinor).format(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          '$label：',
          style: styles.formLabel.copyWith(color: colors.onSurfaceVariant),
        ),
        Flexible(
          child: Text(
            value,
            style: styles.formLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final InstallmentContractStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InstallmentContractStatus.active => (
        '进行中',
        Theme.of(context).colorScheme.primary,
      ),
      InstallmentContractStatus.settled => (
        '已结清',
        Theme.of(context).colorScheme.tertiary,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: context.appTextStyles.formLabel.copyWith(color: color),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.contract});

  final InstallmentContractReadModel contract;

  @override
  Widget build(BuildContext context) {
    if (contract.status != InstallmentContractStatus.active) {
      return const SizedBox.shrink();
    }
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
                label: '提前还款',
                onTap: () => context.push('/installments/${contract.id}/repay'),
              ),
            ),
            const SizedBox(width: AppSpacing.space6),
            Expanded(
              child: _ActionButton(
                icon: RemixIcons.edit_line,
                label: '编辑合同',
                onTap: () => context.push('/installments/${contract.id}/edit'),
              ),
            ),
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

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.contract, required this.schedule});

  final InstallmentContractReadModel contract;
  final InstallmentScheduleReadModel schedule;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final total =
        schedule.expectedPrincipal +
        schedule.expectedInterest +
        schedule.expectedFee;
    return InkWell(
      onTap: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text('第${schedule.periodNo}期', style: styles.formLabel),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(schedule.expectedRepaymentDate),
                    style: styles.formLabel,
                  ),
                  Text(
                    '本金 ${schedule.expectedPrincipal.format()}'
                    '${schedule.expectedInterest.minorUnits > 0 ? '  利息 ${schedule.expectedInterest.format()}' : ''}'
                    '${schedule.expectedFee.minorUnits > 0 ? '  手续费 ${schedule.expectedFee.format()}' : ''}',
                    style: styles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(total.format(), style: styles.formLabel),
                Text(
                  _scheduleStatusLabel(schedule.status),
                  style: styles.listSupporting.copyWith(
                    color: _scheduleStatusColor(schedule.status, colors),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RepaymentRow extends ConsumerWidget {
  const _RepaymentRow({required this.cashflow, required this.contract});

  final ContractRepayment cashflow;
  final InstallmentContractReadModel contract;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final total = cashflow.principal + cashflow.interest + cashflow.fee;
    return InkWell(
      onTap:
          cashflow.transactionId == null
              ? null
              : () => context.push('/transaction/${cashflow.transactionId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                _repaymentTypeLabel(cashflow.repaymentType),
                style: styles.formLabel.copyWith(
                  color: _repaymentTypeColor(cashflow.repaymentType, colors),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(cashflow.occurredAt),
                    style: styles.formLabel,
                  ),
                  Text(
                    '本金 ${cashflow.principal.format()}'
                    '${cashflow.interest.minorUnits > 0 ? '  利息 ${cashflow.interest.format()}' : ''}'
                    '${cashflow.fee.minorUnits > 0 ? '  手续费 ${cashflow.fee.format()}' : ''}',
                    style: styles.listSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space8),
            Text(total.format(), style: styles.formLabel),
            IconButton(
              tooltip: '撤销',
              icon: Icon(
                RemixIcons.arrow_go_back_line,
                color: colors.onSurfaceVariant,
                size: AppSpacing.space20,
              ),
              onPressed: () => _confirmRevert(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevert(BuildContext context, WidgetRef ref) async {
    final typeLabel = _repaymentTypeLabel(cashflow.repaymentType);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('撤销$typeLabel'),
            content: const Text('将删除该笔还款交易，并把对应期次状态还原为待还。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('撤销'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final outcome = await ref
        .read(installmentDetailViewModelProvider(contract.id).notifier)
        .revertRepayment(cashflow.id);
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<void>():
        break;
      case UiActionFailure<void>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('撤销失败：${error.message}')));
    }
  }
}

String _methodLabel(InstallmentRepaymentMethod method) {
  return switch (method) {
    InstallmentRepaymentMethod.equalInstallment => '等额本息',
    InstallmentRepaymentMethod.equalPrincipal => '等额本金',
    InstallmentRepaymentMethod.interestFirst => '先息后本',
    InstallmentRepaymentMethod.flatFee => '一次性手续费',
    InstallmentRepaymentMethod.custom => '自定义',
  };
}

String _scheduleStatusLabel(InstallmentScheduleStatus status) {
  return switch (status) {
    InstallmentScheduleStatus.pending => '待还',
    InstallmentScheduleStatus.partiallyPaid => '部分已还',
    InstallmentScheduleStatus.paid => '已还',
    InstallmentScheduleStatus.skipped => '已跳过',
  };
}

Color _scheduleStatusColor(
  InstallmentScheduleStatus status,
  ColorScheme colors,
) {
  return switch (status) {
    InstallmentScheduleStatus.pending => colors.primary,
    InstallmentScheduleStatus.partiallyPaid => colors.error,
    InstallmentScheduleStatus.paid => colors.tertiary,
    InstallmentScheduleStatus.skipped => colors.outline,
  };
}

String _repaymentTypeLabel(RepaymentType type) {
  return switch (type) {
    RepaymentType.bill => '账单还款',
    RepaymentType.installment => '分期还款',
    RepaymentType.prepayment => '提前还款',
    RepaymentType.unattributed => '未归属',
  };
}

Color _repaymentTypeColor(RepaymentType type, ColorScheme colors) {
  return switch (type) {
    RepaymentType.bill => colors.tertiary,
    RepaymentType.installment => colors.tertiary,
    RepaymentType.prepayment => colors.primary,
    RepaymentType.unattributed => colors.outline,
  };
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatRate(InterestRatePeriod? period, int? ppm) {
  if (period == null || ppm == null) return '—';
  final percent = (ppm / 10000).toStringAsFixed(4);
  final periodLabel = switch (period) {
    InterestRatePeriod.annual => '年',
    InterestRatePeriod.monthly => '月',
    InterestRatePeriod.daily => '日',
  };
  return '$percent% / $periodLabel';
}
