import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/import/import_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/progress_indicator.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_empty_state.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_status_banner.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../../widget/business/account/account_picker_sheet.dart';
import '../../../widget/business/category/category_picker_sheet.dart';
import '../../../widget/business/transaction/transaction_day_card.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/import_presentation.dart';
import '../view_model/import_view_model.dart';
import '../widget/import_analysis_card.dart';
import '../widget/import_mapping_item.dart';
import '../widget/import_source_icon.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportLandingPageState();
}

class ImportHistoryPage extends ConsumerStatefulWidget {
  const ImportHistoryPage({super.key});

  @override
  ConsumerState<ImportHistoryPage> createState() => _ImportHistoryPageState();
}

class ImportProcessPage extends ConsumerStatefulWidget {
  const ImportProcessPage({required this.source, super.key});

  final ImportEntrySource source;

  @override
  ConsumerState<ImportProcessPage> createState() => _ImportProcessPageState();
}

class ImportMappingPage extends ConsumerWidget {
  const ImportMappingPage({required this.onSelectMapping, super.key});

  final ValueChanged<ImportMappingReviewItem> onSelectMapping;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importViewModelProvider);
    final notifier = ref.read(importViewModelProvider.notifier);
    final review = state.review;
    final summary = review == null
        ? const ImportMappingAnalysisSummary(mapped: 0, pending: 0, unmapped: 0)
        : summarizeImportMappings(review);
    final mappingItems =
        review?.mappingItems ?? const <ImportMappingReviewItem>[];
    final accountItems = mappingItems
        .where((item) => item.key.entityKind == ImportEntityKind.account)
        .toList(growable: false);
    final categoryItems = mappingItems
        .where((item) => item.key.entityKind == ImportEntityKind.category)
        .toList(growable: false);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '账户与分类映射',
              actions: [
                AppHeaderTextButton(
                  label: '确认',
                  onPressed: state.isBusy || state.missingMappingCount > 0
                      ? null
                      : () => _confirm(context, notifier),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.space16),
                children: [
                  ImportAnalysisCard(
                    title: '映射概览',
                    icon: RemixIcons.git_merge_line,
                    metrics: [
                      ImportAnalysisMetric(
                        label: '映射成功',
                        value: summary.mapped,
                      ),
                      ImportAnalysisMetric(
                        label: '待确认',
                        value: summary.pending,
                      ),
                      ImportAnalysisMetric(
                        label: '无法映射',
                        value: summary.unmapped,
                      ),
                    ],
                    description: importMappingAnalysisDescription(summary),
                    showViewAll: false,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _MappingList(
                    entityKind: ImportEntityKind.account,
                    title: '账户',
                    emptyMessage: '未提取到需要映射的来源账户。',
                    state: state,
                    items: accountItems,
                    onSelectMapping: onSelectMapping,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  _MappingList(
                    entityKind: ImportEntityKind.category,
                    title: '分类',
                    emptyMessage: '未提取到需要映射的来源分类。',
                    state: state,
                    items: categoryItems,
                    onSelectMapping: onSelectMapping,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, ImportViewModel notifier) async {
    final outcome = await notifier.confirmMappingConfiguration();
    if (!context.mounted) return;
    if (outcome case ImportActionFailure<void>(:final error)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    Navigator.of(context).maybePop();
  }
}

class ImportPreviewPage extends ConsumerWidget {
  const ImportPreviewPage({required this.review, super.key});

  final ImportPlanReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importViewModelProvider);
    final currentReview = state.review ?? review;
    final groups = buildImportPreviewGroups(
      currentReview,
      selectedGroupIndexes: state.selectedGroupIndexes,
      showSelectionControls: true,
    );
    final summary = summarizeImportPreview(
      currentReview,
      confirmedExactDuplicateIndexes: state.confirmedExactDuplicateIndexes,
      confirmedSuspectedDuplicateIndexes:
          state.confirmedSuspectedDuplicateIndexes,
      confirmedWarningIndexes: state.confirmedWarningIndexes,
    );
    final blockedGroups = currentReview.groups
        .where((group) => group.isBlocked)
        .toList(growable: false);
    final filteredRecords = currentReview.plan.filteredRecords;
    final bulkSelectableCount = currentReview.groups
        .where((group) => group.canSelect)
        .length;
    final notifier = ref.read(importViewModelProvider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '导入预览',
              actions: [
                AppHeaderTextButton(
                  label: state.allSelectableSelected ? '全不选' : '全选',
                  onPressed: state.isBusy || bulkSelectableCount == 0
                      ? null
                      : () => notifier.selectAllSelectable(
                          !state.allSelectableSelected,
                        ),
                ),
                AppHeaderTextButton(
                  label: '确认',
                  onPressed: state.isBusy
                      ? null
                      : () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space12,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  ImportAnalysisCard(
                    title: '解析概览',
                    icon: RemixIcons.list_check_3,
                    metrics: [
                      ImportAnalysisMetric(
                        label: '解析成功',
                        value: summary.parsed,
                      ),
                      ImportAnalysisMetric(
                        label: '待确认',
                        value: summary.pending,
                      ),
                      ImportAnalysisMetric(
                        label: '已跳过',
                        value: summary.skipped,
                      ),
                      ImportAnalysisMetric(
                        label: '无法解析',
                        value: summary.unparsed,
                      ),
                    ],
                    description: importPreviewAnalysisDescription(summary),
                    showViewAll: false,
                  ),
                  const SizedBox(height: AppSpacing.space16),
                  if (blockedGroups.isNotEmpty ||
                      filteredRecords.isNotEmpty) ...[
                    _ImportPreviewDetailsEntry(
                      blockedCount: blockedGroups.length,
                      skippedCount: filteredRecords.length,
                      onTap: () => _openIssuesPage(
                        context,
                        blockedGroups,
                        filteredRecords,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.space16),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '已选 ${state.selectedGroupIndexes.length} 笔',
                      style: context.appTextStyles.listSupporting,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  for (var index = 0; index < groups.length; index++) ...[
                    TransactionDayCard(
                      group: groups[index],
                      enableRowTap: !state.isBusy,
                      showDailyTotals: false,
                      onRowTap: (transactionId) => _handleRowTap(
                        ref,
                        state,
                        currentReview,
                        transactionId,
                      ),
                      onRowSelectionChanged: state.isBusy
                          ? null
                          : (transactionId, selected) {
                              final groupIndex = _importGroupIndexFromRowId(
                                transactionId,
                              );
                              if (groupIndex == null) return;
                              ref
                                  .read(importViewModelProvider.notifier)
                                  .setGroupSelection(groupIndex, selected);
                            },
                    ),
                    if (index < groups.length - 1)
                      const SizedBox(height: AppSpacing.space10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openIssuesPage(
    BuildContext context,
    List<ImportGroupReview> blockedGroups,
    List<ImportFilteredRecord> filteredRecords,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImportIssuesPage(
          blockedGroups: blockedGroups,
          filteredRecords: filteredRecords,
        ),
      ),
    );
  }

  void _handleRowTap(
    WidgetRef ref,
    ImportPageState state,
    ImportPlanReview review,
    String transactionId,
  ) {
    final groupIndex = _importGroupIndexFromRowId(transactionId);
    if (groupIndex == null) return;
    final group = review.groups[groupIndex];
    if (!group.canSelect) return;
    ref
        .read(importViewModelProvider.notifier)
        .setGroupSelection(
          groupIndex,
          !state.selectedGroupIndexes.contains(groupIndex),
        );
  }
}

int? _importGroupIndexFromRowId(String transactionId) {
  const prefix = 'import-group-';
  if (!transactionId.startsWith(prefix)) return null;
  return int.tryParse(transactionId.substring(prefix.length));
}

class _ImportPreviewDetailsEntry extends StatelessWidget {
  const _ImportPreviewDetailsEntry({
    required this.blockedCount,
    required this.skippedCount,
    required this.onTap,
  });

  final int blockedCount;
  final int skippedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasBlocked = blockedCount > 0;
    final subtitle = [
      if (hasBlocked) '无法解析 $blockedCount',
      if (skippedCount > 0) '已跳过 $skippedCount',
    ].join(' · ');
    return AppSurface(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space16),
          child: Row(
            children: [
              Icon(
                hasBlocked
                    ? RemixIcons.error_warning_line
                    : RemixIcons.information_line,
                size: AppSpacing.space20,
                color: hasBlocked ? colors.error : colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('解析详情', style: context.appTextStyles.listTitle),
                    const SizedBox(height: AppSpacing.space2),
                    Text(subtitle, style: context.appTextStyles.pageSubtitle),
                  ],
                ),
              ),
              Icon(
                RemixIcons.arrow_right_s_line,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImportIssuesPage extends StatelessWidget {
  const ImportIssuesPage({
    required this.blockedGroups,
    required this.filteredRecords,
    super.key,
  });

  final List<ImportGroupReview> blockedGroups;
  final List<ImportFilteredRecord> filteredRecords;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '解析详情'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space12,
                  AppSpacing.space16,
                  AppSpacing.space24,
                ),
                children: [
                  if (blockedGroups.isNotEmpty) ...[
                    Text(
                      '无法解析 (${blockedGroups.length})',
                      style: context.appTextStyles.groupTitle,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    for (
                      var index = 0;
                      index < blockedGroups.length;
                      index++
                    ) ...[
                      _blockedGroupCard(context, blockedGroups[index]),
                      if (index < blockedGroups.length - 1)
                        const SizedBox(height: AppSpacing.space10),
                    ],
                  ],
                  if (blockedGroups.isNotEmpty && filteredRecords.isNotEmpty)
                    const SizedBox(height: AppSpacing.space16),
                  if (filteredRecords.isNotEmpty) ...[
                    Text(
                      '已跳过记录 (${filteredRecords.length})',
                      style: context.appTextStyles.groupTitle,
                    ),
                    const SizedBox(height: AppSpacing.space8),
                    for (
                      var index = 0;
                      index < filteredRecords.length;
                      index++
                    ) ...[
                      _SkippedRecordCard(record: filteredRecords[index]),
                      if (index < filteredRecords.length - 1)
                        const SizedBox(height: AppSpacing.space10),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockedGroupCard(BuildContext context, ImportGroupReview group) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  RemixIcons.error_warning_line,
                  size: AppSpacing.space18,
                  color: colors.error,
                ),
                const SizedBox(width: AppSpacing.space8),
                Expanded(
                  child: Text(
                    '${importOperationLabel(group.group.topLevel.operationKind)}'
                    ' · ${formatImportDateTime(group.group.topLevel.occurredAt)}',
                    style: context.appTextStyles.listTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space6),
            for (final issue in group.issues.where((issue) => issue.isBlocking))
              _IssueLine(issue: issue, color: colors.error),
          ],
        ),
      ),
    );
  }
}

class _SkippedRecordCard extends StatelessWidget {
  const _SkippedRecordCard({required this.record});

  final ImportFilteredRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final location = [
      importFileTypeLabel(record.fileType),
      if (record.rowNumber != null) '第 ${record.rowNumber} 行',
    ].join(' · ');
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              RemixIcons.information_line,
              size: AppSpacing.space18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location, style: context.appTextStyles.listTitle),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    record.reason,
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

class _ImportProcessPageState extends ConsumerState<ImportProcessPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(importViewModelProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importViewModelProvider);
    final notifier = ref.read(importViewModelProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '导入中',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.close_line,
                  tooltip: '取消导入',
                  onPressed: _cancel,
                ),
              ],
            ),
            Expanded(
              child: widget.source.isAvailable
                  ? _ImportReviewTab(
                      source: widget.source,
                      state: state,
                      onAddFiles: () => _pickFiles(append: true),
                      onParseFiles: _parseFiles,
                      onReset: notifier.reset,
                      onClearError: notifier.clearError,
                      onViewAllMappings: _viewAllMappings,
                      onToggleSaveMappingConfiguration:
                          _toggleSaveMappingConfiguration,
                      onCommit: _commit,
                    )
                  : _UnavailableImportSource(source: widget.source),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles({required bool append}) async {
    final source = widget.source.domainSource;
    if (source == null) return;
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .pickFiles(source: source, append: append);
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _parseFiles() async {
    final source = widget.source.domainSource;
    if (source == null) return;
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .parseSelectedFiles(source: source);
    if (!mounted) return;
    _showFailure(outcome);
  }

  void _cancel() {
    ref.read(importViewModelProvider.notifier).reset();
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/import');
    }
  }

  Future<void> _selectMapping(ImportMappingReviewItem item) async {
    final state = ref.read(importViewModelProvider);
    final review = state.review;
    if (review == null) return;
    final key = item.key;
    final selection = await showModalBottomSheet<_MappingSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MappingTargetSheet(
        item: item,
        selectedDecision: item.effectiveDecision,
        hasTemporaryOverride:
            state.temporaryMappings.containsKey(key) ||
            state.plannedCreations.containsKey(key),
      ),
    );
    if (!mounted || selection == null) return;
    final notifier = ref.read(importViewModelProvider.notifier);
    final outcome = await notifier.setMappingDecision(key, selection.decision);
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _viewAllMappings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ImportMappingPage(onSelectMapping: _selectMapping),
      ),
    );
    if (!mounted) return;
    final state = ref.read(importViewModelProvider);
    if (!state.mappingConfirmed || state.previewReady) return;
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .preparePreview();
    if (!mounted) return;
    _showFailure(outcome);
  }

  void _toggleSaveMappingConfiguration() {
    final outcome = ref
        .read(importViewModelProvider.notifier)
        .toggleSaveMappingConfiguration();
    _showFailure(outcome);
  }

  Future<void> _commit() async {
    final state = ref.read(importViewModelProvider);
    final selectedCount = state.selectedGroupIndexes.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .commitSelectedGroups();
    if (!mounted) return;
    switch (outcome) {
      case ImportActionSuccess(:final value):
        final batch = value.batch;
        if (batch == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('没有创建新批次，所选交易组均被跳过。')));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入成功：${batch.importedGroupCount} 个交易组，'
              '${batch.createdTransactionCount} 条交易；'
              '跳过 ${batch.skippedGroupCount} 个交易组。',
            ),
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/import');
        }
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

class _ImportLandingPageState extends ConsumerState<ImportPage> {
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '数据导入',
              onBack: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/profile');
                }
              },
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.question_line,
                  tooltip: '导入帮助',
                  onPressed: () {},
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space16,
                    AppSpacing.space32,
                  ),
                  children: [
                    Text('导入来源', style: context.appTextStyles.groupTitle),
                    const SizedBox(height: AppSpacing.space10),
                    _ImportSourceList(
                      onSelected: (source) =>
                          context.push('/import/process/${source.routeValue}'),
                    ),
                    const SizedBox(height: AppSpacing.space16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '导入记录',
                            style: context.appTextStyles.groupTitle,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/import/history'),
                          child: const Text('查看全部'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space6),
                    if (state.error case final error?) ...[
                      AppStatusBanner(
                        message: error.message,
                        tone: AppStatusBannerTone.danger,
                        action: IconButton(
                          onPressed: ref
                              .read(importViewModelProvider.notifier)
                              .clearError,
                          icon: const Icon(RemixIcons.close_line),
                          tooltip: '关闭提示',
                        ),
                      ),
                    ] else if (state.historyLoading && state.batches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.space24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.batches.isEmpty)
                      const _EmptyImportHistoryCard()
                    else
                      for (final batch in state.batches.take(5)) ...[
                        _ImportBatchCard(batch: batch),
                        const SizedBox(height: AppSpacing.space10),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .loadHistory();
    if (!mounted || outcome is ImportActionSuccess<List<ImportBatch>>) return;
    final error = (outcome as ImportActionFailure<List<ImportBatch>>).error;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }
}

class _ImportHistoryPageState extends ConsumerState<ImportHistoryPage> {
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '导入记录'),
            Expanded(
              child: _ImportHistoryTab(
                state: state,
                onRefresh: _loadHistory,
                onRevert: _confirmRevert,
                onClearError: ref
                    .read(importViewModelProvider.notifier)
                    .clearError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .loadHistory();
    if (!mounted || outcome is ImportActionSuccess<List<ImportBatch>>) return;
    final error = (outcome as ImportActionFailure<List<ImportBatch>>).error;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
  }

  Future<void> _confirmRevert(ImportBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ImportSourceList extends StatelessWidget {
  const _ImportSourceList({required this.onSelected});

  final ValueChanged<ImportEntrySource> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: Column(
        children: [
          for (
            var index = 0;
            index < ImportEntrySource.values.length;
            index++
          ) ...[
            _ImportSourceRow(
              source: ImportEntrySource.values[index],
              onTap: () => onSelected(ImportEntrySource.values[index]),
            ),
            if (index < ImportEntrySource.values.length - 1)
              Container(
                height: AppListTokens.dividerThickness,
                margin: const EdgeInsets.only(
                  left: AppSpacing.space48 + AppSpacing.space16,
                ),
                color: colors.outlineVariant.withValues(
                  alpha: AppListTokens.dividerOpacity,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ImportSourceRow extends StatelessWidget {
  const _ImportSourceRow({required this.source, required this.onTap});

  final ImportEntrySource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space14,
        ),
        child: Row(
          children: [
            ImportSourceIcon(source: source),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.label, style: context.appTextStyles.listTitle),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    source.description,
                    style: context.appTextStyles.pageSubtitle,
                  ),
                ],
              ),
            ),
            const Icon(RemixIcons.arrow_right_s_line),
          ],
        ),
      ),
    );
  }
}

class _EmptyImportHistoryCard extends StatelessWidget {
  const _EmptyImportHistoryCard();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: AppEmptyState(
        icon: const Icon(RemixIcons.history_line),
        title: '暂无导入记录',
        message: '完成一次导入后，任务记录会显示在这里。',
      ),
    );
  }
}

