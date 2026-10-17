import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/token/motion.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../widget/business/tag/tag_multi_select_sheet.dart';
import '../../../widget/business/transaction/transaction_batch_action_bar.dart';
import '../../../widget/business/transaction/transaction_batch_tag_action_sheet.dart';
import '../../../widget/business/transaction/transaction_feed.dart';
import '../view_model/filtered_transactions_view_model.dart';

final _logger = Logger('feature.transaction');

class FilteredTransactionsPage extends ConsumerStatefulWidget {
  const FilteredTransactionsPage({
    required this.target,
    required this.targetId,
    super.key,
  });

  final FilteredTransactionTarget target;
  final String targetId;

  @override
  ConsumerState<FilteredTransactionsPage> createState() =>
      _FilteredTransactionsPageState();
}

class _FilteredTransactionsPageState
    extends ConsumerState<FilteredTransactionsPage> {
  FilteredTransactionsViewModel get _viewModel => ref.read(
    filteredTransactionsViewModelProvider(
      widget.target,
      widget.targetId,
    ).notifier,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      filteredTransactionsViewModelProvider(widget.target, widget.targetId),
    );
    final loaded = state is FilteredTransactionsLoaded ? state : null;
    final batch = loaded?.batch ?? const FilteredTransactionBatchState();
    final visibleIds = loaded?.visibleTransactionIds ?? const <String>{};
    final selectedIds = loaded?.selectedVisibleIds ?? const <String>{};
    final allSelected =
        visibleIds.isNotEmpty && selectedIds.length == visibleIds.length;

    return PopScope(
      canPop: !batch.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _viewModel.exitBatchMode();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: AppMotion.durationFast,
                child: batch.active
                    ? AppPageHeader(
                        key: const ValueKey('filtered-batch-header'),
                        title: selectedIds.isEmpty
                            ? '选择交易'
                            : '已选 ${selectedIds.length} 笔',
                        subtitle: loaded?.hasMore == true
                            ? '已加载 ${visibleIds.length} 笔'
                            : null,
                        onBack: () => _viewModel.exitBatchMode(),
                        actions: [
                          AppHeaderIconButton(
                            icon: allSelected
                                ? RemixIcons.checkbox_circle_fill
                                : RemixIcons.checkbox_circle_line,
                            tooltip: allSelected ? '取消全选' : '全选已加载',
                            onPressed:
                                !batch.submitting && visibleIds.isNotEmpty
                                ? () => _viewModel.toggleSelectAll()
                                : null,
                          ),
                        ],
                      )
                    : AppPageHeader(
                        key: const ValueKey('filtered-header'),
                        title: loaded?.title ?? '交易流水',
                        subtitle: loaded?.subtitle,
                      ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: batch.submitting,
                  child: switch (state) {
                    FilteredTransactionsLoaded(
                      :final groups,
                      :final emptyMessage,
                      :final hasMore,
                      :final isLoadingMore,
                      :final loadMoreErrorMessage,
                    ) =>
                      TransactionFeedScrollView(
                        groups: [
                          for (final group in groups)
                            group.copyWith(
                              rows: [
                                for (final row in group.rows)
                                  row.copyWith(
                                    selectable: batch.active,
                                    selected: selectedIds.contains(
                                      row.transactionId,
                                    ),
                                    dimmed: batch.active ? false : row.dimmed,
                                  ),
                              ],
                            ),
                        ],
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.space16,
                          AppSpacing.space8,
                          AppSpacing.space16,
                          AppSpacing.space24,
                        ),
                        showDailyTotals: false,
                        emptyMessage: emptyMessage,
                        hasMore: hasMore,
                        isLoadingMore: isLoadingMore,
                        loadMoreErrorMessage: loadMoreErrorMessage,
                        onLoadMore: () => _viewModel.loadMore(),
                        onRowTap: (id) {
                          if (batch.active) {
                            _viewModel.setTransactionSelected(
                              id,
                              !selectedIds.contains(id),
                            );
                          } else {
                            context.push('/transaction/$id');
                          }
                        },
                        onRowLongPress:
                            widget.target == FilteredTransactionTarget.category
                            ? (id) => _viewModel.enterBatchMode(id)
                            : null,
                        onRowSelectionChanged: batch.submitting
                            ? null
                            : (id, selected) => _viewModel
                                  .setTransactionSelected(id, selected),
                        enableRowQuickEdit: !batch.active,
                      ),
                    FilteredTransactionsError(:final message) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space24),
                        child: Text(message),
                      ),
                    ),
                    FilteredTransactionsLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: batch.active
            ? TransactionBatchActionBar(
                selectedCount: selectedIds.length,
                enabled: !batch.submitting,
                processing: batch.submitting,
                onDelete: () => _deleteSelectedTransactions(selectedIds),
                onManageTags: () => _manageSelectedTags(selectedIds),
              )
            : null,
      ),
    );
  }

  Future<void> _deleteSelectedTransactions(Set<String> selectedIds) async {
    final ids = Set<String>.of(selectedIds);
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除交易'),
        content: Text('确定删除选中的 ${ids.length} 笔交易？删除后交易及其账务记录将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: _destructiveConfirmStyle(context),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final result = await _viewModel.deleteTransactions(ids);
      if (!mounted) return;
      _showBatchResult(
        result.skippedGroupCount,
        successMessage: '已删除 ${result.deletedGroupCount} 笔交易',
        skippedMessage: '笔交易因存在业务关联未处理',
      );
    } catch (error, stackTrace) {
      _logger.severe(
        'Filtered transaction batch delete failed.',
        error,
        stackTrace,
      );
      if (!mounted) return;
      _showMessage('批量删除失败，请稍后重试');
    }
  }

  Future<void> _manageSelectedTags(Set<String> selectedIds) async {
    final ids = Set<String>.of(selectedIds);
    if (ids.isEmpty) return;

    List<TagView> tags;
    try {
      tags = await _viewModel.loadTags();
    } catch (error, stackTrace) {
      _logger.severe(
        'Filtered transaction tag list load failed.',
        error,
        stackTrace,
      );
      if (mounted) _showMessage('标签加载失败，请稍后重试');
      return;
    }
    if (!mounted) return;

    final action = await showModalBottomSheet<TransactionTagBatchOperation>(
      context: context,
      showDragHandle: true,
      builder: (context) => const TransactionBatchTagActionSheet(),
    );
    if (action == null || !mounted) return;

    if (action == TransactionTagBatchOperation.clear) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('清空标签'),
          content: Text('确定清空选中的 ${ids.length} 笔交易的全部标签？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: _destructiveConfirmStyle(context),
              child: const Text('清空'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _runTagBatch(
        ids: ids,
        operation: TransactionTagBatchOperation.clear,
        tagIds: const {},
      );
      return;
    }

    final result = await showTagMultiSelectSheet(
      context: context,
      tags: tags,
      selectedIds: const {},
      allowCreate: action == TransactionTagBatchOperation.add,
    );
    if (result == null || !mounted || result.selectedTagIds.isEmpty) return;
    await _runTagBatch(
      ids: ids,
      operation: action == TransactionTagBatchOperation.add
          ? TransactionTagBatchOperation.add
          : TransactionTagBatchOperation.remove,
      tagIds: result.selectedTagIds,
    );
  }

  Future<void> _runTagBatch({
    required Set<String> ids,
    required TransactionTagBatchOperation operation,
    required Set<String> tagIds,
  }) async {
    try {
      final result = await _viewModel.updateTags(
        ids: ids,
        operation: operation,
        tagIds: tagIds,
      );
      if (!mounted) return;
      final successMessage = switch (operation) {
        TransactionTagBatchOperation.add =>
          '已为 ${result.updatedGroupCount} 笔交易添加标签',
        TransactionTagBatchOperation.remove =>
          '已从 ${result.updatedGroupCount} 笔交易移除标签',
        TransactionTagBatchOperation.clear =>
          '已清空 ${result.updatedGroupCount} 笔交易的标签',
      };
      _showBatchResult(
        result.skippedGroupCount,
        successMessage: successMessage,
        skippedMessage: '笔交易不支持标签操作',
      );
    } catch (error, stackTrace) {
      _logger.severe(
        'Filtered transaction tag batch update failed.',
        error,
        stackTrace,
      );
      if (!mounted) return;
      _showMessage('批量标签操作失败，请稍后重试');
    }
  }

  void _showBatchResult(
    int skippedCount, {
    required String successMessage,
    required String skippedMessage,
  }) {
    final message = skippedCount == 0
        ? successMessage
        : '$successMessage，跳过 $skippedCount $skippedMessage';
    _showMessage(
      message,
      duration: skippedCount == 0
          ? const Duration(seconds: 3)
          : const Duration(seconds: 6),
    );
  }

  void _showMessage(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: duration));
  }
}

ButtonStyle _destructiveConfirmStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: colors.error,
    foregroundColor: colors.onError,
  );
}
