import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_inline_action_button.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../design_system/widget/app_swipe_action.dart';
import '../../../widget/business/finance/finance_activity_row.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/social_insurance_detail_view_model.dart';
import '../widget/social_contribution_editor.dart';

class SocialInsuranceDetailPage extends ConsumerWidget {
  const SocialInsuranceDetailPage({required this.insuranceId, super.key});

  final String insuranceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = socialInsuranceDetailViewModelProvider(insuranceId);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ref
            .watch(provider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text('加载失败，点击重试'),
                ),
              ),
              data: (detail) {
                if (detail == null) {
                  return const Column(
                    children: [
                      AppPageHeader(title: '社保详情'),
                      Expanded(child: Center(child: Text('社保记录不存在'))),
                    ],
                  );
                }
                final notifier = ref.read(provider.notifier);
                final contributionRecords = insuranceContributionsNewestFirst(
                  detail.contributionRecords,
                );
                return Column(
                  children: [
                    AppPageHeader(
                      title: '社保详情',
                      actions: [
                        AppHeaderIconButton(
                          icon: RemixIcons.edit_line,
                          tooltip: '编辑社保记录',
                          onPressed: () => context.push(
                            '/insurance/social/$insuranceId/edit',
                          ),
                        ),
                        AppPopupMenuButton(
                          tooltip: '社保记录操作',
                          icon: RemixIcons.more_2_line,
                          items: [
                            AppPopupMenuAction(
                              label: '删除社保记录',
                              icon: RemixIcons.delete_bin_line,
                              onPressed: () => _delete(
                                context,
                                notifier,
                                detail.insuranceType.label,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.space16,
                          AppSpacing.space8,
                          AppSpacing.space16,
                          AppSpacing.space32,
                        ),
                        children: [
                          AppDetailSummaryCard(
                            key: const ValueKey('social-overview-card'),
                            title: '社保${detail.insuranceType.label}',
                            headerTrailing: Text(
                              detail.participantType.label,
                              style: context.appTextStyles.listSupporting,
                            ),
                            mainItems: [
                              AppDetailSummaryCardItem(
                                label: '参保人',
                                value: detail.insuredPersonName,
                                maxLines: 2,
                              ),
                              AppDetailSummaryCardItem(
                                label: '参保地区',
                                value: detail.region,
                                maxLines: 2,
                              ),
                            ],
                            supportingItems: const [],
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          AppSurface(
                            key: const ValueKey('social-action-bar'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.space8,
                                vertical: AppSpacing.space6,
                              ),
                              child: AppInlineActionButton(
                                icon: RemixIcons.bank_card_line,
                                label: '缴费',
                                onPressed: detail.submitting
                                    ? null
                                    : () =>
                                          _editContribution(context, notifier),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.space12),
                          Text(
                            '缴费记录',
                            style: context.appTextStyles.dateSectionTitle,
                          ),
                          const SizedBox(height: AppSpacing.space6),
                          AppSurface(
                            key: const ValueKey('social-contribution-records'),
                            child: contributionRecords.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(AppSpacing.space20),
                                    child: Text('暂无缴费记录'),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < contributionRecords.length;
                                        index++
                                      ) ...[
                                        _ContributionRow(
                                          record: contributionRecords[index],
                                          enabled: !detail.submitting,
                                          onEdit: () => _editContribution(
                                            context,
                                            notifier,
                                            contributionRecords[index],
                                          ),
                                          onDelete: () => _deleteContribution(
                                            context,
                                            notifier,
                                            contributionRecords[index],
                                          ),
                                        ),
                                        if (index <
                                            contributionRecords.length - 1)
                                          const AppListDivider(),
                                      ],
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    SocialInsuranceDetailViewModel notifier,
    String insuranceTypeLabel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除社保$insuranceTypeLabel'),
        content: const Text('确定删除该社保记录及其全部缴费记录吗？'),
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
    );
    if (confirmed != true || !context.mounted) return;
    final outcome = await notifier.deleteInsurance();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<void>():
        context.pop();
      case UiActionFailure<void>(:final error):
        _showOutcome(context, UiActionOutcome.failure(error));
    }
  }

  Future<void> _editContribution(
    BuildContext context,
    SocialInsuranceDetailViewModel notifier, [
    SocialContributionRecord? record,
  ]) async {
    final draft = await showDialog<SocialContributionDraft>(
      context: context,
      builder: (context) => SocialContributionEditorDialog(existing: record),
    );
    if (draft == null || !context.mounted) return;
    final outcome = await notifier.saveContributionRecord(
      originalPeriod: record?.period,
      year: draft.year,
      month: draft.month,
      contributionBase: draft.contributionBase,
      contributionAmount: draft.contributionAmount,
      note: draft.note,
    );
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _deleteContribution(
    BuildContext context,
    SocialInsuranceDetailViewModel notifier,
    SocialContributionRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除缴费记录'),
        content: Text(
          '确定删除 ${insuranceContributionPeriodLabel(record)} 的缴费记录吗？',
        ),
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
    );
    if (confirmed != true || !context.mounted) return;
    final outcome = await notifier.removeContributionRecord(record.period);
    if (context.mounted) _showOutcome(context, outcome);
  }

  void _showOutcome(BuildContext context, UiActionOutcome<void> outcome) {
    if (outcome case UiActionFailure<void>(:final error)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.record,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final SocialContributionRecord record;
  final bool enabled;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final supportingItems = [
      if (record.contributionBase != null)
        '缴费基数 ${insuranceMoneyLabel(record.contributionBase)}',
      ?record.note,
    ];
    final row = FinanceActivityRow.period(
      key: ValueKey('social-contribution-${record.period}'),
      label: '缴费',
      periodLabel: insuranceContributionPeriodLabel(record),
      amountLabel: insuranceMoneyLabel(record.contributionAmount),
      supportingText: supportingItems.isEmpty
          ? null
          : supportingItems.join(' · '),
      icon: RemixIcons.bank_card_line,
      onTap: enabled ? onEdit : null,
    );
    if (!enabled) return row;
    return AppSwipeAction(
      dismissibleKey: ValueKey('social-contribution-swipe-${record.period}'),
      label: '删除',
      icon: RemixIcons.delete_bin_line,
      tone: AppSwipeActionTone.danger,
      onTriggered: onDelete,
      child: row,
    );
  }
}
