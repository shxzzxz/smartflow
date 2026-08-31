import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/motion.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final content = ref.watch(homeContentProvider(state.visibleMonth));
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();
    final visibleTransactionIds = _contentTransactionIds(content);
    final visibleCount = visibleTransactionIds.length;
    final selectedVisibleCount =
        _selectedTransactionIds.intersection(visibleTransactionIds).length;
    final allVisibleTransactionsSelected =
        visibleTransactionIds.isNotEmpty &&
        selectedVisibleCount == visibleCount;
    final hasMore = content is HomeContentLoaded && content.hasMore;

    return PopScope(
      canPop: !_batchMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitBatchMode();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: AppMotion.durationFast,
                child:
                    _batchMode
                        ? AppPageHeader(
                          key: const ValueKey('home-batch-header'),
                          title:
                              selectedVisibleCount > 0
                                  ? '已选 $selectedVisibleCount 笔'
                                  : '选择交易',
                          subtitle: hasMore ? '已加载 $visibleCount 笔' : null,
                          onBack: _exitBatchMode,
                          actions: [
                            AppHeaderIconButton(
                              icon:
                                  allVisibleTransactionsSelected
                                      ? RemixIcons.checkbox_circle_fill
                                      : RemixIcons.checkbox_circle_line,
                              tooltip:
                                  allVisibleTransactionsSelected
                                      ? '取消全选'
                                      : '全选已加载',
                              onPressed:
                                  !_batchSubmitting &&
                                          visibleTransactionIds.isNotEmpty
                                      ? () =>
                                          _toggleSelectAll(visibleTransactionIds)
                                      : null,
                            ),
                          ],
                        )
                        : AppPageHeader.custom(
                          key: const ValueKey('home-header'),
                          titleContent: AppMonthSelector(
                            visibleMonth: state.visibleMonth,
                            onPreviousMonth: () => _shiftMonth(-1),
                            onMonthPressed: _pickMonth,
                            onNextMonth: () => _shiftMonth(1),
                          ),
                          actions: [
                            _HomeFilterButton(filter: state.transactionFilter),
                            _HomeSettingsMenu(
                              showAddTransactionFab:
                                  settings.showAddTransactionFab,
                              pullToCreateSensitivity:
                                  settings.pullToCreateSensitivity,
                              cashflowPeriodMetric:
                                  settings.cashflowPeriodMetric,
                            ),
                          ],
                        ),
              ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _batchSubmitting,
                  child: HomePullToCreate(
                    onTrigger: _openNewTransaction,
                    triggerExtent:
                        settings.pullToCreateSensitivity.triggerExtent,
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
                          reserveFabSpace:
                              settings.showAddTransactionFab && !_batchMode,
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
                          onSelectionChanged:
                              _batchSubmitting ? null : _handleSelectionChanged,
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
                  enabled: !_batchSubmitting,
                  processing: _batchSubmitting,
                  onDelete:
                      () => _deleteSelectedTransactions(visibleTransactionIds),
                  onManageTags:
                      () => _manageSelectedTags(visibleTransactionIds),
                )
                : null,
      ),
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

  void _toggleSelectAll(Set<String> transactionIds) {
    if (!_batchMode || _batchSubmitting) return;
    final selectedVisibleIds = _selectedTransactionIds.intersection(
      transactionIds,
    );
    final allSelected =
        transactionIds.isNotEmpty &&
        selectedVisibleIds.length == transactionIds.length;
    final next = Set<String>.of(_selectedTransactionIds);
    if (allSelected) {
      next.removeAll(transactionIds);
    } else {
      next.addAll(transactionIds);
    }
    setState(() {
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

  Future<void> _deleteSelectedTransactions(
    Set<String> visibleTransactionIds,
  ) async {
    final ids = Set<String>.of(
      _selectedTransactionIds.intersection(visibleTransactionIds),
    );
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
                style: _destructiveConfirmStyle(context),
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
      final shouldExit = result.skippedGroupCount == 0;
      setState(() {
        _batchSubmitting = false;
        if (shouldExit) {
          _batchMode = false;
          _selectedTransactionIds = {};
        } else {
          // 删除成功的交易会从列表中消失，保留快照可以让被跳过的交易继续处于选择态。
          _selectedTransactionIds = ids;
        }
      });
      if (shouldExit) {
        ref.read(homeBatchModeProvider.notifier).exit();
      }
      _showBatchResult(
        result.skippedGroupCount,
        successMessage: '已删除 ${result.deletedGroupCount} 笔交易',
        skippedMessage: '笔交易因存在业务关联未处理',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _batchSubmitting = false);
      _showMessage('批量删除失败，请稍后重试');
    }
  }

  Future<void> _manageSelectedTags(Set<String> visibleTransactionIds) async {
    final ids = Set<String>.of(
      _selectedTransactionIds.intersection(visibleTransactionIds),
    );
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _batchSubmitting = false);
      _showMessage('批量标签操作失败，请稍后重试');
    }
  }

  void _showBatchResult(
    int skippedCount, {
    required String successMessage,
    required String skippedMessage,
  }) {
    final message =
        skippedCount == 0
            ? successMessage
            : '$successMessage，跳过 $skippedCount $skippedMessage';
    _showMessage(
      message,
      duration:
          skippedCount == 0
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
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          // SnackBar 由根 Scaffold 承载，批量模式下根 Scaffold 没有底部栏，
          // 需要自行让开挂在本页 Scaffold 上的批量操作栏。
          margin:
              _batchMode
                  ? const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space4,
                    AppSpacing.space16,
                    AppComponentTokens.navigationBarHeight + AppSpacing.space10,
                  )
                  : null,
        ),
      );
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

  /// 传 null 表示当前不接受选中变更（批量提交中），复选框会渲染为禁用态。
  final void Function(String transactionId, bool selected)? onSelectionChanged;
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
                dimmed: batchMode ? false : row.dimmed,
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
      // 批量操作栏由 Scaffold 的底部槽位占位，不需要额外让位。
      bottomPadding: AppSpacing.space24 + (reserveFabSpace ? 56 : 0),
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

ButtonStyle _destructiveConfirmStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: colors.error,
    foregroundColor: colors.onError,
  );
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
