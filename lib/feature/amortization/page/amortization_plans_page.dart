import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../provider/amortization_providers.dart';

class AmortizationPlansPage extends ConsumerWidget {
  const AmortizationPlansPage({
    this.deferralAccountId,
    this.initialKind = AmortizationKind.prepaidExpense,
    super.key,
  });

  final String? deferralAccountId;
  final AmortizationKind initialKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(
      amortizationPlansProvider(deferralAccountId: deferralAccountId),
    );
    final accounts = ref.watch(accountsByIdProvider).value ?? const {};
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '摊销计划',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.add_line,
                  tooltip: '新建摊销',
                  onPressed: () => _openNew(context),
                ),
              ],
            ),
            Expanded(
              child: switch (plans) {
                AsyncData(value: final values) when values.isEmpty =>
                  const AppEmptyState(
                    icon: Icon(RemixIcons.calendar_schedule_line),
                    title: '暂无摊销计划',
                    message: '预付费用或预收收入可以按日、月、年自动确认。',
                  ),
                AsyncData(value: final values) => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space12,
                    AppSpacing.space16,
                    AppSpacing.space24,
                  ),
                  itemCount: values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.space10),
                  itemBuilder: (context, index) {
                    final plan = values[index];
                    return _PlanCard(
                      plan: plan,
                      deferralName:
                          accounts[plan.deferralAccountId]?.name ?? '递延账户',
                      categoryName:
                          accounts[plan.categoryAccountId]?.name ?? '分类',
                      onTap: () => context.push('/amortizations/${plan.id}'),
                    );
                  },
                ),
                AsyncError() => const Center(child: Text('摊销计划加载失败')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openNew(BuildContext context) {
    final kind = '&kind=${initialKind.name}';
    final account = deferralAccountId == null
        ? ''
        : '&deferralAccountId=$deferralAccountId';
    context.push('/amortizations/new?source=list$kind$account');
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.deferralName,
    required this.categoryName,
    required this.onTap,
  });

  final AmortizationPlan plan;
  final String deferralName;
  final String categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = plan.nextPendingEntry;
    return AppSurface(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.space12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      categoryName,
                      style: context.appTextStyles.listTitle,
                    ),
                  ),
                  AppStatusBadge(
                    presentation: AppStatusBadgePresentation(
                      label: _statusLabel(plan.status),
                      tone: _statusTone(plan.status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              Text(
                '$deferralName · ${_kindLabel(plan.kind)}',
                style: context.appTextStyles.listSupporting,
              ),
              const SizedBox(height: AppSpacing.space12),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: '计划总额',
                      value: MoneyText(money: plan.total),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: '剩余待确认',
                      value: MoneyText(money: plan.remainingAmount),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: next == null ? '计划状态' : '下一期',
                      value: Text(
                        next == null
                            ? _statusLabel(plan.status)
                            : _date(next.dueAt),
                        style: context.appTextStyles.formValue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.appTextStyles.listSupporting),
        const SizedBox(height: AppSpacing.space2),
        DefaultTextStyle(
          style: context.appTextStyles.formValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: value,
        ),
      ],
    );
  }
}

String _kindLabel(AmortizationKind kind) => switch (kind) {
  AmortizationKind.prepaidExpense => '预付费用',
  AmortizationKind.deferredIncome => '预收收入',
};

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

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
