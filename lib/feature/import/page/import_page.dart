import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/import/import_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/list.dart';
import '../../../design_system/token/progress_indicator.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/transaction/transaction_day_card.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/import_presentation.dart';
import '../view_model/import_view_model.dart';
import '../widget/import_analysis_card.dart';
import '../widget/import_mapping_item.dart';

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
    final review = state.review;
    final summary =
        review == null
            ? const ImportMappingAnalysisSummary(
              mapped: 0,
              pending: 0,
              unmapped: 0,
            )
            : summarizeImportMappings(review);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _ImportHeader(title: '全部账户与分类映射'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.space20),
                children: [
                  ImportAnalysisCard(
                    title: '账户与分类映射',
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
                    state: state,
                    items: review == null ? const [] : review.mappingItems,
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
}

class ImportPreviewPage extends ConsumerWidget {
  const ImportPreviewPage({required this.review, super.key});

  final ImportPlanReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importViewModelProvider);
    final currentReview = state.review ?? review;
    final groups = buildImportPreviewGroups(currentReview);
    final summary = summarizeImportPreview(
      currentReview,
      confirmedSuspectedDuplicateIndexes:
          state.confirmedSuspectedDuplicateIndexes,
      confirmedWarningIndexes: state.confirmedWarningIndexes,
    );
    final confirmations = buildImportPreviewConfirmations(currentReview);
    final blockedGroups = currentReview.groups
        .where((group) => group.isBlocked && !group.isExactDuplicate)
        .toList(growable: false);
    final filteredRecords = currentReview.plan.filteredRecords;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _ImportHeader(title: '全部导入预览'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space20,
                  AppSpacing.space12,
                  AppSpacing.space20,
                  AppSpacing.space24,
                ),
                children: [
                  ImportAnalysisCard(
                    title: '导入预览',
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
                  if (confirmations.isNotEmpty) ...[
                    _ImportPreviewConfirmationSection(
                      items: confirmations,
                      state: state,
                      onChanged:
                          ref
                              .read(importViewModelProvider.notifier)
                              .setGroupSelection,
                    ),
                    const SizedBox(height: AppSpacing.space16),
                  ],
                  if (blockedGroups.isNotEmpty ||
                      filteredRecords.isNotEmpty) ...[
                    _ImportPreviewDetailsSection(
                      blockedGroups: blockedGroups,
                      filteredRecords: filteredRecords,
                    ),
                    const SizedBox(height: AppSpacing.space16),
                  ],
                  for (var index = 0; index < groups.length; index++) ...[
                    TransactionDayCard(
                      group: groups[index],
                      enableRowTap: false,
                      showDailyTotals: false,
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
}

class _ImportPreviewDetailsSection extends StatelessWidget {
  const _ImportPreviewDetailsSection({
    required this.blockedGroups,
    required this.filteredRecords,
  });

  final List<ImportGroupReview> blockedGroups;
  final List<ImportFilteredRecord> filteredRecords;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('解析详情', style: context.appTextStyles.groupTitle),
            if (blockedGroups.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space12),
              Text('无法解析', style: context.appTextStyles.listTitle),
              const SizedBox(height: AppSpacing.space8),
              for (var index = 0; index < blockedGroups.length; index++) ...[
                Text(
                  '${importOperationLabel(blockedGroups[index].group.topLevel.operationKind)}'
                  ' · ${formatImportDateTime(blockedGroups[index].group.topLevel.occurredAt)}',
                  style: context.appTextStyles.listSupporting,
                ),
                const SizedBox(height: AppSpacing.space6),
                for (final issue in blockedGroups[index].issues.where(
                  (issue) => issue.isBlocking,
                ))
                  _IssueLine(issue: issue, color: colors.error),
                if (index < blockedGroups.length - 1)
                  const SizedBox(height: AppSpacing.space8),
              ],
            ],
            if (filteredRecords.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.space12),
              Text('已跳过记录', style: context.appTextStyles.listTitle),
              const SizedBox(height: AppSpacing.space8),
              for (final record in filteredRecords)
                _FilteredRecordLine(record: record),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilteredRecordLine extends StatelessWidget {
  const _FilteredRecordLine({required this.record});

  final ImportFilteredRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final location = [
      importFileTypeLabel(record.fileType),
      if (record.rowNumber != null) '第 ${record.rowNumber} 行',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            RemixIcons.information_line,
            size: AppSpacing.space18,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Text(
              '$location：${record.reason}',
              style: context.appTextStyles.detailValue.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportPreviewConfirmationSection extends StatelessWidget {
  const _ImportPreviewConfirmationSection({
    required this.items,
    required this.state,
    required this.onChanged,
  });

  final List<ImportPreviewConfirmationPresentation> items;
  final ImportPageState state;
  final void Function(int index, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('待确认交易', style: context.appTextStyles.groupTitle),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '疑似重复或带有警告的交易，确认后才会参与导入。',
              style: context.appTextStyles.pageSubtitle,
            ),
            const SizedBox(height: AppSpacing.space8),
            for (var index = 0; index < items.length; index++) ...[
              _ImportPreviewConfirmationTile(
                item: items[index],
                selected: _isSelected(items[index]),
                enabled: !state.isBusy,
                onChanged:
                    (selected) => onChanged(items[index].groupIndex, selected),
              ),
              if (index < items.length - 1)
                const SizedBox(height: AppSpacing.space6),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSelected(ImportPreviewConfirmationPresentation item) {
    return state.selectedGroupIndexes.contains(item.groupIndex);
  }
}

class _ImportPreviewConfirmationTile extends StatelessWidget {
  const _ImportPreviewConfirmationTile({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final ImportPreviewConfirmationPresentation item;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: enabled ? (value) => onChanged(value ?? false) : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(item.title),
      subtitle: Text(item.reason),
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
            _ImportHeader(
              title: '导入中',
              trailing: TextButton(onPressed: _cancel, child: const Text('取消')),
            ),
            Expanded(
              child:
                  widget.source.isAvailable
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
                        onConfirmMappingConfiguration:
                            _confirmMappingConfiguration,
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
    final outcome = await ref
        .read(importViewModelProvider.notifier)
        .pickFiles(append: append);
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _parseFiles() async {
    final outcome =
        await ref.read(importViewModelProvider.notifier).parseSelectedFiles();
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
      builder:
          (context) => _MappingTargetSheet(
            item: item,
            selectedDecision: item.effectiveDecision,
            hasTemporaryOverride:
                state.temporaryMappings.containsKey(key) ||
                state.plannedCreations.containsKey(key),
            restoreLabel: '恢复默认映射',
          ),
    );
    if (!mounted || selection == null) return;
    final notifier = ref.read(importViewModelProvider.notifier);
    final outcome = await notifier.setMappingDecision(key, selection.decision);
    if (!mounted) return;
    _showFailure(outcome);
  }

  Future<void> _viewAllMappings() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ImportMappingPage(onSelectMapping: _selectMapping),
      ),
    );
  }

  void _toggleSaveMappingConfiguration() {
    final outcome =
        ref
            .read(importViewModelProvider.notifier)
            .toggleSaveMappingConfiguration();
    _showFailure(outcome);
  }

  void _confirmMappingConfiguration() {
    final outcome =
        ref
            .read(importViewModelProvider.notifier)
            .confirmMappingConfiguration();
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
            _ImportHeader(
              title: '数据导入',
              trailing: IconButton(
                onPressed: () {},
                icon: const Icon(RemixIcons.question_line),
                tooltip: '导入帮助',
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space20,
                    AppSpacing.space16,
                    AppSpacing.space20,
                    AppSpacing.space32,
                  ),
                  children: [
                    Text('导入来源', style: context.appTextStyles.groupTitle),
                    const SizedBox(height: AppSpacing.space10),
                    _ImportSourceList(
                      onSelected:
                          (source) => context.push(
                            '/import/process/${source.routeValue}',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.space28),
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
                      _FeedbackBanner(
                        icon: RemixIcons.error_warning_line,
                        message: error.message,
                        tone: _FeedbackTone.error,
                        onClose:
                            ref
                                .read(importViewModelProvider.notifier)
                                .clearError,
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
    final outcome =
        await ref.read(importViewModelProvider.notifier).loadHistory();
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
            const _ImportHeader(title: '导入记录'),
            Expanded(
              child: _ImportHistoryTab(
                state: state,
                onRefresh: _loadHistory,
                onRevert: _confirmRevert,
                onClearError:
                    ref.read(importViewModelProvider.notifier).clearError,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final outcome =
        await ref.read(importViewModelProvider.notifier).loadHistory();
    if (!mounted || outcome is ImportActionSuccess<List<ImportBatch>>) return;
    final error = (outcome as ImportActionFailure<List<ImportBatch>>).error;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ImportHeader extends StatelessWidget {
  const _ImportHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

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
                  Navigator.of(context).pop();
                } else {
                  context.go('/profile');
                }
              },
              icon: const Icon(RemixIcons.arrow_left_s_line),
              iconSize: AppSpacing.space32,
              tooltip: '返回',
            ),
          ),
          Text(title, style: context.appTextStyles.dateNavigationTitle),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
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
            _ImportSourceIcon(source: source),
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

class _ImportSourceIcon extends StatelessWidget {
  const _ImportSourceIcon({
    required this.source,
    this.size = AppSpacing.space40,
  });

  final ImportEntrySource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (source == ImportEntrySource.wechat ||
        source == ImportEntrySource.alipay) {
      final asset =
          source == ImportEntrySource.wechat
              ? 'assets/icons/account/wechat_pay.svg'
              : 'assets/icons/account/alipay.svg';
      return SizedBox.square(
        dimension: size,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: SvgPicture.asset(asset),
        ),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final palette = switch (source) {
      ImportEntrySource.yimu => (
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
      ),
      ImportEntrySource.unionPay => (
        background: colors.secondaryContainer,
        foreground: colors.onSecondaryContainer,
      ),
      ImportEntrySource.generic => (
        background: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
      ),
      ImportEntrySource.wechat || ImportEntrySource.alipay => (
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
      ),
    };
    final icon = switch (source) {
      ImportEntrySource.yimu => Icons.energy_savings_leaf_rounded,
      ImportEntrySource.unionPay => RemixIcons.bank_card_line,
      ImportEntrySource.generic => RemixIcons.file_excel_2_line,
      ImportEntrySource.wechat ||
      ImportEntrySource.alipay => RemixIcons.file_list_3_line,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.background,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: palette.foreground),
    );
  }
}

class _EmptyImportHistoryCard extends StatelessWidget {
  const _EmptyImportHistoryCard();

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          children: [
            Icon(
              RemixIcons.history_line,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.space10),
            Text('暂无导入记录', style: context.appTextStyles.groupTitle),
            const SizedBox(height: AppSpacing.space4),
            Text(
              '完成一次导入后，任务记录会显示在这里。',
              textAlign: TextAlign.center,
              style: context.appTextStyles.pageSubtitle,
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(AppSpacing.space20),
      children: [
        const _ImportStepIndicator(activeStep: 0),
        const SizedBox(height: AppSpacing.space24),
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space20),
            child: Column(
              children: [
                _ImportSourceIcon(source: source, size: AppSpacing.space48),
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
    required this.onConfirmMappingConfiguration,
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
  final VoidCallback onConfirmMappingConfiguration;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final review = state.review;
    final files = state.selectedBundle?.files ?? const <ImportFilePayload>[];
    final activeStep =
        state.lastCommit != null
            ? 4
            : review != null
            ? state.mappingConfirmed
                ? 3
                : 2
            : files.isNotEmpty
            ? 1
            : 0;
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
            _ImportStepIndicator(activeStep: activeStep),
            const SizedBox(height: AppSpacing.space24),
            if (state.error case final error?) ...[
              _FeedbackBanner(
                icon: RemixIcons.error_warning_line,
                message: error.message,
                tone: _FeedbackTone.error,
                onClose: onClearError,
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
              const SizedBox(height: AppSpacing.space20),
              if (state.lastCommit case final result?) ...[
                _CommitResultBanner(result: result),
                const SizedBox(height: AppSpacing.space16),
              ],
              _MappingSection(
                state: state,
                onViewAll: onViewAllMappings,
                onToggleSaveMappingConfiguration:
                    onToggleSaveMappingConfiguration,
                onConfirmMappingConfiguration: onConfirmMappingConfiguration,
              ),
              const SizedBox(height: AppSpacing.space24),
              _ImportPreviewSection(state: state),
            ] else if (state.phase == ImportPagePhase.reviewing) ...[
              const SizedBox(height: AppSpacing.space20),
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
                    state.isBusy ||
                            state.selectedGroupIndexes.isEmpty ||
                            !state.mappingConfirmed
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
                  state.phase == ImportPagePhase.committing ? '正在导入' : '导入',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ImportStepIndicator extends StatelessWidget {
  const _ImportStepIndicator({required this.activeStep});

  final int activeStep;

  static const _labels = ['上传文件', '解析数据', '配置映射', '数据预览', '导入完成'];
  static const _icons = [
    RemixIcons.upload_2_line,
    RemixIcons.file_search_line,
    RemixIcons.git_merge_line,
    RemixIcons.list_check_3,
    RemixIcons.checkbox_circle_line,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '导入进度：${_labels[activeStep.clamp(0, 4)]}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nodeWidth = constraints.maxWidth / _labels.length;
          return Stack(
            children: [
              Positioned(
                top: AppSpacing.space14,
                left: nodeWidth / 2,
                right: nodeWidth / 2,
                child: Row(
                  children: [
                    for (var index = 1; index < _labels.length; index++)
                      Expanded(
                        child: Container(
                          height: AppListTokens.dividerThickness * 2,
                          color:
                              index <= activeStep
                                  ? colors.primary
                                  : colors.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < _labels.length; index++)
                    Expanded(
                      child: _ImportStepNode(
                        label: _labels[index],
                        icon: _icons[index],
                        active: index <= activeStep,
                        completed: index < activeStep || activeStep == 4,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ImportStepNode extends StatelessWidget {
  const _ImportStepNode({
    required this.label,
    required this.icon,
    required this.active,
    required this.completed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.space28,
          height: AppSpacing.space28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? colors.primary : colors.surfaceContainerHighest,
          ),
          child: Icon(
            completed ? RemixIcons.check_line : icon,
            size: AppSpacing.space16,
            color: active ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.space8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.appTextStyles.badgeLabel.copyWith(
            color: active ? colors.primary : colors.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;
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
                    _ImportSourceIcon(source: source),
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
                    TextButton(
                      onPressed:
                          controlsDisabled || files.isEmpty
                              ? null
                              : onParseFiles,
                      child: Text(isParsing ? '解析中' : '解析'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space8),
                if (files.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.space16,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          RemixIcons.folder_upload_line,
                          size: AppSpacing.space32,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppSpacing.space8),
                        Text(
                          '选择一木导出的账单、转账和债务 .xls 文件',
                          textAlign: TextAlign.center,
                          style: context.appTextStyles.pageSubtitle,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  for (var index = 0; index < files.length; index++) ...[
                    _ImportFileRow(
                      file: files[index],
                      progress: state.fileProgressAt(index),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.space6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: AppSpacing.space4,
                    children: [
                      TextButton(
                        onPressed:
                            controlsDisabled || files.isEmpty ? null : onReset,
                        child: const Text('清空'),
                      ),
                      TextButton(
                        onPressed: controlsDisabled ? null : onAddFiles,
                        child: const Text('添加文件'),
                      ),
                    ],
                  ),
                ),
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

class _ImportFileRow extends StatelessWidget {
  const _ImportFileRow({required this.file, required this.progress});

  final ImportFilePayload file;
  final ImportFileProgress progress;

  @override
  Widget build(BuildContext context) {
    final color = switch (progress.status) {
      ImportFileProcessingStatus.waiting =>
        Theme.of(context).colorScheme.onSurfaceVariant,
      ImportFileProcessingStatus.parsing =>
        Theme.of(context).colorScheme.primary,
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

class _MappingSection extends StatelessWidget {
  const _MappingSection({
    required this.state,
    required this.onViewAll,
    required this.onToggleSaveMappingConfiguration,
    required this.onConfirmMappingConfiguration,
  });

  final ImportPageState state;
  final VoidCallback onViewAll;
  final VoidCallback onToggleSaveMappingConfiguration;
  final VoidCallback onConfirmMappingConfiguration;

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
        ),
        const SizedBox(height: AppSpacing.space12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    state.isBusy || state.missingMappingCount > 0
                        ? null
                        : onToggleSaveMappingConfiguration,
                icon: Icon(
                  state.saveMappingConfiguration
                      ? RemixIcons.checkbox_circle_fill
                      : RemixIcons.save_line,
                ),
                label: const Text('保存映射配置'),
              ),
            ),
            const SizedBox(width: AppSpacing.space10),
            Expanded(
              child: FilledButton(
                onPressed:
                    state.isBusy || state.missingMappingCount > 0
                        ? null
                        : onConfirmMappingConfiguration,
                child: const Text('确认配置'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MappingList extends StatelessWidget {
  const _MappingList({
    required this.state,
    required this.items,
    required this.onSelectMapping,
  });

  final ImportPageState state;
  final List<ImportMappingReviewItem> items;
  final ValueChanged<ImportMappingReviewItem> onSelectMapping;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppSurface(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space16),
          child: Text('资料包未提取到需要映射的账户或类别。'),
        ),
      );
    }
    return AppSurface(
      child: Column(
        children: [
          const ImportMappingHeader(),
          for (final item in items)
            _MappingItem(
              state: state,
              item: item,
              onSelectMapping: onSelectMapping,
            ),
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
    final target =
        decision is ExistingTargetDecision
            ? review.targets
                .where((candidate) => candidate.id == decision.targetId)
                .firstOrNull
            : null;
    final creation =
        decision is PlannedCreationDecision ? decision.creation : null;
    final targetLabel =
        target?.isArchived == true
            ? '${target!.displayPath}（已归档）'
            : item.targetPath ?? item.targetName ?? '待配置';
    return ImportMappingItem(
      sourceLabel: item.sourceName,
      sourceKindLabel: item.sourceDescription,
      targetLabel: targetLabel,
      action:
          item.action == ImportMappingAction.create || creation != null
              ? ImportMappingItemAction.create
              : item.action == ImportMappingAction.unresolved
              ? ImportMappingItemAction.unresolved
              : ImportMappingItemAction.map,
      targetKindLabel:
          item.targetDescription == targetLabel ? null : item.targetDescription,
      onTap:
          item.existingTargetOptions.isEmpty && item.creationOptions.isEmpty ||
                  state.isBusy
              ? null
              : () => onSelectMapping(item),
    );
  }
}

class _MappingTargetSheet extends StatefulWidget {
  const _MappingTargetSheet({
    required this.item,
    required this.selectedDecision,
    required this.hasTemporaryOverride,
    this.restoreLabel = '恢复默认映射',
  });

  final ImportMappingReviewItem item;
  final ImportMappingDecision selectedDecision;
  final bool hasTemporaryOverride;
  final String restoreLabel;

  @override
  State<_MappingTargetSheet> createState() => _MappingTargetSheetState();
}

class _MappingTargetSheetState extends State<_MappingTargetSheet> {
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
                    widget.item.sourceName,
                    style: context.appTextStyles.subsectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    widget.item.sourceDescription,
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
                  if (widget.hasTemporaryOverride)
                    ListTile(
                      leading: const Icon(RemixIcons.restart_line),
                      title: Text(widget.restoreLabel),
                      onTap:
                          () => Navigator.of(context).pop(
                            const _MappingSelection(
                              decision: UnresolvedDecision('恢复默认映射'),
                            ),
                          ),
                    ),
                  if (widget.item.existingTargetOptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.space16,
                        AppSpacing.space10,
                        AppSpacing.space16,
                        AppSpacing.space4,
                      ),
                      child: Text(
                        '映射到已有目标',
                        style: context.appTextStyles.listSupporting,
                      ),
                    ),
                  for (final target in widget.item.existingTargetOptions)
                    ListTile(
                      leading: Icon(
                        _isExistingTargetSelected(target)
                            ? RemixIcons.checkbox_circle_fill
                            : RemixIcons.checkbox_blank_circle_line,
                      ),
                      title: Text(target.displayPath),
                      subtitle:
                          target.displayPath == target.name
                              ? Text(
                                importTargetDescription(
                                  target.effectiveDescriptor,
                                ),
                              )
                              : Text(
                                '${target.name} · '
                                '${importTargetDescription(target.effectiveDescriptor)}',
                              ),
                      onTap:
                          () => Navigator.of(context).pop(
                            _MappingSelection(
                              decision: ExistingTargetDecision(target.id),
                            ),
                          ),
                    ),
                  if (widget.item.creationOptions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.space16,
                        AppSpacing.space10,
                        AppSpacing.space16,
                        AppSpacing.space4,
                      ),
                      child: Text(
                        '导入时新增',
                        style: context.appTextStyles.listSupporting,
                      ),
                    ),
                  for (final creation in widget.item.creationOptions)
                    ListTile(
                      leading: Icon(
                        _isCreationSelected(creation)
                            ? RemixIcons.checkbox_circle_fill
                            : RemixIcons.checkbox_blank_circle_line,
                      ),
                      title: Text(
                        '新增${importTargetDescription(creation.effectiveDescriptor)}',
                      ),
                      subtitle: Text(
                        [
                          if (creation.pathSegments.isNotEmpty)
                            creation.pathSegments.join(' / ')
                          else
                            creation.name,
                          if (creation.defaultParametersHint case final hint?)
                            hint,
                        ].join(' · '),
                      ),
                      onTap:
                          () => Navigator.of(context).pop(
                            _MappingSelection(
                              decision: PlannedCreationDecision(creation),
                            ),
                          ),
                    ),
                  if (widget.item.existingTargetOptions.isEmpty &&
                      widget.item.creationOptions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.space20),
                      child: Text(
                        '暂无角色兼容的可用目标。',
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

  bool _isExistingTargetSelected(ImportMappingTarget target) {
    final decision = widget.selectedDecision;
    return decision is ExistingTargetDecision && decision.targetId == target.id;
  }

  bool _isCreationSelected(ImportMappingCreation creation) {
    final decision = widget.selectedDecision;
    return decision is PlannedCreationDecision &&
        decision.creation.name == creation.name &&
        decision.creation.effectiveDescriptor == creation.effectiveDescriptor &&
        decision.creation.pathSegments.join('/') ==
            creation.pathSegments.join('/');
  }
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
    final groups = buildImportPreviewGroups(review);
    final summary = summarizeImportPreview(
      review,
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
          onViewAll: hasPreviewDetails ? () => _showAll(context, review) : null,
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
                child: Text(
                  '全部记录 ${state.batches.length}',
                  style: context.appTextStyles.groupTitle,
                ),
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
    final statusLabel =
        reverted
            ? '已撤销'
            : partial
            ? '部分导入'
            : '导入成功';
    final statusTone =
        reverted
            ? _FeedbackTone.info
            : partial
            ? _FeedbackTone.warning
            : _FeedbackTone.success;
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ImportSourceIcon(source: ImportEntrySource.yimu),
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
