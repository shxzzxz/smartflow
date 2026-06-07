import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import 'package:smartflow/widget/business/transaction/empty_transaction_card.dart';
import 'package:smartflow/widget/business/transaction/transaction_day_card.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../view_model/home_view_model.dart';
import '../widget/home_header.dart';
import '../widget/monthly_summary_card.dart';

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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HomeHeader(
              visibleMonth: state.visibleMonth,
              onMonthPressed: _pickMonth,
              onPreviousMonth: () => _shiftMonth(-1),
              onNextMonth: () => _shiftMonth(1),
            ),
            Expanded(
              child: switch (content) {
                HomeContentLoaded(:final summary, :final groups) =>
                  _HomeContent(summary: summary, groups: groups),
                HomeContentError(:final message) => Center(
                  child: Text(message),
                ),
                HomeContentLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transaction/new'),
        tooltip: '新建记账',
        shape: const CircleBorder(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(RemixIcons.add_line),
      ),
    );
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

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.summary, required this.groups});

  final MonthlySummaryPresentation summary;
  final List<TransactionDayGroup> groups;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        AppSpacing.space24 + 56, // 留给 FAB
      ),
      children: [
        MonthlySummaryCard(summary: summary),
        const SizedBox(height: AppSpacing.space20),
        if (groups.isEmpty)
          const EmptyTransactionCard()
        else
          for (final group in groups) ...[
            TransactionDayCard(group: group),
            const SizedBox(height: AppSpacing.space10),
          ],
      ],
    );
  }
}
