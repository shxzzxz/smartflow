import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';

import '../../../core/money/money.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_swipe_action.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_status_badge.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/contract_status_validation_presentation.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '分期合同',
              actions: [
                if (loaded != null)
                  AppHeaderIconButton(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: RemixIcons.delete_bin_line,
                    tooltip: '删除合同',
                  ),
              ],
            ),
            Expanded(
              child: switch (detailAsync) {
                AsyncData(value: final InstallmentDetailLoaded loaded) => _Body(
                  loaded: loaded,
                  onValidate: () => _confirmStatusValidation(context, ref),
                ),
                AsyncData(value: InstallmentDetailNotFound()) => const Center(
                  child: Text('合同不存在'),
                ),
                AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
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

  Future<void> _confirmStatusValidation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('校验合同状态'),
            content: const Text('将根据实际还款记录重新计算还款计划和合同状态。不会修改金额、日期、账单或交易。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('校验'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final outcome =
        await ref
            .read(installmentDetailViewModelProvider(contractId).notifier)
            .validateContractStatuses();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<ContractStatusValidationResult>(:final value):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(contractStatusValidationMessage(value))),
        );
      case UiActionFailure<ContractStatusValidationResult>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('校验失败：${error.message}')));
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.loaded, required this.onValidate});

  final InstallmentDetailLoaded loaded;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final contract = loaded.contract;
    final scheduleItems = loaded.scheduleItems;
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
        _ActionBar(contract: contract, onValidate: onValidate),
        const SizedBox(height: AppSpacing.space12),
        Text('还款计划', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        AppSurface(
          child: Column(
            children: [
              for (var i = 0; i < scheduleItems.length; i++) ...[
                _ScheduleRow(contract: contract, item: scheduleItems[i]),
                if (i < scheduleItems.length - 1)
                  SizedBox(
                    key: ValueKey('installment-schedule-gap-$i'),
                    height: AppSpacing.space4,
                  ),
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
                    SizedBox(
                      key: ValueKey('installment-repayment-gap-$i'),
                      height: AppSpacing.space4,
                    ),
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
    final (statusLabel, statusColor) = switch (contract.status) {
      InstallmentContractStatus.active => (
        '进行中',
        Theme.of(context).colorScheme.primary,
      ),
      InstallmentContractStatus.settled => (
        '已结清',
        Theme.of(context).colorScheme.tertiary,
      ),
    };
    return AppDetailSummaryCard(
      title: '分期合同',
      headerTrailing: AppStatusBadge(label: statusLabel, color: statusColor),
      mainItems: [
        AppDetailSummaryCardItem(
          label: '待还本金',
          value: Money(minorUnits: remainingPrincipalMinor).format(),
        ),
        AppDetailSummaryCardItem(
          label: '已还利息',
          value: Money(minorUnits: paidInterestMinor).format(),
        ),
        AppDetailSummaryCardItem(
          label: '已还手续费',
          value: Money(minorUnits: paidFeeMinor).format(),
        ),
      ],
      supportingItems: [
        AppDetailSummaryCardItem(
          label: '分期方式',
          value: _methodLabel(contract.repaymentMethod),
        ),
        AppDetailSummaryCardItem(
          label: '本金',
          value: contract.principal.format(),
        ),
        AppDetailSummaryCardItem(
          label: '借款日期',
          value: formatDateLabel(contract.borrowingDate),
        ),
        AppDetailSummaryCardItem(
          label: '期数',
          value: '${contract.totalPeriods} 期',
        ),
        AppDetailSummaryCardItem(
          label: '计息方式',
          value: _accrualMethodLabel(contract.interestAccrualMethod),
        ),
        AppDetailSummaryCardItem(
          label: '利率',
          value: _formatRate(
            contract.interestRatePeriod,
            contract.interestRatePpm,
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.contract, required this.onValidate});

  final InstallmentContractReadModel contract;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final active = contract.status == InstallmentContractStatus.active;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space8,
          vertical: AppSpacing.space6,
        ),
        child: Row(
          children: [
            if (active) ...[
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.bank_card_line,
                  label: '提前还款',
                  onTap:
                      () => context.push('/installments/${contract.id}/repay'),
                ),
              ),
              const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.edit_line,
                  label: '编辑合同',
                  onTap:
                      () => context.push('/installments/${contract.id}/edit'),
                ),
              ),
              const SizedBox(width: AppSpacing.space6),
            ],
            Expanded(
              child: _ActionButton(
                icon: RemixIcons.refresh_line,
                label: '校验状态',
                onTap: onValidate,
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

class _ScheduleRow extends ConsumerWidget {
  const _ScheduleRow({required this.contract, required this.item});

  final InstallmentContractReadModel contract;
  final InstallmentScheduleItemState item;

  InstallmentScheduleReadModel get schedule => item.schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final total =
        schedule.expectedPrincipal +
        schedule.expectedInterest +
        schedule.expectedFee;
    final row = InkWell(
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
                    formatDateLabel(schedule.expectedRepaymentDate),
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

    final action = item.action;
    if (action == null) return row;

    final (label, icon, callback) = switch (action) {
      InstallmentScheduleAction.skip => (
        '跳过',
        RemixIcons.skip_forward_line,
        () => _confirmSkip(context, ref),
      ),
      InstallmentScheduleAction.restore => (
        '撤销跳过',
        RemixIcons.arrow_go_back_line,
        () => _restore(context, ref),
      ),
    };
    return AppSwipeAction(
      dismissibleKey: ValueKey('installment-schedule-${schedule.id}'),
      label: label,
      icon: icon,
      onTriggered: callback,
      child: row,
    );
  }

  Future<void> _confirmSkip(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('跳过本期'),
            content: Text('第${schedule.periodNo}期将不再进入账单，之后可以撤销跳过。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('跳过'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    await _handleOutcome(
      context,
      ref
          .read(installmentDetailViewModelProvider(contract.id).notifier)
          .skipSchedule(schedule.id),
      failurePrefix: '跳过失败',
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    await _handleOutcome(
      context,
      ref
          .read(installmentDetailViewModelProvider(contract.id).notifier)
          .restoreSchedule(schedule.id),
      failurePrefix: '撤销跳过失败',
    );
  }

  Future<void> _handleOutcome(
    BuildContext context,
    Future<UiActionOutcome<void>> action, {
    required String failurePrefix,
  }) async {
    final outcome = await action;
    if (!context.mounted) return;
    if (outcome case UiActionFailure<void>(:final error)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failurePrefix：${error.message}')),
      );
    }
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
    final row = InkWell(
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
                    formatDateLabel(cashflow.occurredAt),
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
          ],
        ),
      ),
    );
    return AppSwipeAction(
      dismissibleKey: ValueKey('installment-repayment-${cashflow.id}'),
      label: '撤销',
      icon: RemixIcons.arrow_go_back_line,
      tone: AppSwipeActionTone.danger,
      onTriggered: () => _confirmRevert(context, ref),
      child: row,
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

String _accrualMethodLabel(InterestAccrualMethod method) {
  return switch (method) {
    InterestAccrualMethod.daily => '按日计息',
    InterestAccrualMethod.monthly => '按月计息',
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
