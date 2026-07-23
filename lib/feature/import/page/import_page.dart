import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/import/import_api.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/progress_indicator.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/import_presentation.dart';
import '../view_model/import_view_model.dart';

enum ImportPageInitialTab { import, history }

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key, this.initialTab = ImportPageInitialTab.import});

  final ImportPageInitialTab initialTab;

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(importViewModelProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importViewModelProvider);
    final notifier = ref.read(importViewModelProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab == ImportPageInitialTab.import ? 0 : 1,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              const _ImportHeader(),
              TabBar(
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: colors.outlineVariant,
                labelStyle: context.appTextStyles.listTitle,
                tabs: const [Tab(text: '导入'), Tab(text: '批次历史')],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ImportReviewTab(
                      state: state,
                      onPickFiles: _pickFiles,
                      onReset: notifier.reset,
                      onClearError: notifier.clearError,
                      onApplySuggestions: _applySuggestions,
                      onSelectAll: notifier.selectAllImportable,
                      onGroupSelected: notifier.setGroupSelection,
                      onSuspectedConfirmed:
                          notifier.setSuspectedDuplicateConfirmed,
                      onWarningConfirmed: notifier.setWarningConfirmed,
                      onSelectMapping: _selectMapping,
                      onSelectGroupMapping: _selectGroupMapping,
                      onEditDraft: _editDraft,
                      onCreateAccount: () => _createTarget('/account/new'),
                      onCreateCategory:
                          (kind) => _createTarget(
                            '/category/new?type=${kind == ImportCategoryKind.income ? 'income' : 'expense'}',
                          ),
                      onCommit: _commit,
                    ),
                    _ImportHistoryTab(
                      state: state,
                      onRefresh: _loadHistory,
                      onRevert: _confirmRevert,
                      onClearError: notifier.clearError,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final outcome =
        await ref.read(importViewModelProvider.notifier).pickFiles();
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _applySuggestions() async {
    final outcome =
        await ref
            .read(importViewModelProvider.notifier)
            .applySuggestedMappings();
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _selectMapping(ImportSourceEntity entity) async {
    final state = ref.read(importViewModelProvider);
    final review = state.review;
    if (review == null) return;
    final key = ImportMappingKey.fromEntity(entity);
    final allowedKinds = review.compatibleTargetKinds[key];
    final targets = review.targets
        .where(
          (target) =>
              allowedKinds == null || allowedKinds.contains(target.kind),
        )
        .where((target) => !target.isArchived)
        .toList(growable: false);
    final selection = await showModalBottomSheet<_MappingSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => _MappingTargetSheet(
            entity: entity,
            targets: targets,
            selectedTargetId: review.effectiveMappings[key],
            hasTemporaryOverride: state.temporaryMappings.containsKey(key),
            allowSaveAsDefault: !entity.isReviewPlaceholder,
            restoreLabel: '恢复默认映射',
          ),
    );
    if (!mounted || selection == null) return;
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .setMapping(
          key,
          selection.targetAccountId,
          saveAsDefault: selection.saveAsDefault,
        );
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _selectGroupMapping(
    int groupIndex,
    ImportSourceEntity entity,
  ) async {
    final state = ref.read(importViewModelProvider);
    final review = state.review;
    if (review == null) return;
    final key = ImportMappingKey.fromEntity(entity);
    final group = review.groups[groupIndex];
    final allowedKinds = group.compatibleTargetKinds[key];
    final targets = review.targets
        .where(
          (target) =>
              allowedKinds == null || allowedKinds.contains(target.kind),
        )
        .where((target) => !target.isArchived)
        .toList(growable: false);
    final selection = await showModalBottomSheet<_MappingSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => _MappingTargetSheet(
            entity: entity,
            targets: targets,
            selectedTargetId: group.effectiveMappings[key],
            hasTemporaryOverride:
                state.groupMappingOverrides[groupIndex]?.containsKey(key) ??
                false,
            allowSaveAsDefault: false,
            restoreLabel: '恢复本次导入映射',
          ),
    );
    if (!mounted || selection == null) return;
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .setGroupMappingOverride(
          groupIndex: groupIndex,
          key: key,
          targetAccountId: selection.targetAccountId,
        );
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _editDraft(int groupIndex, int? childIndex) async {
    final state = ref.read(importViewModelProvider);
    final review = state.review;
    if (review == null) return;
    final group = review.groups[groupIndex].group;
    final draft =
        childIndex == null ? group.topLevel : group.children[childIndex];
    final edit = await showModalBottomSheet<ImportDraftEdit>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ImportDraftEditSheet(draft: draft),
    );
    if (!mounted || edit == null) return;
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .editGroupDraft(
          groupIndex: groupIndex,
          childIndex: childIndex,
          edit: edit,
        );
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _createTarget(String route) async {
    await context.push(route);
    if (!mounted) return;
    final outcome =
        await ref.read(importViewModelProvider.notifier).refreshReview();
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _commit() async {
    final state = ref.read(importViewModelProvider);
    final selectedCount = state.selectedGroupIndexes.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认导入'),
            content: Text('将原子提交 $selectedCount 个交易组。任一交易失败时，本次提交会全部回滚。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('开始导入'),
              ),
            ],
          ),
    );
    if (!mounted || confirmed != true) return;

    final outcome =
        await ref.read(importViewModelProvider.notifier).commitSelectedGroups();
    if (!mounted) return;
    switch (outcome) {
      case ImportActionSuccess(:final value):
        final batch = value.batch;
        final message =
            batch == null
                ? '没有创建新批次，所选交易组均被跳过。'
                : '导入完成：${batch.importedGroupCount} 个交易组，'
                    '${batch.createdTransactionCount} 条交易。';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      case ImportActionFailure(:final error):
        _showError(error);
    }
  }

  Future<void> _loadHistory() async {
    final outcome =
        await ref.read(importViewModelProvider.notifier).loadHistory();
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _confirmRevert(ImportBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('撤销导入批次'),
            content: const Text('将删除该批次当前仍存在的全部顶层交易及其子交易。来源映射、账户和分类会保留。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('确认撤销'),
              ),
            ],
          ),
    );
    if (!mounted || confirmed != true) return;

    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .revertBatch(batch.id);
    if (!mounted) return;
    switch (outcome) {
      case ImportActionSuccess():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导入批次已撤销。')));
      case ImportActionFailure(:final error):
        _showError(error);
    }
  }

  void _showFailure<T>(ImportActionOutcome<T> outcome) {
    if (outcome case ImportActionFailure<T>(:final error)) {
      _showError(error);
    }
  }

  void _showError(UiError error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class _ImportHeader extends StatelessWidget {
  const _ImportHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space12,
        AppSpacing.space12,
        AppSpacing.space4,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/profile');
                }
              },
              icon: const Icon(RemixIcons.arrow_left_s_line),
              iconSize: AppSpacing.space32,
              tooltip: '返回',
            ),
          ),
          Text('一木记账导入', style: context.appTextStyles.dateNavigationTitle),
        ],
      ),
    );
  }
}

