import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_month_picker.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_text.dart';
import '../presentation/statistics_presentation.dart';
import '../view_model/statistics_view_model.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statisticsPageProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StatisticsHeader(
              visibleMonth: state.visibleMonth,
              section: state.section,
              onPreviousMonth:
                  () => ref
                      .read(statisticsViewModelProvider.notifier)
                      .shiftMonth(-1),
              onNextMonth:
                  () => ref
                      .read(statisticsViewModelProvider.notifier)
                      .shiftMonth(1),
              onMonthPressed: () => _pickMonth(context, ref),
              onSectionChanged:
                  (section) => ref
                      .read(statisticsViewModelProvider.notifier)
                      .selectSection(section),
            ),
            Expanded(
              child: switch (state.content) {
                StatisticsContentLoaded(:final presentation) =>
                  state.section == StatisticsSection.cashflow
                      ? _CashflowContent(presentation: presentation)
                      : _BalanceContent(presentation: presentation),
                StatisticsContentError(:final message) => Center(
                  child: Text(message),
                ),
                StatisticsContentLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context, WidgetRef ref) async {
    final selected = await showAppMonthPicker(
      context: context,
      initialMonth: ref.read(statisticsViewModelProvider).visibleMonth,
    );
    if (selected == null) return;
    ref.read(statisticsViewModelProvider.notifier).pickMonth(selected);
  }
}

class _StatisticsHeader extends StatelessWidget {
  const _StatisticsHeader({
    required this.visibleMonth,
    required this.section,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onMonthPressed,
    required this.onSectionChanged,
  });

