import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_command_api.dart'
    show PremiumPlan;
import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_inline_action_button.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/commercial_insurance_detail_view_model.dart';
import '../widget/insurance/insurance_coverage_overview_card.dart';
import '../widget/insurance_premium_plan_editor.dart';
import '../../../design_system/widget/app_scaffold.dart';

class CommercialInsuranceDetailPage extends ConsumerWidget {
  const CommercialInsuranceDetailPage({required this.insuranceId, super.key});

  final String insuranceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = commercialInsuranceDetailViewModelProvider(insuranceId);
    final asyncDetail = ref.watch(provider);
    return AppScaffold(
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
              return const Column(
                children: [
                  AppPageHeader(title: '商业保险'),
                  Expanded(child: Center(child: Text('商业保险不存在'))),
                ],
              );
            }
            final insurance = detail.insurance;
            return Column(
              children: [
                AppPageHeader(
                  title: '保单详情',
                  actions: [
                    AppHeaderIconButton(
                      icon: RemixIcons.edit_line,
                      tooltip: '编辑商业保险',
                      onPressed: () => context.push(
                        '/insurance/commercial/$insuranceId/edit',
                      ),
                    ),
                    AppPopupMenuButton(
                      tooltip: '商业保险操作',
                      icon: RemixIcons.more_2_line,
                      items: [
                        AppPopupMenuAction(
                          label: '删除商业保险',
                          icon: RemixIcons.delete_bin_line,
                          onPressed: () => _deleteInsurance(
                            context,
                            ref.read(provider.notifier),
                            insurance.name,
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
                      _OverviewCard(detail: detail),
                      const SizedBox(height: AppSpacing.space8),
                      _ActionBar(
                        onConfigurePremium: () => _editPremiumPlan(
                          context,
                          ref.read(provider.notifier),
                          insurance.premiumPlan,
                        ),
                        onUploadAttachment: () => _addAttachments(
                          context,
                          ref.read(provider.notifier),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space12),
                      InsuranceCoverageOverviewCard(
                        key: const ValueKey('commercial-coverage-overview'),
                        title: '保障责任',
                        summary: insurance.coverageSummary,
                        highlights: insurance.coverageHighlights,
                        waitingPeriodDescription:
                            insurance.waitingPeriodDescription,
                        exclusionsDescription: insurance.exclusionsDescription,
                        showResponsibilitiesLink: true,
                        onTap: () => context.push(
                          '/insurance/commercial/$insuranceId/'
                          'responsibilities',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space12),
                      _AttachmentSection(
                        attachments: insurance.attachments,
                        onOpen: (attachmentId) => _openAttachment(
                          context,
                          ref.read(provider.notifier),
                          attachmentId,
                        ),
                        onDelete: (attachmentId) => _deleteAttachment(
                          context,
                          ref.read(provider.notifier),
                          attachmentId,
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

  Future<void> _addAttachments(
    BuildContext context,
    CommercialInsuranceDetailViewModel notifier,
  ) async {
    final outcome = await notifier.addAttachments();
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<int>(:final value) when value > 0:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已添加 $value 个附件')));
      case UiActionSuccess<int>():
        break;
      case UiActionFailure<int>(:final error):
        _showError(context, error.message);
    }
  }

  Future<void> _editPremiumPlan(
    BuildContext context,
    CommercialInsuranceDetailViewModel notifier,
    PremiumPlan? existing,
  ) async {
    final draft = await showDialog<InsurancePremiumPlanDraft>(
      context: context,
      builder: (context) =>
          InsurancePremiumPlanEditorDialog(existing: existing),
    );
    if (draft == null || !context.mounted) return;
    final outcome = await notifier.savePremiumPlan(draft.plan);
    if (!context.mounted) return;
    switch (outcome) {
      case UiActionSuccess<void>():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(draft.plan == null ? '缴费配置已清除' : '缴费配置已保存')),
        );
      case UiActionFailure<void>(:final error):
        _showError(context, error.message);
    }
  }

  Future<void> _openAttachment(
    BuildContext context,
    CommercialInsuranceDetailViewModel notifier,
    String attachmentId,
  ) async {
    final outcome = await notifier.openAttachment(attachmentId);
    if (!context.mounted) return;
    if (outcome case UiActionFailure<void>(:final error)) {
      _showError(context, error.message);
    }
  }

  Future<void> _deleteAttachment(
    BuildContext context,
    CommercialInsuranceDetailViewModel notifier,
    String attachmentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除附件'),
        content: const Text('删除后无法恢复，确定继续吗？'),
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
    final outcome = await notifier.deleteAttachment(attachmentId);
    if (!context.mounted) return;
    if (outcome case UiActionFailure<void>(:final error)) {
      _showError(context, error.message);
    }
  }

  Future<void> _deleteInsurance(
    BuildContext context,
    CommercialInsuranceDetailViewModel notifier,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除商业保险'),
        content: Text('确定删除“$name”吗？相关责任项、缴费计划和附件也会一并删除。'),
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
        _showError(context, error.message);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.detail});

  final CommercialInsuranceDetail detail;

  @override
  Widget build(BuildContext context) {
    final insurance = detail.insurance;
    return AppDetailSummaryCard(
      key: const ValueKey('commercial-overview-card'),
      title: [
        insurance.name,
        if (insurance.productForm?.isNotEmpty ?? false) insurance.productForm!,
      ].join(' · '),
      headerTrailing: AppStatusBadge(
        presentation: insuranceStatusBadgePresentation(detail.status),
      ),
      mainItems: [
        AppDetailSummaryCardItem(
          label: '被保人',
          value: detail.insuredPeople.map((person) => person.name).join('、'),
          maxLines: 2,
        ),
        AppDetailSummaryCardItem(
          label: '保障期限至',
          value: insuranceCoverageEndDateLabel(insurance.coverageTerm),
        ),
        AppDetailSummaryCardItem(
          label: '保额',
          value: insuranceCoverageAmountDisplayLabel(
            insurance.coverageAmount?.amount,
          ),
        ),
      ],
      supportingItems: [
        AppDetailSummaryCardItem(
          label: '险种',
          value: insuranceCategoryDisplayLabel(insurance.category),
        ),
        AppDetailSummaryCardItem(
          label: '保险公司',
          value: insurance.insurerName,
          maxLines: 2,
        ),
        AppDetailSummaryCardItem(
          label: '投保人',
          value: insurance.policyholderName ?? '',
          maxLines: 2,
        ),
        AppDetailSummaryCardItem(
          label: '受益人',
          value: insurance.beneficiaryDescription ?? '',
          maxLines: 3,
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onConfigurePremium,
    required this.onUploadAttachment,
  });

  final VoidCallback onConfigurePremium;
  final VoidCallback onUploadAttachment;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      key: const ValueKey('commercial-action-bar'),
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
                label: '缴费配置',
                onPressed: onConfigurePremium,
              ),
            ),
            const SizedBox(width: AppSpacing.space6),
            Expanded(
              child: AppInlineActionButton(
                icon: RemixIcons.upload_2_line,
                label: '附件上传',
                onPressed: onUploadAttachment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.attachments,
    required this.onOpen,
    required this.onDelete,
  });

  final List<InsuranceAttachment> attachments;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      key: const ValueKey('commercial-attachments'),
      border: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space16,
              AppSpacing.space16,
              AppSpacing.space8,
            ),
            child: Text(
              '合同附件',
              style: context.appTextStyles.subsectionTitleStrong,
            ),
          ),
          if (attachments.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space16,
              ),
              child: Text(
                '暂无合同附件',
                style: context.appTextStyles.listSupporting,
              ),
            ),
          for (var index = 0; index < attachments.length; index++) ...[
            _AttachmentRow(
              attachment: attachments[index],
              onOpen: () => onOpen(attachments[index].id),
              onDelete: () => onDelete(attachments[index].id),
            ),
            if (index < attachments.length - 1) const AppListDivider(),
          ],
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.attachment,
    required this.onOpen,
    required this.onDelete,
  });

  final InsuranceAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('insurance-attachment-${attachment.id}'),
      onTap: onOpen,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space12,
          AppSpacing.space16,
          AppSpacing.space12,
        ),
        child: Row(
          children: [
            Icon(
              RemixIcons.file_text_line,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.formValue,
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    insuranceDateLabel(attachment.createdAt),
                    style: context.appTextStyles.listSupporting,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