class _ImportReviewTab extends StatelessWidget {
  const _ImportReviewTab({
    required this.state,
    required this.onPickFiles,
    required this.onReset,
    required this.onClearError,
    required this.onApplySuggestions,
    required this.onSelectAll,
    required this.onGroupSelected,
    required this.onSuspectedConfirmed,
    required this.onWarningConfirmed,
    required this.onSelectMapping,
    required this.onSelectGroupMapping,
    required this.onEditDraft,
    required this.onCreateAccount,
    required this.onCreateCategory,
    required this.onCommit,
  });

  final ImportPageState state;
  final VoidCallback onPickFiles;
  final VoidCallback onReset;
  final VoidCallback onClearError;
  final VoidCallback onApplySuggestions;
  final ValueChanged<bool> onSelectAll;
  final void Function(int index, bool selected) onGroupSelected;
  final void Function(int index, bool confirmed) onSuspectedConfirmed;
  final void Function(int index, bool confirmed) onWarningConfirmed;
  final ValueChanged<ImportSourceEntity> onSelectMapping;
  final void Function(int groupIndex, ImportSourceEntity entity)
  onSelectGroupMapping;
  final void Function(int groupIndex, int? childIndex) onEditDraft;
  final VoidCallback onCreateAccount;
  final ValueChanged<ImportCategoryKind> onCreateCategory;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final review = state.review;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space20,
            AppSpacing.space20,
            AppSpacing.space20,
            AppSpacing.space48 + AppSpacing.space40,
          ),
          children: [
            if (state.error case final error?) ...[
              _FeedbackBanner(
                icon: RemixIcons.error_warning_line,
                message: error.message,
                tone: _FeedbackTone.error,
                onClose: onClearError,
              ),
              const SizedBox(height: AppSpacing.space16),
            ],
            const _SourceIntroductionCard(),
            if (plan == null) ...[
              const SizedBox(height: AppSpacing.space24),
              _EmptyImportState(busy: state.isBusy, onPickFiles: onPickFiles),
            ] else if (plan.hasFatalIssues) ...[
              const SizedBox(height: AppSpacing.space24),
              _FatalIssuesCard(plan: plan),
              const SizedBox(height: AppSpacing.space16),
              FilledButton.icon(
                onPressed: state.isBusy ? null : onPickFiles,
                icon: const Icon(RemixIcons.folder_open_line),
                label: const Text('重新选择一木资料包'),
              ),
            ] else if (review != null) ...[
              const SizedBox(height: AppSpacing.space24),
              if (state.lastCommit case final result?) ...[
                _CommitResultBanner(result: result),
                const SizedBox(height: AppSpacing.space16),
              ],
              _ImportSummaryCard(state: state),
              const SizedBox(height: AppSpacing.space24),
              _MappingSection(
                state: state,
                onSelectMapping: onSelectMapping,
                onApplySuggestions: onApplySuggestions,
                onCreateAccount: onCreateAccount,
                onCreateCategory: onCreateCategory,
              ),
              const SizedBox(height: AppSpacing.space24),
              _GroupReviewSection(
                state: state,
                onSelectAll: onSelectAll,
                onGroupSelected: onGroupSelected,
                onSuspectedConfirmed: onSuspectedConfirmed,
                onWarningConfirmed: onWarningConfirmed,
                onSelectGroupMapping: onSelectGroupMapping,
                onEditDraft: onEditDraft,
              ),
              if (plan.filteredRecords.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space24),
                _FilteredRecordsSection(records: plan.filteredRecords),
              ],
              const SizedBox(height: AppSpacing.space16),
              OutlinedButton.icon(
                onPressed: state.isBusy ? null : onPickFiles,
                icon: const Icon(RemixIcons.folder_open_line),
                label: const Text('更换资料包'),
              ),
              TextButton(
                onPressed: state.isBusy ? null : onReset,
                child: const Text('清空审阅'),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.space24),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
        if (review != null && !plan!.hasFatalIssues)
          Positioned(
            left: AppSpacing.space20,
            right: AppSpacing.space20,
            bottom: AppSpacing.space16,
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed:
                    state.phase == ImportPagePhase.committing ||
                            state.selectedGroupIndexes.isEmpty
                        ? null
                        : onCommit,
                icon:
                    state.phase == ImportPagePhase.committing
                        ? const SizedBox.square(
                          dimension: AppSpacing.space18,
                          child: CircularProgressIndicator(
                            strokeWidth:
                                AppProgressIndicatorTokens.compactStrokeWidth,
                          ),
                        )
                        : const Icon(RemixIcons.import_line),
                label: Text(
                  state.phase == ImportPagePhase.committing
                      ? '正在导入'
                      : '导入所选 ${state.selectedGroupIndexes.length} 组',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SourceIntroductionCard extends StatelessWidget {
  const _SourceIntroductionCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(RemixIcons.file_excel_2_line, color: colors.primary),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('当前仅支持一木记账', style: context.appTextStyles.listTitle),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    '请选择一木导出的账单、转账、债务三个传统 .xls 文件。文件角色会自动识别，原文件不会保存。',
                    style: context.appTextStyles.pageSubtitle,
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

class _EmptyImportState extends StatelessWidget {
  const _EmptyImportState({required this.busy, required this.onPickFiles});

  final bool busy;
  final VoidCallback onPickFiles;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          children: [
            Icon(
              RemixIcons.folder_upload_line,
              size: AppSpacing.space40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.space12),
            Text('选择导出文件开始审阅', style: context.appTextStyles.groupTitle),
            const SizedBox(height: AppSpacing.space6),
            Text(
              '导入前可以检查映射、阻塞问题、重复提示，并按交易组整体选择。',
              textAlign: TextAlign.center,
              style: context.appTextStyles.pageSubtitle,
            ),
            const SizedBox(height: AppSpacing.space20),
            FilledButton.icon(
              onPressed: busy ? null : onPickFiles,
              icon:
                  busy
                      ? const SizedBox.square(
                        dimension: AppSpacing.space18,
                        child: CircularProgressIndicator(
                          strokeWidth:
                              AppProgressIndicatorTokens.compactStrokeWidth,
                        ),
                      )
                      : const Icon(RemixIcons.folder_open_line),
              label: Text(busy ? '正在解析' : '选择一木 .xls 文件'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FatalIssuesCard extends StatelessWidget {
  const _FatalIssuesCard({required this.plan});

  final ImportParseResult plan;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('资料包无法继续解析', style: context.appTextStyles.groupTitle),
            const SizedBox(height: AppSpacing.space8),
            for (final issue in plan.fatalIssues)
              _IssueLine(
                issue: issue,
                color: Theme.of(context).colorScheme.error,
              ),
          ],
        ),
      ),
    );
  }
}

class _CommitResultBanner extends StatelessWidget {
  const _CommitResultBanner({required this.result});

  final ImportCommitResult result;

  @override
  Widget build(BuildContext context) {
    final batch = result.batch;
    return _FeedbackBanner(
      icon:
          batch == null
              ? RemixIcons.information_line
              : RemixIcons.checkbox_circle_line,
      message:
          batch == null
              ? '没有创建新批次；${result.skippedGroupCount} 个交易组被跳过。'
              : '已导入 ${batch.importedGroupCount} 个交易组，创建 '
                  '${batch.createdTransactionCount} 条交易，跳过 '
                  '${batch.skippedGroupCount} 个交易组。',
      tone: batch == null ? _FeedbackTone.info : _FeedbackTone.success,
    );
  }
}

class _ImportSummaryCard extends StatelessWidget {
  const _ImportSummaryCard({required this.state});

  final ImportPageState state;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('审阅摘要', style: context.appTextStyles.groupTitle),
            const SizedBox(height: AppSpacing.space12),
            Wrap(
              spacing: AppSpacing.space8,
              runSpacing: AppSpacing.space8,
              children: [
                _SummaryChip(label: '交易组', value: '${state.groupCount}'),
                _SummaryChip(
                  label: '已选择',
                  value: '${state.selectedGroupCount}',
                ),
                _SummaryChip(
                  label: '未映射',
                  value: '${state.missingMappingCount}',
                ),
                _SummaryChip(label: '阻塞', value: '${state.blockedGroupCount}'),
                _SummaryChip(
                  label: '精确重复',
                  value: '${state.exactDuplicateGroupCount}',
                ),
                _SummaryChip(
                  label: '疑似重复',
                  value: '${state.suspectedDuplicateGroupCount}',
                ),
                _SummaryChip(
                  label: '已过滤来源行',
                  value: '${state.filteredRecordCount}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space10,
        vertical: AppSpacing.space6,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
      ),
      child: Text('$label $value', style: context.appTextStyles.listSupporting),
    );
  }
}

class _MappingSection extends StatelessWidget {
  const _MappingSection({
    required this.state,
    required this.onSelectMapping,
    required this.onApplySuggestions,
    required this.onCreateAccount,
    required this.onCreateCategory,
  });

  final ImportPageState state;
  final ValueChanged<ImportSourceEntity> onSelectMapping;
  final VoidCallback onApplySuggestions;
  final VoidCallback onCreateAccount;
  final ValueChanged<ImportCategoryKind> onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final review = state.review!;
    final entities = review.plan.sourceEntities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('来源映射', style: context.appTextStyles.groupTitle),
            ),
            if (review.suggestions.isNotEmpty)
              TextButton.icon(
                onPressed: state.isBusy ? null : onApplySuggestions,
                icon: const Icon(RemixIcons.magic_line),
                label: Text('应用建议 ${review.suggestions.length}'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space8),
        AppSurface(
          child:
              entities.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.space16),
                    child: Text('资料包未提取到需要映射的账户或类别。'),
                  )
                  : Column(
                    children: [
                      for (var index = 0; index < entities.length; index++) ...[
                        _MappingRow(
                          entity: entities[index],
                          review: review,
                          isTemporary: state.temporaryMappings.containsKey(
                            ImportMappingKey.fromEntity(entities[index]),
                          ),
                          onTap: () => onSelectMapping(entities[index]),
                        ),
                        if (index < entities.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.space16,
                            ),
                            child: Divider(
                              height: AppListTokens.dividerThickness,
                            ),
                          ),
                      ],
                    ],
                  ),
        ),
        const SizedBox(height: AppSpacing.space10),
        Wrap(
          spacing: AppSpacing.space8,
          runSpacing: AppSpacing.space8,
          children: [
            OutlinedButton.icon(
              onPressed: state.isBusy ? null : onCreateAccount,
              icon: const Icon(RemixIcons.wallet_3_line),
              label: const Text('新建账户'),
            ),
            OutlinedButton.icon(
              onPressed:
                  state.isBusy
                      ? null
                      : () => onCreateCategory(ImportCategoryKind.income),
              icon: const Icon(RemixIcons.apps_2_line),
              label: const Text('新建收入分类'),
            ),
            OutlinedButton.icon(
              onPressed:
                  state.isBusy
                      ? null
                      : () => onCreateCategory(ImportCategoryKind.expense),
              icon: const Icon(RemixIcons.apps_2_line),
              label: const Text('新建支出分类'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MappingRow extends StatelessWidget {
  const _MappingRow({
    required this.entity,
    required this.review,
    required this.isTemporary,
    required this.onTap,
  });

  final ImportSourceEntity entity;
  final ImportPlanReview review;
  final bool isTemporary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final key = ImportMappingKey.fromEntity(entity);
    final targetId = review.effectiveMappings[key];
    final target =
        review.targets.where((item) => item.id == targetId).firstOrNull;
    final targetAvailable = target != null && !target.isArchived;
    final suggestion = review.suggestions.any((item) => item.key == key);
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entity.displayName,
                    style: context.appTextStyles.listTitle,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    importEntityKindLabel(entity),
                    style: context.appTextStyles.listSupporting,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    target == null
                        ? '未映射'
                        : target.isArchived
                        ? '${target.displayPath}（已归档）'
                        : target.displayPath,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: context.appTextStyles.detailValue.copyWith(
                      color: targetAvailable ? colors.onSurface : colors.error,
                    ),
                  ),
                  if (isTemporary || suggestion) ...[
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      isTemporary ? '仅本次覆盖' : '有唯一匹配建议',
                      style: context.appTextStyles.listSupporting.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.space6),
            Icon(RemixIcons.arrow_right_s_line, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _MappingTargetSheet extends StatefulWidget {
  const _MappingTargetSheet({
    required this.entity,
    required this.targets,
    required this.selectedTargetId,
    required this.hasTemporaryOverride,
    this.allowSaveAsDefault = true,
    this.restoreLabel = '恢复默认映射',
  });

  final ImportSourceEntity entity;
  final List<ImportMappingTarget> targets;
  final String? selectedTargetId;
  final bool hasTemporaryOverride;
  final bool allowSaveAsDefault;
  final String restoreLabel;

  @override
  State<_MappingTargetSheet> createState() => _MappingTargetSheetState();
}

class _MappingTargetSheetState extends State<_MappingTargetSheet> {
  bool _saveAsDefault = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '映射 ${widget.entity.displayName}',
                    style: context.appTextStyles.subsectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    importEntityKindLabel(widget.entity),
                    style: context.appTextStyles.pageSubtitle,
                  ),
                ],
              ),
            ),
            if (widget.allowSaveAsDefault)
              CheckboxListTile(
                value: _saveAsDefault,
                onChanged:
                    (value) => setState(() => _saveAsDefault = value ?? false),
                title: const Text('以后也这样映射'),
                subtitle: const Text('立即更新一木记账的默认映射；与本次导入是否提交无关。'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            const Divider(height: AppListTokens.dividerThickness),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.hasTemporaryOverride)
                    ListTile(
                      leading: const Icon(RemixIcons.restart_line),
                      title: Text(widget.restoreLabel),
                      onTap:
                          () => Navigator.of(context).pop(
                            const _MappingSelection(
                              targetAccountId: null,
                              saveAsDefault: false,
                            ),
                          ),
                    ),
                  for (final target in widget.targets)
                    ListTile(
                      leading: Icon(
                        target.id == widget.selectedTargetId
                            ? RemixIcons.checkbox_circle_fill
                            : RemixIcons.checkbox_blank_circle_line,
                      ),
                      title: Text(target.displayPath),
                      subtitle:
                          target.displayPath == target.name
                              ? null
                              : Text(target.name),
                      onTap:
                          () => Navigator.of(context).pop(
                            _MappingSelection(
                              targetAccountId: target.id,
                              saveAsDefault: _saveAsDefault,
                            ),
                          ),
                    ),
                  if (widget.targets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.space20),
                      child: Text(
                        '暂无角色兼容的可用目标，请先新建账户或分类。',
                        textAlign: TextAlign.center,
                        style: context.appTextStyles.pageSubtitle,
                      ),
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

class _MappingSelection {
  const _MappingSelection({
    required this.targetAccountId,
    required this.saveAsDefault,
  });

  final String? targetAccountId;
  final bool saveAsDefault;
}

class _GroupReviewSection extends StatelessWidget {
  const _GroupReviewSection({
    required this.state,
    required this.onSelectAll,
    required this.onGroupSelected,
    required this.onSuspectedConfirmed,
    required this.onWarningConfirmed,
    required this.onSelectGroupMapping,
    required this.onEditDraft,
  });

  final ImportPageState state;
  final ValueChanged<bool> onSelectAll;
  final void Function(int index, bool selected) onGroupSelected;
  final void Function(int index, bool confirmed) onSuspectedConfirmed;
  final void Function(int index, bool confirmed) onWarningConfirmed;
  final void Function(int groupIndex, ImportSourceEntity entity)
  onSelectGroupMapping;
  final void Function(int groupIndex, int? childIndex) onEditDraft;

  @override
  Widget build(BuildContext context) {
    final groups = state.review!.groups;
    final allSelected = state.allDirectlyImportableSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('交易组审阅', style: context.appTextStyles.groupTitle),
            ),
            TextButton(
              onPressed: state.isBusy ? null : () => onSelectAll(!allSelected),
              child: Text(allSelected ? '取消全选' : '选择全部可直接导入'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space8),
        if (groups.isEmpty)
          const AppSurface(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.space20),
              child: Text('资料包没有产生候选交易组。'),
            ),
          )
        else
          for (final group in groups) ...[
            _ImportGroupCard(
              review: group,
              sourceEntities: state.review!.plan.sourceEntities,
              selected: state.selectedGroupIndexes.contains(group.index),
              suspectedConfirmed: state.confirmedSuspectedDuplicateIndexes
                  .contains(group.index),
              warningConfirmed: state.confirmedWarningIndexes.contains(
                group.index,
              ),
              onSelected: (value) => onGroupSelected(group.index, value),
              onSuspectedConfirmed:
                  (value) => onSuspectedConfirmed(group.index, value),
              onWarningConfirmed:
                  (value) => onWarningConfirmed(group.index, value),
              onSelectGroupMapping:
                  (entity) => onSelectGroupMapping(group.index, entity),
              onEditDraft: (childIndex) => onEditDraft(group.index, childIndex),
            ),
            const SizedBox(height: AppSpacing.space10),
          ],
      ],
    );
  }
}