  final DateTime visibleMonth;
  final StatisticsSection section;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onMonthPressed;
  final ValueChanged<StatisticsSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space10,
        AppSpacing.space16,
        AppSpacing.space12,
      ),
      child: Column(
        children: [
          AppMonthSelector(
            visibleMonth: visibleMonth,
            onPreviousMonth: onPreviousMonth,
            onMonthPressed: onMonthPressed,
            onNextMonth: onNextMonth,
          ),
          const SizedBox(height: AppSpacing.space12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<StatisticsSection>(
              segments: const [
                ButtonSegment(
                  value: StatisticsSection.cashflow,
                  label: Text('收支'),
                ),
                ButtonSegment(
                  value: StatisticsSection.balance,
                  label: Text('资产'),
                ),
              ],
              selected: {section},
              showSelectedIcon: false,
              onSelectionChanged:
                  (selected) => onSectionChanged(selected.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashflowContent extends StatelessWidget {
  const _CashflowContent({required this.presentation});

  final StatisticsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final summary = presentation.cashflowComparison.current;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        _SummaryCard(
          metrics: [
            _SummaryValue(
              '收入',
              summary.income,
              MoneySemantic.income,
              presentation.incomeChangeText,
            ),
            _SummaryValue(
              '支出',
              summary.expense,
              MoneySemantic.expense,
              presentation.expenseChangeText,
            ),
            _SummaryValue('结余', summary.net, MoneySemantic.neutral),
          ],
        ),
        const SizedBox(height: AppSpacing.space20),
        const _SectionTitle('收支趋势'),
        const SizedBox(height: AppSpacing.space8),
        _DailyCashflowList(items: presentation.dailySummaries),
        const SizedBox(height: AppSpacing.space20),
        const _SectionTitle('支出分类'),
        const SizedBox(height: AppSpacing.space8),
        _BreakdownList(
          items: presentation.expenseCategories,
          semantic: MoneySemantic.expense,
          onTap:
              (item) => _openDrilldown(
                context,
                item,
                occurredFrom: presentation.cashflowFrom,
                occurredUntil: presentation.cashflowUntil,
                scope: StatisticsDrilldownScope.cashflow,
              ),
        ),
        const SizedBox(height: AppSpacing.space20),
        const _SectionTitle('收入分类'),
        const SizedBox(height: AppSpacing.space8),
        _BreakdownList(
          items: presentation.incomeCategories,
          semantic: MoneySemantic.income,
          onTap:
              (item) => _openDrilldown(
                context,
                item,
                occurredFrom: presentation.cashflowFrom,
                occurredUntil: presentation.cashflowUntil,
                scope: StatisticsDrilldownScope.cashflow,
              ),
        ),
      ],
    );
  }
}

class _BalanceContent extends StatelessWidget {
  const _BalanceContent({required this.presentation});

  final StatisticsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final summary = presentation.balanceComparison.current;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        0,
        AppSpacing.space16,
        AppSpacing.space24,
      ),
      children: [
        _SummaryCard(
          metrics: [
            _SummaryValue('资产', summary.assets, MoneySemantic.asset),
            _SummaryValue('负债', summary.liabilities, MoneySemantic.liability),
            _SummaryValue(
              '净资产',
              summary.netAssets,
              MoneySemantic.equity,
              presentation.netAssetChangeText,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space20),
        const _SectionTitle('净资产趋势'),
        const SizedBox(height: AppSpacing.space8),
        _NetAssetTrendList(items: presentation.netAssetTrend),
        const SizedBox(height: AppSpacing.space20),
        const _SectionTitle('账户分布'),
        const SizedBox(height: AppSpacing.space8),
        _BreakdownList(
          items: presentation.balanceAccounts,
          semantic: MoneySemantic.neutral,
          onTap:
              (item) => _openDrilldown(
                context,
                item,
                occurredUntil: presentation.balanceUntil,
                scope: StatisticsDrilldownScope.balance,
              ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.metrics});

  final List<_SummaryValue> metrics;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Row(
          children: [
            for (var index = 0; index < metrics.length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.space12),
              Expanded(child: _SummaryMetric(value: metrics[index])),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.value});

  final _SummaryValue value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value.label, style: context.appTextStyles.metricLabel),
        const SizedBox(height: AppSpacing.space6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MoneyText(
            money: value.amount,
            semantic: value.semantic,
            style: context.appTextStyles.metricValue,
          ),
        ),
        if (value.caption != null) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            value.caption!,
            style: context.appTextStyles.metricSupporting.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: context.appTextStyles.sectionTitle);
  }
}

class _DailyCashflowList extends StatelessWidget {
  const _DailyCashflowList({required this.items});

  final List<DailyCashflowSummary> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptySurface(message: '本月暂无收支数据');
    return AppSurface(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            _MetricRow(
              label: '${items[index].date.day}日',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoneyText(
                    money: items[index].income,
                    semantic: MoneySemantic.income,
                    style: context.appTextStyles.listSupporting,
                  ),
                  const SizedBox(width: AppSpacing.space12),
                  MoneyText(
                    money: items[index].expense,
                    semantic: MoneySemantic.expense,
                    style: context.appTextStyles.listSupporting,
                  ),
                ],
              ),
              showDivider: index < items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _NetAssetTrendList extends StatelessWidget {
  const _NetAssetTrendList({required this.items});

  final List<NetAssetTrendPoint> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptySurface(message: '暂无净资产趋势');
    return AppSurface(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            _MetricRow(
              label: '${items[index].month.year}年${items[index].month.month}月',
              trailing: MoneyText(
                money: items[index].netAssets,
                semantic: MoneySemantic.equity,
                style: context.appTextStyles.amountList,
              ),
              showDivider: index < items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({
    required this.items,
    required this.semantic,
    required this.onTap,
  });

  final List<StatisticsBreakdownItem> items;
  final MoneySemantic semantic;
  final ValueChanged<StatisticsBreakdownItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptySurface(message: '暂无数据');
    return AppSurface(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++)
            _BreakdownRow(
              item: items[index],
              semantic: semantic,
              showDivider: index < items.length - 1,
              onTap: () => onTap(items[index]),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.item,
    required this.semantic,
    required this.showDivider,
    required this.onTap,
  });

  final StatisticsBreakdownItem item;
  final MoneySemantic semantic;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(item.title)),
                MoneyText(
                  money: item.amount,
                  semantic: semantic,
                  style: context.appTextStyles.amountList,
                ),
                const SizedBox(width: AppSpacing.space4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: AppSpacing.space20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space8),
            LinearProgressIndicator(
              value: item.progress,
              minHeight: AppSpacing.space4,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            ),
            if (showDivider) const SizedBox(height: AppSpacing.space2),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.trailing,
    required this.showDivider,
  });

  final String label;
  final Widget trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space16,
            vertical: AppSpacing.space12,
          ),
          child: Row(children: [Expanded(child: Text(label)), trailing]),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: AppSpacing.space16,
            color: colors.outlineVariant,
          ),
      ],
    );
  }
}

class _EmptySurface extends StatelessWidget {
  const _EmptySurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space20),
        child: Center(
          child: Text(
            message,
            style: context.appTextStyles.listSupporting.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryValue {
  const _SummaryValue(this.label, this.amount, this.semantic, [this.caption]);

  final String label;
  final Money amount;
  final MoneySemantic semantic;
  final String? caption;
}

void _openDrilldown(
  BuildContext context,
  StatisticsBreakdownItem item, {
  DateTime? occurredFrom,
  required DateTime occurredUntil,
  required StatisticsDrilldownScope scope,
}) {
  final ids = (item.accountIds.toList()..sort()).join(',');
  final uri = Uri(
    path: '/statistics/transactions',
    queryParameters: {
      'accountIds': ids,
      if (occurredFrom != null) 'from': occurredFrom.toIso8601String(),
      'until': occurredUntil.toIso8601String(),
      'title': item.title,
      'scope': scope.name,
    },
  );
  context.push(uri.toString());
}