class _UnavailableImportSource extends StatelessWidget {
  const _UnavailableImportSource({required this.source});

  final ImportEntrySource source;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space20),
            child: Column(
              children: [
                ImportSourceIcon(source: source, size: AppSpacing.space48),
                const SizedBox(height: AppSpacing.space12),
                Text(source.label, style: context.appTextStyles.groupTitle),
                const SizedBox(height: AppSpacing.space6),
                Text(
                  '该导入来源尚未开放，文件选择与解析能力将在后续版本接入。',
                  textAlign: TextAlign.center,
                  style: context.appTextStyles.pageSubtitle,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportReviewTab extends StatelessWidget {
  const _ImportReviewTab({
    required this.source,
    required this.state,
    required this.onAddFiles,
    required this.onParseFiles,
    required this.onReset,
    required this.onClearError,
    required this.onViewAllMappings,
    required this.onToggleSaveMappingConfiguration,
    required this.onCommit,
  });

  final ImportEntrySource source;
  final ImportPageState state;
  final VoidCallback onAddFiles;
  final VoidCallback onParseFiles;
  final VoidCallback onReset;
  final VoidCallback onClearError;
  final VoidCallback onViewAllMappings;
  final VoidCallback onToggleSaveMappingConfiguration;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final review = state.review;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space16,
            AppSpacing.space16,
            AppSpacing.space16,
            AppSpacing.space48 + AppSpacing.space40,
          ),
          children: [
            if (state.error case final error?) ...[
              AppStatusBanner(
                message: error.message,
                tone: AppStatusBannerTone.danger,
                action: IconButton(
                  onPressed: onClearError,
                  icon: const Icon(RemixIcons.close_line),
                  tooltip: '关闭提示',
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
            ],
            _ImportFilesSection(
              source: source,
              state: state,
              onAddFiles: onAddFiles,
              onParseFiles: onParseFiles,
              onReset: onReset,
            ),
            if (plan?.hasFatalIssues ?? false) ...[
              const SizedBox(height: AppSpacing.space16),
              _FatalIssuesCard(plan: plan!),
            ] else if (review != null) ...[
              if (plan!.issues.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space16),
                _PlanIssuesCard(issues: plan.issues),
              ],
              const SizedBox(height: AppSpacing.space16),
              if (state.lastCommit case final result?) ...[
                _CommitResultBanner(result: result),
                const SizedBox(height: AppSpacing.space16),
              ],
              _MappingSection(
                state: state,
                onViewAll: onViewAllMappings,
                onToggleSaveMappingConfiguration:
                    onToggleSaveMappingConfiguration,
              ),
              const SizedBox(height: AppSpacing.space16),
              _ImportPreviewSection(state: state),
            ] else if (state.phase == ImportPagePhase.reviewing) ...[
              const SizedBox(height: AppSpacing.space16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
        if (review != null && !plan!.hasFatalIssues)
          Positioned(
            left: AppSpacing.space16,
            right: AppSpacing.space16,
            bottom: AppSpacing.space16,
            child: SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0),
                      Theme.of(context).colorScheme.surface,
                    ],
                    stops: const [0, 0.4],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space16),
                  child: FilledButton.icon(
                    onPressed:
                        state.isBusy ||
                            state.selectedGroupIndexes.isEmpty ||
                            !state.mappingConfirmed ||
                            !state.previewReady
                        ? null
                        : onCommit,
                    icon: state.phase == ImportPagePhase.committing
                        ? const SizedBox.square(
                            dimension: AppSpacing.space18,
                            child: CircularProgressIndicator(
                              strokeWidth:
                                  AppProgressIndicatorTokens.compactStrokeWidth,
                            ),
                          )
                        : const Icon(RemixIcons.import_line),
                    label: Text(
                      state.phase == ImportPagePhase.committing ? '正在导入' : '导入',
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImportFilesSection extends StatelessWidget {
  const _ImportFilesSection({
    required this.source,
    required this.state,
    required this.onAddFiles,
    required this.onParseFiles,
    required this.onReset,
  });

  final ImportEntrySource source;
  final ImportPageState state;
  final VoidCallback onAddFiles;
  final VoidCallback onParseFiles;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final files = state.selectedBundle?.files ?? const <ImportFilePayload>[];
    final isParsing = state.phase == ImportPagePhase.parsing;
    final controlsDisabled = state.isBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ImportSourceIcon(source: source),
                    const SizedBox(width: AppSpacing.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.label,
                            style: context.appTextStyles.listTitle,
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          Text(
                            _fileSummary(files),
                            style: context.appTextStyles.pageSubtitle,
                          ),
                        ],
                      ),
                    ),
                    if (files.isNotEmpty) ...[
                      IconButton(
                        onPressed: controlsDisabled ? null : onReset,
                        icon: const Icon(RemixIcons.delete_bin_line),
                        tooltip: '清空',
                      ),
                      IconButton(
                        onPressed: controlsDisabled ? null : onAddFiles,
                        icon: const Icon(RemixIcons.add_line),
                        tooltip: '添加文件',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.space8),
                if (files.isEmpty) ...[
                  _UploadDropzone(
                    description: source.fileSelectionHint,
                    onTap: controlsDisabled ? null : onAddFiles,
                  ),
                ] else ...[
                  for (var index = 0; index < files.length; index++) ...[
                    _ImportFileRow(
                      file: files[index],
                      progress: state.fileProgressAt(index),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space8),
                  OutlinedButton.icon(
                    onPressed: controlsDisabled || files.isEmpty
                        ? null
                        : onParseFiles,
                    icon: isParsing
                        ? const SizedBox.square(
                            dimension: AppSpacing.space18,
                            child: CircularProgressIndicator(
                              strokeWidth:
                                  AppProgressIndicatorTokens.compactStrokeWidth,
                            ),
                          )
                        : const Icon(RemixIcons.file_search_line),
                    label: Text(isParsing ? '解析中' : '解析文件'),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isParsing) ...[
          const SizedBox(height: AppSpacing.space10),
          Text(
            '正在解析 ${files.length} 个文件…',
            style: context.appTextStyles.pageSubtitle,
          ),
          const SizedBox(height: AppSpacing.space6),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  String _fileSummary(List<ImportFilePayload> files) {
    if (files.isEmpty) return '尚未选择文件';
    return '共 ${files.length} 个文件';
  }
}

class _UploadDropzone extends StatelessWidget {
  const _UploadDropzone({required this.description, this.onTap});

  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.space28),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(
            color: colors.outlineVariant.withValues(
              alpha: AppComponentTokens.mutedOutlineOpacity,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(
              RemixIcons.folder_upload_line,
              size: AppSpacing.space32,
              color: colors.primary,
            ),
            const SizedBox(height: AppSpacing.space8),
            Text('点击选择文件', style: context.appTextStyles.listTitle),
            const SizedBox(height: AppSpacing.space4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space16,
              ),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: context.appTextStyles.pageSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportFileRow extends StatelessWidget {
  const _ImportFileRow({required this.file, required this.progress});

  final ImportFilePayload file;
  final ImportFileProgress progress;

  @override
  Widget build(BuildContext context) {
    final color = switch (progress.status) {
      ImportFileProcessingStatus.waiting => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
      ImportFileProcessingStatus.parsing => Theme.of(
        context,
      ).colorScheme.primary,
      ImportFileProcessingStatus.success => _themeExtension(context).success,
      ImportFileProcessingStatus.warning => _themeExtension(context).warning,
      ImportFileProcessingStatus.failed => Theme.of(context).colorScheme.error,
    };
    final icon = switch (progress.status) {
      ImportFileProcessingStatus.waiting => RemixIcons.time_line,
      ImportFileProcessingStatus.parsing => RemixIcons.loader_4_line,
      ImportFileProcessingStatus.success => RemixIcons.checkbox_circle_line,
      ImportFileProcessingStatus.warning => RemixIcons.error_warning_line,
      ImportFileProcessingStatus.failed => RemixIcons.close_circle_line,
    };
    final label = switch (progress.status) {
      ImportFileProcessingStatus.waiting => '待解析',
      ImportFileProcessingStatus.parsing => '解析中',
      ImportFileProcessingStatus.success => '解析成功',
      ImportFileProcessingStatus.warning => '存在异常',
      ImportFileProcessingStatus.failed => '解析失败',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.detailValue,
                ),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  formatImportFileSize(file.bytes.length),
                  style: context.appTextStyles.pageSubtitle,
                ),
                if (progress.detail case final detail?) ...[
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTextStyles.pageSubtitle.copyWith(
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          Icon(icon, color: color, size: AppSpacing.space20),
          const SizedBox(width: AppSpacing.space4),
          Text(
            label,
            style: context.appTextStyles.badgeLabel.copyWith(color: color),
          ),
        ],
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

class _PlanIssuesCard extends StatelessWidget {
  const _PlanIssuesCard({required this.issues});

  final List<ImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasBlocking = issues.any((issue) => issue.isBlocking);
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasBlocking ? '解析步骤需要注意' : '解析提示',
              style: context.appTextStyles.groupTitle,
            ),
            const SizedBox(height: AppSpacing.space8),
            for (final issue in issues)
              _IssueLine(
                issue: issue,
                color: issue.isBlocking ? colors.error : colors.primary,
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
    return AppStatusBanner(
      message: batch == null
          ? '没有创建新批次；${result.skippedGroupCount} 个交易组被跳过。'
          : '已导入 ${batch.importedGroupCount} 个交易组，创建 '
                '${batch.createdTransactionCount} 条交易，跳过 '
                '${batch.skippedGroupCount} 个交易组。',
      tone: batch == null
          ? AppStatusBannerTone.info
          : AppStatusBannerTone.success,
    );
  }
}

class _MappingSection extends StatelessWidget {
  const _MappingSection({
    required this.state,
    required this.onViewAll,
    required this.onToggleSaveMappingConfiguration,
  });

  final ImportPageState state;
  final VoidCallback onViewAll;
  final VoidCallback onToggleSaveMappingConfiguration;

  @override
  Widget build(BuildContext context) {
    final review = state.review!;
    final summary = summarizeImportMappings(review);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImportAnalysisCard(
          title: '账户与分类映射',
          icon: RemixIcons.git_merge_line,
          metrics: [
            ImportAnalysisMetric(label: '映射成功', value: summary.mapped),
            ImportAnalysisMetric(label: '待确认', value: summary.pending),
            ImportAnalysisMetric(label: '无法映射', value: summary.unmapped),
          ],
          description: importMappingAnalysisDescription(summary),
          onViewAll: summary.total == 0 ? null : onViewAll,
          footer: AppPlainSwitchRow(
            label: '保存映射配置',
            description: '导入成功后，下次自动沿用本次账户与分类选择',
            value: state.saveMappingConfiguration,
            enabled: !state.isBusy && state.missingMappingCount == 0,
            onChanged: (_) => onToggleSaveMappingConfiguration(),
          ),
        ),
      ],
    );
  }
}

class _MappingList extends StatelessWidget {
  const _MappingList({
    required this.entityKind,
    required this.title,
    required this.emptyMessage,
    required this.state,
    required this.items,
    required this.onSelectMapping,
  });

  final ImportEntityKind entityKind;
  final String title;
  final String emptyMessage;
  final ImportPageState state;
  final List<ImportMappingReviewItem> items;
  final ValueChanged<ImportMappingReviewItem> onSelectMapping;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      key: ValueKey('import-mapping-${entityKind.name}-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space16),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: context.appTextStyles.groupTitle),
                ),
                Text(
                  '${items.length} 项',
                  style: context.appTextStyles.listSupporting,
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space16,
              ),
              child: Text(
                emptyMessage,
                style: context.appTextStyles.pageSubtitle,
              ),
            )
          else ...[
            const ImportMappingHeader(),
            for (final item in items)
              _MappingItem(
                state: state,
                item: item,
                onSelectMapping: onSelectMapping,
              ),
          ],
        ],
      ),
    );
  }
}

class _MappingItem extends StatelessWidget {
  const _MappingItem({
    required this.state,
    required this.item,
    required this.onSelectMapping,
  });

  final ImportPageState state;
  final ImportMappingReviewItem item;
  final ValueChanged<ImportMappingReviewItem> onSelectMapping;

  @override
  Widget build(BuildContext context) {
    final review = state.review!;
    final decision = item.effectiveDecision;
    final target = decision is ExistingTargetDecision
        ? review.targets
              .where((candidate) => candidate.id == decision.targetId)
              .firstOrNull
        : null;
    final creation = decision is PlannedCreationDecision
        ? decision.creation
        : null;
    final targetLabel = target?.isArchived == true
        ? '${target!.displayPath}（已归档）'
        : item.targetPath ?? item.targetName ?? '待配置';
    return ImportMappingItem(
      key: ValueKey(
        'import-mapping-item-${item.key.entityKind.name}-'
        '${item.key.sourceEntityKey}',
      ),
      sourceLabel: item.sourceName,
      sourceKindLabel: item.sourceDescription,
      targetLabel: targetLabel,
      action: item.action == ImportMappingAction.create || creation != null
          ? ImportMappingItemAction.create
          : item.action == ImportMappingAction.unresolved
          ? ImportMappingItemAction.unresolved
          : ImportMappingItemAction.map,
      targetKindLabel: item.targetDescription == targetLabel
          ? null
          : item.targetDescription,
      onTap:
          item.existingTargetOptions.isEmpty && item.creationOptions.isEmpty ||
              state.isBusy
          ? null
          : () => onSelectMapping(item),
    );
  }
}

class _MappingTargetSheet extends StatelessWidget {
  const _MappingTargetSheet({
    required this.item,
    required this.selectedDecision,
    required this.hasTemporaryOverride,
  });

  final ImportMappingReviewItem item;
  final ImportMappingDecision selectedDecision;
  final bool hasTemporaryOverride;

  @override
  Widget build(BuildContext context) {
    final selectedTargetId = selectedDecision is ExistingTargetDecision
        ? (selectedDecision as ExistingTargetDecision).targetId
        : null;
    final picker = item.key.entityKind == ImportEntityKind.category
        ? CategoryPickerSheet(
            sections: _categoryPickerSections(item.existingTargetOptions),
            selectableIds: {
              for (final target in item.existingTargetOptions) target.id,
            },
            selectedId: selectedTargetId,
            onCategoryTap: (targetId) => Navigator.of(context).pop(
              _MappingSelection(decision: ExistingTargetDecision(targetId)),
            ),
          )
        : AccountPickerOptionsSheet(
            accounts: [
              for (final target in item.existingTargetOptions)
                AccountPickerOption(
                  id: target.id,
                  name: target.name,
                  iconKey: target.iconKey,
                  profileKey: _accountProfileKey(target.descriptor),
                ),
            ],
            selectedId: selectedTargetId,
            onAccountTap: (target) => Navigator.of(context).pop(
              _MappingSelection(decision: ExistingTargetDecision(target.id)),
            ),
          );
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.55)
        .clamp(320.0, 440.0)
        .toDouble();
    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.sourceName,
                          style: context.appTextStyles.subsectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.space4),
                        Text(
                          item.sourceDescription,
                          style: context.appTextStyles.pageSubtitle,
                        ),
                      ],
                    ),
                  ),
                  if (item.creationOptions.isNotEmpty)
                    _MappingActionButton(
                      key: const ValueKey('import-mapping-create'),
                      label: '新建',
                      onPressed: () => _selectCreation(context),
                    ),
                  if (hasTemporaryOverride)
                    _MappingActionButton(
                      key: const ValueKey('import-mapping-default'),
                      label: '默认',
                      onPressed: () => Navigator.of(context).pop(
                        const _MappingSelection(
                          decision: UnresolvedDecision('恢复默认映射'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: AppListTokens.dividerThickness),
            Expanded(child: picker),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCreation(BuildContext context) async {
    if (item.creationOptions.length == 1) {
      Navigator.of(context).pop(
        _MappingSelection(
          decision: PlannedCreationDecision(item.creationOptions.first),
        ),
      );
      return;
    }
    final creation = await showModalBottomSheet<ImportMappingCreation>(
      context: context,
      showDragHandle: true,
      builder: (context) => _MappingCreationSheet(
        sourceName: item.sourceName,
        options: item.creationOptions,
      ),
    );
    if (creation == null || !context.mounted) return;
    Navigator.of(
      context,
    ).pop(_MappingSelection(decision: PlannedCreationDecision(creation)));
  }
}

class _MappingActionButton extends StatelessWidget {
  const _MappingActionButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppComponentTokens.controlMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
      ),
      child: Text(label),
    );
  }
}

class _MappingCreationSheet extends StatelessWidget {
  const _MappingCreationSheet({
    required this.sourceName,
    required this.options,
  });

  final String sourceName;
  final List<ImportMappingCreation> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                  '新建$sourceName',
                  style: context.appTextStyles.subsectionTitle,
                ),
                const SizedBox(height: AppSpacing.space4),
                Text(
                  '选择要创建的账户或分类类型',
                  style: context.appTextStyles.pageSubtitle,
                ),
              ],
            ),
          ),
          const Divider(height: AppListTokens.dividerThickness),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final creation in options)
                  ListTile(
                    key: ValueKey(
                      'import-mapping-create-${creation.descriptor.name}',
                    ),
                    leading: const Icon(RemixIcons.add_line),
                    title: Text(importTargetDescription(creation.descriptor)),
                    subtitle: creation.defaultParametersHint == null
                        ? null
                        : Text(creation.defaultParametersHint!),
                    onTap: () => Navigator.of(context).pop(creation),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _accountProfileKey(ImportTargetDescriptor descriptor) {
  return switch (descriptor) {
    ImportTargetDescriptor.fundAccount => AccountProfileKind.fund.key,
    ImportTargetDescriptor.advanceAccount =>
      AccountProfileKind.reimbursement.key,
    ImportTargetDescriptor.receivableAccount =>
      AccountProfileKind.receivable.key,
    ImportTargetDescriptor.prepaidExpenseAccount =>
      AccountProfileKind.prepaidExpense.key,
    ImportTargetDescriptor.payableAccount => AccountProfileKind.payable.key,
    ImportTargetDescriptor.deferredIncomeAccount =>
      AccountProfileKind.deferredIncome.key,
    ImportTargetDescriptor.creditAccount => AccountProfileKind.credit.key,
    ImportTargetDescriptor.loanAccount => AccountProfileKind.loan.key,
    ImportTargetDescriptor.incomeCategory ||
    ImportTargetDescriptor.expenseCategory ||
    ImportTargetDescriptor.ghostAccount ||
    ImportTargetDescriptor.unsupported => null,
  };
}

List<CategoryPickerSection> _categoryPickerSections(
  List<ImportMappingTarget> targets,
) {
  final expenseTargets = targets
      .where(
        (target) => target.descriptor == ImportTargetDescriptor.expenseCategory,
      )
      .toList(growable: false);
  final incomeTargets = targets
      .where(
        (target) => target.descriptor == ImportTargetDescriptor.incomeCategory,
      )
      .toList(growable: false);
  return [
    if (expenseTargets.isNotEmpty)
      CategoryPickerSection(
        type: AccountType.expense,
        label: '支出',
        nodes: _categoryPickerRoots(expenseTargets),
      ),
    if (incomeTargets.isNotEmpty)
      CategoryPickerSection(
        type: AccountType.income,
        label: '收入',
        nodes: _categoryPickerRoots(incomeTargets),
      ),
  ];
}

List<CategoryPickerNode> _categoryPickerRoots(
  List<ImportMappingTarget> targets,
) {
  final targetIds = {for (final target in targets) target.id};
  return [
    for (final target in targets)
      if (target.parentId == null || !targetIds.contains(target.parentId))
        CategoryPickerNode(
          id: target.id,
          label: target.name,
          iconKey: target.iconKey,
          children: [
            for (final child in targets)
              if (child.parentId == target.id)
                CategoryPickerNode(
                  id: child.id,
                  label: child.name,
                  iconKey: child.iconKey,
                ),
          ],
        ),
  ];
}

class _MappingSelection {
  const _MappingSelection({required this.decision});

  final ImportMappingDecision decision;
}

class _ImportPreviewSection extends StatelessWidget {
  const _ImportPreviewSection({required this.state});

  final ImportPageState state;

  @override
  Widget build(BuildContext context) {
    final review = state.review!;
    final groups = buildImportPreviewGroups(
      review,
      selectedGroupIndexes: state.selectedGroupIndexes,
    );
    final summary = summarizeImportPreview(
      review,
      confirmedExactDuplicateIndexes: state.confirmedExactDuplicateIndexes,
      confirmedSuspectedDuplicateIndexes:
          state.confirmedSuspectedDuplicateIndexes,
      confirmedWarningIndexes: state.confirmedWarningIndexes,
    );
    final hasPreviewDetails =
        groups.isNotEmpty || review.plan.filteredRecords.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImportAnalysisCard(
          title: '导入预览',
          icon: RemixIcons.list_check_3,
          metrics: [
            ImportAnalysisMetric(label: '解析成功', value: summary.parsed),
            ImportAnalysisMetric(label: '待确认', value: summary.pending),
            ImportAnalysisMetric(label: '已跳过', value: summary.skipped),
            ImportAnalysisMetric(label: '无法解析', value: summary.unparsed),
          ],
          description: importPreviewAnalysisDescription(summary),
          onViewAll: state.previewReady && hasPreviewDetails
              ? () => _showAll(context, review)
              : null,
        ),
      ],
    );
  }

  Future<void> _showAll(BuildContext context, ImportPlanReview review) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ImportPreviewPage(review: review)),
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
      if (issue.fileType != null) importFileTypeLabel(issue.fileType!),
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
          AppSpacing.space16,
          AppSpacing.space20,
          AppSpacing.space16,
          AppSpacing.space32,
        ),
        children: [
          if (state.error case final error?) ...[
            AppStatusBanner(
              message: error.message,
              tone: AppStatusBannerTone.danger,
              action: IconButton(
                onPressed: onClearError,
                icon: const Icon(RemixIcons.close_line),
                tooltip: '关闭提示',
              ),
            ),
            const SizedBox(height: AppSpacing.space16),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  '全部记录 ${state.batches.length}',
                  style: context.appTextStyles.groupTitle,
                ),
              ),
              IconButton(
                onPressed: state.historyLoading ? null : onRefresh,
                icon: state.historyLoading
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
            const _EmptyImportHistoryCard()
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
    this.reverting = false,
    this.onRevert,
  });

  final ImportBatch batch;
  final bool reverting;
  final VoidCallback? onRevert;

  @override
  Widget build(BuildContext context) {
    final reverted = batch.status == ImportBatchStatus.reverted;
    final partial = !reverted && batch.skippedGroupCount > 0;
    final statusLabel = reverted
        ? '已撤销'
        : partial
        ? '部分导入'
        : '导入成功';
    final statusTone = reverted
        ? _ImportStatusTone.info
        : partial
        ? _ImportStatusTone.warning
        : _ImportStatusTone.success;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ImportSourceIcon(source: ImportEntrySource.yimu),
                const SizedBox(width: AppSpacing.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatImportTaskName(batch),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTextStyles.listTitle,
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Text(
                        '导入 ${batch.createdTransactionCount} 条交易 · '
                        '${batch.importedGroupCount} 个交易组',
                        style: context.appTextStyles.pageSubtitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.space8),
                _StatusBadge(label: statusLabel, tone: statusTone),
              ],
            ),
            if (batch.skippedGroupCount > 0) ...[
              const SizedBox(height: AppSpacing.space8),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.space48 + AppSpacing.space4,
                ),
                child: Text(
                  '跳过 ${batch.skippedGroupCount} 个交易组',
                  style: context.appTextStyles.pageSubtitle.copyWith(
                    color: _themeExtension(context).warning,
                  ),
                ),
              ),
            ],
            if (batch.revertedAt case final revertedAt?) ...[
              const SizedBox(height: AppSpacing.space4),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.space48 + AppSpacing.space4,
                ),
                child: Text(
                  '撤销于 ${formatImportDateTime(revertedAt)}',
                  style: context.appTextStyles.pageSubtitle,
                ),
              ),
            ],
            if (!reverted && onRevert != null) ...[
              const SizedBox(height: AppSpacing.space12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: reverting ? null : onRevert,
                  icon: reverting
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

enum _ImportStatusTone { success, warning, error, info }

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final _ImportStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space8,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: AppComponentTokens.statusBackgroundOpacity,
        ),
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

Color _toneColor(BuildContext context, _ImportStatusTone tone) {
  final extension = _themeExtension(context);
  return switch (tone) {
    _ImportStatusTone.success => extension.success,
    _ImportStatusTone.warning => extension.warning,
    _ImportStatusTone.error => Theme.of(context).colorScheme.error,
    _ImportStatusTone.info => extension.info,
  };
}
