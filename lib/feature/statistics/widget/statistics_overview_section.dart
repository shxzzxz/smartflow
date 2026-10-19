import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../feature/shared/presentation/transaction_list_presentation.dart';
import '../../../widget/business/finance/adaptive_money_text.dart';
import '../../../widget/business/finance/finance_tone.dart';
import '../../../widget/business/finance/finance_tone_color.dart';
import '../presentation/statistics_period_presentation.dart';
import '../presentation/statistics_presentation.dart';

class StatisticsOverviewSection extends StatelessWidget {
  const StatisticsOverviewSection({
    required this.overview,
    required this.comparison,
    super.key,
  });

  final StatisticsOverviewPresentation overview;
  final StatisticsComparisonPresentation? comparison;

  @override
  Widget build(BuildContext context) {
    final summary = overview.cashflowComparison.current;
    return AppSurface(
      key: const ValueKey('statistics-overview-card'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space16,
          vertical: AppSpacing.space16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OverviewSummary(summary: summary, comparison: comparison),
            const SizedBox(height: AppSpacing.space16),
            _KpiStrip(kpis: overview.kpis),
          ],
        ),
      ),
    );
  }
}

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({required this.summary, required this.comparison});

  final CashflowSummary summary;
  final StatisticsComparisonPresentation? comparison;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        id: 'expense',
        label: '支出',
        amount: summary.expense,
        tone: FinanceTone.expense,
        change: comparison == null
            ? null
            : PeriodChange(
                current: summary.expense,
                previous: comparison!.cashflow.expense,
              ),
      ),
      (
        id: 'income',
        label: '收入',
        amount: summary.income,
        tone: FinanceTone.income,
        change: comparison == null
            ? null
            : PeriodChange(
                current: summary.income,
                previous: comparison!.cashflow.income,
              ),
      ),
      (
        id: 'net',
        label: '结余',
        amount: summary.net,
        tone: FinanceTone.neutral,
        change: comparison == null
            ? null
            : PeriodChange(current: summary.net, previous: comparison!.net),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final dividersWidth =
            (metrics.length - 1) * (AppSpacing.space12 * 2 + 1);
        final metricWidth =
            (constraints.maxWidth - dividersWidth) / metrics.length;
        return IntrinsicHeight(
          child: Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                if (index > 0) const _OverviewVerticalDivider(),
                Expanded(
                  child: _OverviewMetric(
                    id: metrics[index].id,
                    label: metrics[index].label,
                    amount: metrics[index].amount,
                    tone: metrics[index].tone,
                    change: metrics[index].change,
                    maxWidth: metricWidth,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.id,
    required this.label,
    required this.amount,
    required this.tone,
    required this.change,
    required this.maxWidth,
  });

  final String id;
  final String label;
  final Money amount;
  final FinanceTone tone;
  final PeriodChange? change;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.appTextStyles.metricLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space6),
        SummaryMoneyText(
          money: amount,
          style: context.appTextStyles.metricValue.copyWith(
            color: financeToneColor(colors, financeColors, tone),
          ),
          maxWidth: maxWidth,
        ),
        if (change case final change?) ...[
          const SizedBox(height: AppSpacing.space6),
          Text(
            _overviewChangeAmount(change),
            key: ValueKey('statistics-overview-$id-change-amount'),
            style: context.appTextStyles.listSupporting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            formatSignedOptionalPercent(change.ratio),
            key: ValueKey('statistics-overview-$id-change-ratio'),
            style: context.appTextStyles.listSupporting.copyWith(
              color: colors.onSurfaceVariant.withValues(alpha: .75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

String _overviewChangeAmount(PeriodChange change) {
  if (change.isFlat) return '持平';
  if (change.previous.minorUnits == 0 && change.current.minorUnits > 0) {
    return '新增 ${formatCompactMoney(change.current)}';
  }
  return formatSignedCompactAmount(change.delta.minorUnits);
}

class _OverviewVerticalDivider extends StatelessWidget {
  const _OverviewVerticalDivider();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space4,
      ),
      color: colors.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final StatisticsCashflowKpis kpis;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('statistics-overview-daily'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _KpiMetric(label: '日均支出', amount: kpis.dailyAverageExpense),
        ),
        const SizedBox(width: AppSpacing.space8),
        Expanded(
          child: _KpiMetric(label: '日均收入', amount: kpis.dailyAverageIncome),
        ),
        const SizedBox(width: AppSpacing.space8),
        Expanded(
          child: _KpiMetric(label: '最高单日支出', amount: kpis.maxDailyExpense),
        ),
      ],
    );
  }
}

class _KpiMetric extends StatelessWidget {
  const _KpiMetric({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.appTextStyles.metricLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.space4),
          SummaryMoneyText(
            money: amount,
            style: context.appTextStyles.amountList,
            maxWidth: constraints.maxWidth,
          ),
        ],
      ),
    );
  }
}