class _ImportGroupCard extends StatelessWidget {
  const _ImportGroupCard({
    required this.review,
    required this.sourceEntities,
    required this.selected,
    required this.suspectedConfirmed,
    required this.warningConfirmed,
    required this.onSelected,
    required this.onSuspectedConfirmed,
    required this.onWarningConfirmed,
    required this.onSelectGroupMapping,
    required this.onEditDraft,
  });

  final ImportGroupReview review;
  final List<ImportSourceEntity> sourceEntities;
  final bool selected;
  final bool suspectedConfirmed;
  final bool warningConfirmed;
  final ValueChanged<bool> onSelected;
  final ValueChanged<bool> onSuspectedConfirmed;
  final ValueChanged<bool> onWarningConfirmed;
  final ValueChanged<ImportSourceEntity> onSelectGroupMapping;
  final ValueChanged<int?> onEditDraft;

  @override
  Widget build(BuildContext context) {
    final draft = review.group.topLevel;
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      border: review.isBlocked || review.isExactDuplicate,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space16,
        ),
        leading: Checkbox(
          value: selected,
          onChanged:
              review.canSelect ? (value) => onSelected(value ?? false) : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${review.index + 1}. ${importOperationLabel(draft.operationKind)}',
                style: context.appTextStyles.listTitle,
              ),
            ),
            MoneyText(
              money: draft.amount,
              style: context.appTextStyles.amountList,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.space4),
            Text(
              formatImportDateTime(draft.occurredAt),
              style: context.appTextStyles.listSupporting,
            ),
            const SizedBox(height: AppSpacing.space6),
            Wrap(
              spacing: AppSpacing.space6,
              runSpacing: AppSpacing.space4,
              children: [
                if (review.group.children.isNotEmpty)
                  _StatusBadge(
                    label: '${review.group.children.length} 条子交易',
                    tone: _FeedbackTone.info,
                  ),
                if (review.isExactDuplicate)
                  const _StatusBadge(label: '已导入', tone: _FeedbackTone.info),
                if (review.isBlocked)
                  const _StatusBadge(label: '阻塞', tone: _FeedbackTone.error),
                if (review.isSuspectedDuplicate)
                  const _StatusBadge(
                    label: '疑似重复',
                    tone: _FeedbackTone.warning,
                  ),
                if (review.hasWarnings && !review.isSuspectedDuplicate)
                  const _StatusBadge(label: '有警告', tone: _FeedbackTone.warning),
                if (draft.isExcludedFromStats)
                  const _StatusBadge(label: '不计收支', tone: _FeedbackTone.info),
                if (draft.isExcludedFromBudget)
                  const _StatusBadge(label: '不计预算', tone: _FeedbackTone.info),
              ],
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (draft.note case final note?
                    when note.trim().isNotEmpty) ...[
                  Text('备注：$note', style: context.appTextStyles.detailValue),
                  const SizedBox(height: AppSpacing.space8),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: AppSpacing.space8,
                    runSpacing: AppSpacing.space8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            review.isExactDuplicate
                                ? null
                                : () => onEditDraft(null),
                        icon: const Icon(RemixIcons.edit_line),
                        label: const Text('编辑顶层交易'),
                      ),
                      for (final entity in importGroupEntities(
                        review.group,
                        sourceEntities,
                      ))
                        OutlinedButton(
                          onPressed: () => onSelectGroupMapping(entity),
                          child: Text('本组映射：${entity.displayName}'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.space10),
                for (final child in review.group.children) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '子交易：${importOperationLabel(child.operationKind)} · '
                          '${formatImportDateTime(child.occurredAt)}',
                          style: context.appTextStyles.detailValue,
                        ),
                      ),
                      MoneyText(
                        money: child.amount,
                        style: context.appTextStyles.detailValue,
                      ),
                      IconButton(
                        onPressed:
                            review.isExactDuplicate
                                ? null
                                : () => onEditDraft(
                                  review.group.children.indexOf(child),
                                ),
                        icon: const Icon(RemixIcons.edit_line),
                        tooltip: '编辑子交易',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space6),
                ],
                for (final issue in review.issues)
                  _IssueLine(
                    issue: issue,
                    color:
                        issue.isWarning
                            ? _themeExtension(context).warning
                            : colors.error,
                  ),
                if (review.isExactDuplicate)
                  Text(
                    '来源操作键已命中仍存在的历史导入交易组，本组不能强制重复导入。',
                    style: context.appTextStyles.pageSubtitle,
                  ),
                if (review.isSuspectedDuplicate)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: suspectedConfirmed,
                    onChanged:
                        review.canSelect
                            ? (value) => onSuspectedConfirmed(value ?? false)
                            : null,
                    title: const Text('确认仍要导入此交易组'),
                    subtitle: const Text('仅来源操作指纹相同，系统不会把它当作精确重复。'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (review.hasWarnings && !review.isSuspectedDuplicate)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: warningConfirmed,
                    onChanged:
                        review.canSelect
                            ? (value) => onWarningConfirmed(value ?? false)
                            : null,
                    title: const Text('确认警告后导入此交易组'),
                    subtitle: const Text('请确认已理解该交易组的解析提示。'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueLine extends StatelessWidget {
  const _IssueLine({required this.issue, required this.color});

  final ImportIssue issue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final location = [
      if (issue.fileRole != null) importFileRoleLabel(issue.fileRole!),
      if (issue.rowNumber != null) '第 ${issue.rowNumber} 行',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            RemixIcons.error_warning_line,
            size: AppSpacing.space18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              location.isEmpty ? issue.message : '$location：${issue.message}',
              style: context.appTextStyles.detailValue.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportDraftEditSheet extends StatefulWidget {
  const _ImportDraftEditSheet({required this.draft});

  final ImportTransactionDraft draft;

  @override
  State<_ImportDraftEditSheet> createState() => _ImportDraftEditSheetState();
}

class _ImportDraftEditSheetState extends State<_ImportDraftEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController? _interestController;
  late final TextEditingController? _feeController;
  late final TextEditingController? _transferFeeController;
  late DateTime _occurredAt;
  late DateTime _postedAt;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    final amount = switch (draft) {
      ImportRepaymentDraft draft => draft.principal,
      ImportReimbursementCloseDraft draft => draft.actualReceivedAmount,
      _ => draft.amount,
    };
    _amountController = TextEditingController(text: amount.format());
    _noteController = TextEditingController(text: draft.note ?? '');
    _interestController =
        draft is ImportRepaymentDraft
            ? TextEditingController(text: draft.interest?.format() ?? '')
            : null;
    _feeController =
        draft is ImportRepaymentDraft
            ? TextEditingController(text: draft.fee?.format() ?? '')
            : null;
    _transferFeeController =
        draft is ImportTransferDraft
            ? TextEditingController(text: draft.feeAmount?.format() ?? '')
            : null;
    _occurredAt = draft.occurredAt;
    _postedAt = draft.postedAt;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _interestController?.dispose();
    _feeController?.dispose();
    _transferFeeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final allowsZero = draft is ImportReimbursementCloseDraft;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space20,
          AppSpacing.space8,
          AppSpacing.space20,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '编辑${importOperationLabel(draft.operationKind)}',
                style: context.appTextStyles.subsectionTitle,
              ),
              const SizedBox(height: AppSpacing.space12),
              MoneyPlainFormRow(
                label: switch (draft) {
                  ImportReimbursementCloseDraft() => '到账金额',
                  ImportRepaymentDraft() => '本金',
                  ImportInterestExpenseDraft() => '利息',
                  _ => '金额',
                },
                controller: _amountController,
                requiredIndicator: true,
                validator:
                    allowsZero
                        ? (value) => validateNonNegativeMoneyText(value)
                        : (value) => validatePositiveMoneyText(value),
              ),
              if (_transferFeeController case final controller?) ...[
                const SizedBox(height: AppSpacing.space8),
                MoneyPlainFormRow(
                  label: '转账手续费',
                  controller: controller,
                  hintText: '可选',
                  validator: validateOptionalNonNegativeMoneyText,
                ),
              ],
              if (_interestController case final controller?) ...[
                const SizedBox(height: AppSpacing.space8),
                MoneyPlainFormRow(
                  label: '利息',
                  controller: controller,
                  hintText: '可选',
                  validator: validateOptionalNonNegativeMoneyText,
                ),
              ],
              if (_feeController case final controller?) ...[
                const SizedBox(height: AppSpacing.space8),
                MoneyPlainFormRow(
                  label: '手续费',
                  controller: controller,
                  hintText: '可选',
                  validator: validateOptionalNonNegativeMoneyText,
                ),
              ],
              const SizedBox(height: AppSpacing.space8),
              AppPlainSelectFormRow<DateTime>(
                label: '交易时间',
                value: _occurredAt,
                placeholder: '选择交易时间',
                valueText: formatImportDateTime(_occurredAt),
                onTap: (onSelected) async {
                  final picked = await showAppDateTimePicker(
                    context: context,
                    initialDateTime: _occurredAt,
                    title: '选择交易时间',
                  );
                  if (picked != null && mounted) onSelected(picked);
                },
                onChanged: (value) {
                  if (value != null) setState(() => _occurredAt = value);
                },
              ),
              const SizedBox(height: AppSpacing.space8),
              AppPlainSelectFormRow<DateTime>(
                label: '入账时间',
                value: _postedAt,
                placeholder: '选择入账时间',
                valueText: formatImportDateTime(_postedAt),
                onTap: (onSelected) async {
                  final picked = await showAppDateTimePicker(
                    context: context,
                    initialDateTime: _postedAt,
                    title: '选择入账时间',
                  );
                  if (picked != null && mounted) onSelected(picked);
                },
                onChanged: (value) {
                  if (value != null) setState(() => _postedAt = value);
                },
              ),
              const SizedBox(height: AppSpacing.space8),
              AppPlainTextFormRow(
                label: '备注',
                controller: _noteController,
                maxLines: 3,
                minLines: 1,
                hintText: '可选',
              ),
              const SizedBox(height: AppSpacing.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppSpacing.space8),
                  FilledButton(onPressed: _submit, child: const Text('保存本次修改')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = Money.tryParse(_amountController.text.trim());
    if (amount == null) return;
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      ImportDraftEdit(
        amount: amount,
        occurredAt: _occurredAt,
        postedAt: _postedAt,
        note: note.isEmpty ? const Patch.clear() : Patch.set(note),
        interest: _moneyPatch(_interestController),
        fee: _moneyPatch(_feeController),
        transferFee: _moneyPatch(_transferFeeController),
      ),
    );
  }

  Patch<Money?>? _moneyPatch(TextEditingController? controller) {
    if (controller == null) return null;
    final text = controller.text.trim();
    return text.isEmpty
        ? const Patch<Money?>.clear()
        : Patch<Money?>.set(Money.parse(text));
  }
}

class _FilteredRecordsSection extends StatelessWidget {
  const _FilteredRecordsSection({required this.records});

  final List<ImportFilteredRecord> records;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: ExpansionTile(
        title: Text(
          '已过滤来源记录 ${records.length}',
          style: context.appTextStyles.listTitle,
        ),
        subtitle: const Text('这些来源行已由其它交易组完整表达，不计入批次跳过数量。'),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space16,
        ),
        children: [
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${importFileRoleLabel(record.fileRole)}'
                  '${record.rowNumber == null ? '' : ' · 第 ${record.rowNumber} 行'}：'
                  '${record.reason}',
                  style: context.appTextStyles.detailValue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImportHistoryTab extends StatelessWidget {
  const _ImportHistoryTab({
    required this.state,
    required this.onRefresh,
    required this.onRevert,
    required this.onClearError,
  });

  final ImportPageState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<ImportBatch> onRevert;
  final VoidCallback onClearError;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space20,
          AppSpacing.space20,
          AppSpacing.space20,
          AppSpacing.space32,
        ),
        children: [
          if (state.error case final error?) ...[
            _FeedbackBanner(
              icon: RemixIcons.error_warning_line,
              message: error.message,
              tone: _FeedbackTone.error,
              onClose: onClearError,
            ),
            const SizedBox(height: AppSpacing.space16),
          ],
          Row(
            children: [
              Expanded(
                child: Text('一木导入批次', style: context.appTextStyles.groupTitle),
              ),
              IconButton(
                onPressed: state.historyLoading ? null : onRefresh,
                icon:
                    state.historyLoading
                        ? const SizedBox.square(
                          dimension: AppSpacing.space18,
                          child: CircularProgressIndicator(
                            strokeWidth:
                                AppProgressIndicatorTokens.compactStrokeWidth,
                          ),
                        )
                        : const Icon(RemixIcons.refresh_line),
                tooltip: '刷新批次历史',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space8),
          if (state.batches.isEmpty && !state.historyLoading)
            AppSurface(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space24),
                child: Column(
                  children: [
                    Icon(
                      RemixIcons.history_line,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.space10),
                    Text('暂无导入批次', style: context.appTextStyles.groupTitle),
                    const SizedBox(height: AppSpacing.space4),
                    Text(
                      '至少成功提交一个交易组后才会产生批次记录。',
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.pageSubtitle,
                    ),
                  ],
                ),
              ),
            )
          else
            for (final batch in state.batches) ...[
              _ImportBatchCard(
                batch: batch,
                reverting: state.revertingBatchId == batch.id,
                onRevert: () => onRevert(batch),
              ),
              const SizedBox(height: AppSpacing.space10),
            ],
        ],
      ),
    );
  }
}

