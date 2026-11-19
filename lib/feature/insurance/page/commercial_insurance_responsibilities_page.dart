import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/insurance/insurance_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_list_divider.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_coverage_field.dart';
import '../view_model/commercial_insurance_responsibilities_view_model.dart';
import '../widget/insurance/insurance_category_icon.dart';
import '../widget/insurance/insurance_coverage_overview_card.dart';
import '../widget/insurance_coverage_overview_editor.dart';
import '../widget/insurance_responsibility_editor.dart';
import '../../../design_system/widget/app_scaffold.dart';

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
    return AppScaffold(
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
            final visible = state.visibleResponsibilities;
            return Column(
              children: [
                AppPageHeader(
                  title: '保障责任',
                  actions: [
                    AppHeaderIconButton(
                      icon: RemixIcons.add_line,
                      tooltip: '新增卡片',
                      onPressed: state.submitting
                          ? null
                          : () => _editResponsibility(context, notifier, null),
                    ),
                  ],
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.space16,
                      AppSpacing.space8,
                      AppSpacing.space16,
                      AppSpacing.space32,
                    ),
                    buildDefaultDragHandles: false,
                    onReorderItem: (oldIndex, newIndex) async {
                      final outcome = await notifier.reorderResponsibilities(
                        oldIndex,
                        newIndex,
                      );
                      if (context.mounted) _showOutcome(context, outcome);
                    },
                    header: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InsuranceCoverageOverviewCard(
                          summary: state.insurance.coverageSummary,
                          highlights: state.insurance.coverageHighlights,
                          waitingPeriodDescription:
                              state.insurance.waitingPeriodDescription,
                          exclusionsDescription:
                              state.insurance.exclusionsDescription,
                          enabled: !state.submitting,
                          onEditField: (field) => _editCoverageField(
                            context,
                            notifier,
                            state,
                            field,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.space16),
                        AppChoiceChipGroup<ResponsibilityKind?>(
                          key: const ValueKey('responsibility-kind-filter'),
                          selected: state.selectedKind,
                          options: [
                            const AppChoiceChipOption(value: null, label: '全部'),
                            for (final kind in state.availableKinds)
                              AppChoiceChipOption(
                                value: kind,
                                label: kind.label,
                              ),
                          ],
                          enabled: !state.submitting,
                          onChanged: notifier.setKind,
                        ),
                        const SizedBox(height: AppSpacing.space12),
                        if (visible.isEmpty)
                          AppSurface(
                            border: true,
                            child: AppEmptyState(
                              title: '还没有保障责任',
                              message: '新增卡片后填写责任类型和名称，要点可在卡片中补充。',
                              layout: AppEmptyStateLayout.inline,
                              action: FilledButton.icon(
                                onPressed: state.submitting
                                    ? null
                                    : () => _editResponsibility(
                                        context,
                                        notifier,
                                        null,
                                      ),
                                icon: const Icon(RemixIcons.add_line),
                                label: const Text('新增卡片'),
                              ),
                            ),
                          ),
                      ],
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final responsibility = visible[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(responsibility.id),
                        index: index,
                        enabled: !state.submitting,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.space12,
                          ),
                          child: _ResponsibilityCard(
                            responsibility: responsibility,
                            enabled: !state.submitting,
                            onAddPoint: () =>
                                _addPoint(context, notifier, responsibility),
                            onEditPoint: (point) => _editPoint(
                              context,
                              notifier,
                              responsibility,
                              point,
                            ),
                            onEdit: () => _editResponsibility(
                              context,
                              notifier,
                              responsibility,
                            ),
                            onDelete: () => _deleteResponsibility(
                              context,
                              notifier,
                              responsibility,
                            ),
                            onReorderPoints: (oldIndex, newIndex) async {
                              final outcome = await notifier.reorderPoints(
                                responsibility.id,
                                oldIndex,
                                newIndex,
                              );
                              if (context.mounted) {
                                _showOutcome(context, outcome);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editCoverageField(
    BuildContext context,
    CommercialInsuranceResponsibilitiesViewModel notifier,
    CommercialInsuranceResponsibilitiesState state,
    InsuranceCoverageField field,
  ) async {
    final value = await showInsuranceCoverageFieldEditor(
      context: context,
      field: field,
      value: switch (field) {
        InsuranceCoverageField.summary => state.insurance.coverageSummary,
        InsuranceCoverageField.highlights => state.insurance.coverageHighlights,
        InsuranceCoverageField.waitingPeriod =>
          state.insurance.waitingPeriodDescription,
        InsuranceCoverageField.exclusions =>
          state.insurance.exclusionsDescription,
      },
    );
    if (value == null || !context.mounted) return;
    final outcome = await notifier.saveCoverageField(field, value);
    if (context.mounted) _showOutcome(context, outcome);
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
      responsibilityKind: responsibility.kind,
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
      responsibilityKind: responsibility.kind,
      existing: point,
      existingLabels: {
        for (final item in responsibility.points)
          if (item.id != point.id) item.label,
      },
      newPointId: notifier.newPointDraftId,
      onDelete: () => _deletePoint(context, notifier, responsibility, point),
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
    required this.enabled,
    required this.onAddPoint,
    required this.onEditPoint,
    required this.onEdit,
    required this.onDelete,
    required this.onReorderPoints,
  });

  final InsuranceResponsibilityDraft responsibility;
  final bool enabled;
  final VoidCallback onAddPoint;
  final ValueChanged<InsurancePointDraft> onEditPoint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ReorderCallback onReorderPoints;

  @override
  Widget build(BuildContext context) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(responsibility.name, style: styles.listTitle),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        [
                          responsibility.kind.label,
                          ?responsibility.description,
                        ].join(' · '),
                        style: styles.listSupporting,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: enabled ? onAddPoint : null,
                  tooltip: '新增要点',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(RemixIcons.add_line),
                ),
                IconButton(
                  onPressed: enabled ? onEdit : null,
                  tooltip: '编辑卡片',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(RemixIcons.edit_line),
                ),
                IconButton(
                  onPressed: enabled ? onDelete : null,
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
            ReorderableListView.builder(
              shrinkWrap: true,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space4,
                AppSpacing.space8,
                AppSpacing.space12,
              ),
              buildDefaultDragHandles: false,
              onReorderItem: onReorderPoints,
              itemCount: responsibility.points.length,
              itemBuilder: (context, index) {
                final point = responsibility.points[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(point.id),
                  index: index,
                  enabled: enabled,
                  child: Column(
                    children: [
                      _ResponsibilityPointRow(
                        point: point,
                        onTap: enabled ? () => onEditPoint(point) : null,
                      ),
                      if (index < responsibility.points.length - 1)
                        const AppListDivider(),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ResponsibilityPointRow extends StatelessWidget {
  const _ResponsibilityPointRow({required this.point, required this.onTap});

  final InsurancePointDraft point;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return InkWell(
      key: ValueKey('responsibility-point-${point.id}'),
      onTap: onTap,
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
