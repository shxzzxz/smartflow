import 'package:flutter/material.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/chart.dart';
import '../../../design_system/token/spacing.dart';
import '../../../widget/business/analytics/category_progress_list_item.dart';
import '../../../widget/business/finance/adaptive_money_text.dart';
import '../presentation/statistics_period_presentation.dart';
import '../presentation/statistics_presentation.dart';

class StatisticsCategoryRow extends StatelessWidget {
  const StatisticsCategoryRow({
    required this.item,
    required this.color,
    required this.trailing,
    required this.onTap,
    this.comparisonLabel,
    super.key,
  });

  final StatisticsBreakdownItem item;
  final Color color;
  final Widget trailing;
  final VoidCallback onTap;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final baseline = item.comparisonAmount;
    return CategoryProgressListItem(
      title: item.title,
      titleTrailing: comparisonLabel == null || baseline == null
          ? null
          : _CategoryComparisonText(
              key: ValueKey('statistics-breakdown-comparison-${item.id}'),
              item: item,
              baseline: baseline,
              comparisonLabel: comparisonLabel!,
            ),
      titleWidth: AppChartGeometry.categoryNameColumnWidth,
      titleTrailingGap: AppSpacing.space4,
      progress: item.progress,
      color: color,
      trailing: trailing,
      trailingGap: AppSpacing.space4,
      trailingWidth: AppChartGeometry.categoryAmountColumnWidth,
      onTap: onTap,
    );
  }
}

class _CategoryComparisonText extends StatelessWidget {
  const _CategoryComparisonText({
    required this.item,
    required this.baseline,
    required this.comparisonLabel,
    super.key,
  });

  final StatisticsBreakdownItem item;
  final Money baseline;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final change = PeriodChange(current: item.amount, previous: baseline);
    final style = context.appTextStyles.listSupporting;
    final prefix = statisticsComparisonChangePrefix(comparisonLabel);
    if (change.isFlat) {
      final text = '$prefix持平';
      return Tooltip(
        message: text,
        child: Text(text, style: style, maxLines: 1),
      );
    }

    final isNew = baseline.minorUnits == 0 && item.amount.minorUnits > 0;
    final label = isNew
        ? '新增'
        : change.delta.minorUnits > 0
        ? '$prefix增加'
        : '$prefix减少';
    final amount = isNew ? item.amount : change.delta.abs();
    final preciseText = formatMoney(amount, style: MoneyFormatStyle.plain);
    final compactText = formatMoney(amount, style: MoneyFormatStyle.compact);
    return Tooltip(
      message: '$label $preciseText',
      child: Row(
        children: [
          Text(label, style: style, maxLines: 1),
          const SizedBox(width: AppSpacing.space4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => AdaptiveMoneyText(
                preciseText: preciseText,
                compactText: compactText,
                style: style,
                fallbackStyle: style,
                maxWidth: constraints.maxWidth,
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