class _ImportBatchCard extends StatelessWidget {
  const _ImportBatchCard({
    required this.batch,
    required this.reverting,
    required this.onRevert,
  });

  final ImportBatch batch;
  final bool reverting;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final reverted = batch.status == ImportBatchStatus.reverted;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatImportDateTime(batch.importedAt),
                    style: context.appTextStyles.listTitle,
                  ),
                ),
                _StatusBadge(
                  label: reverted ? '已撤销' : '已导入',
                  tone: reverted ? _FeedbackTone.info : _FeedbackTone.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space10),
            Text(
              '${batch.importedGroupCount} 个交易组 · '
              '${batch.createdTransactionCount} 条交易 · '
              '跳过 ${batch.skippedGroupCount} 组',
              style: context.appTextStyles.detailValue,
            ),
            if (batch.revertedAt case final revertedAt?) ...[
              const SizedBox(height: AppSpacing.space4),
              Text(
                '撤销于 ${formatImportDateTime(revertedAt)}',
                style: context.appTextStyles.pageSubtitle,
              ),
            ],
            if (!reverted) ...[
              const SizedBox(height: AppSpacing.space12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: reverting ? null : onRevert,
                  icon:
                      reverting
                          ? const SizedBox.square(
                            dimension: AppSpacing.space18,
                            child: CircularProgressIndicator(
                              strokeWidth:
                                  AppProgressIndicatorTokens.compactStrokeWidth,
                            ),
                          )
                          : const Icon(RemixIcons.arrow_go_back_line),
                  label: Text(reverting ? '正在撤销' : '撤销批次'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _FeedbackTone { success, warning, error, info }

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.icon,
    required this.message,
    required this.tone,
    this.onClose,
  });

  final IconData icon;
  final String message;
  final _FeedbackTone tone;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppListTokens.statusBackgroundOpacity),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(
          color: color.withValues(alpha: AppListTokens.statusBorderOpacity),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.space10),
          Expanded(
            child: Text(
              message,
              style: context.appTextStyles.detailValue.copyWith(color: color),
            ),
          ),
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(RemixIcons.close_line),
              color: color,
              tooltip: '关闭提示',
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _FeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppListTokens.statusBackgroundOpacity),
        borderRadius: BorderRadius.circular(AppRadius.radiusFull),
      ),
      child: Text(
        label,
        style: context.appTextStyles.badgeLabel.copyWith(color: color),
      ),
    );
  }
}

AppThemeExtension _themeExtension(BuildContext context) {
  return Theme.of(context).extension<AppThemeExtension>()!;
}

Color _toneColor(BuildContext context, _FeedbackTone tone) {
  final extension = _themeExtension(context);
  return switch (tone) {
    _FeedbackTone.success => extension.success,
    _FeedbackTone.warning => extension.warning,
    _FeedbackTone.error => Theme.of(context).colorScheme.error,
    _FeedbackTone.info => extension.info,
  };
}
