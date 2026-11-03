import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_inline_action_button.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_swipe_action.dart';
import '../../../domain/orchestration/entity/amortization_period.dart';
import '../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../widget/business/finance/finance_activity_row.dart';
import '../../../widget/business/finance/finance_schedule_list.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/amortization_detail_view_model.dart';

class AmortizationDetailPage extends ConsumerWidget {
  const AmortizationDetailPage({required this.planId, super.key});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(amortizationDetailViewModelProvider(planId));
    return switch (asyncState) {
      AsyncData(value: final state) when state != null => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppPageHeader(
                title: '摊销详情',
                actions: [
                  AppPopupMenuButton(
                    icon: RemixIcons.more_2_fill,
                    tooltip: '更多',
                    items: [
                      AppPopupMenuAction(
                        label: '删除摊销计划',
                        icon: RemixIcons.delete_bin_line,
                        onPressed: () => _confirmDeletePlan(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(child: _Body(state: state)),
            ],
          ),
        ),
      ),
      AsyncData(value: null) => const _StatusPage(message: '摊销计划不存在'),
      AsyncError() => const _StatusPage(message: '摊销计划加载失败'),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Future<void> _confirmDeletePlan(BuildContext context, WidgetRef ref) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除摊销计划'),
            content: const Text('将删除该计划及全部关联账务交易，且无法恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    final outcome = await ref
        .read(amortizationDetailViewModelProvider(planId).notifier)
        .deletePlan();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess():
        Navigator.of(context).maybePop();
      case UiActionFailure(:final error):
        _showMessage(context, error.message);
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final AmortizationDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = state.plan;
    final canCreateRefund =
        plan.status != AmortizationStatus.terminated &&
        plan.remainingAmount.minorUnits > 0;
    final canTerminate = canCreateRefund;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space6,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        _SummaryCard(plan: plan),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space8,
              vertical: AppSpacing.space6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppInlineActionButton(
                    icon: RemixIcons.settings_3_line,
                    label: '配置编辑',
                    onPressed: () =>
                        context.push('/amortizations/${plan.id}/configuration'),
                  ),
                ),
                const SizedBox(width: AppSpacing.space6),
                Expanded(
                  child: AppInlineActionButton(
                    icon: RemixIcons.refund_2_line,
                    label: '摊销退款',
                    onPressed: canCreateRefund
                        ? () => context.push(
                            '/transaction/${plan.initialTransactionId}/refund',
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.space6),
                Expanded(
                  child: AppInlineActionButton(
                    icon: RemixIcons.stop_circle_line,
                    label: '摊销终止',
                    onPressed: canTerminate
                        ? () => context.push(
                            '/transaction/${plan.initialTransactionId}'
                            '/amortization-terminate',
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space16),
        Text('摊销进度', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        _Schedule(periods: plan.periods),
        const SizedBox(height: AppSpacing.space16),
        Text('摊销动态', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        if (state.activities.isEmpty)
          const AppSurface(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.space20),
              child: Text('暂无摊销动态'),
            ),
          )
        else
          AppSurface(
            child: Column(
              children: [
                for (final activity in state.activities)
                  _ActivityEntry(
                    planId: plan.id,
                    kind: plan.kind,
                    activity: activity,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan});

  final AmortizationPlan plan;

  @override
  Widget build(BuildContext context) {
    return AppDetailSummaryCard(
      title: '摊销计划',
      headerTrailing: AppStatusBadge(
        presentation: AppStatusBadgePresentation(
          label: _statusLabel(plan.status),
          tone: _statusTone(plan.status),
        ),
      ),
      mainItems: [
        AppDetailSummaryCardItem(
          label: '待摊金额',
          value: _money(plan.remainingAmount),
        ),
        AppDetailSummaryCardItem(
          label: '已摊销',
          value: _money(plan.recognizedAmount),
        ),
        AppDetailSummaryCardItem(
          label: '累计退款',
          value: _money(plan.refundedAmount),
        ),
      ],
      supportingItems: [
        AppDetailSummaryCardItem(
          label: '原摊销额',
          value: _money(plan.originalAmount),
        ),
        AppDetailSummaryCardItem(label: '净摊销额', value: _money(plan.netAmount)),
        AppDetailSummaryCardItem(
          label: '首期日期',
          value: formatDateLabel(plan.firstRecognitionAt),
        ),
        AppDetailSummaryCardItem(
          label: '摊销期数',
          value: '${plan.recognitionCount} 期',
        ),
        AppDetailSummaryCardItem(
          label: '期次间隔',
          value: _cadenceUnitLabel(plan.cadenceUnit),
        ),
        AppDetailSummaryCardItem(
          label: '间隔数',
          value: '${plan.cadenceInterval}',
        ),
      ],
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.periods});

  final List<AmortizationPeriod> periods;

  @override
  Widget build(BuildContext context) {
    return FinanceScheduleList(
      emptyMessage: '暂无摊销进度',
      items: [
        for (final period in periods)
          FinanceScheduleItem(
            id: period.id,
            periodLabel: period.sequenceNo.toString().padLeft(2, '0'),
            date: period.dueAt,
            amountLabel: _money(period.amount),
            statusLabel: _periodStatusLabel(period),
            statusTone: _periodStatusTone(period),
            onTap: period.isPosted
                ? () => context.push('/transaction/${period.transactionId}')
                : null,
          ),
      ],
    );
  }
}

class _ActivityEntry extends ConsumerWidget {
  const _ActivityEntry({
    required this.planId,
    required this.kind,
    required this.activity,
  });

  final String planId;
  final AmortizationKind kind;
  final AmortizationActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = _ActivityRow(planKind: kind, activity: activity);
    return switch (activity.kind) {
      AmortizationActivityKind.initial => row,
      AmortizationActivityKind.refund => AppSwipeAction(
        dismissibleKey: ValueKey('amortization-refund-${activity.id}'),
        label: '删除退款',
        icon: RemixIcons.delete_bin_6_line,
        tone: AppSwipeActionTone.danger,
        onTriggered: () => _confirmDeleteRefund(context, ref),
        child: row,
      ),
      AmortizationActivityKind.termination => AppSwipeAction(
        dismissibleKey: ValueKey('amortization-termination-${activity.id}'),
        label: '删除摊销终止',
        icon: RemixIcons.delete_bin_6_line,
        tone: AppSwipeActionTone.danger,
        onTriggered: () => _confirmDeleteTermination(context, ref),
        child: row,
      ),
    };
  }

  Future<void> _confirmDeleteRefund(BuildContext context, WidgetRef ref) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除摊销退款'),
            content: const Text('删除后将移除这笔退款，并按剩余净额重新计算全部摊销期次。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    final outcome = await ref
        .read(amortizationDetailViewModelProvider(planId).notifier)
        .deleteRefund(activity.refundId!);
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess():
        _showMessage(context, '摊销退款已删除');
      case UiActionFailure(:final error):
        _showMessage(context, error.message);
    }
  }

  Future<void> _confirmDeleteTermination(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除摊销终止'),
            content: const Text('删除后将移除终止确认和终止退还交易，恢复并补齐摊销期次。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    final outcome = await ref
        .read(amortizationDetailViewModelProvider(planId).notifier)
        .deleteTermination();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess():
        _showMessage(context, '摊销终止已删除');
      case UiActionFailure(:final error):
        _showMessage(context, error.message);
    }
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.planKind, required this.activity});

  final AmortizationKind planKind;
  final AmortizationActivity activity;

  @override
  Widget build(BuildContext context) {
    final (label, icon, amount, supporting) = switch (activity.kind) {
      AmortizationActivityKind.initial => (
        planKind == AmortizationKind.prepaidExpense ? '摊销预付' : '摊销预收',
        RemixIcons.arrow_left_right_line,
        activity.amount,
        null,
      ),
      AmortizationActivityKind.refund => (
        '摊销退款',
        RemixIcons.refund_2_line,
        activity.amount,
        null,
      ),
      AmortizationActivityKind.termination => (
        '摊销终止',
        RemixIcons.stop_circle_line,
        activity.terminationReturnAmount +
            activity.terminationRecognitionAmount,
        '退还 ${_money(activity.terminationReturnAmount)}'
            ' · 确认 ${_money(activity.terminationRecognitionAmount)}',
      ),
    };
    return FinanceActivityRow(
      label: label,
      occurredAt: activity.occurredAt,
      amountLabel: _money(amount),
      icon: icon,
      supportingText: supporting,
      onTap: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    context.push('/transaction/${activity.transactionId}');
  }
}

class _StatusPage extends StatelessWidget {
  const _StatusPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '摊销详情'),
            Expanded(child: Center(child: Text(message))),
          ],
        ),
      ),
    );
  }
}

String _money(Money money) => formatMoney(money, style: MoneyFormatStyle.plain);

String _statusLabel(AmortizationStatus status) => switch (status) {
  AmortizationStatus.active => '进行中',
  AmortizationStatus.completed => '已完成',
  AmortizationStatus.terminated => '已终止',
};

AppStatusTone _statusTone(AmortizationStatus status) => switch (status) {
  AmortizationStatus.active => AppStatusTone.info,
  AmortizationStatus.completed => AppStatusTone.success,
  AmortizationStatus.terminated => AppStatusTone.neutral,
};

String _periodStatusLabel(AmortizationPeriod period) {
  return switch (period.status) {
    AmortizationPeriodStatus.pending => '待确认',
    AmortizationPeriodStatus.posted => '已确认',
    AmortizationPeriodStatus.zero => '零金额',
    AmortizationPeriodStatus.canceled => '已取消',
  };
}

FinanceScheduleTone _periodStatusTone(AmortizationPeriod period) {
  return switch (period.status) {
    AmortizationPeriodStatus.pending => FinanceScheduleTone.info,
    AmortizationPeriodStatus.posted => FinanceScheduleTone.success,
    AmortizationPeriodStatus.zero ||
    AmortizationPeriodStatus.canceled => FinanceScheduleTone.neutral,
  };
}

String _cadenceUnitLabel(AmortizationCadenceUnit unit) {
  return switch (unit) {
    AmortizationCadenceUnit.daily => '天',
    AmortizationCadenceUnit.monthly => '月',
    AmortizationCadenceUnit.yearly => '年',
  };
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
