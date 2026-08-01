import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_popup_menu_button.dart';
import 'package:smartflow/widget/business/transaction/transaction_feed.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../../shared/view_model/app_settings_view_model.dart';
import '../view_model/home_view_model.dart';
import '../widget/home_header.dart';
import '../widget/home_pull_to_create.dart';
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
            HomeHeader(
              visibleMonth: state.visibleMonth,
              onMonthPressed: _pickMonth,
              onPreviousMonth: () => _shiftMonth(-1),
              onNextMonth: () => _shiftMonth(1),
              trailing: _HomeSettingsMenu(
                showAddTransactionFab: settings.showAddTransactionFab,
              ),
            ),
            Expanded(
              child: HomePullToCreate(
                onTrigger: _openNewTransaction,
                child: switch (content) {
                  HomeContentLoaded(:final summary, :final groups) =>
                    _HomeContent(
                      summary: summary,
                      groups: groups,
                      reserveFabSpace: settings.showAddTransactionFab,
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

class _HomeSettingsMenu extends ConsumerWidget {
  const _HomeSettingsMenu({required this.showAddTransactionFab});

  final bool showAddTransactionFab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPopupMenuButton<bool>(
      tooltip: '页面设置',
      icon: RemixIcons.settings_3_line,
      selected: showAddTransactionFab ? true : null,
      onSelected:
          (_) => ref
              .read(appSettingsViewModelProvider.notifier)
              .setShowAddTransactionFab(!showAddTransactionFab),
      options: const [
        AppPopupMenuOption(
          value: true,
          label: '显示记账悬浮按钮',
          icon: RemixIcons.add_circle_line,
        ),
      ],
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.summary,
    required this.groups,
    required this.reserveFabSpace,
  });

  final CashflowSummaryPresentation summary;
  final List<TransactionDayGroup> groups;
  final bool reserveFabSpace;

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
        CashflowSummaryCard(summary: summary),
        const SizedBox(height: AppSpacing.space20),
      ],
      groups: groups,
      emptyMessage: '本月暂无交易记录',
    );
  }
}
