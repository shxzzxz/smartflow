import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import 'package:smartflow/widget/business/transaction/transaction_feed.dart';
import 'package:smartflow/feature/shared/presentation/cashflow_period_metric_options.dart';
import 'package:smartflow/feature/shared/presentation/pull_to_create_sensitivity_options.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../view_model/home_view_model.dart';
import '../widget/home_pull_to_create.dart';
import '../widget/home_batch_action_bar.dart';
import '../widget/home_transaction_filter_sheet.dart';
import '../../../widget/business/finance/cashflow_summary_card.dart';
import '../../../widget/business/tag/tag_multi_select_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _batchMode = false;
  bool _batchSubmitting = false;
  Set<String> _selectedTransactionIds = {};
  HomeBatchMode? _batchModeNotifier;

  @override
  void dispose() {
    _batchModeNotifier?.exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final content = ref.watch(homeContentProvider(state.visibleMonth));
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();
    final visibleTransactionIds = _contentTransactionIds(content);
    final selectedVisibleCount =
        _selectedTransactionIds.intersection(visibleTransactionIds).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_batchMode)
              AppPageHeader(title: '批量操作', onBack: _exitBatchMode)
            else
              AppPageHeader.custom(
                titleContent: AppMonthSelector(
                  visibleMonth: state.visibleMonth,
                  onPreviousMonth: () => _shiftMonth(-1),
                  onMonthPressed: _pickMonth,
                  onNextMonth: () => _shiftMonth(1),
                ),
                actions: [
                  _HomeFilterButton(filter: state.transactionFilter),
                  _HomeSettingsMenu(
                    showAddTransactionFab: settings.showAddTransactionFab,
                    pullToCreateSensitivity: settings.pullToCreateSensitivity,
                    cashflowPeriodMetric: settings.cashflowPeriodMetric,
                  ),
                ],
              ),
            Expanded(
              child: HomePullToCreate(
                onTrigger: _openNewTransaction,
                triggerExtent: settings.pullToCreateSensitivity.triggerExtent,
                enabled: !_batchMode,
                child: switch (content) {
                  HomeContentLoaded(
                    :final summary,
                    :final groups,
                    :final hasMore,
                    :final isLoadingMore,
                    :final loadMoreErrorMessage,
                    :final hasPendingRefresh,
                    :final isRefreshing,
                    :final refreshErrorMessage,
                  ) =>
                    _HomeContent(
                      visibleMonth: state.visibleMonth,
                      summary: summary,
                      groups: groups,
                      reserveFabSpace: settings.showAddTransactionFab,
                      hasMore: hasMore,
                      isLoadingMore: isLoadingMore,
                      loadMoreErrorMessage: loadMoreErrorMessage,
                      hasPendingRefresh: hasPendingRefresh,
                      isRefreshing: isRefreshing,
                      refreshErrorMessage: refreshErrorMessage,
                      filterActive: state.transactionFilter.isActive,
                      batchMode: _batchMode,
                      selectedTransactionIds: _selectedTransactionIds,
                      onTransactionTap: _handleTransactionTap,
                      onTransactionLongPress: _handleTransactionLongPress,
                      onSelectionChanged: _handleSelectionChanged,
                      onLoadMore:
                          () =>
                              ref
                                  .read(
                                    homeTransactionFeedViewModelProvider(
                                      state.visibleMonth,
                                    ).notifier,
                                  )
                                  .loadMore(),
                      onRefresh:
                          () =>
                              ref
                                  .read(
                                    homeTransactionFeedViewModelProvider(
                                      state.visibleMonth,
                                    ).notifier,
                                  )
                                  .refresh(),
                    ),
                  HomeContentError(:final message) => Center(
                    child: Text(message),
                  ),
                  HomeContentLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          !_batchMode && settings.showAddTransactionFab
              ? FloatingActionButton(
                onPressed: _openNewTransaction,
                tooltip: '新建记账',
                shape: const CircleBorder(),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                child: const Icon(RemixIcons.add_line),
              )
              : null,
      bottomNavigationBar:
          _batchMode
              ? HomeBatchActionBar(
                selectedCount: selectedVisibleCount,
                totalCount: visibleTransactionIds.length,
                enabled: !_batchSubmitting,
                onSelectAll: () => _selectAll(visibleTransactionIds),
                onClearAll: () => _clearAll(visibleTransactionIds),
                onDelete: _deleteSelectedTransactions,
                onManageTags: _manageSelectedTags,
              )
              : null,
    );
  }

  void _handleTransactionTap(String transactionId) {
    if (_batchMode) {
      _toggleSelection(transactionId);
      return;
    }
    context.push('/transaction/$transactionId');
  }

  void _handleTransactionLongPress(String transactionId) {
    if (_batchSubmitting) return;
    if (_batchMode) return;
    setState(() {
      _batchMode = true;
      _selectedTransactionIds = {transactionId};
    });
    final batchModeNotifier = ref.read(homeBatchModeProvider.notifier);
    _batchModeNotifier = batchModeNotifier;
    batchModeNotifier.enter();
  }

  void _handleSelectionChanged(String transactionId, bool selected) {
    if (!_batchMode || _batchSubmitting) return;
    setState(() {
      final next = Set<String>.of(_selectedTransactionIds);
      if (selected) {
        next.add(transactionId);
      } else {
        next.remove(transactionId);
      }
      _selectedTransactionIds = next;
    });
  }

  void _toggleSelection(String transactionId) {
    _handleSelectionChanged(
      transactionId,
      !_selectedTransactionIds.contains(transactionId),
    );
  }

  void _selectAll(Set<String> transactionIds) {
    if (!_batchMode || _batchSubmitting) return;
    setState(() {
      _selectedTransactionIds = Set<String>.of(transactionIds);
    });
  }

  void _clearAll(Set<String> transactionIds) {
    if (!_batchMode || _batchSubmitting) return;
    setState(() {
      final next = Set<String>.of(_selectedTransactionIds)
        ..removeAll(transactionIds);
      _selectedTransactionIds = next;
    });
  }

  void _exitBatchMode() {
    if (_batchSubmitting) return;
    setState(() {
      _batchMode = false;
      _selectedTransactionIds = {};
    });
    ref.read(homeBatchModeProvider.notifier).exit();
  }

  Future<void> _deleteSelectedTransactions() async {
    final ids = Set<String>.of(_selectedTransactionIds);
    if (ids.isEmpty || _batchSubmitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除交易'),
            content: Text('确定删除选中的 ${ids.length} 笔交易？删除后交易及其账务记录将无法恢复。'),
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
    if (confirmed != true || !mounted) return;

    setState(() => _batchSubmitting = true);
    try {
      final result = await ref
          .read(homeViewModelProvider.notifier)
          .deleteTransactions(ids);
      if (!mounted) return;
      setState(() {
        _batchSubmitting = false;
        _batchMode = false;
        _selectedTransactionIds = {};
      });
      ref.read(homeBatchModeProvider.notifier).exit();
      _showBatchResult(
        result.deletedGroupCount,
        result.skippedGroupCount,
        successLabel: '已删除',
        skippedLabel: '笔交易因存在业务归属未删除',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _batchSubmitting = false);
      _showMessage('批量删除失败，请稍后重试');
    }
  }

  Future<void> _manageSelectedTags() async {
    final ids = Set<String>.of(_selectedTransactionIds);
    if (ids.isEmpty || _batchSubmitting) return;

    List<TagView> tags;
    try {
      tags = await ref.read(tagApplicationServiceProvider).listTags();
    } catch (_) {
      if (mounted) _showMessage('标签加载失败，请稍后重试');
      return;
    }
    if (!mounted) return;

    final action = await showModalBottomSheet<_BatchTagAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _BatchTagActionSheet(),
    );
    if (action == null || !mounted) return;

    if (action == _BatchTagAction.clear) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('清空标签'),
              content: Text('确定清空选中的 ${ids.length} 笔交易的全部标签？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
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
      allowCreate: action == _BatchTagAction.add,
    );
    if (result == null || !mounted || result.selectedTagIds.isEmpty) return;
    await _runTagBatch(
      ids: ids,
      operation:
          action == _BatchTagAction.add
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
    setState(() => _batchSubmitting = true);
    try {
      final result = await ref
          .read(homeViewModelProvider.notifier)
          .updateTags(ids: ids, operation: operation, tagIds: tagIds);
      if (!mounted) return;
      setState(() => _batchSubmitting = false);
      _showBatchResult(
        result.updatedGroupCount,
        result.skippedGroupCount,
        successLabel: switch (operation) {
          TransactionTagBatchOperation.add => '已新增标签到',
          TransactionTagBatchOperation.remove => '已删除标签于',
          TransactionTagBatchOperation.clear => '已清空标签于',
        },
        skippedLabel: '笔交易不支持标签操作',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _batchSubmitting = false);
      _showMessage('批量标签操作失败，请稍后重试');
    }
  }

  void _showBatchResult(
    int affectedCount,
    int skippedCount, {
    required String successLabel,
    required String skippedLabel,
  }) {
    final message =
        skippedCount == 0
            ? '$successLabel $affectedCount 笔交易'
            : '$successLabel $affectedCount 笔交易，跳过 $skippedCount $skippedLabel';
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openNewTransaction() {
    context.push('/transaction/new');
  }

  Future<void> _pickMonth() async {
    final selected = await showAppMonthPicker(
      context: context,
      initialMonth: ref.read(homeViewModelProvider).visibleMonth,
    );
    if (!mounted || selected == null) {
      return;
    }
    ref.read(homeViewModelProvider.notifier).pickMonth(selected);
  }

  void _shiftMonth(int delta) {
    ref.read(homeViewModelProvider.notifier).shiftMonth(delta);
  }
}

class _HomeFilterButton extends ConsumerWidget {
  const _HomeFilterButton({required this.filter});

  final HomeTransactionFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(homeFilterOptionsProvider);
    final loadedOptions = options is HomeFilterOptionsLoaded ? options : null;
    return IconButton(
      tooltip: filter.isActive ? '交易筛选（已启用）' : '交易筛选',
      onPressed:
          loadedOptions != null
              ? () async {
                final selected = await showHomeTransactionFilterSheet(
                  context: context,
                  initialFilter: filter,
                  expenseTree: loadedOptions.expenseTree,
                  incomeTree: loadedOptions.incomeTree,
                  accounts: loadedOptions.accounts,
                );
                if (selected == null || !context.mounted) return;
                ref
                    .read(homeViewModelProvider.notifier)
                    .applyTransactionFilter(
                      categoryAccountIds: selected.categoryAccountIds,
                      settlementAccountIds: selected.settlementAccountIds,
                      tagIds: selected.tagIds,
                      untaggedOnly: selected.untaggedOnly,
                    );
              }
              : null,
      icon: Badge(
        isLabelVisible: filter.isActive,
        smallSize: AppSpacing.space8,
        child: const Icon(RemixIcons.filter_line),
      ),
    );
  }
}

class _HomeSettingsMenu extends ConsumerWidget {
  const _HomeSettingsMenu({
    required this.showAddTransactionFab,
    required this.pullToCreateSensitivity,
    required this.cashflowPeriodMetric,
  });

  final bool showAddTransactionFab;
  final PullToCreateSensitivity pullToCreateSensitivity;
  final CashflowPeriodMetric cashflowPeriodMetric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appSettingsViewModelProvider.notifier);
    return AppPopupMenuButton(
      tooltip: '页面设置',
      icon: RemixIcons.settings_3_line,
      items: [
        AppPopupMenuToggle(
          label: '悬浮按钮',
          value: showAddTransactionFab,
          onChanged: notifier.setShowAddTransactionFab,
        ),
        AppPopupMenuSelect<PullToCreateSensitivity>(
          label: '下拉灵敏度',
          value: pullToCreateSensitivity,
          options: pullToCreateSensitivityOptions,
          onChanged: notifier.setPullToCreateSensitivity,
        ),
        AppPopupMenuSelect<CashflowPeriodMetric>(
          label: '收支指标',
          value: cashflowPeriodMetric,
          options: cashflowPeriodMetricOptions,
          onChanged: notifier.setCashflowPeriodMetric,
        ),
      ],
    );
  }
}

