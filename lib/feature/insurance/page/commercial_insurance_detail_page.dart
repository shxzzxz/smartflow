import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_list_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import '../../../design_system/widget/app_section_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_presentation.dart';
import '../view_model/commercial_insurance_detail_view_model.dart';
import '../widget/insurance/insurance_key_value_row.dart';
import '../widget/insurance/insurance_policy_facts_panel.dart';
import '../widget/insurance/insurance_policy_identity_header.dart';
import '../widget/insurance/insurance_responsibility_tile.dart';

class CommercialInsuranceDetailPage extends ConsumerWidget {
  const CommercialInsuranceDetailPage({required this.insuranceId, super.key});

  final String insuranceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = commercialInsuranceDetailViewModelProvider(insuranceId);
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
                      InsurancePolicyIdentityHeader(
                        insurance: insurance,
                        status: detail.status,
                      ),
                      const SizedBox(height: AppSpacing.space12),
                      InsurancePolicyFactsPanel(
                        coverageAmountLabel:
                            insuranceCoverageAmountDisplayLabel(
                              insurance.coverageAmount?.amount,
                            ),
                        coverageTermLabel: insuranceCoverageTermCompactLabel(
                          insurance.coverageTerm,
                        ),
                        coverageTermEnded:
                            !insurance.coverageTerm.lifetime &&
                            insurance.coverageTerm.endDate != null,
                        premiumLabel:
                            insurance.premiumPlan?.frequency.label ??
                            PremiumFrequency.other.label,
                      ),
                      const SizedBox(height: AppSpacing.space20),
                      const AppSectionHeader(title: '基本信息'),
                      const SizedBox(height: AppSpacing.space8),
                      AppListSection(
                        border: true,
                        children: [
                          InsuranceKeyValueRow(
                            label: '被保险人',
                            value: detail.insuredPeople
                                .map(
                                  (person) =>
                                      '${person.name} · '
                                      '${person.relationship.label} · '
                                      '${person.ageAt(detail.asOf)} 岁',
                                )
                                .join('、'),
                          ),
                          InsuranceKeyValueRow(
                            label: '险种',
                            value: insuranceCategoryDisplayLabel(
                              insurance.category,
                            ),
                          ),
                          if (insurance.productForm case final form?)
                            InsuranceKeyValueRow(label: '产品形态', value: form),
                          InsuranceKeyValueRow(
                            label: '缴费计划',
                            value: insurancePremiumPlanLabel(
                              insurance.premiumPlan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.space20),
                      _ResponsibilitySection(
                        responsibilities: insurance.responsibilities,
                        onManage: () => context.push(
                          '/insurance/commercial/$insuranceId/'
                          'responsibilities',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space20),
                      _AttachmentSection(
                        attachments: insurance.attachments,
                        onAdd: () => _addAttachments(
                          context,
                          ref.read(provider.notifier),
                        ),
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

class _ResponsibilitySection extends StatelessWidget {
  const _ResponsibilitySection({
    required this.responsibilities,
    required this.onManage,
  });

  final List<CoverageResponsibility> responsibilities;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: '保障责任',
          trailing: TextButton(onPressed: onManage, child: const Text('详情')),
        ),
        const SizedBox(height: AppSpacing.space8),
        if (responsibilities.isEmpty)
          AppSurface(
            border: true,
            child: const AppEmptyState(
              title: '还没有保障责任项',
              message: '点击详情添加责任项和责任要点。',
              layout: AppEmptyStateLayout.inline,
            ),
          )
        else
          AppListSection(
            border: true,
            children: [
              for (final responsibility in responsibilities)
                InsuranceResponsibilityTile(responsibility: responsibility),
            ],
          ),
      ],
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.attachments,
    required this.onAdd,
    required this.onOpen,
    required this.onDelete,
  });

  final List<InsuranceAttachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: '合同附件',
          trailing: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(
              RemixIcons.attachment_line,
              size: AppSpacing.space16,
            ),
            label: const Text('添加'),
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          border: true,
          child: attachments.isEmpty
              ? const AppEmptyState(
                  title: '还没有合同附件',
                  message: '可添加多份合同、批单或缴费凭证文件。',
                  layout: AppEmptyStateLayout.inline,
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < attachments.length;
                      index++
                    ) ...[
                      _AttachmentRow(
                        attachment: attachments[index],
                        onOpen: () => onOpen(attachments[index].id),
                        onDelete: () => onDelete(attachments[index].id),
                      ),
                      if (index < attachments.length - 1)
                        const AppListDivider(),
                    ],
                  ],
                ),
        ),
      ],
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space12,
          AppSpacing.space8,
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
            IconButton(
              onPressed: onDelete,
              tooltip: '删除附件',
              icon: const Icon(RemixIcons.delete_bin_line),
            ),
          ],
        ),
      ),
    );
  }
}
