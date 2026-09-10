import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';

import '../../../core/money/money.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_swipe_action.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../shared/presentation/reference_rate_presentation.dart';
import '../presentation/contract_status_validation_presentation.dart';
import '../presentation/installment_schedule_presentation.dart';
import '../view_model/installment_detail_view_model.dart';
import '../widget/installment_schedule_view.dart';

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
                if (loaded != null &&
                    loaded.contract.status ==
                        InstallmentContractStatus.active &&
                    loaded.contract.stageTerms.repayments.any(
                      (s) => s.floatingRate != null,
                    ))
                  AppHeaderIconButton(
                    onPressed: () => _previewRepricing(context, ref),
                    icon: RemixIcons.percent_line,
                    tooltip: '重定价预览',
                  ),
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
      builder: (ctx) => AlertDialog(
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
    final outcome = await ref
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

  Future<void> _previewRepricing(BuildContext context, WidgetRef ref) async {
    final vm = ref.read(
      installmentDetailViewModelProvider(contractId).notifier,
    );
    final outcome = await vm.previewRepricing();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionFailure<RepricingPreview?>(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      case UiActionSuccess<RepricingPreview?>(:final value):
        if (value == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无可应用的重定价结果；未确定的报价继续按已知利率预测。')),
          );
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('重定价差异预览'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatDateLabel(value.effectiveDate)} 起，执行年利率 ${value.ratePpm / 10000}%',
                  ),
                  if (value.hasFrozenPeriods)
                    const Text('部分受影响期次已冻结，金额保持原样，请核对历史利息。'),
                  if (value.hasIssuedBills)
                    const Text('已出账账单保持原样，确认后请按需在账单详情刷新。'),
                  if (value.requiresReview)
                    const Text('请核对人工调整及冻结期次。确认将应用以下金额变化。'),
                  for (final d in value.differences)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.space12),
                      child: Text(
                        '第 ${d.periodNo} 期 · ${formatDateLabel(d.date)}\n'
                        '本金 ${d.oldPrincipal.format()} → ${d.principal.format()}\n'
                        '利息 ${d.oldInterest.format()} → ${d.interest.format()}',
                      ),
                    ),
                  if (value.differences.isEmpty)
                    const Text('待还计划金额无变化，仍会记录本次重定价。'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('确认应用'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final applied = await vm.applyRepricing(value);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(switch (applied) {
              UiActionSuccess<void>() => '已应用本次重定价',
              UiActionFailure<void>(:final error) => error.message,
            }),
          ),
        );
    }
  }

  Future<void> _confirmStatusValidation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
    final outcome = await ref
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
    final scheduleItems = {
      for (final item in loaded.scheduleItems) item.schedule.id: item,
    };
    final cashflows = loaded.repayments;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space6,
        AppSpacing.space16,
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
        if (contract.stageTerms.repayments.any(
          (s) => s.floatingRate != null,
        )) ...[
          const SizedBox(height: AppSpacing.space12),
          const Text('浮动利率计划：尚未确定的未来利率沿用已知利率预测，总利息与年化成本会随重定价变化。'),
          for (final stage in contract.stageTerms.repayments)
            for (final change in stage.rateChanges)
              Text(
                '${formatDateLabel(change.effectiveDate)} 起 ${change.rate.ppm / 10000}% · '
                '${referenceRateTypeLabel(change.referenceRate.type)} ${referenceRatePercent(change.referenceRate.ratePpm)} ${change.spreadBp >= 0 ? '+' : ''}${change.spreadBp} BP',
              ),
        ],
        const SizedBox(height: AppSpacing.space12),
        Text('还款计划', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        InstallmentScheduleView(
          items: contractScheduleItems(contract, loaded.schedules),
          rowWrapper: (context, row, child) => _ScheduleActions(
            contract: contract,
            item: scheduleItems[row.id]!,
            child: child,
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
      title: contract.name,
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
          value: contract.stageTerms.stages.length > 1
              ? contract.stageTerms.stages
                    .map(
                      (s) => s.terms is DefermentStage
                          ? '免还期'
                          : _methodLabel((s.terms as AmortizingStage).method),
                    )
                    .join(' → ')
              : _methodLabel(contract.stageTerms.repayments.first.method),
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
          value: contract.stageTerms.stages.length > 1
              ? '按各阶段条款'
              : _accrualMethodLabel(
                  contract.stageTerms.repayments.first.accrual,
                ),
        ),
        AppDetailSummaryCardItem(
          label: '利率',
          value: contract.stageTerms.stages.length > 1
              ? '按各阶段条款'
              : _formatRate(
                  contract.stageTerms.repayments.first
                      .rateOn(DateTime.now())
                      ?.period,
                  contract.stageTerms.repayments.first
                      .rateOn(DateTime.now())
                      ?.ppm,
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
                  onTap: () =>
                      context.push('/installments/${contract.id}/repay'),
                ),
              ),
              const SizedBox(width: AppSpacing.space6),
              Expanded(
                child: _ActionButton(
                  icon: RemixIcons.edit_line,
                  label: '编辑合同',
                  onTap: () =>
                      context.push('/installments/${contract.id}/edit'),
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

class _ScheduleActions extends ConsumerWidget {
  const _ScheduleActions({
    required this.contract,
    required this.item,
    required this.child,
  });
  final InstallmentContractReadModel contract;
  final InstallmentScheduleItemState item;
  final Widget child;
  InstallmentScheduleReadModel get schedule => item.schedule;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = child;
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
      builder: (ctx) => AlertDialog(
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
      onTap: cashflow.transactionId == null
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
      builder: (ctx) => AlertDialog(
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
    InterestAccrualMethod.annual => '按年计息',
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