enum _BatchTagAction { add, remove, clear }

class _BatchTagActionSheet extends StatelessWidget {
  const _BatchTagActionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.space16,
              0,
              AppSpacing.space16,
              AppSpacing.space8,
            ),
            child: Text('标签管理', style: context.appTextStyles.subsectionTitle),
          ),
          ListTile(
            leading: const Icon(RemixIcons.add_line),
            title: const Text('新增标签'),
            onTap: () => Navigator.of(context).pop(_BatchTagAction.add),
          ),
          ListTile(
            leading: const Icon(RemixIcons.subtract_line),
            title: const Text('删除标签'),
            onTap: () => Navigator.of(context).pop(_BatchTagAction.remove),
          ),
          ListTile(
            leading: const Icon(RemixIcons.delete_bin_line),
            title: const Text('清空标签'),
            onTap: () => Navigator.of(context).pop(_BatchTagAction.clear),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.visibleMonth,
    required this.summary,
    required this.groups,
    required this.reserveFabSpace,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreErrorMessage,
    required this.hasPendingRefresh,
    required this.isRefreshing,
    required this.refreshErrorMessage,
    required this.filterActive,
    required this.batchMode,
    required this.selectedTransactionIds,
    required this.onTransactionTap,
    required this.onTransactionLongPress,
    required this.onSelectionChanged,
    required this.onLoadMore,
    required this.onRefresh,
  });

  final DateTime visibleMonth;
  final CashflowSummaryPresentation summary;
  final List<TransactionDayGroup> groups;
  final bool reserveFabSpace;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final bool hasPendingRefresh;
  final bool isRefreshing;
  final String? refreshErrorMessage;
  final bool filterActive;
  final bool batchMode;
  final Set<String> selectedTransactionIds;
  final ValueChanged<String> onTransactionTap;
  final ValueChanged<String> onTransactionLongPress;
  final void Function(String transactionId, bool selected) onSelectionChanged;
  final VoidCallback onLoadMore;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final selectedGroups = [
      for (final group in groups)
        group.copyWith(
          rows: [
            for (final row in group.rows)
              row.copyWith(
                selectable: batchMode,
                selected: selectedTransactionIds.contains(row.transactionId),
                dimmed:
                    batchMode &&
                    !selectedTransactionIds.contains(row.transactionId),
              ),
          ],
        ),
    ];
    return TransactionFeedScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        0,
      ),
      bottomPadding:
          AppSpacing.space24 +
          (reserveFabSpace ? 56 : 0) +
          (batchMode ? 56 : 0), // 留给 FAB 或批量操作栏
      leading: [
        CashflowSummaryCard(
          summary: summary,
          metricActions: {
            CashflowSummaryMetricKind.budget:
                () => context.push(
                  Uri(
                    path: '/budget',
                    queryParameters: {
                      'month':
                          '${visibleMonth.year}-'
                          '${visibleMonth.month.toString().padLeft(2, '0')}',
                    },
                  ).toString(),
                ),
          },
        ),
        if (hasPendingRefresh || isRefreshing) ...[
          const SizedBox(height: AppSpacing.space12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: isRefreshing ? null : onRefresh,
              icon:
                  isRefreshing
                      ? const SizedBox(
                        width: AppSpacing.space16,
                        height: AppSpacing.space16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(RemixIcons.refresh_line),
              label: Text(
                refreshErrorMessage ?? (isRefreshing ? '正在刷新交易' : '交易有更新，点击刷新'),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.space20),
      ],
      groups: selectedGroups,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
      onLoadMore: onLoadMore,
      onRowTap: onTransactionTap,
      onRowLongPress: onTransactionLongPress,
      onRowSelectionChanged: onSelectionChanged,
      enableRowQuickEdit: !batchMode,
      emptyMessage: filterActive ? '没有符合筛选条件的交易' : '本月暂无交易记录',
    );
  }
}

Set<String> _contentTransactionIds(HomeContentState content) {
  return switch (content) {
    HomeContentLoaded(:final groups) => {
      for (final group in groups)
        for (final row in group.rows) row.transactionId,
    },
    _ => const <String>{},
  };
}
