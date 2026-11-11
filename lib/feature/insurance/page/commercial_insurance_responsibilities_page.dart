import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/commercial_insurance_responsibilities_view_model.dart';
import '../widget/insurance/insurance_category_icon.dart';
import '../widget/insurance_responsibility_editor.dart';

class CommercialInsuranceResponsibilitiesPage extends ConsumerWidget {
  const CommercialInsuranceResponsibilitiesPage({
    required this.insuranceId,
    super.key,
  });

  final String insuranceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = commercialInsuranceResponsibilitiesViewModelProvider(
      insuranceId,
    );
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(provider),
              child: const Text('加载失败，点击重试'),
            ),
          ),
          data: (state) {
            if (state == null) {
              return const Column(
                children: [
                  AppPageHeader(title: '保障责任'),
                  Expanded(child: Center(child: Text('商业保险不存在'))),
                ],
              );
            }
            final notifier = ref.read(provider.notifier);
            return Column(
              children: [
                AppPageHeader(
                  title: '保障责任',
                  actions: [
                    AppHeaderIconButton(
                      icon: RemixIcons.add_line,
                      tooltip: '新增卡片',
                      onPressed: () =>
                          _editResponsibility(context, notifier, null),
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
                      if (state.responsibilities.isEmpty)
                        AppSurface(
                          border: true,
                          child: AppEmptyState(
                            title: '还没有保障责任',
                            message: '新增卡片后填写责任类型和名称，要点可在卡片中补充。',
                            layout: AppEmptyStateLayout.inline,
                            action: FilledButton.icon(
                              onPressed: () =>
                                  _editResponsibility(context, notifier, null),
                              icon: const Icon(RemixIcons.add_line),
                              label: const Text('新增卡片'),
                            ),
                          ),
                        )
                      else
                        for (
                          var index = 0;
                          index < state.responsibilities.length;
                          index++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index < state.responsibilities.length - 1
                                  ? AppSpacing.space12
                                  : 0,
                            ),
                            child: _ResponsibilityCard(
                              responsibility: state.responsibilities[index],
                              onAddPoint: () => _addPoint(
                                context,
                                notifier,
                                state.responsibilities[index],
                              ),
                              onEditPoint: (point) => _editPoint(
                                context,
                                notifier,
                                state.responsibilities[index],
                                point,
                              ),
                              onEdit: () => _editResponsibility(
                                context,
                                notifier,
                                state.responsibilities[index],
                              ),
                              onDelete: () => _deleteResponsibility(
                                context,
                                notifier,
                                state.responsibilities[index],
                              ),
                              onDeletePoint: (point) => _deletePoint(
                                context,
                                notifier,
                                state.responsibilities[index],
                                point,
                              ),
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

  Future<void> _editResponsibility(
    BuildContext context,
    CommercialInsuranceResponsibilitiesViewModel notifier,
    InsuranceResponsibilityDraft? existing,
  ) async {
    final result = await showInsuranceResponsibilityEditor(
      context: context,
      existing: existing,
      newResponsibilityId: notifier.newResponsibilityDraftId,
    );
    if (result == null || !context.mounted) return;
    final outcome = await notifier.upsertResponsibility(result);
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _addPoint(
    BuildContext context,
    CommercialInsuranceResponsibilitiesViewModel notifier,
    InsuranceResponsibilityDraft responsibility,
  ) async {
    final result = await showInsurancePointEditor(
      context: context,
      existing: null,
      existingLabels: {for (final point in responsibility.points) point.label},
      newPointId: notifier.newPointDraftId,
    );
    if (result == null || !context.mounted) return;
    final outcome = await notifier.upsertPoint(responsibility.id, result);
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _editPoint(
    BuildContext context,
    CommercialInsuranceResponsibilitiesViewModel notifier,
    InsuranceResponsibilityDraft responsibility,
    InsurancePointDraft point,
  ) async {
    final result = await showInsurancePointEditor(
      context: context,
      existing: point,
      existingLabels: {
        for (final item in responsibility.points)
          if (item.id != point.id) item.label,
      },
      newPointId: notifier.newPointDraftId,
    );
    if (result == null || !context.mounted) return;
    final outcome = await notifier.upsertPoint(responsibility.id, result);
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _deleteResponsibility(
    BuildContext context,
    CommercialInsuranceResponsibilitiesViewModel notifier,
    InsuranceResponsibilityDraft responsibility,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除保障责任'),
        content: Text('确定删除“${responsibility.name}”及其全部责任要点吗？'),
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
    final outcome = await notifier.removeResponsibility(responsibility.id);
    if (context.mounted) _showOutcome(context, outcome);
  }

  Future<void> _deletePoint(
    BuildContext context,
    CommercialInsuranceResponsibilitiesViewModel notifier,
    InsuranceResponsibilityDraft responsibility,
    InsurancePointDraft point,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除要点'),
        content: Text('确定删除“${point.label}”吗？'),
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
    final outcome = await notifier.removePoint(responsibility.id, point.id);
    if (context.mounted) _showOutcome(context, outcome);
  }

  void _showOutcome(BuildContext context, UiActionOutcome<String> outcome) {
    if (outcome case UiActionFailure<String>(:final error)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ResponsibilityCard extends StatelessWidget {
  const _ResponsibilityCard({
    required this.responsibility,
    required this.onAddPoint,
    required this.onEditPoint,
    required this.onEdit,
    required this.onDelete,
    required this.onDeletePoint,
  });

  final InsuranceResponsibilityDraft responsibility;
  final VoidCallback onAddPoint;
  final ValueChanged<InsurancePointDraft> onEditPoint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<InsurancePointDraft> onDeletePoint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return AppSurface(
      key: ValueKey('manage-responsibility-${responsibility.id}'),
      border: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space12,
              AppSpacing.space8,
              AppSpacing.space12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InsuranceCategoryIcon.responsibility(
                  kind: responsibility.kind,
                  size: AppSpacing.space40,
                ),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(responsibility.name, style: styles.listTitle),
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          responsibility.kind.label,
                          style: styles.listSupporting,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onAddPoint,
                  tooltip: '新增要点',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(RemixIcons.add_line),
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: '编辑卡片',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(RemixIcons.edit_line),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: '删除卡片',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(RemixIcons.delete_bin_line),
                ),
              ],
            ),
          ),
          const AppListDivider(),
          if (responsibility.points.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space16),
              child: Text('暂无责任要点，可通过右上角按钮新增。', style: styles.listSupporting),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space4,
                AppSpacing.space16,
                AppSpacing.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var index = 0;
                    index < responsibility.points.length;
                    index++
                  ) ...[
                    _ResponsibilityPointRow(
                      point: responsibility.points[index],
                      onTap: () => onEditPoint(responsibility.points[index]),
                      onLongPress: () =>
                          onDeletePoint(responsibility.points[index]),
                    ),
                    if (index < responsibility.points.length - 1)
                      const AppListDivider(),
                  ],
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    '点击要点可编辑，长按可删除',
                    style: styles.metricSupporting.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResponsibilityPointRow extends StatelessWidget {
  const _ResponsibilityPointRow({
    required this.point,
    required this.onTap,
    required this.onLongPress,
  });

  final InsurancePointDraft point;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return InkWell(
      key: ValueKey('responsibility-point-${point.id}'),
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppSpacing.space8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppComponentTokens.keyValueLabelWidth,
              child: Text(point.label, style: styles.detailLabel),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Text(
                point.value,
                textAlign: TextAlign.end,
                style: styles.detailValue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
