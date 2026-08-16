import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_settings_store.dart';
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
import '../widget/home_transaction_filter_sheet.dart';
import '../../../widget/business/finance/cashflow_summary_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final content = ref.watch(homeContentProvider(state.visibleMonth));
    final settings =
        ref.watch(appSettingsViewModelProvider).value ?? const AppSettings();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
          settings.showAddTransactionFab
              ? FloatingActionButton(
                onPressed: _openNewTransaction,
                tooltip: '新建记账',
                shape: const CircleBorder(),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                child: const Icon(RemixIcons.add_line),
              )
              : null,
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
  final VoidCallback onLoadMore;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return TransactionFeedScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        0,
      ),
      bottomPadding: AppSpacing.space24 + (reserveFabSpace ? 56 : 0), // 留给 FAB
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
      groups: groups,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
      onLoadMore: onLoadMore,
      emptyMessage: filterActive ? '没有符合筛选条件的交易' : '本月暂无交易记录',
    );
  }
}
