import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/provider.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../application/ledger/ledger_api.dart';
import '../view_model/home_transaction_group.dart';
import '../widget/empty_transaction_card.dart';
import '../widget/home_header.dart';
import '../widget/monthly_summary_card.dart';
import '../widget/transaction_day_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(
      homeMonthTransactionsProvider(
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      ),
    );
    final summaryAsync = ref.watch(
      homeMonthCashflowComparisonProvider(
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      ),
    );
    final dailySummariesAsync = ref.watch(
      homeMonthDailyCashflowSummariesProvider(
        year: _visibleMonth.year,
        month: _visibleMonth.month,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HomeHeader(
              visibleMonth: _visibleMonth,
              onMonthPressed: _pickMonth,
              onPreviousMonth: () => _shiftMonth(-1),
              onNextMonth: () => _shiftMonth(1),
            ),
            Expanded(
              child: switch ((
                transactionsAsync,
                summaryAsync,
                dailySummariesAsync,
              )) {
                (
                  AsyncData(:final value),
                  AsyncData(value: final comparison),
                  AsyncData(value: final dailySummaries),
                ) =>
                  _HomeContent(
                    transactions: value,
                    comparison: comparison,
                    dailySummaries: dailySummaries,
                  ),
                (AsyncError(:final error), _, _) ||
                (_, AsyncError(:final error), _) ||
                (
                  _,
                  _,
                  AsyncError(:final error),
                ) => Center(child: Text('加载失败：$error')),
                _ => const Center(child: CircularProgressIndicator()),
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
      initialMonth: _visibleMonth,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _visibleMonth = DateTime(selected.year, selected.month);
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.transactions,
    required this.comparison,
    required this.dailySummaries,
  });

  final List<TransactionListItem> transactions;
  final CashflowComparison comparison;
  final List<DailyCashflowSummary> dailySummaries;

  @override
  Widget build(BuildContext context) {
    final groups = groupTransactionsByDay(transactions, dailySummaries);

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
        MonthlySummaryCard(comparison: comparison),
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
