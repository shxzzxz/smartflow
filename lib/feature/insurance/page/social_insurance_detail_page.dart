import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
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
    final asyncDetail = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: asyncDetail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(provider),
              child: const Text('加载失败，点击重试'),
            ),
          ),
          data: (detail) {
            if (detail == null) {
              return Column(
                children: [
                  const AppPageHeader(title: '社保详情'),
                  const Expanded(child: Center(child: Text('社保记录不存在'))),
                ],
              );
            }
            return Column(
              children: [
                AppPageHeader(
                  title: '社保${detail.insuranceType.label}',
                  subtitle: detail.insuredPersonName,
                  actions: [
                    AppHeaderIconButton(
                      icon: RemixIcons.edit_line,
                      tooltip: '编辑社保记录',
                      onPressed: () =>
                          context.push('/insurance/social/$insuranceId/edit'),
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
                            ref.read(provider.notifier),
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
                      AppSurface(
                        border: true,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.space16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SummaryRow(
                                label: '参保人',
                                value: detail.insuredPersonName,
                              ),
                              const SizedBox(height: AppSpacing.space10),
                              _SummaryRow(label: '参保地区', value: detail.region),
                              const SizedBox(height: AppSpacing.space10),
                              _SummaryRow(
                                label: '社保类型',
                                value: detail.insuranceType.label,
                              ),
                              const SizedBox(height: AppSpacing.space10),
                              _SummaryRow(
                                label: '参保类型',
                                value: detail.participantType.label,
                              ),
                              const SizedBox(height: AppSpacing.space10),
                              _SummaryRow(
                                label: '缴费记录',
                                value: '${detail.contributionRecords.length} 条',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space20),
                      AppSectionHeader(
                        title: '缴费记录',
                        trailing: TextButton.icon(
                          onPressed: () => _addContribution(
                            context,
                            ref.read(provider.notifier),
                          ),
                          icon: const Icon(
                            RemixIcons.add_line,
                            size: AppSpacing.space16,
                          ),
                          label: const Text('添加'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space8),
                      AppSurface(
                        border: true,
                        child: detail.contributionRecords.isEmpty
                            ? const AppEmptyState(
                                title: '还没有缴费记录',
                                message: '可按月份添加缴费基数。',
                                layout: AppEmptyStateLayout.inline,
                              )
                            : Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < detail.contributionRecords.length;
                                    index++
                                  ) ...[
                                    _ContributionRow(
                                      record: detail.contributionRecords[index],
                                      onEdit: () => _editContribution(
                                        context,
                                        ref.read(provider.notifier),
                                        detail.contributionRecords[index],
                                      ),
                                      onDelete: () => _deleteContribution(
                                        context,
                                        ref.read(provider.notifier),
                                        detail.contributionRecords[index],
                                      ),
                                    ),
                                    if (index <
                                        detail.contributionRecords.length - 1)
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _addContribution(
    BuildContext context,
    SocialInsuranceDetailViewModel notifier,
  ) async {
    final draft = await showDialog<SocialContributionDraft>(
      context: context,
      builder: (context) => const SocialContributionEditorDialog(),
    );
    if (draft == null || !context.mounted) return;
    final outcome = await notifier.addContributionRecord(
      draft.month,
      draft.contributionBase,
    );
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _editContribution(
    BuildContext context,
    SocialInsuranceDetailViewModel notifier,
    SocialContributionRecord record,
  ) async {
    final draft = await showDialog<SocialContributionDraft>(
      context: context,
      builder: (context) => SocialContributionEditorDialog(existing: record),
    );
    if (draft == null || !context.mounted) return;
    final outcome = await notifier.updateContributionRecord(
      originalMonth: record.month,
      month: draft.month,
      contributionBase: draft.contributionBase,
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
        content: Text('确定删除 ${insuranceMonthLabel(record.month)} 的缴费记录吗？'),
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
    final outcome = await notifier.removeContributionRecord(record.month);
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: context.appTextStyles.detailLabel),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.appTextStyles.detailValue,
          ),
        ),
      ],
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final SocialContributionRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('social-contribution-${record.month}'),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space10,
          AppSpacing.space8,
          AppSpacing.space10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insuranceMonthLabel(record.month),
                    style: context.appTextStyles.listTitle,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text('缴费基数', style: context.appTextStyles.listSupporting),
                ],
              ),
            ),
            MoneyText(
              money: record.contributionBase,
              semantic: MoneySemantic.neutral,
              style: context.appTextStyles.formValue,
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: '编辑缴费记录',
              visualDensity: VisualDensity.compact,
              icon: const Icon(RemixIcons.edit_line),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: '删除缴费记录',
              visualDensity: VisualDensity.compact,
              icon: const Icon(RemixIcons.delete_bin_line),
            ),
          ],
        ),
      ),
    );
  }
}
